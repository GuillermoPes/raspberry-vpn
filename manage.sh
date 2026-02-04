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
    echo "5. 📱 Mostrar códigos QR WG-Easy"
    echo "6. 💾 Crear backup"
    echo "7. 🔒 Cambiar contraseña AdGuard Home"
    echo "8. 🔐 Cambiar contraseña WG-Easy"
    echo "9. 🌐 Mostrar IP pública"
    echo "10. 🔄 Cambiar IP/Dominio del servidor"
    echo "11. 🔧 Configurar whitelist DuckDNS en AdGuard"
    echo "12. 🔄 Migrar WG-Easy a versión mantenida"
    echo "13. 🚀 Información del sistema"
    echo "14. 🔄 Actualizar sistema Linux"
    echo "15. 📊 Estado de Watchtower y actualizaciones"
    echo "16. 🛑 Detener servicios"
    echo "17. ▶️ Iniciar servicios"
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
    
    # Verificar docker compose (plugin moderno) o docker_compose (legacy)
    if ! docker compose version &> /dev/null && ! command -v docker_compose &> /dev/null; then
        echo -e "${RED}Docker Compose no está instalado${NC}"
        exit 1
    fi
}

# Función helper para ejecutar docker compose (compatible con ambas versiones)
docker_compose() {
    if docker compose version &> /dev/null; then
        docker compose "$@"
    else
        docker_compose "$@"
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
    docker_compose ps
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
    echo "6. Solo n8n"
    echo "7. Solo Cloudflare Tunnel"
    echo "0. Volver al menú"
    echo -n "Selecciona: "
    read restart_choice
    
    case $restart_choice in
        1)
            echo -e "${GREEN}Reiniciando todos los servicios...${NC}"
            docker_compose restart
            ;;
        2)
            echo -e "${GREEN}Reiniciando WG-Easy...${NC}"
            docker_compose restart wg-easy
            ;;
        3)
            echo -e "${GREEN}Reiniciando AdGuard Home...${NC}"
            docker_compose restart adguardhome
            ;;
        4)
            echo -e "${GREEN}Reiniciando Portainer...${NC}"
            docker_compose restart portainer
            ;;
        5)
            echo -e "${GREEN}Reiniciando Nginx Proxy Manager...${NC}"
            docker_compose restart nginx-proxy-manager 2>/dev/null || echo -e "${YELLOW}Nginx no está instalado${NC}"
            ;;
        6)
            echo -e "${GREEN}Reiniciando n8n...${NC}"
            docker_compose restart n8n 2>/dev/null || echo -e "${YELLOW}n8n no está instalado${NC}"
            ;;
        7)
            echo -e "${GREEN}Reiniciando Cloudflare Tunnel...${NC}"
            docker_compose restart cloudflared 2>/dev/null || echo -e "${YELLOW}Cloudflare Tunnel no está instalado${NC}"
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
    echo "6. n8n"
    echo "7. Cloudflare Tunnel"
    echo "0. Volver al menú"
    echo -n "Selecciona: "
    read log_choice

    case $log_choice in
        1)
            docker_compose logs -f
            ;;
        2)
            docker_compose logs -f wg-easy
            ;;
        3)
            docker_compose logs -f adguardhome
            ;;
        4)
            docker_compose logs -f portainer
            ;;
        5)
            docker_compose logs -f nginx-proxy-manager
            ;;
        6)
            docker_compose logs -f n8n
            ;;
        7)
            docker_compose logs -f cloudflared
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
    docker_compose pull
    docker_compose up -d
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
    docker_compose stop wg-easy
    
    # Eliminar el contenedor e imagen antigua
    echo -e "${YELLOW}Eliminando contenedor e imagen antigua...${NC}"
    docker_compose rm -f wg-easy
    docker rmi weejewel/wg-easy:latest 2>/dev/null || true
    
    # Actualizar docker-compose.yml con la nueva imagen
    echo -e "${YELLOW}Actualizando docker-compose.yml...${NC}"
    if grep -q "weejewel/wg-easy" docker-compose.yml; then
        sed -i 's/weejewel\/wg-easy:latest/ghcr.io\/wg-easy\/wg-easy:latest/g' docker-compose.yml
        echo -e "${GREEN}docker-compose.yml actualizado${NC}"
    else
        echo -e "${GREEN}docker-compose.yml ya está actualizado${NC}"
    fi
    
    # Descargar nueva imagen oficial
    echo -e "${YELLOW}Descargando nueva imagen oficial...${NC}"
    docker_compose pull wg-easy
    
    # Iniciar con la nueva imagen
    echo -e "${YELLOW}Iniciando WG-Easy con la imagen mantenida...${NC}"
    docker_compose up -d wg-easy
    
    # Migrar formato de contraseña si es necesario
    echo -e "${YELLOW}Verificando formato de contraseña...${NC}"
    migrate_password_format
    
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
        
        # Verificar que realmente está usando la nueva imagen
        local new_image=$(docker inspect --format='{{.Config.Image}}' wg-easy 2>/dev/null)
        echo -e "${GREEN}Imagen actual: $new_image${NC}"
        
        # Verificación adicional
        if [[ "$new_image" == "ghcr.io/wg-easy/wg-easy:latest" ]]; then
            echo -e "${GREEN}✅ Migración completada correctamente${NC}"
        else
            echo -e "${YELLOW}⚠️  Verificar: La imagen debería ser ghcr.io/wg-easy/wg-easy:latest${NC}"
        fi
    else
        echo -e "${RED}❌ Error durante la migración${NC}"
        echo "El servicio no se inició correctamente. Revisa los logs:"
        echo "docker_compose logs wg-easy"
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

# Función para cambiar contraseña de WG-Easy
change_wg_easy_password() {
    echo -e "${CYAN}=== Cambio de contraseña WG-Easy ===${NC}"
    echo ""
    
    # Verificar que WG-Easy está ejecutándose
    if ! docker ps | grep -q wg-easy; then
        echo -e "${RED}WG-Easy no está ejecutándose${NC}"
        echo "Inicia los servicios primero con la opción 16"
        return
    fi
    
    echo -e "${YELLOW}Cambiarás la contraseña de acceso a la interfaz web de WG-Easy${NC}"
    echo "URL: http://IP:51821"
    echo ""
    
    while true; do
        echo -n "Introduce la nueva contraseña (mínimo 8 caracteres): "
        read -s new_password
        echo ""
        
        if [[ ${#new_password} -lt 8 ]]; then
            echo -e "${RED}La contraseña debe tener al menos 8 caracteres${NC}"
            continue
        fi
        
        echo -n "Confirma la nueva contraseña: "
        read -s password_confirm
        echo ""
        
        if [[ "$new_password" != "$password_confirm" ]]; then
            echo -e "${RED}Las contraseñas no coinciden${NC}"
            continue
        fi
        
        # Confirmar el cambio
        echo -e "${YELLOW}¿Confirmar el cambio de contraseña? (y/N): ${NC}"
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Cambio cancelado"
            return
        fi
        
        break
    done
    
    echo -e "${GREEN}Actualizando contraseña...${NC}"
    
    # Verificar que Python y bcrypt están disponibles
    if ! python3 -c "import bcrypt" 2>/dev/null; then
        echo -e "${YELLOW}Instalando bcrypt...${NC}"
        pip3 install bcrypt >/dev/null 2>&1 || {
            echo -e "${RED}Error: No se pudo instalar bcrypt${NC}"
            return
        }
    fi
    
    # Generar hash bcrypt
    local raw_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$new_password', bcrypt.gensalt()).decode())" 2>/dev/null)
    
    if [[ -z "$raw_hash" ]]; then
        echo -e "${RED}Error al generar hash de contraseña${NC}"
        return
    fi
    
    # Escapar el símbolo $ para Docker Compose
    local escaped_hash=$(echo "$raw_hash" | sed 's/\$/\$\$/g')
    
    # Hacer backup del archivo .env
    cp .env .env.backup.$(date +%Y%m%d-%H%M%S)
    echo -e "${GREEN}Backup del .env creado${NC}"
    
    # Actualizar .env
    sed -i '/PASSWORD_HASH/d' .env
    echo "PASSWORD_HASH=$escaped_hash" >> .env
    
    echo -e "${GREEN}Archivo .env actualizado${NC}"
    
    # Reiniciar WG-Easy para aplicar cambios
    echo -e "${YELLOW}Reiniciando WG-Easy para aplicar cambios...${NC}"
    docker_compose down wg-easy
    docker_compose up -d wg-easy
    
    # Esperar a que inicie
    echo -e "${YELLOW}Esperando que WG-Easy inicie...${NC}"
    sleep 10
    
    if docker ps | grep wg-easy | grep -q "Up"; then
        echo ""
        echo -e "${GREEN}¡Contraseña cambiada exitosamente!${NC}"
        echo ""
        echo -e "${CYAN}Información de acceso:${NC}"
        echo "• URL: http://IP:51821"
        echo "• Nueva contraseña: [La que acabas de configurar]"
        echo ""
        echo -e "${YELLOW}Nota: Puede que necesites limpiar la cache del navegador${NC}"
    else
        echo -e "${RED}Error: WG-Easy no se inició correctamente${NC}"
        echo "Revisa los logs: docker logs wg-easy"
    fi
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

# Función para configurar DuckDNS cuando se detecta un dominio
configure_duckdns_for_domain() {
    local domain="$1"
    local subdomain=$(echo "$domain" | sed 's/\.duckdns\.org$//')
    
    echo ""
    echo -e "${CYAN}🦆 Dominio DuckDNS detectado: $domain${NC}"
    echo ""
    
    # Verificar si ya existe configuración de DuckDNS
    local existing_token=""
    local existing_domain=""
    
    if [ -f .env ]; then
        existing_token=$(grep "DUCKDNS_TOKEN=" .env 2>/dev/null | cut -d'=' -f2)
        existing_domain=$(grep "DUCKDNS_DOMAIN=" .env 2>/dev/null | cut -d'=' -f2)
    fi
    
    if [[ -n "$existing_token" && "$existing_domain" == "$subdomain" ]]; then
        echo -e "${GREEN}✅ DuckDNS ya está configurado para este dominio${NC}"
        echo -e "${YELLOW}Token actual: ${existing_token:0:8}...${NC}"
        echo ""
        echo -e "${CYAN}¿Quieres mantener la configuración actual? (Y/n):${NC}"
        read -r keep_config
        
        if [[ ! "$keep_config" =~ ^[Nn]$ ]]; then
            echo -e "${GREEN}Manteniendo configuración actual de DuckDNS${NC}"
            return
        fi
    fi
    
    echo -e "${YELLOW}Para que DuckDNS funcione, necesitas configurar:${NC}"
    echo "1. 📋 Token de DuckDNS"
    echo "2. 🔄 Actualización automática de IP"
    echo ""
    
    # Solicitar token de DuckDNS
    while true; do
        echo -e "${CYAN}Introduce tu token de DuckDNS:${NC}"
        echo -e "${YELLOW}(Lo encuentras en: https://www.duckdns.org/install.jsp)${NC}"
        echo -n "Token: "
        read -r duckdns_token
        
        if [[ -z "$duckdns_token" ]]; then
            echo -e "${RED}El token no puede estar vacío${NC}"
            echo -e "${YELLOW}¿Quieres continuar sin DuckDNS? (y/N):${NC}"
            read -r skip_duckdns
            if [[ "$skip_duckdns" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Continuando sin configuración automática de DuckDNS${NC}"
                return
            fi
            continue
        fi
        
        # Validar formato básico del token (UUID)
        if [[ ! "$duckdns_token" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
            echo -e "${YELLOW}⚠️  El token no parece tener el formato correcto de DuckDNS${NC}"
            echo -e "${YELLOW}¿Continuar de todas formas? (y/N):${NC}"
            read -r continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        echo ""
        echo -e "${BLUE}🧪 Probando conexión con DuckDNS...${NC}"
        
        # Test de la API de DuckDNS
        test_response=$(curl -s "https://www.duckdns.org/update?domains=$subdomain&token=$duckdns_token&ip=" || echo "FAILED")
        
        if [[ "$test_response" == "OK" ]]; then
            echo -e "${GREEN}✅ Token válido y conexión exitosa${NC}"
            break
        else
            echo -e "${RED}❌ Error al conectar con DuckDNS${NC}"
            echo -e "${YELLOW}Respuesta: $test_response${NC}"
            echo ""
            echo -e "${CYAN}¿Quieres:${NC}"
            echo "1. Intentar con otro token"
            echo "2. Continuar de todas formas (el token se guardará)"
            echo "3. Saltar configuración de DuckDNS"
            echo -n "Opción (1-3): "
            read -r retry_choice
            
            case $retry_choice in
                1) continue ;;
                2) break ;;
                3) return ;;
                *) continue ;;
            esac
        fi
    done
    
    echo ""
    echo -e "${GREEN}💾 Guardando configuración de DuckDNS...${NC}"
    
    # Actualizar o añadir configuración en .env
    if [ -f .env ]; then
        # Eliminar líneas existentes de DuckDNS
        sed -i '/DUCKDNS_TOKEN=/d' .env
        sed -i '/DUCKDNS_DOMAIN=/d' .env
        
        # Añadir nueva configuración
        echo "DUCKDNS_TOKEN=$duckdns_token" >> .env
        echo "DUCKDNS_DOMAIN=$subdomain" >> .env
    fi
    
    # Configurar cron job para actualización automática
    echo -e "${BLUE}⏰ Configurando actualización automática cada 5 minutos...${NC}"
    
    # Crear script de actualización
    cat > /opt/vpn-server/duckdns_update.sh << EOF
#!/bin/bash
# Script de actualización automática de DuckDNS
# Generado automáticamente por raspberry-vpn

DOMAIN="$subdomain"
TOKEN="$duckdns_token"

# Obtener IP pública actual
CURRENT_IP=\$(curl -s --max-time 10 ifconfig.me 2>/dev/null)

if [[ -n "\$CURRENT_IP" ]]; then
    # Actualizar DuckDNS
    RESPONSE=\$(curl -s "https://www.duckdns.org/update?domains=\$DOMAIN&token=\$TOKEN&ip=\$CURRENT_IP")
    
    if [[ "\$RESPONSE" == "OK" ]]; then
        echo "\$(date): IP actualizada correctamente: \$CURRENT_IP"
    else
        echo "\$(date): Error al actualizar IP: \$RESPONSE"
    fi
else
    echo "\$(date): No se pudo obtener la IP pública"
fi
EOF
    
    chmod +x /opt/vpn-server/duckdns_update.sh
    
    # Añadir cron job (eliminar existente primero)
    crontab -l 2>/dev/null | grep -v "duckdns_update.sh" | crontab -
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/vpn-server/duckdns_update.sh >> /var/log/duckdns_update.log 2>&1") | crontab -
    
    echo ""
    echo -e "${GREEN}✅ DuckDNS configurado exitosamente${NC}"
    echo ""
    echo -e "${BLUE}📋 Configuración aplicada:${NC}"
    echo "• 🌐 Dominio: $domain"
    echo "• 🔑 Token: ${duckdns_token:0:8}... (guardado en .env)"
    echo "• ⏰ Actualización: Cada 5 minutos automáticamente"
    echo "• 📝 Logs: /var/log/duckdns_update.log"
    echo ""
    echo -e "${YELLOW}💡 El script ejecutará la primera actualización ahora...${NC}"
    /opt/vpn-server/duckdns_update.sh
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
            # Verificar si es DuckDNS y configurar token
            if [[ "$new_server" =~ \.duckdns\.org$ ]]; then
                configure_duckdns_for_domain "$new_server"
            fi
            ;;
        3)
            echo -n "Introduce IP pública o dominio: "
            read -r new_server
            # Verificar si es DuckDNS y configurar token
            if [[ "$new_server" =~ \.duckdns\.org$ ]]; then
                configure_duckdns_for_domain "$new_server"
            fi
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
        
        # Reiniciar servicios para aplicar cambios
        echo ""
        echo -e "${YELLOW}Para aplicar los cambios es necesario reiniciar WG-Easy${NC}"
        echo -e "${YELLOW}(Los clientes existentes necesitarán regenerar sus configuraciones)${NC}"
        echo -e "${CYAN}¿Reiniciar WG-Easy ahora? (Y/n):${NC}"
        read -r restart_confirm
        
        if [[ ! "$restart_confirm" =~ ^[Nn]$ ]]; then
            echo -e "${GREEN}Reiniciando WG-Easy para aplicar cambios...${NC}"
            echo -e "${BLUE}• Deteniendo WG-Easy...${NC}"
            docker_compose down wg-easy
            
            echo -e "${BLUE}• Iniciando WG-Easy con nueva configuración...${NC}"
            docker_compose up -d wg-easy
            
            # Esperar a que inicie
            echo -e "${YELLOW}Esperando que WG-Easy inicie...${NC}"
            sleep 8
            
            # Verificar estado
            if docker ps | grep wg-easy | grep -q "Up"; then
                echo ""
                echo -e "${GREEN}✅ ¡WG-Easy reiniciado correctamente!${NC}"
                echo ""
                echo -e "${BLUE}📋 Nueva configuración aplicada:${NC}"
                echo "• 🌐 Servidor: $new_server"
                echo "• 🔗 Interfaz web: http://IP:51821"
                echo "• 🔌 Puerto VPN: 51820/UDP"
                echo ""
                echo -e "${YELLOW}📱 Importante:${NC}"
                echo "• Los clientes VPN existentes necesitarán configuraciones actualizadas"
                echo "• Regenera los códigos QR desde la interfaz web"
                echo "• Si usas router, verifica que el puerto 51820/UDP sigue abierto"
            else
                echo ""
                echo -e "${RED}❌ Error: WG-Easy no se inició correctamente${NC}"
                echo -e "${YELLOW}Revisa los logs: docker logs wg-easy${NC}"
                echo -e "${YELLOW}La configuración se guardó, pero hay un problema con el servicio${NC}"
            fi
        else
            echo ""
            echo -e "${YELLOW}⚠️  Configuración guardada pero no aplicada${NC}"
            echo -e "${CYAN}Para aplicar los cambios ejecuta:${NC}"
            echo "docker_compose down wg-easy"
            echo "docker_compose up -d wg-easy"
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
    docker_compose restart adguardhome
    
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
    docker_compose ps --format table
}

# Función para actualizar sistema Linux
update_system_linux() {
    echo -e "${CYAN}=== Actualización del Sistema Linux ===${NC}"
    echo ""
    
    echo -e "${YELLOW}Esta función actualizará el sistema operativo Raspberry Pi${NC}"
    echo -e "${YELLOW}Esto puede tomar varios minutos dependiendo de las actualizaciones disponibles${NC}"
    echo ""
    echo -e "${RED}ADVERTENCIA: Durante la actualización se pueden reiniciar servicios del sistema${NC}"
    echo -e "${RED}Se recomienda hacer esto cuando no haya tráfico crítico${NC}"
    echo ""
    
    # Mostrar espacio en disco antes
    echo -e "${BLUE}Espacio en disco actual:${NC}"
    df -h / | tail -1
    echo ""
    
    echo -e "${YELLOW}¿Continuar con la actualización? (y/N): ${NC}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Actualización cancelada"
        return
    fi
    
    echo ""
    echo -e "${GREEN}Iniciando actualización del sistema...${NC}"
    echo ""
    
    # Paso 1: Actualizar lista de paquetes
    echo -e "${BLUE}1/4 - Actualizando lista de paquetes...${NC}"
    sudo apt update
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al actualizar la lista de paquetes${NC}"
        return
    fi
    
    # Paso 2: Mostrar actualizaciones disponibles
    echo ""
    echo -e "${BLUE}2/4 - Verificando actualizaciones disponibles...${NC}"
    upgradable=$(apt list --upgradable 2>/dev/null | wc -l)
    
    if [ $upgradable -le 1 ]; then
        echo -e "${GREEN}✅ El sistema ya está actualizado${NC}"
        echo ""
        echo -e "${BLUE}Verificando si hay actualizaciones del firmware...${NC}"
        sudo rpi-update --help >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${YELLOW}¿Verificar actualizaciones del firmware? (y/N): ${NC}"
            read -r firmware_check
            if [[ "$firmware_check" =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Verificando firmware...${NC}"
                sudo rpi-update
            fi
        fi
        return
    fi
    
    echo -e "${YELLOW}Se encontraron $((upgradable-1)) paquetes para actualizar${NC}"
    echo ""
    
    # Mostrar algunos paquetes principales
    echo -e "${BLUE}Principales actualizaciones disponibles:${NC}"
    apt list --upgradable 2>/dev/null | head -10
    echo ""
    
    echo -e "${YELLOW}¿Continuar con la instalación de actualizaciones? (y/N): ${NC}"
    read -r install_confirm
    if [[ ! "$install_confirm" =~ ^[Yy]$ ]]; then
        echo "Instalación de actualizaciones cancelada"
        return
    fi
    
    # Paso 3: Actualizar paquetes
    echo ""
    echo -e "${BLUE}3/4 - Instalando actualizaciones...${NC}"
    sudo apt upgrade -y
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error durante la actualización de paquetes${NC}"
        return
    fi
    
    # Paso 4: Limpiar paquetes obsoletos
    echo ""
    echo -e "${BLUE}4/4 - Limpiando paquetes obsoletos...${NC}"
    sudo apt autoremove -y
    sudo apt autoclean
    
    echo ""
    echo -e "${GREEN}✅ Actualización del sistema completada${NC}"
    echo ""
    
    # Mostrar espacio en disco después
    echo -e "${BLUE}Espacio en disco después de la actualización:${NC}"
    df -h / | tail -1
    echo ""
    
    # Verificar si se requiere reinicio
    if [ -f /var/run/reboot-required ]; then
        echo -e "${YELLOW}⚠️  Se requiere reinicio del sistema para completar algunas actualizaciones${NC}"
        echo -e "${YELLOW}¿Reiniciar ahora? (y/N): ${NC}"
        read -r reboot_confirm
        if [[ "$reboot_confirm" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Reiniciando sistema en 10 segundos...${NC}"
            echo -e "${YELLOW}Los servicios Docker se reiniciarán automáticamente${NC}"
            sleep 10
            sudo reboot
        else
            echo -e "${YELLOW}Recuerda reiniciar el sistema cuando sea conveniente${NC}"
        fi
    else
        echo -e "${GREEN}✅ No se requiere reinicio${NC}"
    fi
    
    # Verificar estado de servicios Docker
    echo ""
    echo -e "${BLUE}Verificando servicios Docker...${NC}"
    docker_compose ps --format table
}

# Función para detener servicios
stop_services() {
    echo -e "${YELLOW}¿Estás seguro de que quieres detener todos los servicios? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Deteniendo servicios...${NC}"
        docker_compose down
        echo -e "${GREEN}Servicios detenidos${NC}"
    fi
}

# Función para iniciar servicios
start_services() {
    echo -e "${GREEN}Iniciando servicios...${NC}"
    docker_compose up -d
    echo -e "${GREEN}Servicios iniciados${NC}"
}

# Función para migrar formato de contraseña de WG-Easy
migrate_password_format() {
    # Verificar si necesita migración
    if grep -q "PASSWORD=\${WG_EASY_PASSWORD}" docker-compose.yml; then
        log_info "Migrando formato de contraseña a hash bcrypt..."
        
        # Obtener contraseña actual
        local current_password=$(grep "WG_EASY_PASSWORD=" .env | cut -d'=' -f2 | sed 's/^#[[:space:]]*//')
        
        if [ -z "$current_password" ]; then
            log_warning "No se encontró contraseña, saltando migración"
            return
        fi
        
        # Verificar que Python y bcrypt están disponibles
        if ! python3 -c "import bcrypt" 2>/dev/null; then
            log_info "Instalando bcrypt para Python..."
            pip3 install bcrypt >/dev/null 2>&1 || {
                log_warning "No se pudo instalar bcrypt, saltando migración de contraseña"
                return
            }
        fi
        
        # Generar hash bcrypt
        local password_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$current_password', bcrypt.gensalt()).decode())" 2>/dev/null)
        
        if [ -z "$password_hash" ]; then
            log_warning "No se pudo generar hash, saltando migración"
            return
        fi
        
        # Actualizar docker-compose.yml
        sed -i 's/PASSWORD=${WG_EASY_PASSWORD}/PASSWORD_HASH=${PASSWORD_HASH}/' docker-compose.yml
        
        # Actualizar .env
        sed -i '/WG_EASY_PASSWORD/d' .env
        sed -i '/PASSWORD_HASH/d' .env
        # Escapar el símbolo $ para Docker Compose
        local escaped_hash=$(echo "$password_hash" | sed 's/\$/\$\$/g')
        echo "PASSWORD_HASH=$escaped_hash" >> .env
        
        log_success "Formato de contraseña migrado a hash bcrypt"
        
        # Reiniciar para aplicar cambios (down/up para recargar variables)
        docker_compose down wg-easy
        docker_compose up -d wg-easy
        sleep 5
    else
        log_info "Formato de contraseña ya está actualizado"
    fi
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
    echo "2. Forzar actualización de Watchtower: docker_compose restart watchtower"
    echo "3. Cambiar intervalo de Watchtower editando .env (WATCHTOWER_POLL_INTERVAL)"
    
    echo ""
    echo -e "${YELLOW}¿Quieres forzar una actualización de todos los servicios ahora? (y/N)${NC}"
    read -r force_update
    
    if [[ "$force_update" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Forzando actualización de todos los servicios...${NC}"
        docker_compose pull
        docker_compose up -d
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
                change_wg_easy_password
                ;;
            9)
                show_public_ip
                ;;
            10)
                change_server_ip
                ;;
            11)
                configure_adguard_whitelist
                ;;
            12)
                migrate_wg_easy
                ;;
            13)
                show_system_info
                ;;
            14)
                update_system_linux
                ;;
            15)
                check_watchtower_status
                ;;
            16)
                stop_services
                ;;
            17)
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