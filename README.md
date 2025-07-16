# 🏠 Raspberry Pi VPN Server Completo

Sistema completo para Raspberry Pi 3B con VPN WireGuard, Pi-hole, Portainer y servicios adicionales útiles.

## 📋 Servicios Incluidos

### 🔧 Servicios Principales
- **Portainer** (Puerto 9000) - Gestión web de contenedores Docker
- **WireGuard** (Puerto 51820/UDP) - Servidor VPN para acceso remoto
- **Pi-hole** (Puerto 8080) - Bloqueo de anuncios y servidor DNS
- **Unbound** (Puerto 5335) - DNS resolver recursivo privado

### 🚀 Servicios Adicionales
- **Nginx Proxy Manager** (Puerto 81) - Gestión fácil de proxy reverso y SSL
- **Watchtower** - Actualización automática de contenedores

## 🛠️ Instalación

### 🚀 Instalación Automática (Recomendada)

**Solo necesitas 3 comandos:**

```bash
# 1. Clonar el repositorio
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn

# 2. Ejecutar instalación interactiva
sudo ./setup.sh

# 3. ¡Listo! El sistema estará funcionando
```

**¿Qué hace `setup.sh`?**
- ✅ Instala Docker y dependencias automáticamente
- ✅ Te pregunta la configuración paso a paso
- ✅ Genera todos los archivos automáticamente
- ✅ Configura firewall y red
- ✅ Inicia todos los servicios
- ✅ Te muestra información de acceso

### 📋 Configuración Interactiva

El script te pedirá:
- **Contraseña de Pi-hole** (para la interfaz web)
- **Zona horaria** (ej: Europe/Madrid)
- **Número de clientes VPN** (1-10)
- **IP pública o dominio** (se detecta automáticamente)

### 🔧 Instalación Manual (Avanzada)

Si prefieres el control total:

```bash
# 1. Preparar sistema
sudo apt update && sudo apt upgrade -y
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn

# 2. Instalar dependencias
sudo ./install.sh

# 3. Configurar manualmente
cd /opt/vpn-server
cp ~/raspberry-vpn/docker-compose.yml .
cp ~/raspberry-vpn/config.env.example .env
nano .env  # Editar configuración

# 4. Iniciar servicios
docker-compose up -d
```

## 🌐 Acceso a los Servicios

### URLs de Acceso Local
- **Portainer**: http://IP-DE-TU-PI:9000
- **Pi-hole**: http://IP-DE-TU-PI:8080/admin
- **Nginx Proxy Manager**: http://IP-DE-TU-PI:81

### Credenciales Iniciales

#### Portainer
- Primera vez: Crear usuario admin
- **Funcionalidad completa**: Gestión completa de contenedores (crear, detener, eliminar, actualizar)

#### Pi-hole
- Usuario: admin
- Contraseña: La que configuraste en docker-compose.yml

#### Nginx Proxy Manager
- Usuario: admin@example.com
- Contraseña: changeme

## 🔒 Configuración de WireGuard

### Configuración de Red
- **Red Docker**: 10.13.13.0/24 (servicios internos)
- **Red WireGuard**: 10.14.14.0/24 (clientes VPN)
- **DNS para clientes VPN**: 10.13.13.100 (Pi-hole)

### Generar Configuraciones de Cliente

```bash
# Ver logs de WireGuard para obtener códigos QR
docker logs wireguard

# O acceder al contenedor
docker exec -it wireguard /bin/bash
```

### Configuración Manual del Cliente

Las configuraciones se generan automáticamente en:
```
/opt/vpn-server/wireguard-config/peer[1-5]/peer[1-5].conf
```

## 📊 Monitoreo y Mantenimiento

### Comandos Útiles

```bash
# Ver estado de todos los servicios
docker-compose ps

# Reiniciar un servicio específico
docker-compose restart [servicio]

# Ver logs de un servicio
docker-compose logs [servicio]

# Actualizar servicios
docker-compose pull
docker-compose up -d
```

### Backup

```bash
# Crear backup
sudo tar -czf backup-vpn-$(date +%Y%m%d).tar.gz /opt/vpn-server

# Restaurar backup
sudo tar -xzf backup-vpn-20240101.tar.gz -C /
```

## 🔧 Solución de Problemas

### WireGuard no conecta
1. Verificar que el puerto 51820/UDP esté abierto en el router
2. Confirmar IP pública correcta en SERVERURL
3. Verificar logs: `docker logs wireguard`

### Pi-hole no resuelve DNS
1. Verificar que Unbound esté funcionando: `docker logs unbound`
2. Comprobar configuración DNS del cliente
3. Verificar logs: `docker logs pihole`

### Servicios no inician
1. Verificar recursos: `free -h` y `df -h`
2. Comprobar logs: `docker-compose logs`
3. Reiniciar servicios: `docker-compose restart`

## 🚀 Mejoras Adicionales

### Opcional: Configurar Dominio Propio
1. Registrar dominio (DuckDNS, No-IP, etc.)
2. Configurar DDNS en router
3. Actualizar SERVERURL en WireGuard

### Opcional: Certificados SSL
1. Usar Nginx Proxy Manager
2. Configurar Let's Encrypt
3. Proxy para servicios internos

## 📱 Aplicaciones Cliente

### Android/iOS
- **WireGuard** - App oficial
- **AdGuard** - Cliente DNS alternativo

### Windows/Mac/Linux
- **WireGuard** - Cliente oficial
- **Configuración manual** - Usar archivos .conf

## 🔄 Actualizaciones

El sistema incluye Watchtower que actualiza automáticamente los contenedores cada 24 horas.

Para actualización manual:
```bash
cd /opt/vpn-server
docker-compose pull
docker-compose up -d
```

## 📞 Soporte

Si tienes problemas:
1. Revisar logs: `docker-compose logs`
2. Verificar configuración de red
3. Comprobar recursos del sistema
4. Consultar documentación de cada servicio

---

**¡Disfruta de tu servidor VPN casero completo!** 🏠🔒 