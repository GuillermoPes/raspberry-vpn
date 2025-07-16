# 🎥 Demostración de la Instalación Interactiva

Este archivo muestra **exactamente** cómo se ve la nueva experiencia de instalación con `setup.sh`.

## 🚀 Proceso Simplificado

### **Paso 1: Clonar repositorio**
```bash
git clone https://github.com/GuillermoPes/raspberry-vpn.git
cd raspberry-vpn
```

### **Paso 2: Ejecutar setup.sh**
```bash
sudo ./setup.sh
```

## 📺 Experiencia de Usuario

### **Pantalla de Bienvenida**
```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║          🏠 RASPBERRY PI VPN SERVER - INSTALACIÓN AUTOMÁTICA          ║
║                                                                      ║
║  📦 Servicios incluidos:                                             ║
║  • WireGuard VPN Server                                              ║
║  • Pi-hole (Bloqueo de anuncios)                                     ║
║  • Unbound (DNS recursivo)                                           ║
║  • Portainer (Gestión Docker)                                        ║
║  • Nginx Proxy Manager                                               ║
║  • Watchtower (Actualizaciones automáticas)                          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

¡Bienvenido al instalador automático!

Este script configurará completamente tu servidor VPN casero.
Te haré algunas preguntas para personalizar la instalación.

⚠️  IMPORTANTE:
• Asegúrate de tener abierto el puerto 51820/UDP en tu router
• Es recomendable configurar IP fija para esta Raspberry Pi  
• La instalación tardará entre 5-15 minutos dependiendo de tu conexión

Presiona Enter para continuar...
```

### **Configuración de Pi-hole**
```
📋 Configuración de Pi-hole

Pi-hole bloqueará anuncios y será tu servidor DNS interno.

Introduce una contraseña segura para Pi-hole: ********
Confirma la contraseña: ********

[✅] Contraseña de Pi-hole configurada

Presiona Enter para continuar...
```

### **Configuración de Zona Horaria**
```
🌍 Configuración de zona horaria

Zona horaria actual detectada: Europe/Madrid

Introduce tu zona horaria (ej: Europe/Madrid, America/New_York) [Europe/Madrid]: 

[✅] Zona horaria configurada: Europe/Madrid

Presiona Enter para continuar...
```

### **Configuración de WireGuard**
```
🔒 Configuración de WireGuard VPN

WireGuard creará configuraciones para tus dispositivos.

¿Cuántos clientes VPN quieres generar? (1-10) [5]: 3

[✅] Configuración WireGuard: 3 clientes

Presiona Enter para continuar...
```

### **Configuración de Red**
```
🌐 Configuración de red

Para que los clientes VPN puedan conectarse, necesito conocer
tu IP pública o dominio.

IP pública detectada: 88.12.34.56

Opciones:
1. Usar IP pública detectada (88.12.34.56)
2. Introducir dominio personalizado (recomendado)
3. Introducir IP/dominio manualmente

Selecciona una opción (1-3) [1]: 2

Servicios DDNS recomendados:
• DuckDNS (duckdns.org) - Gratuito
• No-IP (noip.com) - Gratuito
• Cloudflare - Gratuito

Introduce tu dominio (ej: miservidor.duckdns.org): casa.duckdns.org

[✅] Configuración de red: casa.duckdns.org

Presiona Enter para continuar...
```

### **Resumen de Configuración**
```
📋 Resumen de configuración

Por favor, revisa la configuración antes de continuar:

Sistema:
  • Zona horaria: Europe/Madrid
  • Directorio de instalación: /opt/vpn-server

Pi-hole:
  • Contraseña: [Configurada]
  • Puerto web: 8080

WireGuard:
  • Número de clientes: 3
  • Servidor: casa.duckdns.org
  • Puerto: 51820/UDP

Otros servicios:
  • Portainer: Puerto 9000
  • Nginx Proxy Manager: Puerto 81
  • Unbound DNS: Puerto 5335

¿Es correcta esta configuración? (Y/n): Y

[✅] Configuración confirmada

Presiona Enter para continuar...
```

### **Proceso de Instalación**
```
[PASO] Verificando sistema...
[✅] Sistema verificado correctamente

[PASO] Instalando dependencias del sistema...
[✅] Dependencias instaladas

[PASO] Instalando Docker...
[✅] Docker instalado

[PASO] Instalando Docker Compose...
[✅] Docker Compose instalado

[PASO] Configurando firewall...
[✅] Firewall configurado

[PASO] Configurando sistema...
[✅] Sistema configurado

[PASO] Creando directorios...
[✅] Directorios creados

[PASO] Generando archivo de configuración...
[✅] Archivo de configuración generado

[PASO] Copiando archivos de configuración...
[✅] Archivos copiados

[PASO] Iniciando servicios...
[INFO] Esperando a que los servicios estén listos...
[✅] Servicios iniciados
```

### **Información Final**
```
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║                    🎉 ¡INSTALACIÓN COMPLETADA! 🎉                    ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📋 Información de acceso:

🌐 Pi-hole (Bloqueo de anuncios):
   URL: http://192.168.1.100:8080/admin
   Usuario: admin
   Contraseña: [La que configuraste]

🐳 Portainer (Gestión Docker):
   URL: http://192.168.1.100:9000
   (Crea tu usuario administrador en el primer acceso)

🚀 Nginx Proxy Manager:
   URL: http://192.168.1.100:81
   Usuario: admin@example.com
   Contraseña: changeme

🔒 WireGuard VPN:
   Servidor: casa.duckdns.org:51820
   Clientes configurados: 3

📱 Para obtener códigos QR de tus clientes VPN:
   cd /opt/vpn-server && ./manage.sh

🔧 Para gestionar el sistema:
   cd /opt/vpn-server && ./manage.sh

⚠️  Recuerda:
• Abre el puerto 51820/UDP en tu router hacia esta Raspberry Pi
• Configura IP fija para esta Raspberry Pi (IP actual: 192.168.1.100)
• Configura tu servicio DDNS para apuntar a tu IP pública

🎉 ¡Disfruta de tu servidor VPN casero!

[✅] ¡Instalación completada exitosamente!
```

## 🔧 Gestión Post-Instalación

### **Script de Gestión**
```bash
cd /opt/vpn-server
./manage.sh
```

### **Menú de Gestión**
```
=== Raspberry Pi VPN Server - Gestión ===

1. 📊 Estado de servicios
2. 🔄 Reiniciar servicios
3. 📋 Ver logs
4. 🔧 Actualizar servicios
5. 📱 Mostrar códigos QR WireGuard
6. 💾 Crear backup
7. 🔒 Cambiar contraseña Pi-hole
8. 🌐 Mostrar IP pública
9. 🚀 Información del sistema
10. 🛑 Detener servicios
11. ▶️ Iniciar servicios
0. ❌ Salir

Selecciona una opción:
```

## 🎯 Ventajas de la Nueva Experiencia

### **Para el Usuario:**
- ✅ **Cero edición manual** de archivos
- ✅ **Instalación guiada** paso a paso
- ✅ **Detección automática** de configuración
- ✅ **Validación** de entrada
- ✅ **Información clara** al final

### **Para el Desarrollador:**
- ✅ **Menos soporte** requerido
- ✅ **Menos errores** de configuración
- ✅ **Experiencia consistente** para todos
- ✅ **Fácil mantenimiento** del sistema

## 🚀 Resultado Final

**Con solo 3 comandos tienes un servidor VPN completo funcionando:**

1. `git clone https://github.com/GuillermoPes/raspberry-vpn.git`
2. `cd raspberry-vpn`
3. `sudo ./setup.sh`

**¡Así de simple!** 🎉 