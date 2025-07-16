#!/bin/bash

# Script de gestión para Raspberry Pi VPN Server
# Facilita operaciones comunes del sistema

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorio de trabajo
WORK_DIR="/opt/vpn-server"

# Función para mostrar el menú
show_menu() {
    echo -e "${GREEN}=== Raspberry Pi VPN Server - Gestión ===${NC}"
    echo ""
    echo "1. 📊 Estado de servicios"
    echo "2. 🔄 Reiniciar servicios"
    echo "3. 📋 Ver logs"
    echo "4. 🔧 Actualizar servicios"
    echo "5. 📱 Mostrar códigos QR WireGuard"
    echo "6. 💾 Crear backup"
    echo "7. 🔒 Cambiar contraseña Pi-hole"
    echo "8. 🌐 Mostrar IP pública"
    echo "9. 🚀 Información del sistema"
    echo "10. 🛑 Detener servicios"
    echo "11. ▶️ Iniciar servicios"
    echo "0. ❌ Salir"
    echo ""
    echo -n "Selecciona una opción: "
}

# Función para verificar Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker no está instalado${NC}"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose no está instalado${NC}"
        exit 1
    fi
}

# Función para cambiar al directorio de trabajo
change_to_work_dir() {
    if [ ! -d "$WORK_DIR" ]; then
        echo -e "${RED}Directorio $WORK_DIR no existe${NC}"
        exit 1
    fi
    cd "$WORK_DIR"
}

# Función para mostrar estado de servicios
show_status() {
    echo -e "${BLUE}=== Estado de Servicios ===${NC}"
    docker-compose ps
    echo ""
    echo -e "${BLUE}=== Uso de recursos ===${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
}

# Función para reiniciar servicios
restart_services() {
    echo -e "${YELLOW}¿Qué servicios quieres reiniciar?${NC}"
    echo "1. Todos los servicios"
    echo "2. Solo WireGuard"
    echo "3. Solo Pi-hole"
    echo "4. Solo Portainer"
    echo "5. Solo Nginx Proxy Manager"
    echo "0. Volver al menú"
    echo -n "Selecciona: "
    read restart_choice
    
    case $restart_choice in
        1)
            echo -e "${GREEN}Reiniciando todos los servicios...${NC}"
            docker-compose restart
            ;;
        2)
            echo -e "${GREEN}Reiniciando WireGuard...${NC}"
            docker-compose restart wireguard
            ;;
        3)
            echo -e "${GREEN}Reiniciando Pi-hole...${NC}"
            docker-compose restart pihole
            ;;
        4)
            echo -e "${GREEN}Reiniciando Portainer...${NC}"
            docker-compose restart portainer
            ;;
        5)
            echo -e "${GREEN}Reiniciando Nginx Proxy Manager...${NC}"
            docker-compose restart nginx-proxy-manager
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            ;;
    esac
}

# Función para ver logs
show_logs() {
    echo -e "${YELLOW}¿De qué servicio quieres ver los logs?${NC}"
    echo "1. Todos los servicios"
    echo "2. WireGuard"
    echo "3. Pi-hole"
    echo "4. Portainer"
    echo "5. Unbound"
    echo "6. Nginx Proxy Manager"
    echo "0. Volver al menú"
    echo -n "Selecciona: "
    read log_choice
    
    case $log_choice in
        1)
            docker-compose logs -f
            ;;
        2)
            docker-compose logs -f wireguard
            ;;
        3)
            docker-compose logs -f pihole
            ;;
        4)
            docker-compose logs -f portainer
            ;;
        5)
            docker-compose logs -f unbound
            ;;
        6)
            docker-compose logs -f nginx-proxy-manager
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            ;;
    esac
}

# Función para actualizar servicios
update_services() {
    echo -e "${GREEN}Actualizando servicios...${NC}"
    docker-compose pull
    docker-compose up -d
    echo -e "${GREEN}Servicios actualizados${NC}"
}

# Función para mostrar códigos QR WireGuard
show_qr_codes() {
    echo -e "${GREEN}Códigos QR de WireGuard:${NC}"
    echo "Revisa los logs de WireGuard para ver los códigos QR:"
    docker logs wireguard 2>&1 | grep -A 50 "GENERATED QR CODE"
}

# Función para crear backup
create_backup() {
    backup_file="backup-vpn-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e "${GREEN}Creando backup: $backup_file${NC}"
    
    # Crear directorio de backup si no existe
    mkdir -p ~/backups
    
    # Crear backup
    tar -czf ~/backups/$backup_file -C /opt vpn-server
    
    echo -e "${GREEN}Backup creado en: ~/backups/$backup_file${NC}"
    echo -e "${YELLOW}Tamaño del backup:${NC}"
    ls -lh ~/backups/$backup_file
}

# Función para cambiar contraseña Pi-hole
change_pihole_password() {
    echo -e "${YELLOW}Cambiar contraseña de Pi-hole${NC}"
    echo "Ejecutando comando en el contenedor Pi-hole..."
    docker exec -it pihole pihole -a -p
}

# Función para mostrar IP pública
show_public_ip() {
    echo -e "${GREEN}IP Pública actual:${NC}"
    curl -s ifconfig.me
    echo ""
    echo -e "${YELLOW}Configuración actual en WireGuard:${NC}"
    grep SERVERURL docker-compose.yml || echo "No encontrado"
}

# Función para mostrar información del sistema
show_system_info() {
    echo -e "${BLUE}=== Información del Sistema ===${NC}"
    echo -e "${GREEN}Raspberry Pi:${NC}"
    cat /proc/cpuinfo | grep "Model"
    echo ""
    echo -e "${GREEN}Memoria:${NC}"
    free -h
    echo ""
    echo -e "${GREEN}Espacio en disco:${NC}"
    df -h /
    echo ""
    echo -e "${GREEN}Temperatura:${NC}"
    vcgencmd measure_temp
    echo ""
    echo -e "${GREEN}Servicios en ejecución:${NC}"
    docker-compose ps --format table
}

# Función para detener servicios
stop_services() {
    echo -e "${YELLOW}¿Estás seguro de que quieres detener todos los servicios? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Deteniendo servicios...${NC}"
        docker-compose down
        echo -e "${GREEN}Servicios detenidos${NC}"
    fi
}

# Función para iniciar servicios
start_services() {
    echo -e "${GREEN}Iniciando servicios...${NC}"
    docker-compose up -d
    echo -e "${GREEN}Servicios iniciados${NC}"
}

# Función principal
main() {
    # Verificar Docker
    check_docker
    
    # Cambiar al directorio de trabajo
    change_to_work_dir
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                show_status
                ;;
            2)
                restart_services
                ;;
            3)
                show_logs
                ;;
            4)
                update_services
                ;;
            5)
                show_qr_codes
                ;;
            6)
                create_backup
                ;;
            7)
                change_pihole_password
                ;;
            8)
                show_public_ip
                ;;
            9)
                show_system_info
                ;;
            10)
                stop_services
                ;;
            11)
                start_services
                ;;
            0)
                echo -e "${GREEN}¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Presiona Enter para continuar...${NC}"
        read
        clear
    done
}

# Ejecutar función principal
main 