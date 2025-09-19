#!/bin/bash

# Script para migrar contraseña de WG-Easy al formato hash
# Uso: ./fix-wg-easy-password.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Migración de contraseña WG-Easy ===${NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ] || [ ! -f ".env" ]; then
    echo -e "${RED}Error: Ejecuta este script desde /opt/vpn-server${NC}"
    exit 1
fi

# Obtener contraseña actual
echo -e "${YELLOW}Obteniendo contraseña actual...${NC}"
current_password=$(grep "WG_EASY_PASSWORD=" .env | cut -d'=' -f2 | sed 's/^#[[:space:]]*//')

if [ -z "$current_password" ]; then
    echo -e "${RED}No se encontró WG_EASY_PASSWORD en .env${NC}"
    echo -n "Introduce tu contraseña de WG-Easy: "
    read -s current_password
    echo ""
fi

echo -e "${GREEN}Contraseña encontrada: ${current_password:0:3}...${NC}"

# Verificar que Python y bcrypt están disponibles
echo -e "${YELLOW}Verificando dependencias...${NC}"
if ! python3 -c "import bcrypt" 2>/dev/null; then
    echo -e "${YELLOW}Instalando bcrypt...${NC}"
    pip3 install bcrypt
fi

# Generar hash bcrypt
echo -e "${YELLOW}Generando hash bcrypt...${NC}"
password_hash=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$current_password', bcrypt.gensalt()).decode())")

echo -e "${GREEN}Hash generado: ${password_hash:0:20}...${NC}"

# Actualizar docker-compose.yml
echo -e "${YELLOW}Actualizando docker-compose.yml...${NC}"
if grep -q "PASSWORD=\${WG_EASY_PASSWORD}" docker-compose.yml; then
    sed -i 's/PASSWORD=${WG_EASY_PASSWORD}/PASSWORD_HASH=${PASSWORD_HASH}/' docker-compose.yml
    echo -e "${GREEN}docker-compose.yml actualizado${NC}"
else
    echo -e "${GREEN}docker-compose.yml ya está actualizado${NC}"
fi

# Actualizar .env
echo -e "${YELLOW}Actualizando .env...${NC}"
# Eliminar líneas antiguas
sed -i '/WG_EASY_PASSWORD/d' .env
sed -i '/PASSWORD_HASH/d' .env
# Agregar nueva línea
echo "PASSWORD_HASH=$password_hash" >> .env

echo -e "${GREEN}.env actualizado${NC}"

# Reiniciar WG-Easy
echo -e "${YELLOW}Reiniciando WG-Easy...${NC}"
docker-compose down wg-easy
docker-compose up -d wg-easy

# Esperar y verificar
echo -e "${YELLOW}Esperando que WG-Easy inicie...${NC}"
sleep 10

# Verificar estado
if docker ps | grep wg-easy | grep -q "Up"; then
    echo -e "${GREEN}¡Migración completada exitosamente!${NC}"
    echo ""
    echo -e "${GREEN}Acceso:${NC}"
    echo "• URL: http://IP:51821"
    echo "• Contraseña: $current_password"
    echo ""
    echo -e "${YELLOW}Verifica que puedes acceder a la interfaz web${NC}"
else
    echo -e "${RED}Error: WG-Easy no se inició correctamente${NC}"
    echo "Logs:"
    docker logs wg-easy --tail 10
fi
