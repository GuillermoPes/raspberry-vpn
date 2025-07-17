#!/bin/bash

# ========================================================================
# 🏠 Raspberry Pi VPN Server - Instalación Automatizada Interactiva
# ========================================================================
# 
# Este script instala y configura completamente el sistema VPN sin
# necesidad de editar archivos manualmente.
#
# Uso: sudo ./setup.sh
#
# Autor: Sistema de automatización
# ========================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuración
WORK_DIR="/opt/vpn-server"
INSTALL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
PROJECT_NAME="raspberry-vpn"

# Variables globales para configuración
PIHOLE_PASSWORD=""
TIMEZONE="Europe/Madrid"
WIREGUARD_PEERS="5"
PUBLIC_IP=""
DOMAIN_NAME=""
USE_DOMAIN="false"
USE_DUCKDNS="false"
DUCKDNS_DOMAIN=""
DUCKDNS_TOKEN=""

# ========================================================================
# FUNCIONES AUXILIARES
# ========================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║          🏠 RASPBERRY PI VPN SERVER - INSTALACIÓN AUTOMÁTICA          ║"
    echo "║                                                                      ║"
    echo "║  📦 Servicios incluidos:                                             ║"
    echo "║  • WireGuard VPN Server                                              ║"
    echo "║  • Pi-hole (Bloqueo de anuncios)                                     ║"
    echo "║  • Unbound (DNS recursivo)                                           ║"
    echo "║  • Portainer (Gestión Docker)                                        ║"
    echo "║  • Nginx Proxy Manager                                               ║"
    echo "║  • Watchtower (Actualizaciones automáticas)                          ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[PASO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

press_enter() {
    echo -e "${YELLOW}Presiona Enter para continuar...${NC}"
    read
}

# ========================================================================
# VERIFICACIONES INICIALES
# ========================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script debe ejecutarse como root (sudo ./setup.sh)"
        exit 1
    fi
}

check_system() {
    log_step "Verificando sistema..."
    
    # Detectar usuario actual
    if [[ -z "$INSTALL_USER" ]]; then
        INSTALL_USER=$(whoami)
        if [[ "$INSTALL_USER" == "root" ]]; then
            log_error "No se pudo detectar el usuario original"
            echo -n "Introduce tu nombre de usuario: "
            read -r INSTALL_USER
        fi
    fi
    
    log_info "Usuario detectado: $INSTALL_USER"
    
    # Verificar instalación existente
    if [ -d "$WORK_DIR" ]; then
        log_warning "Instalación existente encontrada en $WORK_DIR"
        echo ""
        echo "Opciones:"
        echo "1. Continuar (actualizar configuración)"
        echo "2. Hacer backup y reinstalar"
        echo "3. Cancelar instalación"
        echo ""
        echo -n "Selecciona una opción (1-3) [1]: "
        read -r install_choice
        
        case "${install_choice:-1}" in
            1)
                log_info "Continuando con instalación existente..."
                ;;
            2)
                log_info "Creando backup de instalación existente..."
                backup_file="$WORK_DIR-backup-$(date +%Y%m%d-%H%M%S)"
                mv "$WORK_DIR" "$backup_file"
                log_success "Backup creado: $backup_file"
                ;;
            3)
                log_info "Instalación cancelada"
                exit 0
                ;;
            *)
                log_info "Opción inválida, continuando..."
                ;;
        esac
    fi
    
    # Detectar arquitectura del sistema
    ARCH=$(uname -m)
    log_info "Arquitectura detectada: $ARCH"
    
    # Verificar compatibilidad
    case $ARCH in
        armv7l|armv6l)
            log_info "Sistema ARM32 detectado - Compatible"
            ;;
        aarch64)
            log_info "Sistema ARM64 detectado - Compatible"
            ;;
        x86_64)
            log_warning "Sistema x86_64 detectado - No es Raspberry Pi"
            echo -n "¿Continuar en este sistema? (y/N): "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "Instalación cancelada"
                exit 0
            fi
            ;;
        *)
            log_error "Arquitectura no soportada: $ARCH"
            exit 1
            ;;
    esac
    
    # Verificar que es una Raspberry Pi (opcional)
    if [[ -f /proc/cpuinfo ]] && grep -q "Raspberry Pi" /proc/cpuinfo; then
        local rpi_model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
        log_info "Raspberry Pi detectada: $rpi_model"
    fi
    
    # Verificar dependencias básicas críticas
    local critical_deps=("curl" "wget" "git" "ufw")
    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_info "Instalando dependencia crítica: $dep..."
            apt update -qq
            apt install -y "$dep"
        fi
    done
    
    log_success "Sistema verificado correctamente"
}

detect_network_info() {
    log_step "Detectando información de red..."
    
    # Detectar IP pública
    PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "")
    if [[ -z "$PUBLIC_IP" ]]; then
        PUBLIC_IP=$(curl -s --max-time 10 ipinfo.io/ip 2>/dev/null || echo "")
    fi
    
    # Detectar IP local
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    log_success "Información de red detectada"
    echo "  IP Local: $LOCAL_IP"
    echo "  IP Pública: ${PUBLIC_IP:-"No detectada"}"
}

# ========================================================================
# RECOPILACIÓN DE INFORMACIÓN DEL USUARIO
# ========================================================================

welcome_message() {
    print_banner
    echo -e "${CYAN}¡Bienvenido al instalador automático!${NC}"
    echo ""
    echo "Este script configurará completamente tu servidor VPN casero."
    echo "Te haré algunas preguntas para personalizar la instalación."
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo "• Asegúrate de tener abierto el puerto 51820/UDP en tu router"
    echo "• Es recomendable configurar IP fija para esta Raspberry Pi"
    echo "• La instalación tardará entre 5-15 minutos dependiendo de tu conexión"
    echo ""
    press_enter
}

collect_pihole_config() {
    clear
    echo -e "${CYAN}📋 Configuración de Pi-hole${NC}"
    echo ""
    echo "Pi-hole bloqueará anuncios y será tu servidor DNS interno."
    echo ""
    
    while true; do
        echo -n "Introduce una contraseña segura para Pi-hole: "
        read -s PIHOLE_PASSWORD
        echo ""
        
        if [[ ${#PIHOLE_PASSWORD} -lt 8 ]]; then
            log_error "La contraseña debe tener al menos 8 caracteres"
            continue
        fi
        
        echo -n "Confirma la contraseña: "
        read -s password_confirm
        echo ""
        
        if [[ "$PIHOLE_PASSWORD" == "$password_confirm" ]]; then
            log_success "Contraseña de Pi-hole configurada"
            break
        else
            log_error "Las contraseñas no coinciden"
        fi
    done
    
    echo ""
    press_enter
}

collect_timezone() {
    clear
    echo -e "${CYAN}🌍 Configuración de zona horaria${NC}"
    echo ""
    echo "Zona horaria actual detectada: $(timedatectl show --property=Timezone --value 2>/dev/null || echo "No detectada")"
    echo ""
    echo -n "Introduce tu zona horaria (ej: Europe/Madrid, America/New_York) [${TIMEZONE}]: "
    read -r input_timezone
    
    if [[ -n "$input_timezone" ]]; then
        TIMEZONE="$input_timezone"
    fi
    
    log_success "Zona horaria configurada: $TIMEZONE"
    echo ""
    press_enter
}

collect_wireguard_config() {
    clear
    echo -e "${CYAN}🔒 Configuración de WireGuard VPN${NC}"
    echo ""
    echo "WireGuard creará configuraciones para tus dispositivos."
    echo ""
    
    while true; do
        echo -n "¿Cuántos clientes VPN quieres generar? (1-10) [${WIREGUARD_PEERS}]: "
        read -r input_peers
        
        if [[ -z "$input_peers" ]]; then
            break
        fi
        
        if [[ "$input_peers" =~ ^[1-9]$|^10$ ]]; then
            WIREGUARD_PEERS="$input_peers"
            break
        else
            log_error "Introduce un número entre 1 y 10"
        fi
    done
    
    log_success "Configuración WireGuard: $WIREGUARD_PEERS clientes"
    echo ""
    press_enter
}

collect_network_config() {
    clear
    echo -e "${CYAN}🌐 Configuración de red${NC}"
    echo ""
    echo "Para que los clientes VPN puedan conectarse, necesito conocer"
    echo "tu IP pública o dominio."
    echo ""
    
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "${GREEN}IP pública detectada: $PUBLIC_IP${NC}"
        echo ""
        echo "Opciones:"
        echo "1. Usar IP pública detectada ($PUBLIC_IP)"
        echo "2. Introducir dominio personalizado (recomendado)"
        echo "3. Introducir IP/dominio manualmente"
        echo ""
        echo -n "Selecciona una opción (1-3) [1]: "
        read -r network_choice
        
        case "${network_choice:-1}" in
            1)
                DOMAIN_NAME="$PUBLIC_IP"
                USE_DOMAIN="false"
                ;;
            2)
                echo ""
                echo "Servicios DDNS recomendados:"
                echo "• DuckDNS (duckdns.org) - Gratuito"
                echo "• No-IP (noip.com) - Gratuito"
                echo "• Cloudflare - Gratuito"
                echo ""
                echo -n "Introduce tu dominio (ej: miservidor.duckdns.org): "
                read -r DOMAIN_NAME
                USE_DOMAIN="true"
                
                # Detectar DuckDNS y pedir token automáticamente
                echo "DEBUG: Dominio introducido: $DOMAIN_NAME"
                if [[ "$DOMAIN_NAME" == *"duckdns.org"* ]]; then
                    echo "DEBUG: DuckDNS detectado, llamando función..."
                    configure_duckdns_auto_update
                else
                    echo "DEBUG: DuckDNS NO detectado"
                fi
                ;;
            3)
                echo -n "Introduce IP pública o dominio: "
                read -r DOMAIN_NAME
                if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    USE_DOMAIN="false"
                else
                    USE_DOMAIN="true"
                    
                    # Detectar DuckDNS y pedir token automáticamente
                    echo "DEBUG: Dominio introducido: $DOMAIN_NAME"
                    if [[ "$DOMAIN_NAME" == *"duckdns.org"* ]]; then
                        echo "DEBUG: DuckDNS detectado, llamando función..."
                        configure_duckdns_auto_update
                    else
                        echo "DEBUG: DuckDNS NO detectado"
                    fi
                fi
                ;;
            *)
                DOMAIN_NAME="$PUBLIC_IP"
                USE_DOMAIN="false"
                ;;
        esac
    else
        echo -e "${YELLOW}No se pudo detectar tu IP pública automáticamente${NC}"
        echo ""
        echo -n "Introduce tu IP pública o dominio: "
        read -r DOMAIN_NAME
        
        if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            USE_DOMAIN="false"
        else
            USE_DOMAIN="true"
            
            # Detectar DuckDNS y pedir token automáticamente
            echo "DEBUG: Dominio introducido: $DOMAIN_NAME"
            if [[ "$DOMAIN_NAME" == *"duckdns.org"* ]]; then
                echo "DEBUG: DuckDNS detectado, llamando función..."
                configure_duckdns_auto_update
            else
                echo "DEBUG: DuckDNS NO detectado"
            fi
        fi
    fi
    
    if [[ -z "$DOMAIN_NAME" ]]; then
        log_error "Debe introducir una IP pública o dominio"
        collect_network_config
        return
    fi
    
    log_success "Configuración de red: $DOMAIN_NAME"
    echo ""
    press_enter
}

show_configuration_summary() {
    clear
    echo -e "${CYAN}📋 Resumen de configuración${NC}"
    echo ""
    echo "Por favor, revisa la configuración antes de continuar:"
    echo ""
    echo -e "${GREEN}Sistema:${NC}"
    echo "  • Zona horaria: $TIMEZONE"
    echo "  • Directorio de instalación: $WORK_DIR"
    echo ""
    echo -e "${GREEN}Pi-hole:${NC}"
    echo "  • Contraseña: [Configurada]"
    echo "  • Puerto web: 8080"
    echo ""
    echo -e "${GREEN}WireGuard:${NC}"
    echo "  • Número de clientes: $WIREGUARD_PEERS"
    echo "  • Servidor: $DOMAIN_NAME"
    echo "  • Puerto: 51820/UDP"
    echo ""
    
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        echo -e "${GREEN}DuckDNS:${NC}"
        echo "  • Dominio: $DUCKDNS_DOMAIN.duckdns.org"
        echo "  • Actualización automática: Habilitada (cada 5 min)"
        echo "  • Token: [Configurado]"
        echo ""
    fi
    echo -e "${GREEN}Otros servicios:${NC}"
    echo "  • Portainer: Puerto 9000"
    echo "  • Nginx Proxy Manager: Puerto 81"
    echo "  • Unbound DNS: Puerto 5335"
    echo ""
    
    echo -n "¿Es correcta esta configuración? (Y/n): "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_info "Reiniciando configuración..."
        collect_user_input
        return
    fi
    
    log_success "Configuración confirmada"
    echo ""
    press_enter
}

configure_duckdns_auto_update() {
    echo "DEBUG: Ejecutando función configure_duckdns_auto_update()"
    echo ""
    echo -e "${GREEN}🦆 DuckDNS detectado!${NC}"
    echo ""
    
    # Extraer subdominio
    DUCKDNS_DOMAIN=$(echo "$DOMAIN_NAME" | cut -d'.' -f1)
    echo "Dominio DuckDNS: $DUCKDNS_DOMAIN"
    echo ""
    
    echo "Para habilitar actualización automática de IP necesitas tu token de DuckDNS."
    echo ""
    echo -e "${YELLOW}¿Cómo obtener tu token DuckDNS?${NC}"
    echo "1. Ve a https://www.duckdns.org/"
    echo "2. Inicia sesión con tu cuenta"
    echo "3. Copia el token que aparece en la parte superior"
    echo ""
    
    while true; do
        echo -n "Introduce tu token de DuckDNS (o 'skip' para omitir): "
        read -r DUCKDNS_TOKEN
        
        if [[ "$DUCKDNS_TOKEN" == "skip" ]]; then
            log_warning "Actualización automática de DuckDNS omitida"
            USE_DUCKDNS="false"
            break
        elif [[ ${#DUCKDNS_TOKEN} -eq 36 ]]; then
            log_info "Verificando token DuckDNS..."
            
            # Verificar token haciendo una actualización de prueba
            local test_result=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=")
            
            if [[ "$test_result" == "OK" ]]; then
                log_success "Token DuckDNS verificado correctamente"
                USE_DUCKDNS="true"
                break
            else
                log_error "Token DuckDNS inválido. Inténtalo de nuevo."
            fi
        else
            log_error "Token inválido. Debe tener 36 caracteres."
        fi
    done
}

collect_user_input() {
    welcome_message
    collect_pihole_config
    collect_timezone
    collect_wireguard_config
    collect_network_config
    show_configuration_summary
}

# ========================================================================
# INSTALACIÓN DEL SISTEMA
# ========================================================================

install_dependencies() {
    log_step "Instalando dependencias del sistema..."
    
    # Actualizar lista de paquetes solo si es necesario
    local last_update=$(stat -c %Y /var/lib/apt/lists 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local hours_since_update=$(( (current_time - last_update) / 3600 ))
    
    if [ $hours_since_update -gt 24 ]; then
        log_info "Actualizando lista de paquetes (última actualización: hace $hours_since_update horas)..."
        apt update
    else
        log_info "Lista de paquetes actualizada recientemente (hace $hours_since_update horas)"
    fi
    
    # Verificar si hay actualizaciones pendientes
    local upgrades=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ $upgrades -gt 1 ]; then
        log_info "Hay $((upgrades-1)) actualizaciones disponibles. Actualizando..."
        apt upgrade -y
    else
        log_info "Sistema ya está actualizado"
    fi
    
    # Instalar paquetes necesarios (solo los que faltan)
    local packages=("curl" "wget" "git" "vim" "htop" "ca-certificates" "gnupg" "lsb-release" "iptables-persistent" "fail2ban" "qrencode" "ufw")
    local to_install=()
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            to_install+=("$package")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Instalando paquetes faltantes: ${to_install[*]}"
        apt install -y "${to_install[@]}"
    else
        log_info "Todos los paquetes necesarios ya están instalados"
    fi
    
    log_success "Dependencias verificadas/instaladas"
}

install_docker() {
    log_step "Instalando Docker..."
    
    # Verificar si Docker está instalado y funcionando
    if command -v docker &> /dev/null && docker --version &> /dev/null; then
        log_info "Docker ya está instalado: $(docker --version)"
        
        # Verificar si el usuario está en el grupo docker
        if ! groups "$INSTALL_USER" | grep -q docker; then
            log_info "Agregando usuario $INSTALL_USER al grupo docker..."
            usermod -aG docker "$INSTALL_USER"
        else
            log_info "Usuario $INSTALL_USER ya está en el grupo docker"
        fi
    else
        log_info "Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Agregar usuario al grupo docker
        if id "$INSTALL_USER" &>/dev/null; then
            usermod -aG docker "$INSTALL_USER"
            log_info "Usuario $INSTALL_USER agregado al grupo docker"
        else
            log_warning "Usuario $INSTALL_USER no encontrado, saltando configuración de grupo docker"
        fi
        
        log_success "Docker instalado"
    fi
}

install_docker_compose() {
    log_step "Instalando Docker Compose..."
    
    if command -v docker-compose &> /dev/null && docker-compose --version &> /dev/null; then
        log_info "Docker Compose ya está instalado: $(docker-compose --version)"
    else
        log_info "Instalando Docker Compose..."
        
        # Detectar arquitectura
        ARCH=$(uname -m)
        case $ARCH in
            armv7l)
                COMPOSE_ARCH="linux-armv7"
                ;;
            aarch64)
                COMPOSE_ARCH="linux-aarch64"
                ;;
            x86_64)
                COMPOSE_ARCH="linux-x86_64"
                ;;
            *)
                log_error "Arquitectura no soportada: $ARCH"
                exit 1
                ;;
        esac
        
        curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        log_success "Docker Compose instalado"
    fi
}

configure_firewall() {
    log_step "Configurando firewall..."
    
    # Verificar que UFW esté disponible
    if ! command -v ufw &> /dev/null; then
        log_error "UFW no está instalado. Instalando..."
        apt update -qq
        apt install -y ufw
    fi
    
    # Configurar UFW
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    
    # Puertos necesarios
    ufw allow ssh
    ufw allow 9000/tcp     # Portainer
    ufw allow 51820/udp    # WireGuard
    ufw allow 53/tcp       # DNS
    ufw allow 53/udp       # DNS
    ufw allow 80/tcp       # HTTP
    ufw allow 443/tcp      # HTTPS
    ufw allow 81/tcp       # Nginx Proxy Manager
    ufw allow 8080/tcp     # Pi-hole
    
    log_success "Firewall configurado"
}

configure_dns_resolution() {
    log_step "Configurando resolución DNS..."
    
    # Debug: Verificar estado actual del puerto 53
    echo "DEBUG: Verificando puerto 53..."
    if lsof -i :53 >/dev/null 2>&1; then
        echo "DEBUG: Puerto 53 ocupado por:"
        lsof -i :53
    else
        echo "DEBUG: Puerto 53 libre"
    fi
    
    # Verificar si systemd-resolved está ocupando el puerto 53
    if systemctl is-active --quiet systemd-resolved; then
        log_info "Configurando systemd-resolved para liberar puerto 53..."
        echo "DEBUG: systemd-resolved está activo"
        
        # Crear configuración personalizada para systemd-resolved
        cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=1.1.1.1 8.8.8.8
FallbackDNS=1.0.0.1 8.8.4.4
DNSStubListener=no
DNSStubListenerExtra=127.0.0.1:5353
Cache=yes
DNSSEC=no
ReadEtcHosts=yes
EOF
        
        # Reiniciar systemd-resolved para aplicar cambios
        echo "DEBUG: Reiniciando systemd-resolved..."
        systemctl restart systemd-resolved
        sleep 2
        
        # Configurar resolv.conf para que use Pi-hole cuando esté disponible
        rm -f /etc/resolv.conf
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        
        # Verificar que el puerto 53 ahora esté libre
        echo "DEBUG: Verificando puerto 53 después de configurar systemd-resolved..."
        if lsof -i :53 >/dev/null 2>&1; then
            echo "DEBUG: Puerto 53 AÚN ocupado por:"
            lsof -i :53
        else
            echo "DEBUG: Puerto 53 ahora libre"
        fi
        
        log_success "systemd-resolved configurado - Puerto 53 liberado"
    else
        log_info "systemd-resolved no está activo"
    fi
    
    # Verificar que el puerto 53 esté libre
    if lsof -i :53 >/dev/null 2>&1; then
        log_warning "Puerto 53 aún ocupado, intentando liberarlo..."
        
        # Intentar parar otros servicios DNS
        for service in dnsmasq bind9 unbound; do
            if systemctl is-active --quiet $service; then
                log_info "Parando servicio $service..."
                systemctl stop $service
                systemctl disable $service
            fi
        done
        
        # Verificar nuevamente
        if lsof -i :53 >/dev/null 2>&1; then
            echo "DEBUG: Puerto 53 sigue ocupado después de parar servicios:"
            lsof -i :53
            log_error "No se pudo liberar el puerto 53. Verifica manualmente:"
            log_error "sudo lsof -i :53"
            exit 1
        else
            echo "DEBUG: Puerto 53 finalmente libre"
        fi
    fi
    
    # Verificación final
    echo "DEBUG: Verificación final del puerto 53..."
    if lsof -i :53 >/dev/null 2>&1; then
        echo "DEBUG: PROBLEMA: Puerto 53 sigue ocupado:"
        lsof -i :53
        log_error "El puerto 53 sigue ocupado. Esto impedirá que Pi-hole funcione."
        exit 1
    else
        echo "DEBUG: ÉXITO: Puerto 53 completamente libre"
    fi
    
    log_success "Puerto 53 disponible para Pi-hole"
}

configure_system() {
    log_step "Configurando sistema..."
    
    # Configurar IP forwarding
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    echo 'net.ipv4.conf.all.src_valid_mark=1' >> /etc/sysctl.conf
    sysctl -p
    
    # Configurar fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    
    log_success "Sistema configurado"
}

create_directories() {
    log_step "Creando directorios..."
    
    # Crear estructura de directorios
    mkdir -p $WORK_DIR
    mkdir -p $WORK_DIR/wireguard-config
    mkdir -p $WORK_DIR/pihole/etc-pihole
    mkdir -p $WORK_DIR/pihole/etc-dnsmasq.d
    mkdir -p $WORK_DIR/unbound
    mkdir -p $WORK_DIR/nginx-proxy-manager/data
    mkdir -p $WORK_DIR/nginx-proxy-manager/letsencrypt
    
    log_success "Directorios creados"
}

generate_env_file() {
    log_step "Generando archivo de configuración..."
    
    cat > $WORK_DIR/.env << EOF
# Archivo de configuración generado automáticamente
# $(date)

# Configuración general
TZ=$TIMEZONE
PUID=1000
PGID=1000
COMPOSE_PROJECT_NAME=vpn-server

# Configuración de red
SERVERURL=$DOMAIN_NAME
PUBLIC_IP=$PUBLIC_IP

# Configuración de DuckDNS
USE_DUCKDNS=$USE_DUCKDNS
DUCKDNS_DOMAIN=$DUCKDNS_DOMAIN
DUCKDNS_TOKEN=$DUCKDNS_TOKEN

# Configuración de Pi-hole
PIHOLE_PASSWORD=$PIHOLE_PASSWORD
PIHOLE_DNS=10.13.13.3#5335

# Configuración de WireGuard
PEERS=$WIREGUARD_PEERS
SERVERPORT=51820
INTERNAL_SUBNET=10.14.14.0

# Configuración de red interna
PIHOLE_IP=10.13.13.100
UNBOUND_IP=10.13.13.3
WIREGUARD_IP=10.13.13.2

# Configuración de Watchtower
WATCHTOWER_POLL_INTERVAL=86400
EOF
    
    log_success "Archivo de configuración generado"
}

copy_configuration_files() {
    log_step "Copiando archivos de configuración..."
    
    # Lista de archivos a copiar (solo los que existen)
    local files_to_copy=("docker-compose.yml" "README.md" "DEMO-INSTALACION.md" "manage.sh" "config.env.example")
    
    # Copiar archivos individuales
    for file in "${files_to_copy[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$WORK_DIR/"
            log_info "Copiado: $file"
        else
            log_warning "Archivo no encontrado: $file"
        fi
    done
    
    # Copiar directorio unbound
    if [ -d "unbound" ]; then
        cp -r unbound "$WORK_DIR/"
        log_info "Copiado: directorio unbound"
    else
        log_warning "Directorio unbound no encontrado"
    fi
    
    # Hacer scripts ejecutables
    chmod +x "$WORK_DIR/manage.sh"
    
    # Configurar DuckDNS si está habilitado
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        setup_duckdns_updater
    fi
    
    # Descargar root hints para Unbound
    if [ -d "$WORK_DIR/unbound" ]; then
        wget -O "$WORK_DIR/unbound/root.hints" https://www.internic.net/domain/named.cache
        log_info "Descargado: root.hints para Unbound"
    else
        log_warning "Directorio unbound no existe, saltando descarga de root.hints"
    fi
    
    # Configurar permisos
    chown -R "$INSTALL_USER:$INSTALL_USER" "$WORK_DIR"
    
    log_success "Archivos copiados"
}

setup_duckdns_updater() {
    log_info "Configurando actualizador automático de DuckDNS..."
    
    # Crear script de actualización DuckDNS
    cat > "$WORK_DIR/duckdns-updater.sh" << 'EOF'
#!/bin/bash

# Script de actualización automática de DuckDNS
# Se ejecuta cada 5 minutos para verificar cambios de IP

# Cargar configuración
source /opt/vpn-server/.env

# Archivos de estado
IP_FILE="/opt/vpn-server/.current_ip"
LOG_FILE="/opt/vpn-server/duckdns.log"

# Función de log
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Obtener IP pública actual
CURRENT_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 ipinfo.io/ip 2>/dev/null)

if [[ -z "$CURRENT_IP" ]]; then
    log_message "ERROR: No se pudo obtener IP pública"
    exit 1
fi

# Leer IP anterior si existe
if [[ -f "$IP_FILE" ]]; then
    PREVIOUS_IP=$(cat "$IP_FILE")
else
    PREVIOUS_IP=""
fi

# Verificar si la IP cambió
if [[ "$CURRENT_IP" != "$PREVIOUS_IP" ]]; then
    log_message "Cambio de IP detectado: $PREVIOUS_IP -> $CURRENT_IP"
    
    # Actualizar DuckDNS
    RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=$CURRENT_IP")
    
    if [[ "$RESPONSE" == "OK" ]]; then
        log_message "DuckDNS actualizado correctamente: $DUCKDNS_DOMAIN.duckdns.org -> $CURRENT_IP"
        echo "$CURRENT_IP" > "$IP_FILE"
        
        # Actualizar configuración de WireGuard si es necesario
        if docker ps | grep -q wireguard; then
            log_message "Reiniciando WireGuard para aplicar nueva IP..."
            cd /opt/vpn-server
            docker-compose restart wireguard
        fi
    else
        log_message "ERROR: Falló actualización de DuckDNS: $RESPONSE"
    fi
else
    # IP no cambió, solo log cada hora (cada 12 ejecuciones de 5 min)
    MINUTE=$(date +%M)
    if [[ "$MINUTE" == "00" ]]; then
        log_message "IP sin cambios: $CURRENT_IP"
    fi
fi
EOF

    # Hacer el script ejecutable
    chmod +x "$WORK_DIR/duckdns-updater.sh"
    
    # Configurar cron job para ejecutar cada 5 minutos
    log_info "Configurando cron job para DuckDNS..."
    
    # Crear entrada de cron
    CRON_JOB="*/5 * * * * /opt/vpn-server/duckdns-updater.sh >/dev/null 2>&1"
    
    # Agregar a cron del usuario
    (crontab -u "$INSTALL_USER" -l 2>/dev/null; echo "$CRON_JOB") | crontab -u "$INSTALL_USER" -
    
    # Ejecutar una vez para configurar IP inicial
    log_info "Configurando IP inicial en DuckDNS..."
    sudo -u "$INSTALL_USER" "$WORK_DIR/duckdns-updater.sh"
    
    log_success "DuckDNS configurado - Verificación cada 5 minutos"
}

configure_system_dns() {
    log_step "Configurando DNS del sistema para usar Pi-hole..."
    
    # Esperar a que Pi-hole esté listo
    local max_wait=60
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        if docker exec pihole pihole status &>/dev/null; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # Detectar IP local
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Configurar el sistema para usar Pi-hole como DNS
    cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=$LOCAL_IP
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=no
DNSStubListenerExtra=127.0.0.1:5353
Cache=no
DNSSEC=no
ReadEtcHosts=yes
EOF
    
    # Reiniciar systemd-resolved
    systemctl restart systemd-resolved
    
    log_success "Sistema configurado para usar Pi-hole como DNS"
    log_info "DNS del sistema: $LOCAL_IP (Pi-hole)"
}

# ========================================================================
# INICIO DE SERVICIOS
# ========================================================================

start_services() {
    log_step "Iniciando servicios..."
    
    cd $WORK_DIR
    
    # Iniciar servicios
    docker-compose up -d
    
    # Esperar a que los servicios estén listos
    log_info "Esperando a que los servicios estén listos..."
    wait_for_services
    
    log_success "Servicios iniciados"
}

wait_for_services() {
    local max_wait=300  # 5 minutos máximo
    local elapsed=0
    local interval=10
    
    local services=("pihole" "unbound" "wireguard" "portainer")
    
    while [ $elapsed -lt $max_wait ]; do
        local all_healthy=true
        
        for service in "${services[@]}"; do
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$service" 2>/dev/null || echo "no-health")
            local status=$(docker inspect --format='{{.State.Status}}' "$service" 2>/dev/null || echo "not-running")
            
            if [[ "$health" == "healthy" ]] || [[ "$health" == "no-health" && "$status" == "running" ]]; then
                continue
            else
                all_healthy=false
                break
            fi
        done
        
        if [[ "$all_healthy" == true ]]; then
            log_success "Todos los servicios están listos"
            return 0
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    log_warning "Algunos servicios pueden tardar en estar completamente listos"
    log_info "Puedes verificar el estado con: docker-compose ps"
}

# ========================================================================
# INFORMACIÓN FINAL
# ========================================================================

show_final_info() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║                    🎉 ¡INSTALACIÓN COMPLETADA! 🎉                    ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Detectar IP local actual
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${CYAN}📋 Información de acceso:${NC}"
    echo ""
    echo -e "${GREEN}🌐 Pi-hole (Bloqueo de anuncios):${NC}"
    echo "   URL: http://$LOCAL_IP:8080/admin"
    echo "   Usuario: admin"
    echo "   Contraseña: [La que configuraste]"
    echo ""
    echo -e "${GREEN}🐳 Portainer (Gestión Docker):${NC}"
    echo "   URL: http://$LOCAL_IP:9000"
    echo "   (Crea tu usuario administrador en el primer acceso)"
    echo ""
    echo -e "${GREEN}🚀 Nginx Proxy Manager:${NC}"
    echo "   URL: http://$LOCAL_IP:81"
    echo "   Usuario: admin@example.com"
    echo "   Contraseña: changeme"
    echo ""
    echo -e "${GREEN}🔒 WireGuard VPN:${NC}"
    echo "   Servidor: $DOMAIN_NAME:51820"
    echo "   Clientes configurados: $WIREGUARD_PEERS"
    echo "   IP pública: $PUBLIC_IP"
    echo ""
    
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        echo -e "${GREEN}🦆 DuckDNS:${NC}"
        echo "   Dominio: $DUCKDNS_DOMAIN.duckdns.org"
        echo "   Actualización automática: ✅ Habilitada"
        echo "   Verificación: Cada 5 minutos"
        echo "   Logs: /opt/vpn-server/duckdns.log"
        echo ""
    fi
    
    echo -e "${YELLOW}📱 Para obtener códigos QR de tus clientes VPN:${NC}"
    echo "   cd $WORK_DIR && ./manage.sh"
    echo ""
    echo -e "${YELLOW}🔧 Para gestionar el sistema:${NC}"
    echo "   cd $WORK_DIR && ./manage.sh"
    echo ""
    
    echo -e "${CYAN}⚠️  Recuerda:${NC}"
    echo "• Abre el puerto 51820/UDP en tu router hacia esta Raspberry Pi"
    echo "• Configura IP fija para esta Raspberry Pi (IP actual: $LOCAL_IP)"
    if [[ "$USE_DOMAIN" == "true" ]]; then
        echo "• Configura tu servicio DDNS para apuntar a tu IP pública"
    fi
    echo ""
    
    echo -e "${GREEN}🎉 ¡Disfruta de tu servidor VPN casero!${NC}"
    echo ""
}

# ========================================================================
# FUNCIÓN PRINCIPAL
# ========================================================================

main() {
    # Verificaciones iniciales
    check_root
    check_system
    detect_network_info
    
    # Recopilación de información
    collect_user_input
    
    # Instalación del sistema
    install_dependencies
    install_docker
    install_docker_compose
    configure_firewall
    configure_dns_resolution
    configure_system
    create_directories
    
    # Configuración
    generate_env_file
    copy_configuration_files
    
    # Inicio de servicios
    start_services
    
    # Configuración final del DNS
    configure_system_dns
    
    # Información final
    show_final_info
    
    log_success "¡Instalación completada exitosamente!"
}

# Ejecutar función principal
main "$@" 