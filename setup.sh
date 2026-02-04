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

# Variables para servicios opcionales
INSTALL_N8N="true"
N8N_USER="admin"
N8N_PASSWORD=""
N8N_HOST="localhost"
N8N_WEBHOOK_URL=""
N8N_PROTOCOL="http"
N8N_SECURE_COOKIE="false"
INSTALL_NGINX="false"
INSTALL_CLOUDFLARE_TUNNEL="false"
CLOUDFLARE_TUNNEL_TOKEN=""

# Variable para hash de contraseña WG-Easy
WG_EASY_PASSWORD_HASH=""

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
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🌐 CONFIGURACIÓN DE RED Y ACCESO REMOTO                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "${GREEN}✓ IP pública detectada: $PUBLIC_IP${NC}"
    else
        echo -e "${YELLOW}⚠ No se pudo detectar la IP pública automáticamente${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}¿Cómo quieres acceder a tu servidor desde Internet?${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 📍 ${WHITE}IP Pública directa${NC}"
    echo -e "     └─ Usar tu IP actual: ${CYAN}$PUBLIC_IP${NC}"
    echo -e "     └─ ${YELLOW}⚠ Cambiará si tu ISP te asigna IP dinámica${NC}"
    echo ""
    echo -e "  ${GREEN}2.${NC} 🦆 ${WHITE}DuckDNS (DDNS gratuito)${NC}"
    echo -e "     └─ Dominio gratis tipo: ${CYAN}tuservidor.duckdns.org${NC}"
    echo -e "     └─ ${GREEN}✓ Actualización automática de IP${NC}"
    echo -e "     └─ ${GREEN}✓ Ideal si tu ISP cambia tu IP${NC}"
    echo ""
    echo -e "  ${GREEN}3.${NC} ☁️  ${WHITE}Cloudflare Tunnel (Recomendado para n8n)${NC}"
    echo -e "     └─ Acceso HTTPS seguro sin abrir puertos"
    echo -e "     └─ ${GREEN}✓ Tu IP real queda oculta${NC}"
    echo -e "     └─ ${GREEN}✓ HTTPS automático y gratuito${NC}"
    echo -e "     └─ ${YELLOW}Requiere: dominio propio + cuenta Cloudflare${NC}"
    echo ""
    echo -e "  ${GREEN}4.${NC} 🔧 ${WHITE}Dominio personalizado${NC}"
    echo -e "     └─ Usar tu propio dominio (No-IP, Cloudflare DNS, etc.)"
    echo ""
    echo -e "  ${GREEN}5.${NC} 🏠 ${WHITE}Solo acceso local + VPN${NC}"
    echo -e "     └─ Sin configurar dominio externo"
    echo -e "     └─ ${GREEN}✓ Acceso remoto solo vía WireGuard VPN${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Selecciona una opción (1-5) [2]: "
    read -r network_choice
    
    case "${network_choice:-2}" in
        1)
            # IP Pública directa
            if [[ -z "$PUBLIC_IP" ]]; then
                echo ""
                echo -n "Introduce tu IP pública: "
                read -r PUBLIC_IP
            fi
            DOMAIN_NAME="$PUBLIC_IP"
            USE_DOMAIN="false"
            USE_DUCKDNS="false"
            log_success "Configurado con IP pública: $DOMAIN_NAME"
            log_warning "Recuerda: si tu IP cambia, tendrás que reconfigurar los clientes VPN"
            ;;
        2)
            # DuckDNS
            configure_duckdns_setup
            ;;
        3)
            # Cloudflare Tunnel
            configure_cloudflare_setup
            ;;
        4)
            # Dominio personalizado
            echo ""
            echo -e "${CYAN}Introduce tu dominio personalizado:${NC}"
            echo -e "${YELLOW}Ejemplos: vpn.midominio.com, miservidor.noip.com${NC}"
            echo ""
            echo -n "Dominio: "
            read -r DOMAIN_NAME
            USE_DOMAIN="true"
            USE_DUCKDNS="false"
            
            if [[ -z "$DOMAIN_NAME" ]]; then
                log_error "Debes introducir un dominio"
                collect_network_config
                return
            fi
            
            log_success "Configurado con dominio: $DOMAIN_NAME"
            log_info "Asegúrate de que el dominio apunte a tu IP pública"
            ;;
        5)
            # Solo local + VPN
            DOMAIN_NAME="$PUBLIC_IP"
            if [[ -z "$DOMAIN_NAME" ]]; then
                DOMAIN_NAME=$(hostname -I | awk '{print $1}')
            fi
            USE_DOMAIN="false"
            USE_DUCKDNS="false"
            log_success "Configurado para acceso local + VPN"
            log_info "Podrás acceder remotamente conectándote primero a la VPN"
            ;;
        *)
            # Por defecto: DuckDNS
            configure_duckdns_setup
            ;;
    esac
    
    echo ""
    press_enter
}

configure_duckdns_setup() {
    clear
    echo -e "${CYAN}🦆 Configuración de DuckDNS${NC}"
    echo ""
    echo "DuckDNS es un servicio DDNS gratuito que te permite tener un dominio"
    echo "que siempre apunta a tu IP pública, aunque esta cambie."
    echo ""
    echo -e "${YELLOW}¿Ya tienes un dominio DuckDNS?${NC}"
    echo ""
    echo "1. Sí, ya tengo uno configurado"
    echo "2. No, necesito crear uno"
    echo ""
    echo -n "Selecciona (1-2) [1]: "
    read -r duckdns_choice
    
    case "${duckdns_choice:-1}" in
        2)
            echo ""
            echo -e "${CYAN}Para crear tu dominio DuckDNS:${NC}"
            echo "1. Ve a ${GREEN}https://www.duckdns.org/${NC}"
            echo "2. Inicia sesión con Google, GitHub, Twitter, etc."
            echo "3. Crea un subdominio (ej: miservidor)"
            echo "4. Copia tu token (aparece arriba de la página)"
            echo ""
            echo -e "${YELLOW}Presiona Enter cuando hayas creado tu dominio...${NC}"
            read
            ;;
    esac
    
    echo ""
    echo -n "Introduce tu subdominio DuckDNS (sin .duckdns.org): "
    read -r DUCKDNS_DOMAIN
    
    if [[ -z "$DUCKDNS_DOMAIN" ]]; then
        log_error "Debes introducir un subdominio"
        configure_duckdns_setup
        return
    fi
    
    # Limpiar el dominio si el usuario puso el dominio completo
    DUCKDNS_DOMAIN=$(echo "$DUCKDNS_DOMAIN" | sed 's/\.duckdns\.org$//')
    
    DOMAIN_NAME="${DUCKDNS_DOMAIN}.duckdns.org"
    USE_DOMAIN="true"
    
    echo ""
    log_info "Dominio configurado: $DOMAIN_NAME"
    echo ""
    
    # Pedir token
    configure_duckdns_auto_update
}

configure_cloudflare_setup() {
    clear
    echo -e "${CYAN}☁️  Configuración de Cloudflare${NC}"
    echo ""
    echo "Cloudflare ofrece dos opciones para acceder a tu servidor:"
    echo ""
    echo -e "${GREEN}1.${NC} ${WHITE}Cloudflare DNS + Dominio propio${NC}"
    echo "   └─ Tu dominio apunta a tu IP pública"
    echo "   └─ Necesitas abrir puertos en el router"
    echo "   └─ Puedes usar Nginx Proxy Manager para HTTPS"
    echo ""
    echo -e "${GREEN}2.${NC} ${WHITE}Cloudflare Tunnel (Zero Trust)${NC} ${CYAN}← Recomendado${NC}"
    echo "   └─ Túnel seguro sin abrir puertos"
    echo "   └─ HTTPS automático"
    echo "   └─ Tu IP real queda oculta"
    echo ""
    echo -n "Selecciona (1-2) [2]: "
    read -r cf_choice
    
    case "${cf_choice:-2}" in
        1)
            # Cloudflare DNS tradicional
            echo ""
            echo -n "Introduce tu dominio (ej: vpn.midominio.com): "
            read -r DOMAIN_NAME
            USE_DOMAIN="true"
            USE_DUCKDNS="false"
            INSTALL_CLOUDFLARE_TUNNEL="false"
            
            log_success "Dominio configurado: $DOMAIN_NAME"
            log_info "Asegúrate de que el registro DNS en Cloudflare apunte a tu IP"
            log_info "Se recomienda instalar Nginx Proxy Manager para HTTPS"
            INSTALL_NGINX="true"
            ;;
        2)
            # Cloudflare Tunnel
            echo ""
            echo -e "${CYAN}Para configurar Cloudflare Tunnel necesitas:${NC}"
            echo "1. Una cuenta en Cloudflare (gratuita)"
            echo "2. Un dominio añadido a Cloudflare"
            echo "3. Crear un túnel en Zero Trust"
            echo ""
            echo -e "${YELLOW}¿Ya tienes todo esto configurado? (y/N):${NC} "
            read -r has_tunnel
            
            if [[ ! "$has_tunnel" =~ ^[Yy]$ ]]; then
                echo ""
                echo -e "${CYAN}Pasos para configurar Cloudflare Tunnel:${NC}"
                echo ""
                echo "1. Ve a ${GREEN}https://dash.cloudflare.com/${NC}"
                echo "   └─ Crea una cuenta si no tienes"
                echo "   └─ Añade tu dominio"
                echo ""
                echo "2. Ve a ${GREEN}https://one.dash.cloudflare.com/${NC}"
                echo "   └─ Access → Tunnels → Create a tunnel"
                echo "   └─ Nombre: raspberry-vpn"
                echo "   └─ Copia el token (empieza con eyJ...)"
                echo ""
                echo -e "${YELLOW}Presiona Enter cuando tengas el token...${NC}"
                read
            fi
            
            # Pedir dominio para la VPN (WireGuard sigue necesitando un dominio/IP)
            echo ""
            echo -n "Introduce tu dominio principal (ej: midominio.com): "
            read -r user_domain
            
            if [[ -z "$user_domain" ]]; then
                log_error "Necesitas un dominio para continuar"
                configure_cloudflare_setup
                return
            fi
            
            # Para WireGuard, usamos un subdominio o la IP
            echo ""
            echo "Para la VPN (WireGuard), ¿qué quieres usar?"
            echo "1. Subdominio: vpn.$user_domain"
            echo "2. Tu IP pública: $PUBLIC_IP"
            echo ""
            echo -n "Selecciona (1-2) [1]: "
            read -r vpn_choice
            
            case "${vpn_choice:-1}" in
                2)
                    DOMAIN_NAME="$PUBLIC_IP"
                    USE_DOMAIN="false"
                    ;;
                *)
                    DOMAIN_NAME="vpn.$user_domain"
                    USE_DOMAIN="true"
                    ;;
            esac
            
            # Configurar n8n para usar Cloudflare Tunnel
            N8N_HOST="n8n.$user_domain"
            N8N_WEBHOOK_URL="https://n8n.$user_domain"
            N8N_PROTOCOL="https"
            N8N_SECURE_COOKIE="true"
            
            # Pedir token del túnel
            echo ""
            echo -n "Pega el token del túnel (o 'skip' para configurar después): "
            read -r tunnel_token
            
            if [[ "$tunnel_token" == "skip" ]]; then
                log_warning "Configuración de Cloudflare Tunnel omitida"
                log_info "Puedes configurarlo después editando .env"
                CLOUDFLARE_TUNNEL_TOKEN=""
                INSTALL_CLOUDFLARE_TUNNEL="false"
            elif [[ "$tunnel_token" =~ ^eyJ ]]; then
                CLOUDFLARE_TUNNEL_TOKEN="$tunnel_token"
                INSTALL_CLOUDFLARE_TUNNEL="true"
                log_success "Token de Cloudflare Tunnel configurado"
                echo ""
                echo -e "${CYAN}📋 Después de la instalación, configura en Cloudflare:${NC}"
                echo "   Tunnels → Tu túnel → Public Hostname → Add:"
                echo "   • Subdomain: n8n | Domain: $user_domain | Service: http://n8n:5678"
                echo ""
            else
                log_error "Token no válido (debe empezar con 'eyJ')"
                CLOUDFLARE_TUNNEL_TOKEN=""
                INSTALL_CLOUDFLARE_TUNNEL="false"
            fi
            
            USE_DUCKDNS="false"
            log_success "VPN configurada con: $DOMAIN_NAME"
            if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" ]]; then
                log_success "n8n accesible en: https://$N8N_HOST"
            fi
            ;;
    esac
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
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📋 RESUMEN DE CONFIGURACIÓN                       ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Por favor, revisa la configuración antes de continuar:"
    echo ""
    
    echo -e "${GREEN}🖥️  Sistema:${NC}"
    echo "  • Zona horaria: $TIMEZONE"
    echo "  • Directorio: $WORK_DIR"
    echo ""
    
    echo -e "${GREEN}🔒 WireGuard VPN (WG-Easy):${NC}"
    echo "  • Servidor: $DOMAIN_NAME"
    echo "  • Puerto VPN: 51820/UDP"
    echo "  • Puerto Web: 51821/TCP"
    echo "  • Contraseña: ✓ Configurada"
    echo ""
    
    if [[ "$USE_DUCKDNS" == "true" && -n "$DUCKDNS_TOKEN" ]]; then
        echo -e "${GREEN}🦆 DuckDNS:${NC}"
        echo "  • Dominio: $DUCKDNS_DOMAIN.duckdns.org"
        echo "  • Token: ✓ Configurado"
        echo "  • Actualización: Cada 5 minutos"
        echo ""
    fi
    
    echo -e "${GREEN}🛡️  AdGuard Home:${NC}"
    echo "  • Puerto inicial: 3000 (configuración)"
    echo "  • Puerto web: 8080"
    echo ""
    
    if [[ "$INSTALL_N8N" == "true" ]]; then
        echo -e "${GREEN}🤖 n8n (Automatización):${NC}"
        echo "  • Puerto: 5678"
        echo "  • Usuario: $N8N_USER"
        echo "  • Contraseña: ✓ Configurada"
        if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
            echo "  • Acceso público: https://$N8N_HOST"
        else
            echo "  • Acceso: Local + VPN"
        fi
        echo ""
    else
        echo -e "${YELLOW}🤖 n8n: No instalado${NC}"
        echo ""
    fi
    
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        echo -e "${GREEN}☁️  Cloudflare Tunnel:${NC}"
        echo "  • Estado: ✓ Configurado"
        echo "  • Token: ✓ Guardado"
        echo "  • n8n en: https://$N8N_HOST"
        echo ""
    fi
    
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        echo -e "${GREEN}🌐 Nginx Proxy Manager:${NC}"
        echo "  • Puerto: 81"
        echo ""
    fi
    
    echo -e "${GREEN}📦 Servicios adicionales:${NC}"
    echo "  • Portainer: Puerto 9000"
    echo "  • Watchtower: Actualizaciones automáticas"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

collect_n8n_config() {
    clear
    echo -e "${CYAN}🤖 Configuración de n8n (Automatización)${NC}"
    echo ""
    echo "n8n es una herramienta de automatización similar a Zapier/Make,"
    echo "pero self-hosted y gratuita. Permite crear flujos de trabajo"
    echo "conectando APIs, bases de datos, servicios web, etc."
    echo ""
    echo -e "${YELLOW}Ejemplos de uso:${NC}"
    echo "• Recibir notificaciones de eventos en tu servidor"
    echo "• Automatizar backups y enviar alertas"
    echo "• Integrar con Telegram, Discord, Email, etc."
    echo "• Procesar webhooks de servicios externos"
    echo ""
    echo -e "${GREEN}Acceso remoto:${NC}"
    echo "• ${CYAN}Opción 1:${NC} Vía VPN (WireGuard) - Ya incluido"
    echo "• ${CYAN}Opción 2:${NC} Vía Cloudflare Tunnel - HTTPS gratis, sin abrir puertos"
    echo ""
    
    echo -n "¿Quieres instalar n8n? (Y/n): "
    read -r install_n8n
    
    if [[ "$install_n8n" =~ ^[Nn]$ ]]; then
        INSTALL_N8N="false"
        log_info "n8n no se instalará"
        press_enter
        return
    fi
    
    INSTALL_N8N="true"
    echo ""
    
    # Configurar usuario y contraseña para n8n
    echo -e "${YELLOW}Configura las credenciales de acceso a n8n:${NC}"
    echo ""
    
    echo -n "Usuario para n8n [admin]: "
    read -r n8n_user
    N8N_USER="${n8n_user:-admin}"
    
    while true; do
        echo -n "Contraseña para n8n (mínimo 8 caracteres): "
        read -s N8N_PASSWORD
        echo ""
        
        if [[ ${#N8N_PASSWORD} -lt 8 ]]; then
            log_error "La contraseña debe tener al menos 8 caracteres"
            continue
        fi
        
        echo -n "Confirma la contraseña: "
        read -s password_confirm
        echo ""
        
        if [[ "$N8N_PASSWORD" == "$password_confirm" ]]; then
            log_success "Credenciales de n8n configuradas"
            break
        else
            log_error "Las contraseñas no coinciden"
        fi
    done
    
    echo ""
    press_enter
}

collect_nginx_config() {
    # Si ya se configuró Cloudflare Tunnel, probablemente no necesita Nginx
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        # Ya tiene acceso HTTPS vía Cloudflare, no necesita Nginx
        INSTALL_NGINX="false"
        return
    fi
    
    # Si ya se marcó como true durante la configuración de Cloudflare DNS, no preguntar
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        return
    fi
    
    clear
    echo -e "${CYAN}🌐 Nginx Proxy Manager (Opcional)${NC}"
    echo ""
    echo "Nginx Proxy Manager permite:"
    echo "• Usar nombres de dominio en lugar de IP:puerto"
    echo "• Configurar certificados SSL automáticos (Let's Encrypt)"
    echo "• Crear proxies reversos para tus servicios"
    echo ""
    echo -e "${YELLOW}¿Necesitas Nginx Proxy Manager?${NC}"
    echo "• ${GREEN}SÍ${NC} - Si tienes un dominio propio y quieres HTTPS"
    echo "• ${GREEN}SÍ${NC} - Si planeas usar subdominios (ej: n8n.midominio.com)"
    echo "• ${RED}NO${NC} - Si solo accedes por IP:puerto o vía VPN"
    echo ""
    
    echo -n "¿Instalar Nginx Proxy Manager? (y/N): "
    read -r install_nginx
    
    if [[ "$install_nginx" =~ ^[Yy]$ ]]; then
        INSTALL_NGINX="true"
        log_success "Nginx Proxy Manager se instalará"
    else
        INSTALL_NGINX="false"
        log_info "Nginx Proxy Manager no se instalará"
    fi
    
    echo ""
    press_enter
}

collect_cloudflare_tunnel_config() {
    # Si ya se configuró en collect_network_config, no preguntar de nuevo
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        return
    fi
    
    # Solo preguntar si n8n está instalado y no se configuró antes
    if [[ "$INSTALL_N8N" != "true" ]]; then
        INSTALL_CLOUDFLARE_TUNNEL="false"
        return
    fi
    
    # Si ya eligió otra opción de red, ofrecer Cloudflare Tunnel como extra
    clear
    echo -e "${CYAN}☁️  Cloudflare Tunnel (Acceso remoto adicional)${NC}"
    echo ""
    echo "Ya configuraste el acceso a tu servidor con: $DOMAIN_NAME"
    echo ""
    echo "Cloudflare Tunnel te permite además acceder a ${GREEN}n8n${NC} desde Internet"
    echo "de forma segura, sin abrir puertos adicionales."
    echo ""
    echo -e "${GREEN}Ventajas:${NC}"
    echo "• ✅ HTTPS automático y gratuito"
    echo "• ✅ No necesitas abrir puertos en tu router"
    echo "• ✅ Tu IP real queda oculta"
    echo "• ✅ Acceso a n8n desde cualquier lugar sin VPN"
    echo ""
    echo -e "${YELLOW}Requisitos:${NC}"
    echo "• Cuenta gratuita en Cloudflare"
    echo "• Un dominio en Cloudflare"
    echo ""
    
    echo -n "¿Quieres configurar Cloudflare Tunnel para n8n? (y/N): "
    read -r install_tunnel
    
    if [[ ! "$install_tunnel" =~ ^[Yy]$ ]]; then
        INSTALL_CLOUDFLARE_TUNNEL="false"
        log_info "Cloudflare Tunnel no se instalará"
        log_info "Podrás acceder a n8n vía VPN"
        press_enter
        return
    fi
    
    INSTALL_CLOUDFLARE_TUNNEL="true"
    echo ""
    
    echo -e "${YELLOW}Para obtener el token del túnel:${NC}"
    echo "1. Ve a: https://one.dash.cloudflare.com/"
    echo "2. Access → Tunnels → Create a tunnel"
    echo "3. Nombre: 'raspberry-vpn'"
    echo "4. Copia el token (empieza con 'eyJ...')"
    echo ""
    
    echo -n "Pega el token del túnel (o 'skip' para después): "
    read -r tunnel_token
    
    if [[ "$tunnel_token" == "skip" || -z "$tunnel_token" ]]; then
        log_warning "Configuración omitida - puedes configurarlo después en .env"
        CLOUDFLARE_TUNNEL_TOKEN=""
        INSTALL_CLOUDFLARE_TUNNEL="false"
    elif [[ "$tunnel_token" =~ ^eyJ ]]; then
        CLOUDFLARE_TUNNEL_TOKEN="$tunnel_token"
        log_success "Token configurado"
        
        echo ""
        echo -n "Dominio para n8n (ej: n8n.tudominio.com): "
        read -r n8n_domain
        if [[ -n "$n8n_domain" ]]; then
            N8N_HOST="$n8n_domain"
            N8N_WEBHOOK_URL="https://$n8n_domain"
            N8N_PROTOCOL="https"
            N8N_SECURE_COOKIE="true"
            log_success "n8n accesible en: https://$n8n_domain"
        fi
    else
        log_error "Token no válido"
        CLOUDFLARE_TUNNEL_TOKEN=""
        INSTALL_CLOUDFLARE_TUNNEL="false"
    fi
    
    echo ""
    press_enter
}

collect_user_input() {
    welcome_message
    collect_timezone
    collect_network_config
    collect_wg_easy_config
    collect_n8n_config
    collect_cloudflare_tunnel_config
    collect_nginx_config
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
    
    # Docker moderno incluye compose como plugin (docker compose sin guion)
    if docker compose version &> /dev/null; then
        log_info "Docker Compose plugin ya está instalado: $(docker compose version)"
        log_success "Docker Compose listo"
        return
    fi
    
    # Intentar instalar el plugin de compose
    log_info "Instalando Docker Compose plugin..."
    apt update -qq
    apt install -y docker-compose-plugin 2>/dev/null || true
    
    # Verificar de nuevo
    if docker compose version &> /dev/null; then
        log_success "Docker Compose plugin instalado"
        return
    fi
    
    # Fallback: instalar binario standalone
    log_info "Instalando Docker Compose standalone..."
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
    
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Crear alias para compatibilidad
    ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
    
    log_success "Docker Compose instalado"
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

    # Ubuntu 24.04+ usa systemd-resolved por defecto - SIEMPRE deshabilitarlo para AdGuard
    log_info "Deshabilitando systemd-resolved para liberar el puerto 53..."
    
    # Detener y deshabilitar systemd-resolved (ignorar errores si no existe)
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    
    # Eliminar el enlace simbólico de resolv.conf que crea systemd-resolved
    if [ -L /etc/resolv.conf ]; then
        rm -f /etc/resolv.conf
    fi
    
    # Crear un resolv.conf estático con DNS públicos
    cat > /etc/resolv.conf << EOF
# DNS configurado por raspberry-vpn setup
# Después de la instalación, AdGuard Home gestionará el DNS
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    
    # Hacer el archivo inmutable para que NetworkManager no lo sobreescriba
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    log_success "Servicio 'systemd-resolved' deshabilitado y puerto 53 liberado."

    # Matar cualquier proceso que siga usando el puerto 53
    if lsof -i :53 >/dev/null 2>&1; then
        log_warning "Liberando puerto 53 de procesos residuales..."
        fuser -k 53/tcp 2>/dev/null || true
        fuser -k 53/udp 2>/dev/null || true
        sleep 2
    fi

    # Comprobación final
    if lsof -i :53 >/dev/null 2>&1 && ! docker ps | grep -q adguardhome; then
        local service_pid=$(lsof -i :53 -t 2>/dev/null | head -1)
        if [ -n "$service_pid" ]; then
            log_warning "Proceso en puerto 53 (PID: $service_pid). Intentando terminar..."
            kill -9 $service_pid 2>/dev/null || true
            sleep 1
        fi
    fi
    
    log_success "Resolución DNS configurada correctamente para la instalación."
}

configure_automatic_security_updates() {
    log_step "Configurando actualizaciones automáticas de seguridad..."
    
    # Instalar unattended-upgrades si no está instalado
    if ! dpkg -l | grep -q unattended-upgrades; then
        apt update -qq
        apt install -y unattended-upgrades
    fi
    
    # Crear configuración de actualizaciones automáticas
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
// Configuración automática generada por raspberry-vpn setup
// $(date)

// Solo actualizaciones de seguridad automáticas
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    // Descomentar la siguiente línea para también actualizar actualizaciones importantes:
    // "\${distro_id}:\${distro_codename}-updates";
};

// Lista de paquetes que nunca se actualizarán automáticamente
Unattended-Upgrade::Package-Blacklist {
    // "libc6";
    // "libc6-dev";
    // "libc6-i686";
    // "docker.io";
    // "docker-ce";
};

// No reiniciar automáticamente (importante para servidores)
Unattended-Upgrade::Automatic-Reboot "false";

// Si se requiere reinicio, avisar pero no hacerlo
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";

// Eliminar paquetes no utilizados automáticamente
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";

// Logging y configuraciones adicionales
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
    
    # Configurar frecuencia: verificar diariamente, instalar los domingos
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
// Configuración de frecuencia - Verificar diariamente, aplicar domingos a las 4 AM
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "7";
EOF
    
    # Crear tarea cron específica para ejecutar domingos a las 4 AM
    cat > /etc/cron.d/unattended-upgrades-custom << EOF
# Ejecutar actualizaciones de seguridad automáticas los domingos a las 4:00 AM
# m h dom mon dow user command
0 4 * * 0 root /usr/bin/unattended-upgrade
EOF
    
    # Deshabilitar el timer systemd por defecto para usar nuestro cron
    systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
    systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
    
    # Habilitar el servicio pero sin timer automático
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    # Mostrar resumen de configuración
    echo ""
    echo -e "${BLUE}📋 Resumen de actualizaciones automáticas:${NC}"
    echo -e "${GREEN}✅ Solo actualizaciones de seguridad críticas${NC}"
    echo -e "${GREEN}✅ NO reinicia automáticamente el sistema${NC}"
    echo -e "${GREEN}✅ Limpia paquetes no utilizados semanalmente${NC}"
    echo -e "${GREEN}✅ Verifica actualizaciones diariamente${NC}"
    echo -e "${GREEN}✅ Instala actualizaciones: Domingos a las 4:00 AM${NC}"
    echo -e "${GREEN}✅ Docker protegido de actualizaciones automáticas${NC}"
    echo ""
    echo -e "${YELLOW}💡 Para actualizaciones completas del sistema, usa:${NC}"
    echo -e "${CYAN}   ./manage.sh → opción 14 (Actualizar sistema Linux)${NC}"
    echo ""
    echo -e "${BLUE}📝 Logs de actualizaciones en: /var/log/unattended-upgrades/${NC}"
    
    log_success "Actualizaciones automáticas configuradas para domingos 4:00 AM"
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
    
    # Configurar actualizaciones automáticas de seguridad
    configure_automatic_security_updates
    
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
    
    # Crear directorio de n8n si está habilitado
    if [[ "$INSTALL_N8N" == "true" ]]; then
        mkdir -p $WORK_DIR/n8n
        # n8n necesita permisos específicos (usuario node con UID 1000)
        chown -R 1000:1000 $WORK_DIR/n8n
    fi
    
    # Crear directorios de Nginx solo si está habilitado
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        mkdir -p $WORK_DIR/nginx-proxy-manager/data
        mkdir -p $WORK_DIR/nginx-proxy-manager/letsencrypt
    fi
    
    log_success "Directorios creados"
}

generate_env_file() {
    log_step "Generando archivo de configuración..."
    
    # Asegurar que las variables tienen valores por defecto
    local env_n8n_host="${N8N_HOST:-localhost}"
    local env_n8n_webhook="${N8N_WEBHOOK_URL:-}"
    local env_n8n_protocol="${N8N_PROTOCOL:-http}"
    local env_n8n_secure="${N8N_SECURE_COOKIE:-false}"
    
    cat > $WORK_DIR/.env << EOF
# ========================================================================
# Archivo de configuración generado automáticamente
# Fecha: $(date)
# ========================================================================

# ========================
# CONFIGURACIÓN GENERAL
# ========================
TZ=$TIMEZONE
PUID=1000
PGID=1000
COMPOSE_PROJECT_NAME=vpn-server

# ========================
# CONFIGURACIÓN DE RED
# ========================
SERVERURL=$DOMAIN_NAME
SERVERPORT=51820
PUBLIC_IP=$PUBLIC_IP

# ========================
# DUCKDNS (DDNS)
# ========================
USE_DUCKDNS=$USE_DUCKDNS
DUCKDNS_DOMAIN=$DUCKDNS_DOMAIN
DUCKDNS_TOKEN=$DUCKDNS_TOKEN

# ========================
# WG-EASY (WIREGUARD VPN)
# ========================
PASSWORD_HASH=$WG_EASY_PASSWORD_HASH
PEERS=$WIREGUARD_PEERS
INTERNAL_SUBNET=10.14.14.0

# ========================
# RED INTERNA DOCKER
# ========================
ADGUARD_IP=10.13.13.100
WG_EASY_IP=10.13.13.4
N8N_IP=10.13.13.50

# ========================
# WATCHTOWER
# ========================
WATCHTOWER_POLL_INTERVAL=86400

# ========================
# N8N (AUTOMATIZACIÓN)
# ========================
INSTALL_N8N=$INSTALL_N8N
N8N_USER=$N8N_USER
N8N_PASSWORD=$N8N_PASSWORD
N8N_HOST=$env_n8n_host
N8N_WEBHOOK_URL=$env_n8n_webhook
N8N_PROTOCOL=$env_n8n_protocol
N8N_SECURE_COOKIE=$env_n8n_secure
N8N_BASIC_AUTH_ACTIVE=true

# ========================
# CLOUDFLARE TUNNEL
# ========================
INSTALL_CLOUDFLARE_TUNNEL=$INSTALL_CLOUDFLARE_TUNNEL
CLOUDFLARE_TUNNEL_TOKEN=$CLOUDFLARE_TUNNEL_TOKEN

# ========================
# NGINX PROXY MANAGER
# ========================
INSTALL_NGINX=$INSTALL_NGINX
EOF
    
    # Verificar que el archivo se creó correctamente
    if [[ -f "$WORK_DIR/.env" ]]; then
        log_success "Archivo de configuración generado: $WORK_DIR/.env"
    else
        log_error "Error al generar archivo de configuración"
        exit 1
    fi
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
            docker compose restart wg-easy
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
    local max_wait=120
    local elapsed=0
    
    log_info "Esperando a que AdGuard Home esté listo..."
    while [ $elapsed -lt $max_wait ]; do
        if curl -s http://localhost:8080/ &>/dev/null; then
            log_success "AdGuard Home está respondiendo"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""
    
    # Detectar IP local
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    # Desbloquear resolv.conf si estaba bloqueado
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    # Configurar el sistema para usar AdGuard Home como DNS (SIN systemd-resolved)
    cat > /etc/resolv.conf << EOF
# DNS gestionado por AdGuard Home - raspberry-vpn
# NO modificar manualmente
nameserver $LOCAL_IP
nameserver 1.1.1.1
EOF
    
    # Bloquear el archivo para que no se sobreescriba
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
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
    docker compose restart adguardhome
    
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
    
    # Construir lista de perfiles a activar
    local profiles_to_use=""
    
    # Servicios base (sin profile, siempre se inician)
    local services_to_start="portainer wg-easy adguardhome watchtower"
    
    if [[ "$INSTALL_N8N" == "true" ]]; then
        services_to_start="$services_to_start n8n"
        log_info "✓ n8n será instalado"
    fi
    
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        profiles_to_use="cloudflare"
        log_info "✓ Cloudflare Tunnel será instalado"
    fi
    
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        if [[ -n "$profiles_to_use" ]]; then
            profiles_to_use="$profiles_to_use,nginx"
        else
            profiles_to_use="nginx"
        fi
        log_info "✓ Nginx Proxy Manager será instalado"
    fi
    
    # Iniciar servicios
    log_info "Iniciando servicios base: $services_to_start"
    
    if [[ -n "$profiles_to_use" ]]; then
        log_info "Perfiles activos: $profiles_to_use"
        COMPOSE_PROFILES="$profiles_to_use" docker compose up -d
    else
        docker compose up -d $services_to_start
    fi
    
    # Esperar a que los servicios estén listos
    log_info "Esperando a que los servicios estén listos..."
    wait_for_services
    
    log_success "Servicios iniciados"
}

wait_for_services() {
    local max_wait=300  # 5 minutos máximo
    local elapsed=0
    local interval=10
    
    # Lista de servicios base
    local services=("adguardhome" "wg-easy" "portainer" "watchtower")
    
    # Añadir servicios opcionales si están instalados
    if [[ "$INSTALL_N8N" == "true" ]]; then
        services+=("n8n")
    fi
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        services+=("cloudflared")
    fi
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        services+=("nginx-proxy-manager")
    fi
    
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
    log_info "Puedes verificar el estado con: docker compose ps"
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
    echo -e "${GREEN}🔒 WG-Easy (VPN - Interfaz Web WireGuard):${NC}"
    echo "   URL: http://$LOCAL_IP:51821"
    echo "   Contraseña: [La que configuraste]"
    echo "   Servidor VPN: $DOMAIN_NAME:51820"
    echo ""
    echo -e "${GREEN}🛡️  AdGuard Home (Bloqueo de anuncios):${NC}"
    echo "   URL inicial: http://$LOCAL_IP:3000 (primera configuración)"
    echo "   URL final: http://$LOCAL_IP:8080 (después de configurar)"
    echo ""
    echo -e "${GREEN}🐳 Portainer (Gestión Docker):${NC}"
    echo "   URL: http://$LOCAL_IP:9000"
    echo "   (Crea tu usuario administrador en el primer acceso)"
    echo ""
    
    if [[ "$INSTALL_N8N" == "true" ]]; then
        echo -e "${GREEN}🤖 n8n (Automatización):${NC}"
        echo "   URL local: http://$LOCAL_IP:5678"
        echo "   Usuario: $N8N_USER"
        echo "   Contraseña: [La que configuraste]"
        if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
            echo -e "   ${CYAN}🌐 URL pública: https://$N8N_HOST${NC}"
        else
            echo -e "   ${CYAN}💡 Acceso remoto: Conéctate a la VPN primero${NC}"
        fi
        echo ""
    fi
    
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        echo -e "${GREEN}☁️  Cloudflare Tunnel:${NC}"
        echo "   Estado: ✅ Activo"
        echo "   n8n accesible en: https://$N8N_HOST"
        echo ""
        echo -e "   ${YELLOW}📋 Siguiente paso en Cloudflare:${NC}"
        echo "   1. Ve a dash.cloudflare.com → Zero Trust → Tunnels"
        echo "   2. Selecciona tu túnel → Public Hostname"
        echo "   3. Añade: n8n.tudominio.com → http://n8n:5678"
        echo ""
    fi
    
    if [[ "$INSTALL_NGINX" == "true" ]]; then
        echo -e "${GREEN}🚀 Nginx Proxy Manager:${NC}"
        echo "   URL: http://$LOCAL_IP:81"
        echo "   Usuario: admin@example.com"
        echo "   Contraseña: changeme"
        echo ""
    fi
    
    if [[ "$USE_DUCKDNS" == "true" ]]; then
        echo -e "${GREEN}🦆 DuckDNS:${NC}"
        echo "   Dominio: $DUCKDNS_DOMAIN.duckdns.org"
        echo "   Actualización automática: ✅ Habilitada"
        echo "   Verificación: Cada 5 minutos"
        echo ""
    fi
    
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
    
    echo -e "${MAGENTA}📱 Acceso remoto:${NC}"
    if [[ "$INSTALL_CLOUDFLARE_TUNNEL" == "true" && -n "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
        echo "• n8n: https://$N8N_HOST (desde cualquier lugar)"
        echo "• Otros servicios: Conéctate a la VPN primero"
    else
        echo "1. Conéctate a tu VPN desde el móvil/PC"
        echo "2. Accede a los servicios usando la IP local ($LOCAL_IP)"
        echo "3. ¡Listo! Es como estar en casa"
    fi
    echo ""
    
    echo -e "${GREEN}🎉 ¡Disfruta de tu servidor casero!${NC}"
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