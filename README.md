# 🏠 Raspberry Pi VPN Server Completo

Sistema completo para Raspberry Pi con VPN WireGuard, Pi-hole, Portainer y servicios adicionales útiles.

## 🚀 Instalación de 3 Comandos

**Solo necesitas ejecutar estos 3 comandos:**

```bash
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn
sudo ./setup.sh
```

**¡Eso es todo!** El script interactivo se encarga de instalar, configurar e iniciar todo automáticamente.

### **🔄 Reinstalación o Actualización**

**Si ya tienes una instalación previa:**

```bash
# Opción A: Actualizar repositorio existente
cd raspberry-vpn
git pull origin main
sudo ./setup.sh

# Opción B: Instalación limpia (borra directorio existente)
rm -rf raspberry-vpn
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn
sudo ./setup.sh
```

**El script detecta automáticamente:**
- ✅ Instalaciones existentes (te pregunta qué hacer)
- ✅ Paquetes ya instalados (no los reinstala)
- ✅ Sistema actualizado (no fuerza actualizaciones innecesarias)
- ✅ Docker instalado (solo verifica configuración)

👉 **[Ver demostración completa](DEMO-INSTALACION.md)**

## 📦 Servicios Incluidos

### 🔧 **Servicios Principales**
- **🔒 WireGuard** (Puerto 51820/UDP) - Servidor VPN para acceso remoto seguro
- **🛡️ Pi-hole** (Puerto 8080) - Bloqueo de anuncios y servidor DNS
- **🌐 Unbound** (Puerto 5335) - DNS resolver recursivo privado
- **🐳 Portainer** (Puerto 9000) - Gestión web completa de contenedores Docker

### 🚀 **Servicios Adicionales**
- **🔧 Nginx Proxy Manager** (Puerto 81) - Gestión de proxy reverso y certificados SSL
- **🔄 Watchtower** - Actualización automática de contenedores Docker

## 🛠️ Características Técnicas

### **🌐 Arquitectura de Red**
- **Red Docker**: `10.13.13.0/24` (servicios internos)
- **Red WireGuard**: `10.14.14.0/24` (clientes VPN)
- **Separación de subredes** para evitar conflictos de enrutamiento

### **📊 Healthchecks y Monitoreo**
- Healthchecks automáticos en todos los servicios críticos
- Detección de fallos y reinicio automático
- Espera inteligente hasta 5 minutos para servicios

### **🔒 Seguridad**
- Firewall configurado automáticamente
- Redes Docker internas aisladas
- Acceso DNS solo desde VPN
- Fail2ban para protección SSH

### **⚡ Optimizaciones**
- Imágenes ARM específicas para Raspberry Pi
- Logs centralizados con Docker
- Configuración de recursos optimizada
- Detección automática de usuario

## 🎯 Proceso de Instalación

### **¿Qué hace `setup.sh`?**

1. **🔍 Verificación del Sistema**
   - Detecta automáticamente el usuario actual
   - Verifica que es compatible con Raspberry Pi
   - Instala dependencias básicas

2. **📋 Configuración Interactiva**
   - Contraseña segura para Pi-hole
   - Zona horaria (autodetectada)
   - Número de clientes VPN (1-10)
   - IP pública o dominio (autodetectado)
   - **🦆 DuckDNS automático**: Si usas DuckDNS, pide token y configura actualización automática

3. **🔧 Instalación Automática**
   - Docker y Docker Compose
   - Configuración de firewall (UFW)
   - Configuración de red (IP forwarding)
   - Fail2ban para seguridad SSH

4. **🚀 Configuración de Servicios**
   - Genera archivos de configuración automáticamente
   - Crea estructura de directorios
   - Configura variables de entorno
   - Inicia todos los servicios

5. **✅ Verificación Final**
   - Espera a que todos los servicios estén listos
   - Verifica healthchecks
   - Muestra información de acceso

## 🌐 Acceso a los Servicios

### **URLs de Acceso**
- **Pi-hole**: `http://IP-RASPBERRY:8080/admin`
- **Portainer**: `http://IP-RASPBERRY:9000`
- **Nginx Proxy Manager**: `http://IP-RASPBERRY:81`

### **Credenciales**

#### **Pi-hole**
- **Usuario**: `admin`
- **Contraseña**: La que configuraste durante la instalación

#### **Portainer**
- **Primera vez**: Crear usuario administrador
- **Funcionalidad**: Gestión completa de contenedores

#### **Nginx Proxy Manager**
- **Usuario**: `admin@example.com`
- **Contraseña**: `changeme` (cambiar en primer acceso)

## 🔒 Configuración de WireGuard

### **Obtener Códigos QR**
```bash
cd /opt/vpn-server
./manage.sh
# Seleccionar opción 5: Mostrar códigos QR WireGuard
```

### **Configuraciones Manuales**
Los archivos de configuración se generan automáticamente en:
```
/opt/vpn-server/wireguard-config/peer[1-N]/peer[1-N].conf
```

### **Aplicaciones Cliente**
- **Android/iOS**: App oficial WireGuard
- **Windows/Mac/Linux**: Cliente oficial WireGuard

## 🦆 DuckDNS - Actualización Automática de IP

### **¿Qué es DuckDNS?**
**DuckDNS** es un servicio gratuito que te permite usar un dominio fijo aunque tu IP cambie.

### **Configuración Automática**
El script **detecta automáticamente** si usas DuckDNS:
1. Al introducir tu dominio (ej: `miservidor.duckdns.org`)
2. **Automáticamente** te pide el token de DuckDNS
3. Configura actualización automática **cada 5 minutos**
4. Si cambia tu IP, **actualiza DuckDNS y reinicia WireGuard** automáticamente

### **¿Cómo obtener tu token DuckDNS?**
1. Ve a [duckdns.org](https://www.duckdns.org/)
2. Inicia sesión (GitHub, Google, etc.)
3. Copia el token que aparece en la parte superior

### **Funcionalidades**
- ✅ **Verificación cada 5 minutos** de cambios de IP
- ✅ **Actualización automática** de DuckDNS
- ✅ **Reinicio automático** de WireGuard si cambia IP
- ✅ **Logs detallados** en `/opt/vpn-server/duckdns.log`
- ✅ **Verificación de token** durante la instalación

### **Verificar que funciona**
```bash
# Ver logs de DuckDNS
tail -f /opt/vpn-server/duckdns.log

# Ver cron job configurado
crontab -l | grep duckdns

# Ejecutar manualmente
/opt/vpn-server/duckdns-updater.sh
```

## 📊 Gestión y Mantenimiento

### **Script de Gestión**
```bash
cd /opt/vpn-server
./manage.sh
```

**Funciones disponibles:**
- 📊 Estado de servicios
- 🔄 Reiniciar servicios
- 📋 Ver logs
- 🔧 Actualizar servicios
- 📱 Mostrar códigos QR WireGuard
- 💾 Crear backup
- 🔒 Cambiar contraseña Pi-hole
- 🌐 Mostrar IP pública
- 🚀 Información del sistema

### **Comandos Útiles**
```bash
# Ver estado con healthchecks
docker ps --format "table {{.Names}}\t{{.Status}}"

# Ver logs específicos
docker logs pihole
docker logs wireguard
docker logs unbound

# Actualizar servicios
docker-compose pull && docker-compose up -d

# Crear backup
tar -czf backup-vpn-$(date +%Y%m%d).tar.gz /opt/vpn-server
```

## 🔧 Configuración de Router

### **Puertos Necesarios**
- **51820/UDP**: WireGuard (OBLIGATORIO)
- **22/TCP**: SSH (recomendado desde red local)

### **Configuración Recomendada**
1. **IP fija** para la Raspberry Pi
2. **Puerto 51820/UDP** abierto hacia la Raspberry Pi
3. **DDNS** (DuckDNS, No-IP) para acceso con dominio

## 🔄 Situaciones Comunes

### **🔁 Ya hice git clone antes**
```bash
# El directorio ya existe, 3 opciones:

# 1. Actualizar el existente (recomendado)
cd raspberry-vpn
git pull origin main
sudo ./setup.sh

# 2. Borrar y empezar limpio
rm -rf raspberry-vpn
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn
sudo ./setup.sh

# 3. Clonar con otro nombre
git clone https://github.com/GuillermoPes/raspberry-vpn.git vpn-new
cd vpn-new
sudo ./setup.sh
```

### **🔧 Ya tengo una instalación funcionando**
El script detecta automáticamente instalaciones existentes y te pregunta:
- **Continuar**: Actualiza configuración sin borrar datos
- **Backup y reinstalar**: Hace backup automático y reinstala
- **Cancelar**: Sale sin hacer cambios

### **📦 Sistema ya actualizado**
El script es inteligente y **NO** fuerza actualizaciones innecesarias:
- Solo actualiza lista de paquetes si tiene +24h
- Solo hace `apt upgrade` si hay actualizaciones pendientes
- Solo instala paquetes que realmente faltan

## 🚨 Solución de Problemas

### **Script se cuelga con "ufw: command not found"**
```bash
# Solución inmediata:
sudo apt update && sudo apt install ufw

# Luego continúa con:
sudo ./setup.sh

# O reinstala desde el principio:
git pull origin main
sudo ./setup.sh
```

### **Error "cannot stat 'ARCHIVO.md': No such file or directory"**
```bash
# Si el script falla copiando archivos:
git pull origin main  # Actualizar repositorio
sudo ./setup.sh       # Ejecutar versión actualizada

# El script ahora verifica que los archivos existan antes de copiarlos
```

### **Error "no matching manifest for linux/arm64" al descargar imágenes**
```bash
# Si falla descargando imágenes Docker:
git pull origin main  # Actualizar con imágenes multi-arquitectura
sudo ./setup.sh       # Ejecutar versión actualizada

# El script ahora usa imágenes :latest que soportan múltiples arquitecturas:
# - ARM32 (Raspberry Pi 3B, 4B 32-bit)
# - ARM64 (Raspberry Pi 4B, 5 64-bit)
# - x86_64 (PC para pruebas)
```

### **WireGuard no conecta**
```bash
# Verificar estado del servicio
docker logs wireguard

# Verificar configuración
docker exec -it wireguard wg show

# Verificar puertos
sudo netstat -ulpn | grep 51820
```

### **Pi-hole no funciona**
```bash
# Verificar estado
docker logs pihole

# Verificar DNS
nslookup google.com localhost

# Reiniciar servicio
docker-compose restart pihole
```

### **Servicios no inician**
```bash
# Ver recursos del sistema
free -h && df -h

# Ver logs de todos los servicios
docker-compose logs

# Reiniciar todos los servicios
docker-compose restart
```

## 📈 Recursos del Sistema

### **Memoria Estimada (Raspberry Pi 3B)**
- **Pi-hole**: ~150MB
- **WireGuard**: ~50MB
- **Portainer**: ~30MB
- **Unbound**: ~20MB
- **Nginx Proxy Manager**: ~100MB
- **Sistema**: ~200MB
- **Total**: ~550MB de 1GB disponible

### **CPU**
- **Uso normal**: 10-20%
- **Picos**: Durante conexiones VPN iniciales
- **Optimización**: CPU governor configurado automáticamente

## 🔄 Actualizaciones

### **Automáticas**
Watchtower actualiza automáticamente los contenedores cada 24 horas.

### **Manuales**
```bash
cd /opt/vpn-server
docker-compose pull
docker-compose up -d
```

## 🛡️ Seguridad

### **Configuración Automática**
- **Firewall UFW** configurado automáticamente
- **Fail2ban** para protección SSH
- **Redes Docker aisladas**
- **Acceso DNS solo desde VPN**

### **Mejores Prácticas**
1. Cambiar contraseñas por defecto
2. Configurar IP fija para la Raspberry Pi
3. Usar DDNS para acceso remoto
4. Mantener sistema actualizado

## 🎯 Requisitos

### **Hardware**
- **Raspberry Pi 3B o superior** (ARM32/ARM64)
- **Raspberry Pi 4B, 5** (32-bit o 64-bit OS)
- **MicroSD de 32GB** o más (Clase 10 recomendada)
- **Conexión ethernet** (recomendado para estabilidad)

### **Arquitecturas Soportadas**
- ✅ **ARM32** (armv7l, armv6l) - Raspberry Pi 3B, 4B 32-bit
- ✅ **ARM64** (aarch64) - Raspberry Pi 4B, 5 con OS 64-bit  
- ✅ **x86_64** - PC/servidor para pruebas

### **Software**
- Raspberry Pi OS (recomendado)
- Acceso a internet
- Permisos de sudo

### **Red**
- Puerto 51820/UDP abierto en router
- IP fija para Raspberry Pi (recomendado)

## 📞 Soporte

### **Verificaciones Básicas**
1. Comprobar logs: `docker-compose logs`
2. Verificar recursos: `free -h` y `df -h`
3. Revisar configuración de red
4. Verificar puertos abiertos

### **Información del Sistema**
```bash
# Script de información completa
cd /opt/vpn-server
./manage.sh
# Opción 9: Información del sistema
```

---

**🎉 ¡Disfruta de tu servidor VPN casero completo!** 🏠🔒 