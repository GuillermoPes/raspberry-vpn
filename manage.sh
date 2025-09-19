#!/bin/bash

# Script de gestión para Raspberry Pi VPN Server
# Facilita operaciones comunes del sistema

# Colores para output
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
BLUE='[0;34m'
NC='[0m' # No Color

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
    echo "4b. 🔄 Migrar WG-Easy a versión mantenida"
    echo "5. 📱 Mostrar códigos QR WG-Easy"
    echo "6. 💾 Crear backup"
    echo "7. 🔒 Cambiar contraseña AdGuard Home"
    echo "8. 🌐 Mostrar IP pública"
    echo "9. 🔄 Cambiar IP/Dominio del servidor"
    echo "10. 🔧 Configurar whitelist DuckDNS en AdGuard"
    echo "11. 🚀 Información del sistema"
    echo "12. 📊 Estado de Watchtower y actualizaciones"
    echo "13. 🛑 Detener servicios"
    echo "14. ▶️ Iniciar servicios"
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
    docker stats --no-stream --format "table {{.Container}}	{{.CPUPerc}}	{{.MemUsage}}	{{.NetIO}}"
}

# Función para reiniciar servicios
restart_services() {
    echo -e "${YELLOW}¿Qué servicios quieres reiniciar?${NC}"
    echo "1. Todos los servicios"
    echo "2. Solo WG-Easy"
    echo "3. Solo AdGuard Home"
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
            echo -e "${GREEN}Reiniciando WG-Easy...${NC}"
            docker-compose restart wg-easy
            ;;
        3)
            echo -e "${GREEN}Reiniciando AdGuard Home...${NC}
"
            docker-compose restart adguardhome
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
    echo "2. WG-Easy"
    echo "3. AdGuard Home"
    echo "4. Portainer"
    echo "5. Nginx Proxy Manager"
    echo "0. Volver al menú"
    echo -n "Selecciona: "
    read log_choice

    case $log_choice in
        1)
            docker-compose logs -f
            ;;
        2)
            docker-compose logs -f wg-easy
            ;;
        3)
            docker-compose logs -f adguardhome
            ;;
        4)
            docker-compose logs -f portainer
            ;;
        5)
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

# Función para migrar WG-Easy a la imagen mantenida oficial
migrate_wg_easy() {
    echo -e "${CYAN}=== Migración de WG-Easy a versión mantenida ===${NC}"
    echo ""
    echo -e "${YELLOW}El proyecto original 'weejewel/wg-easy' fue archivado en abril 2024${NC}"
    echo -e "${GREEN}Migrando a la versión oficial mantenida: 'ghcr.io/wg-easy/wg-easy'${NC}"
    echo ""
    echo -e "${BLUE}Esta migración:${NC}"
    echo "• ✅ Mantiene toda tu configuración y clientes VPN"
    echo "• ✅ Actualiza a la versión mantenida oficialmente"
    echo "• ✅ Eliminará las notificaciones de actualización obsoletas"
    echo "• ✅ Asegura futuras actualizaciones automáticas"
    echo ""
    echo -n "¿Continuar con la migración? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Migración cancelada"
        return
    fi
    
    echo -e "${GREEN}Iniciando migración...${NC}"
    
    # Hacer backup de la configuración actual
    echo -e "${YELLOW}Creando backup de seguridad...${NC}"
    if [ -d ./wg-easy ]; then
        cp -r ./wg-easy ./wg-easy-backup-$(date +%Y%m%d-%H%M%S)
        echo -e "${GREEN}Backup creado${NC}"
    fi
    
    # Detener el contenedor actual
    echo -e "${YELLOW}Deteniendo WG-Easy actual...${NC}"
    docker-compose stop wg-easy
    
    # Eliminar el contenedor e imagen antigua
    echo -e "${YELLOW}Eliminando contenedor e imagen antigua...${NC}"
    docker-compose rm -f wg-easy
    docker rmi weejewel/wg-easy:latest 2>/dev/null || true
    
    # El docker-compose.yml ya está actualizado con la nueva imagen
    echo -e "${YELLOW}Descargando nueva imagen oficial...${NC}"
    docker-compose pull wg-easy
    
    # Iniciar con la nueva imagen
    echo -e "${YELLOW}Iniciando WG-Easy con la imagen mantenida...${NC}"
    docker-compose up -d wg-easy
    
    # Verificar que está funcionando
    echo -e "${YELLOW}Verificando el servicio...${NC}"
    sleep 10
    
    if docker ps | grep -q wg-easy; then
        echo ""
        echo -e "${GREEN}🎉 ¡Migración completada exitosamente!${NC}"
        echo ""
        echo -e "${CYAN}Detalles de la migración:${NC}"
        echo "• Nueva imagen: ghcr.io/wg-easy/wg-easy:latest"
        echo "• Todos los clientes VPN mantienen su configuración"
        echo "• Acceso web: http://IP:51821 (mismo que antes)"
        echo "• Las actualizaciones automáticas funcionarán correctamente"
        echo ""
        echo -e "${YELLOW}Nota: Ya no verás notificaciones de actualización obsoletas${NC}"
        
        # Mostrar la versión actual
        local new_image=$(docker inspect --format='{{.Config.Image}}' wg-easy 2>/dev/null)
        echo -e "${GREEN}Imagen actual: $new_image${NC}"
    else
        echo -e "${RED}❌ Error durante la migración${NC}"
        echo "El servicio no se inició correctamente. Revisa los logs:"
        echo "docker-compose logs wg-easy"
    fi
}

# Función para mostrar códigos QR WG-Easy
show_qr_codes() {
    echo -e "${GREEN}Códigos QR de WG-Easy:${NC}"
    echo ""
    echo -e "${YELLOW}Por favor, accede a la interfaz web de WG-Easy para generar y descargar los códigos QR de tus clientes VPN.${NC}"
    echo -e "${CYAN}URL: http://IP-RASPBERRY:51821${NC}"
    echo ""
    echo -e "${YELLOW}WG-Easy gestiona la configuración de los clientes de forma centralizada."
    echo -e "No es necesario generar archivos .conf manualmente.${NC}"
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

# Función para cambiar contraseña AdGuard Home
change_adguard_password() {
    echo -e "${YELLOW}Para cambiar la contraseña de AdGuard Home, por favor, accede a su interfaz web:${NC}"
    echo -e "${CYAN}http://IP-RASPBERRY:8080${NC}"
    echo ""
    echo -e "${YELLOW}Si necesitas cambiar la contraseña de la cuenta de administrador de AdGuard Home, puedes hacerlo desde la sección de 'Usuarios' en la interfaz web."
    echo -e "${YELLOW}Si olvidaste la contraseña y no puedes acceder, puedes restablecerla editando el archivo de configuración 'AdGuardHome.yaml' en el volumen de AdGuard Home y eliminando la línea 'password:'. Luego reinicia el contenedor.${NC}"
}

# Función para mostrar IP pública
show_public_ip() {
    echo -e "${GREEN}IP Pública actual:${NC}"
    curl -s ifconfig.me
    echo ""
    echo -e "${YELLOW}Configuración actual en WG-Easy:${NC}"
    if [ -f .env ]; then
        grep SERVERURL .env || echo "SERVERURL no encontrado en .env"
    else
        echo "Archivo .env no encontrado"
    fi
}

# Función para cambiar IP/Dominio del servidor
change_server_ip() {
    echo -e "${CYAN}=== Cambio de IP/Dominio del Servidor ===${NC}"
    echo ""
    
    # Mostrar configuración actual
    if [ -f .env ]; then
        current_server=$(grep SERVERURL .env | cut -d'=' -f2)
        echo -e "${GREEN}Configuración actual: ${current_server}${NC}"
    else
        echo -e "${RED}Archivo .env no encontrado${NC}"
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Detectando IP pública actual...${NC}"
    current_public_ip=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "No detectada")
    if [ "$current_public_ip" != "No detectada" ]; then
        echo -e "${GREEN}IP pública detectada: $current_public_ip${NC}"
    else
        echo -e "${YELLOW}No se pudo detectar la IP pública automáticamente${NC}"
    fi
    
    echo ""
    echo "Opciones:"
    echo "1. Usar IP pública detectada ($current_public_ip)"
    echo "2. Introducir dominio personalizado (ej: miservidor.duckdns.org)"
    echo "3. Introducir IP/dominio manualmente"
    echo "0. Cancelar"
    echo ""
    echo -n "Selecciona una opción (0-3): "
    read -r ip_choice
    
    case $ip_choice in
        1)
            if [ "$current_public_ip" = "No detectada" ]; then
                echo -e "${RED}No se pudo detectar la IP pública${NC}"
                return
            fi
            new_server="$current_public_ip"
            ;;
        2)
            echo -n "Introduce tu dominio (ej: miservidor.duckdns.org): "
            read -r new_server
            ;;
        3)
            echo -n "Introduce IP pública o dominio: "
            read -r new_server
            ;;
        0)
            echo "Operación cancelada"
            return
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            return
            ;;
    esac
    
    if [ -z "$new_server" ]; then
        echo -e "${RED}No se introdujo ningún valor${NC}"
        return
    fi
    
    echo ""
    echo -e "${YELLOW}Nueva configuración: $new_server${NC}"
    echo -n "¿Confirmar el cambio? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Actualizando configuración...${NC}"
        
        # Hacer backup del archivo .env
        cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
        
        # Actualizar SERVERURL en .env
        sed -i "s/SERVERURL=.*/SERVERURL=$new_server/" .env
        
        # Actualizar PUBLIC_IP si es una IP
        if [[ "$new_server" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            sed -i "s/PUBLIC_IP=.*/PUBLIC_IP=$new_server/" .env
        fi
        
        echo -e "${GREEN}Configuración actualizada en .env${NC}"
        
        # Preguntar si reiniciar servicios
        echo ""
        echo -e "${YELLOW}¿Quieres reiniciar WG-Easy para aplicar los cambios? (y/N)${NC}"
        echo -e "${YELLOW}(Los clientes existentes necesitarán regenerar sus configuraciones)${NC}"
        read -r restart_confirm
        
        if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Reiniciando WG-Easy...${NC}"
            docker-compose restart wg-easy
            echo ""
            echo -e "${GREEN}¡Cambio completado!${NC}"
            echo -e "${YELLOW}Recuerda:${NC}"
            echo "• Los clientes VPN existentes necesitarán configuraciones actualizadas"
            echo "• Puedes regenerar los códigos QR desde WG-Easy: http://IP:51821"
            echo "• Si usas router, asegúrate que el puerto 51820/UDP sigue abierto"
        else
            echo -e "${YELLOW}Configuración guardada. Reinicia WG-Easy manualmente cuando estés listo.${NC}"
        fi
    else
        echo "Cambio cancelado"
    fi
}

# Función para configurar whitelist de DuckDNS en AdGuard Home
configure_adguard_whitelist() {
    echo -e "${CYAN}=== Configuración de Whitelist DuckDNS en AdGuard Home ===${NC}"
    echo ""
    
    # Verificar si AdGuard Home está ejecutándose
    if ! docker ps | grep -q adguardhome; then
        echo -e "${RED}AdGuard Home no está ejecutándose${NC}"
        echo "Inicia los servicios primero con la opción 13"
        return
    fi
    
    echo -e "${YELLOW}Este proceso agregará dominios de DuckDNS y detección de IP a la lista blanca de AdGuard Home${NC}"
    echo ""
    echo "Dominios que se agregarán a la lista blanca:"
    echo "• duckdns.org"
    echo "• www.duckdns.org" 
    echo "• ifconfig.me"
    echo "• ipinfo.io"
    echo ""
    echo -n "¿Continuar? (y/N): "
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operación cancelada"
        return
    fi
    
    echo -e "${GREEN}Configurando whitelist...${NC}"
    
    # Buscar el archivo de configuración de AdGuard Home
    AGH_CONFIG="/opt/vpn-server/adguardhome/conf/AdGuardHome.yaml"
    
    if [ ! -f "$AGH_CONFIG" ]; then
        echo -e "${RED}No se encontró el archivo de configuración de AdGuard Home${NC}"
        echo "Ruta esperada: $AGH_CONFIG"
        return
    fi
    
    # Hacer backup del archivo de configuración
    cp "$AGH_CONFIG" "$AGH_CONFIG.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${GREEN}Backup creado del archivo de configuración${NC}"
    
    # Agregar reglas a la whitelist
    local whitelist_rules=(
        "@@||duckdns.org^"
        "@@||www.duckdns.org^"
        "@@||ifconfig.me^"
        "@@||ipinfo.io^"
    )
    
    # Verificar si ya existe la sección user_rules en el YAML
    if grep -q "user_rules:" "$AGH_CONFIG"; then
        echo -e "${YELLOW}Encontrada sección user_rules existente${NC}"
        
        # Agregar reglas si no existen
        for rule in "${whitelist_rules[@]}"; do
            if ! grep -q "$rule" "$AGH_CONFIG"; then
                echo -e "${GREEN}Agregando regla: $rule${NC}"
                # Agregar regla después de "user_rules:"
                sed -i "/user_rules:/a\\  - \"$rule\"" "$AGH_CONFIG"
            else
                echo -e "${YELLOW}Regla ya existe: $rule${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No se encontró sección user_rules, creando nueva${NC}"
        # Crear nueva sección user_rules antes de la última línea
        {
            head -n -1 "$AGH_CONFIG"
            echo "user_rules:"
            for rule in "${whitelist_rules[@]}"; do
                echo "  - \"$rule\""
            done
            tail -n 1 "$AGH_CONFIG"
        } > "$AGH_CONFIG.tmp" && mv "$AGH_CONFIG.tmp" "$AGH_CONFIG"
    fi
    
    echo -e "${GREEN}Whitelist configurada correctamente${NC}"
    echo ""
    echo -e "${YELLOW}Reiniciando AdGuard Home para aplicar cambios...${NC}"
    docker-compose restart adguardhome
    
    echo ""
    echo -e "${GREEN}¡Configuración completada!${NC}"
    echo ""
    echo -e "${CYAN}Verificación:${NC}"
    echo "1. Ve a AdGuard Home: http://IP:8080"
    echo "2. Filtros → Reglas de filtrado personalizadas"
    echo "3. Deberías ver las reglas agregadas con @@||duckdns.org^"
    echo ""
    echo -e "${YELLOW}Nota: Los logs de DuckDNS ya no deberían mostrar bloqueos${NC}"
}

# Función para mostrar información del sistema
show_system_info() {
    echo -e "${BLUE}=== Información del Sistema ===${NC}"
    echo -e "${GREEN}Raspberry Pi:${NC}"
    cat /proc/cpuinfo | grep "Model"
    echo ""
    echo -e "${GREEN}Memoria:${NC}
"
    free -h
    echo ""
    echo -e "${GREEN}Espacio en disco:${NC}
"
    df -h /
    echo ""
    echo -e "${GREEN}Temperatura:${NC}
"
    vcgencmd measure_temp
    echo ""
    echo -e "${GREEN}Servicios en ejecución:${NC}
"
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

# Función para verificar estado de Watchtower y actualizaciones
check_watchtower_status() {
    echo -e "${CYAN}=== Estado de Watchtower y Actualizaciones ===${NC}"
    echo ""
    
    # Verificar si Watchtower está ejecutándose
    if docker ps | grep -q watchtower; then
        echo -e "${GREEN}✅ Watchtower está ejecutándose${NC}"
    else
        echo -e "${RED}❌ Watchtower NO está ejecutándose${NC}"
        echo "Inicia los servicios con la opción 14"
        return
    fi
    
    echo ""
    echo -e "${BLUE}📊 Configuración de Watchtower:${NC}"
    if [ -f .env ]; then
        local poll_interval=$(grep WATCHTOWER_POLL_INTERVAL .env | cut -d'=' -f2)
        local hours=$((poll_interval / 3600))
        echo "   Intervalo de verificación: $hours horas ($poll_interval segundos)"
    else
        echo "   Configuración: 24 horas (por defecto)"
    fi
    
    echo ""
    echo -e "${BLUE}🐳 Logs recientes de Watchtower:${NC}"
    docker logs --tail 10 watchtower
    
    echo ""
    echo -e "${BLUE}📦 Verificando imágenes actualizables:${NC}"
    echo ""
    
    # Verificar actualizaciones disponibles manualmente
    local services=("wg-easy" "adguardhome" "portainer" "nginx-proxy-manager" "watchtower")
    
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            local current_image=$(docker inspect --format='{{.Config.Image}}' "$service" 2>/dev/null)
            echo -e "${YELLOW}🔍 $service:${NC} $current_image"
            
            # Intentar pull para ver si hay actualizaciones
            echo -n "   Verificando actualizaciones... "
            local pull_result=$(docker pull "$current_image" 2>&1)
            if echo "$pull_result" | grep -q "up to date"; then
                echo -e "${GREEN}✅ Actualizado${NC}"
            elif echo "$pull_result" | grep -q "Downloaded"; then
                echo -e "${YELLOW}🔄 Actualización disponible${NC}"
            else
                echo -e "${CYAN}ℹ️  Sin verificar${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${CYAN}💡 Opciones:${NC}"
    echo "1. Usar opción 4 del menú para actualizar todos los servicios"
    echo "2. Forzar actualización de Watchtower: docker-compose restart watchtower"
    echo "3. Cambiar intervalo de Watchtower editando .env (WATCHTOWER_POLL_INTERVAL)"
    
    echo ""
    echo -e "${YELLOW}¿Quieres forzar una actualización de todos los servicios ahora? (y/N)${NC}"
    read -r force_update
    
    if [[ "$force_update" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Forzando actualización de todos los servicios...${NC}"
        docker-compose pull
        docker-compose up -d
        echo -e "${GREEN}Actualización completada${NC}"
    fi
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
            4b)
                migrate_wg_easy
                ;;
            5)
                show_qr_codes
                ;;
            6)
                create_backup
                ;;
            7)
                change_adguard_password
                ;;
            8)
                show_public_ip
                ;;
            9)
                change_server_ip
                ;;
            10)
                configure_adguard_whitelist
                ;;
            11)
                show_system_info
                ;;
            12)
                check_watchtower_status
                ;;
            13)
                stop_services
                ;;
            14)
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