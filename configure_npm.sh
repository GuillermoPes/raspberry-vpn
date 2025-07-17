#!/bin/bash

# Script para configurar Nginx Proxy Manager automáticamente

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

WORK_DIR="/opt/vpn-server"

# Cargar variables del archivo .env
if [ -f "$WORK_DIR/.env" ]; then
    source "$WORK_DIR/.env"
else
    log_error "Archivo .env no encontrado en $WORK_DIR. No se puede configurar NPM."
    exit 1
fi

# Verificar que las variables necesarias estén definidas
if [ -z "$USER_EMAIL" ] || [ -z "$MASTER_PASSWORD" ] || [ -z "$ADGUARD_IP" ] || [ -z "$WG_EASY_IP" ]; then
    log_error "Variables de entorno USER_EMAIL, MASTER_PASSWORD, ADGUARD_IP o WG_EASY_IP no definidas en .env"
    exit 1
}

NPM_HOST="localhost"
NPM_PORT="81"
NPM_API_URL="http://${NPM_HOST}:${NPM_PORT}/api"

log_info "Iniciando configuración automática de Nginx Proxy Manager..."

# Paso 1: Obtener Token de autenticación
log_info "Obteniendo token de autenticación de NPM..."
TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"identity": "admin@example.com", "secret": "changeme"}' \
  "${NPM_API_URL}/users/login" | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    log_error "No se pudo obtener el token de autenticación de NPM. Asegúrate de que NPM esté completamente iniciado y las credenciales por defecto sean correctas."
    exit 1
}
log_success "Token obtenido."

# Paso 2: Cambiar credenciales de administrador
log_info "Cambiando credenciales de administrador de NPM..."
CHANGE_RESPONSE=$(curl -s -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"email": "'"$USER_EMAIL"'", "name": "admin", "password": "'"$MASTER_PASSWORD"'"}' \
  "${NPM_API_URL}/users/1")

if echo "$CHANGE_RESPONSE" | grep -q "error"; then
    log_error "Error al cambiar las credenciales de NPM: $CHANGE_RESPONSE"
    exit 1
}
log_success "Credenciales de administrador de NPM cambiadas a $USER_EMAIL."

# Guardar la contraseña de NPM en un archivo seguro
log_info "Guardando contraseña de NPM en $WORK_DIR/npm_password.txt..."
echo "$MASTER_PASSWORD" > "$WORK_DIR/npm_password.txt"
chmod 600 "$WORK_DIR/npm_password.txt"
log_success "Contraseña de NPM guardada."

# Paso 3: Crear Proxy Hosts
log_info "Creando Proxy Hosts para AdGuard Home y WG-Easy..."

# AdGuard Home
ADGUARD_HOST="adguardhome.vpn.local"
log_info "Creando proxy host para AdGuard Home ($ADGUARD_HOST)..."
ADGUARD_PROXY_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "domain_names": ["'"$ADGUARD_HOST"'"],
    "forward_host": "'"$ADGUARD_IP"'",
    "forward_port": 80,
    "forward_scheme": "http",
    "access_list_id": 0,
    "certificate_id": "new",
    "ssl_forced": true,
    "hsts_enabled": false,
    "http2_enabled": false,
    "block_exploits": false,
    "advanced_config": "",
    "meta": {"letsencrypt_email": "'"$USER_EMAIL"'", "dns_challenge": false},
    "locations": [],
    "allow_websocket_upgrade": false,
    "enabled": true
  }' \
  "${NPM_API_URL}/proxy-hosts")

if echo "$ADGUARD_PROXY_RESPONSE" | grep -q "error"; then
    log_error "Error al crear proxy host para AdGuard Home: $ADGUARD_PROXY_RESPONSE"
else
    log_success "Proxy host para AdGuard Home creado: https://$ADGUARD_HOST"
fi

# WG-Easy
WG_EASY_HOST="wgeasy.vpn.local"
log_info "Creando proxy host para WG-Easy ($WG_EASY_HOST)..."
WG_EASY_PROXY_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "domain_names": ["'"$WG_EASY_HOST"'"],
    "forward_host": "'"$WG_EASY_IP"'",
    "forward_port": 51821,
    "forward_scheme": "http",
    "access_list_id": 0,
    "certificate_id": "new",
    "ssl_forced": true,
    "hsts_enabled": false,
    "http2_enabled": false,
    "block_exploits": false,
    "advanced_config": "",
    "meta": {"letsencrypt_email": "'"$USER_EMAIL"'", "dns_challenge": false},
    "locations": [],
    "allow_websocket_upgrade": false,
    "enabled": true
  }' \
  "${NPM_API_URL}/proxy-hosts")

if echo "$WG_EASY_PROXY_RESPONSE" | grep -q "error"; then
    log_error "Error al crear proxy host para WG-Easy: $WG_EASY_PROXY_RESPONSE"
else
    log_success "Proxy host para WG-Easy creado: https://$WG_EASY_HOST"
fi

log_success "Configuración automática de Nginx Proxy Manager completada."
log_warning "Recuerda que para acceder a los dominios .vpn.local, necesitarás añadir estas entradas a tu archivo hosts o configurar tu DNS local."
log_warning "Ejemplo para /etc/hosts o similar:"
log_warning "10.13.13.100 adguardhome.vpn.local"
log_warning "10.13.13.4 wgeasy.vpn.local"
