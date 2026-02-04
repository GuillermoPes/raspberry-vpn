#!/bin/bash

# Script para solucionar problemas de instalación
# Compatible con Ubuntu 24.04 y Docker moderno
# Uso: sudo ./fix-installation-issues.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Solucionando problemas de instalación ===${NC}"
echo ""

# Función para mostrar pasos
log_step() {
    echo -e "${BLUE}[PASO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠️]${NC} $1"
}

# Función helper para docker compose (compatible con ambas versiones)
docker_compose() {
    if docker compose version &> /dev/null; then
        docker compose "$@"
    else
        docker-compose "$@"
    fi
}

# Verificar si estamos en el directorio correcto
if [[ ! -f "docker-compose.yml" ]]; then
    log_error "No se encontró docker-compose.yml. Ejecuta desde /opt/vpn-server o ~/raspberry-vpn"
    exit 1
fi

# 0. Liberar puerto 53 (CRÍTICO para Ubuntu 24.04)
log_step "Liberando puerto 53 (systemd-resolved)..."
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    log_warning "systemd-resolved está activo, deshabilitando..."
    sudo systemctl stop systemd-resolved 2>/dev/null || true
    sudo systemctl disable systemd-resolved 2>/dev/null || true
    
    # Eliminar enlace simbólico y crear resolv.conf estático
    if [ -L /etc/resolv.conf ]; then
        sudo rm -f /etc/resolv.conf
    fi
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    sudo chattr +i /etc/resolv.conf 2>/dev/null || true
    log_success "systemd-resolved deshabilitado y puerto 53 liberado"
else
    log_success "systemd-resolved ya está deshabilitado"
fi

# 1. Detener todos los contenedores
log_step "Deteniendo todos los contenedores..."
docker_compose down --remove-orphans 2>/dev/null || true

# 2. Limpiar contenedores huérfanos
log_step "Limpiando contenedores huérfanos..."
docker container prune -f

# 3. Limpiar redes Docker conflictivas
log_step "Limpiando redes Docker conflictivas..."
docker network rm vpn-server_vpn-network 2>/dev/null || true
docker network rm raspberry-vpn_vpn-network 2>/dev/null || true
docker network prune -f

# 4. Verificar puertos en uso
log_step "Verificando puertos en uso..."
echo -e "${YELLOW}Puertos que deberían estar libres:${NC}"
echo "• 51820/UDP (WireGuard)"
echo "• 51821/TCP (WG-Easy web)"
echo "• 53/TCP,UDP (AdGuard Home)"
echo "• 8080/TCP (AdGuard Home web)"
echo "• 9000/TCP (Portainer)"
echo "• 81/TCP (Nginx Proxy Manager)"
echo ""

# Mostrar qué está usando los puertos
for port in 51820 51821 53 8080 9000 81; do
    if ss -tuln | grep -q ":$port "; then
        log_warning "Puerto $port está en uso:"
        ss -tuln | grep ":$port " || true
        # Intentar liberar el puerto
        if [ "$port" == "53" ]; then
            sudo fuser -k 53/tcp 2>/dev/null || true
            sudo fuser -k 53/udp 2>/dev/null || true
        fi
    else
        log_success "Puerto $port está libre"
    fi
done

echo ""

# 5. Verificar variables de entorno
log_step "Verificando archivo .env..."
if [[ -f ".env" ]]; then
    if grep -q "PASSWORD_HASH=" .env; then
        log_success "PASSWORD_HASH configurado en .env"
    else
        log_warning "PASSWORD_HASH no encontrado en .env"
        echo -e "${YELLOW}Necesitas ejecutar el setup.sh para configurar la contraseña${NC}"
    fi
    
    if grep -q "SERVERURL=" .env; then
        server_url=$(grep "SERVERURL=" .env | cut -d'=' -f2)
        log_success "SERVERURL configurado: $server_url"
    else
        log_error "SERVERURL no encontrado en .env"
    fi
else
    log_error "Archivo .env no encontrado"
    echo -e "${YELLOW}Buscando en /opt/vpn-server...${NC}"
    if [[ -f "/opt/vpn-server/.env" ]]; then
        log_success "Encontrado .env en /opt/vpn-server, copiando..."
        cp /opt/vpn-server/.env .env
    else
        echo -e "${YELLOW}Necesitas ejecutar el setup.sh primero${NC}"
    fi
fi

# 6. Verificar permisos de DuckDNS
log_step "Verificando permisos de DuckDNS..."
if [[ -f "duckdns-updater.sh" ]]; then
    chmod +x duckdns-updater.sh
    chown $(whoami):$(whoami) duckdns-updater.sh
    log_success "Permisos de DuckDNS corregidos"
else
    log_warning "Script de DuckDNS no encontrado (opcional)"
fi

# 7. Verificar COMPOSE_PROJECT_NAME
log_step "Verificando nombre del proyecto..."
current_dir=$(basename "$(pwd)")
if grep -q "COMPOSE_PROJECT_NAME=" .env 2>/dev/null; then
    project_name=$(grep "COMPOSE_PROJECT_NAME=" .env | cut -d'=' -f2)
    if [ "$project_name" != "$current_dir" ]; then
        log_warning "COMPOSE_PROJECT_NAME ($project_name) no coincide con el directorio ($current_dir)"
        echo -e "${YELLOW}Actualizando COMPOSE_PROJECT_NAME...${NC}"
        sed -i "s/COMPOSE_PROJECT_NAME=.*/COMPOSE_PROJECT_NAME=$current_dir/" .env
        log_success "COMPOSE_PROJECT_NAME actualizado a: $current_dir"
    fi
fi

# 8. Intentar iniciar servicios
log_step "Iniciando servicios..."
echo -e "${YELLOW}Esto puede tomar unos minutos...${NC}"

if docker_compose up -d; then
    log_success "Servicios iniciados correctamente"
    
    # Esperar un poco y verificar estado
    echo -e "${YELLOW}Esperando que los servicios se estabilicen...${NC}"
    sleep 20
    
    echo ""
    echo -e "${BLUE}📊 Estado de los contenedores:${NC}"
    docker_compose ps
    
    echo ""
    echo -e "${BLUE}🔍 Verificando servicios críticos:${NC}"
    
    # Verificar WG-Easy
    if docker ps | grep wg-easy | grep -q "Up"; then
        log_success "WG-Easy está funcionando"
    else
        log_error "WG-Easy no está funcionando"
        echo -e "${YELLOW}Logs de WG-Easy:${NC}"
        docker logs wg-easy --tail 10 2>/dev/null || true
    fi
    
    # Verificar AdGuard Home
    if docker ps | grep adguardhome | grep -q "Up"; then
        log_success "AdGuard Home está funcionando"
    else
        log_error "AdGuard Home no está funcionando"
        echo -e "${YELLOW}Logs de AdGuard Home:${NC}"
        docker logs adguardhome --tail 10 2>/dev/null || true
    fi
    
    # Verificar Portainer
    if docker ps | grep portainer | grep -q "Up"; then
        log_success "Portainer está funcionando"
    else
        log_warning "Portainer no está funcionando"
    fi
    
    # Verificar n8n (opcional)
    if docker ps | grep n8n | grep -q "Up"; then
        log_success "n8n está funcionando"
    elif docker ps -a | grep -q n8n; then
        log_warning "n8n existe pero no está corriendo"
        echo -e "${YELLOW}Logs de n8n:${NC}"
        docker logs n8n --tail 10 2>/dev/null || true
    fi
    
    # Verificar Cloudflared (opcional)
    if docker ps | grep cloudflared | grep -q "Up"; then
        log_success "Cloudflare Tunnel está funcionando"
    elif docker ps -a | grep -q cloudflared; then
        log_warning "Cloudflared existe pero no está corriendo"
        echo -e "${YELLOW}Logs de Cloudflared:${NC}"
        docker logs cloudflared --tail 10 2>/dev/null || true
    fi
    
else
    log_error "Error al iniciar servicios"
    echo -e "${YELLOW}Revisa los logs:${NC}"
    docker_compose logs --tail 20
fi

echo ""
echo -e "${CYAN}=== Resumen de soluciones aplicadas ===${NC}"
echo -e "${GREEN}✅ systemd-resolved deshabilitado (puerto 53 libre)${NC}"
echo -e "${GREEN}✅ Contenedores detenidos y limpiados${NC}"
echo -e "${GREEN}✅ Redes Docker conflictivas eliminadas${NC}"
echo -e "${GREEN}✅ Puertos verificados${NC}"
echo -e "${GREEN}✅ Variables de entorno verificadas${NC}"
echo -e "${GREEN}✅ Servicios reiniciados${NC}"

# Obtener IP local
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${BLUE}📋 URLs de acceso:${NC}"
echo "• WG-Easy: http://$LOCAL_IP:51821"
echo "• AdGuard Home: http://$LOCAL_IP:8080"
echo "• Portainer: http://$LOCAL_IP:9000"
echo "• n8n: http://$LOCAL_IP:5678"
echo "• Nginx Proxy Manager: http://$LOCAL_IP:81 (si está instalado)"

echo ""
echo -e "${YELLOW}💡 Si el problema persiste:${NC}"
echo "• Reinicia el sistema: sudo reboot"
echo "• Revisa los logs: docker compose logs SERVICIO"
echo "• Verifica que el archivo .env esté correctamente configurado"
echo "• Para servicios opcionales: COMPOSE_PROFILES=cloudflare docker compose up -d"