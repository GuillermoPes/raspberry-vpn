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

## 🚨 Solución de Problemas

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
- Raspberry Pi 3B o superior
- MicroSD de 32GB o más
- Conexión ethernet (recomendado)

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