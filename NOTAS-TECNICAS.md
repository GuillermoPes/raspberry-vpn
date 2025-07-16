# 📋 Notas Técnicas Importantes

## 🔧 Decisiones de Diseño

### **Separación de Subredes**
- **Red Docker**: `10.13.13.0/24` - Para servicios internos (Pi-hole, Unbound, etc.)
- **Red WireGuard**: `10.14.14.0/24` - Para clientes VPN conectados

**Razón**: Evitar conflictos de enrutamiento. Si ambas redes usan la misma subred, el kernel no sabría si enviar paquetes a la red Docker o al túnel VPN.

### **Acceso Completo de Portainer**
- **Configuración**: Socket Docker SIN `:ro` (solo lectura)
- **Funcionalidad**: Gestión completa de contenedores

**Razón**: Permitir administración completa del sistema a través de la interfaz web de Portainer.

## 🌐 Arquitectura de Red

```
Internet
    ↓
[Router] Puerto 51820/UDP
    ↓
[Raspberry Pi]
    ├── Red Docker (10.13.13.0/24)
    │   ├── Pi-hole (10.13.13.100)
    │   ├── Unbound (10.13.13.3)
    │   ├── WireGuard (10.13.13.2)
    │   ├── Portainer
    │   └── Nginx Proxy Manager
    └── Red VPN (10.14.14.0/24)
        ├── Cliente 1 (10.14.14.2)
        ├── Cliente 2 (10.14.14.3)
        └── Cliente N (10.14.14.X)
```

## 🔒 Flujo de DNS

1. **Cliente VPN se conecta** → IP en red `10.14.14.0/24`
2. **DNS configurado** → `10.13.13.100` (Pi-hole)
3. **Pi-hole consulta** → `10.13.13.3:5335` (Unbound)
4. **Unbound resuelve** → Servidores DNS root públicos
5. **Respuesta filtrada** → Pi-hole bloquea anuncios
6. **Cliente recibe** → DNS limpio y rápido

## ⚡ Optimizaciones Implementadas

### **Recursos Limitados (Raspberry Pi 3B)**
- Imágenes ARM específicas para mejor rendimiento
- Configuración de red optimizada
- Limits de recursos en contenedores sensibles

### **Seguridad**
- Redes Docker internas aisladas
- Firewall configurado automáticamente
- Acceso DNS solo desde VPN
- Contenedores con restart automático

### **Mantenimiento**
- Watchtower para actualizaciones automáticas
- Scripts de gestión incluidos
- Backup automático
- Logs centralizados

## 🚨 Puntos Críticos

### **Configuración de Router**
- **OBLIGATORIO**: Abrir puerto `51820/UDP` hacia la Raspberry Pi
- **RECOMENDADO**: IP fija para la Raspberry Pi
- **OPCIONAL**: DDNS para acceso con dominio

### **Configuración de IP Pública**
- Cambiar `SERVERURL=auto` por tu IP pública real
- O usar un servicio DDNS (DuckDNS, No-IP, etc.)

### **Contraseñas**
- **Pi-hole**: Cambiar `WEBPASSWORD` por una contraseña segura
- **Nginx Proxy Manager**: Cambiar credenciales por defecto
- **Portainer**: Configurar usuario admin en primer acceso

## 🔄 Actualizaciones y Mantenimiento

### **Actualización Manual**
```bash
cd /opt/vpn-server
docker-compose pull
docker-compose up -d
```

### **Backup Completo**
```bash
tar -czf backup-vpn-$(date +%Y%m%d).tar.gz /opt/vpn-server
```

### **Monitoreo**
```bash
./manage.sh  # Script con menú interactivo
```

## 📊 Recursos del Sistema

### **Memoria Estimada**
- **Pi-hole**: ~150MB
- **WireGuard**: ~50MB
- **Portainer**: ~30MB
- **Unbound**: ~20MB
- **Nginx Proxy Manager**: ~100MB
- **Total**: ~350MB de 1GB disponible

### **CPU**
- **Uso normal**: 10-20%
- **Picos**: Durante conexiones VPN iniciales
- **Optimización**: CPU governor en "ondemand"

## 🔧 Solución de Problemas Comunes

### **WireGuard no conecta**
1. Verificar puerto 51820/UDP abierto
2. Confirmar IP pública correcta
3. Revisar logs: `docker logs wireguard`

### **DNS no resuelve**
1. Verificar Pi-hole activo
2. Confirmar Unbound funcionando
3. Verificar configuración cliente

### **Servicios no inician**
1. Comprobar memoria disponible
2. Verificar logs: `docker-compose logs`
3. Reiniciar: `docker-compose restart`

---

**Estas notas técnicas aseguran un funcionamiento óptimo del sistema** 🚀 