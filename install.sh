#!/bin/bash

# Script de instalación para Raspberry Pi VPN Server
# Autor: Sistema de automatización
# Descripción: Instala Docker, Docker Compose y configura el entorno

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Instalación de Raspberry Pi VPN Server ===${NC}"

# Función para mostrar mensajes
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root (sudo)"
    exit 1
fi

# Actualizar sistema
log_info "Actualizando sistema..."
apt update && apt upgrade -y

# Instalar dependencias
log_info "Instalando dependencias..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    ca-certificates \
    gnupg \
    lsb-release \
    iptables-persistent

# Instalar Docker
log_info "Instalando Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Agregar usuario pi al grupo docker
log_info "Configurando permisos Docker..."
usermod -aG docker pi

# Instalar Docker Compose
log_info "Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-armv7" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verificar instalación
log_info "Verificando instalación..."
docker --version
docker-compose --version

# Crear directorios necesarios
log_info "Creando directorios..."
mkdir -p /opt/vpn-server
mkdir -p /opt/vpn-server/wireguard-config
mkdir -p /opt/vpn-server/adguardhome/work
mkdir -p /opt/vpn-server/adguardhome/conf
mkdir -p /opt/vpn-server/unbound
mkdir -p /opt/vpn-server/nginx-proxy-manager/data
mkdir -p /opt/vpn-server/nginx-proxy-manager/letsencrypt

# Configurar firewall
log_info "Configurando firewall..."
ufw enable
ufw allow ssh
ufw allow 9000/tcp  # Portainer
ufw allow 51820/udp # WireGuard
ufw allow 53/tcp    # DNS
ufw allow 53/udp    # DNS
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 81/tcp    # Nginx Proxy Manager
ufw allow 8080/tcp  # AdGuard Home
ufw allow 8443/tcp  # AdGuard Home HTTPS
ufw allow 3000/tcp  # AdGuard Home setup inicial

# Configurar IP forwarding
log_info "Configurando IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.src_valid_mark=1' >> /etc/sysctl.conf
sysctl -p

# Descargar root hints para Unbound
log_info "Descargando archivos DNS root..."
wget -O /opt/vpn-server/unbound/root.hints https://www.internic.net/domain/named.cache

# Configurar permisos
log_info "Configurando permisos..."
chown -R pi:pi /opt/vpn-server
chmod -R 755 /opt/vpn-server

# Crear archivo de configuración de IP pública
log_info "Detectando IP pública..."
PUBLIC_IP=$(curl -s ifconfig.me)
echo "SERVERURL=$PUBLIC_IP" > /opt/vpn-server/.env
echo "IP_PUBLICA=$PUBLIC_IP" >> /opt/vpn-server/.env

log_info "Configuración completada!"
log_warning "Recuerda:"
log_warning "1. Configurar AdGuard Home accediendo a http://IP:3000 para la configuración inicial"
log_warning "2. Configurar tu IP pública en SERVERURL del servicio WireGuard"
log_warning "3. Abrir el puerto 51820/UDP en tu router"
log_warning "4. Ejecutar 'docker-compose up -d' en /opt/vpn-server"

echo -e "${GREEN}=== Instalación completada exitosamente ===${NC}"
echo -e "${YELLOW}Reinicia el sistema antes de continuar: sudo reboot${NC}" 