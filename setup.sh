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

WG_EASY_PASSWORD=""
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
    echo "║  • AdGuard Home (Bloqueo de anuncios avanzado)                       ║"
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
    echo "• AdGuard Home será tu servidor DNS con bloqueo de anuncios avanzado"
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
                if [[ "$DOMAIN_NAME" =~ duckdns\.org$ ]]; then
                    configure_duckdns_auto_update
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
                    if [[ "$DOMAIN_NAME" =~ duckdns\.org$ ]]; then
                        configure_duckdns_auto_update
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
                if [[ "$DOMAIN_NAME" == *"duckdns.org"* ]]; then
                    configure_duckdns_auto_update
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

collect_wg_easy_config() {
    clear
    echo -e "${CYAN}🔒 Configuración de WG-Easy (Interfaz Web WireGuard)${NC}"
    echo ""
    echo "WG-Easy te permitirá gestionar tus clientes WireGuard desde una interfaz web."
    echo ""
    
    while true; do
        echo -n "Introduce una contraseña segura para WG-Easy: "
        read -s WG_EASY_PASSWORD
        echo ""
        
        if [[ ${#WG_EASY_PASSWORD} -lt 8 ]]; then
            log_error "La contraseña debe tener al menos 8 caracteres"
            continue
        fi
        
        echo -n "Confirma la contraseña: "
        read -s password_confirm
        echo ""
        
        if [[ "$WG_EASY_PASSWORD" == "$password_confirm" ]]; then
            # Generar hash bcrypt automáticamente
            log_info "Generando hash seguro de contraseña..."
            
            # Verificar que Python y bcrypt están disponibles
            if ! python3 -c "import bcrypt" 2>/dev/null; then
                log_info "Instalando bcrypt para Python..."
                pip3 install bcrypt >/dev/null 2>&1 || {
                    log_error "No se pudo instalar bcrypt"
                    continue
                }
            fi
            
            # Generar hash bcrypt
            local raw_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$WG_EASY_PASSWORD', bcrypt.gensalt()).decode())" 2>/dev/null)
            # Escapar el símbolo $ para Docker Compose
            WG_EASY_PASSWORD_HASH=$(echo "$raw_hash" | sed 's/\$/\$\$/g')
            
            if [[ -n "$WG_EASY_PASSWORD_HASH" ]]; then
                log_success "Contraseña de WG-Easy configurada y encriptada"
                break
            else
                log_error "Error al generar hash de contraseña"
                continue
            fi
        else
            log_error "Las contraseñas no coinciden"
        fi
    done
    
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
    echo -e "${GREEN}AdGuard Home:${NC}"
    echo "  • Contraseña: [Configurada]"
    echo "  • Puerto web: 8080 (HTTP) / 8443 (HTTPS)"
    echo "  • Puerto inicial: 3000 (primer acceso)"
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
    echo "  • Nginx Proxy Manager: Puerto 81 (web), 80/443 (proxy)"
    echo "  • Watchtower: Actualizaciones automáticas"
    
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
    collect_timezone
    collect_network_config
    collect_wg_easy_config
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
    ufw allow 51821/tcp    # WG-Easy Web UI
    ufw allow 53/tcp       # DNS
    ufw allow 53/udp       # DNS
    ufw allow 80/tcp       # HTTP
    ufw allow 443/tcp      # HTTPS
    ufw allow 81/tcp       # Nginx Proxy Manager
    ufw allow 8080/tcp     # AdGuard Home
    ufw allow 8443/tcp     # AdGuard Home HTTPS
    ufw allow 3000/tcp     # AdGuard Home setup inicial
    
    log_success "Firewall configurado"
}

configure_dns_resolution() {
    log_step "Configurando resolución DNS para AdGuard Home..."

    # Herramienta para verificar puertos: lsof. Si no está, se instala.
    if ! command -v lsof &> /dev/null; then
        log_info "Instalando 'lsof' para verificar puertos..."
        apt update -qq && apt install -y lsof
    fi

    # Verificar si systemd-resolved está usando el puerto 53
    if lsof -i :53 | grep -q systemd-resolved; then
        log_warning "El servicio 'systemd-resolved' está usando el puerto 53."
        log_info "Deteniendo y deshabilitando 'systemd-resolved' para liberar el puerto para AdGuard Home..."
        
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        
        # Eliminar el enlace simbólico de resolv.conf que crea systemd-resolved
        if [ -L /etc/resolv.conf ]; then
            rm /etc/resolv.conf
        fi
        # Crear un resolv.conf temporal para que el sistema no se quede sin DNS
        echo "nameserver 1.1.1.1" > /etc/resolv.conf
        
        log_success "Servicio 'systemd-resolved' deshabilitado y puerto 53 liberado para AdGuard Home."
    else
        log_info "El puerto 53 parece estar libre y disponible para AdGuard Home."
    fi

    # Comprobación final para otros posibles servicios
    if lsof -i :53 >/dev/null 2>&1 && ! docker ps | grep -q adguardhome; then
        local service_name=$(lsof -i :53 -t -sTCP:LISTEN)
        log_error "El puerto 53 sigue ocupado por otro proceso (PID: $service_name)."
        log_error "Por favor, detén ese servicio manualmente antes de continuar."
        exit 1
    fi
    
    log_success "Resolución DNS configurada correctamente para la instalación."
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
    mkdir -p $WORK_DIR/adguardhome/work
    mkdir -p $WORK_DIR/adguardhome/conf
    mkdir -p $WORK_DIR/wg-easy
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

# Configuración de WG-Easy
PASSWORD_HASH=$WG_EASY_PASSWORD_HASH

# Configuración de WireGuard
PEERS=$WIREGUARD_PEERS
SERVERPORT=51820
INTERNAL_SUBNET=10.14.14.0

# Configuración de red interna
ADGUARD_IP=10.13.13.100
WG_EASY_IP=10.13.13.4

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
    
    # Ya no necesitamos copiar archivos de configuración específicos
    # AdGuard Home se configura automáticamente
    
    # Hacer scripts ejecutables
    chmod +x "$WORK_DIR/manage.sh"
    
    # Configurar AdGuard Home automáticamente
    setup_adguard_config

    # Configurar DuckDNS si está habilitado
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        setup_duckdns_updater
    fi
    
    # AdGuard Home maneja automáticamente los archivos DNS necesarios
    
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
        if docker ps | grep -q wg-easy; then
            log_message "Reiniciando WG-Easy para aplicar nueva IP..."
            cd /opt/vpn-server
            docker-compose restart wg-easy
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

setup_adguard_config() {
    log_info "Configurando AdGuard Home automáticamente..."
    
    # Crear configuración básica para AdGuard Home
    cat > "$WORK_DIR/adguardhome/conf/AdGuardHome.yaml" << EOF
http:
  pprof:
    port: 6060
    enabled: false
  address: 0.0.0.0:80
  session_ttl: 720h
users:
  - name: admin
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: es
theme: auto
debug_pprof: false
web_session_ttl: 720h
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  protection_enabled: true
  blocking_mode: default
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_response_ttl: 10
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
    - tls://1.1.1.1
    - tls://8.8.8.8
  upstream_dns_file: ""
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
    - 2620:fe::10
    - 2620:fe::fe:10
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: false
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  filtering_enabled: true
  filters_update_interval: 24
  parental_enabled: false
  safesearch_enabled: false
  safebrowsing_enabled: false
  safebrowsing_cache_size: 1048576
  safesearch_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  rewrites: []
  blocked_services: []
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: true
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 784
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  allow_unencrypted_doh: false
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
querylog:
  enabled: true
  file_enabled: true
  interval: 2160h
  size_memory: 1000
  ignored: []
statistics:
  enabled: true
  interval: 24h
  ignored: []
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt
    name: EasyList
    id: 3
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt
    name: EasyPrivacy
    id: 4
whitelist_filters: []
user_rules:
  - "@@||duckdns.org^"
  - "@@||www.duckdns.org^"
  - "@@||ifconfig.me^"
  - "@@||ipinfo.io^"
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log_file: ""
log_max_backups: 0
log_max_size: 100
log_max_age: 3
log_compress: false
log_localtime: false
verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 27
EOF

    # Configurar permisos
    chown -R $INSTALL_USER:$INSTALL_USER "$WORK_DIR/adguardhome"
    chmod -R 755 "$WORK_DIR/adguardhome"
    
    log_success "AdGuard Home configurado automáticamente"
}

configure_system_dns() {
    log_step "Configurando DNS del sistema para usar AdGuard Home..."
    
    # Esperar a que AdGuard Home esté listo
    local max_wait=60
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        if curl -s http://localhost:8080/ &>/dev/null; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    # Detectar IP local
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Configurar el sistema para usar AdGuard Home como DNS
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
    
    log_success "Sistema configurado para usar AdGuard Home como DNS"
    log_info "DNS del sistema: $LOCAL_IP (AdGuard Home)"
}

configure_adguard_duckdns_whitelist() {
    log_step "Configurando whitelist de DuckDNS en AdGuard Home..."
    
    # Esperar unos segundos adicionales para que AdGuard Home esté completamente listo
    sleep 5
    
    # Verificar que AdGuard Home esté respondiendo
    local max_wait=60
    local elapsed=0
    
    while [ $elapsed -lt $max_wait ]; do
        if curl -s http://localhost:8080/ &>/dev/null; then
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    if [ $elapsed -ge $max_wait ]; then
        log_warning "AdGuard Home no está respondiendo, saltando configuración de whitelist"
        log_info "Puedes configurar la whitelist manualmente más tarde con: ./manage.sh opción 10"
        return
    fi
    
    log_info "AdGuard Home está listo, configurando whitelist para DuckDNS..."
    log_info "Esto evitará que se bloqueen las actualizaciones automáticas de IP"
    
    # La whitelist ya está incluida en la configuración inicial de AdGuard Home
    # Solo necesitamos reiniciar el contenedor para asegurar que se aplique
    
    cd $WORK_DIR
    docker-compose restart adguardhome
    
    # Esperar a que reinicie
    sleep 10
    
    log_success "Whitelist de DuckDNS configurada en AdGuard Home"
    log_info "Las actualizaciones automáticas de DuckDNS no serán bloqueadas"
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
    
    local services=("adguardhome" "wg-easy" "portainer" "nginx-proxy-manager" "watchtower")
    
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
    echo -e "${GREEN}🛡️  AdGuard Home (Bloqueo de anuncios):${NC}"
    echo "   URL inicial: http://$LOCAL_IP:3000 (primera configuración)"
    echo "   URL final: http://$LOCAL_IP:8080 (después de configurar)"
    echo "   Usuario: [Configuras en el primer acceso]"
    echo "   Contraseña: [Configuras en el primer acceso]"
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
    echo -e "${GREEN}🔒 WG-Easy (Interfaz Web WireGuard):${NC}"
    echo "   URL: http://$LOCAL_IP:51821"
    echo "   Usuario: admin"
    echo "   Contraseña: [La que configuraste para WG-Easy]"
    echo "   Servidor VPN: $DOMAIN_NAME:51820"
    echo "   Clientes configurados: Gestionado desde WG-Easy"
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
    
    # Configurar whitelist de DuckDNS si está habilitado
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        configure_adguard_duckdns_whitelist
    fi
    
    # Información final
    show_final_info
    
    log_success "¡Instalación completada exitosamente!"
}

# Ejecutar función principal
main "$@" 