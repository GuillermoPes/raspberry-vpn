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
║  ║  • AdGuard Home (Bloqueo de anuncios avanzado)                       ║
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

### **Configuración de AdGuard Home**
```
📋 Configuración de AdGuard Home

AdGuard Home bloqueará anuncios y será tu servidor DNS completo.

Características de AdGuard Home:
• Bloqueo de anuncios avanzado
• DNS-over-HTTPS y DNS-over-TLS nativos
• Interfaz web moderna y potente
• Estadísticas detalladas
• Configuración automática

[✅] Contraseña de AdGuard Home configurada automáticamente con la contraseña maestra.

Presiona Enter para continuar...
```

### **Configuración de WG-Easy (Interfaz Web WireGuard)**
```
🔒 Configuración de WG-Easy (Interfaz Web WireGuard)

WG-Easy te permitirá gestionar tus clientes WireGuard desde una interfaz web.

Introduce una contraseña segura para WG-Easy: ********
Confirma la contraseña: ********

[✅] Contraseña de WG-Easy configurada

Presiona Enter para continuar...
```

### **Configuración de Correo Electrónico**
```
📧 Configuración de Correo Electrónico

Introduce tu dirección de correo electrónico. Se utilizará para la configuración
inicial de Nginx Proxy Manager y futuras notificaciones.

Introduce tu correo electrónico: tu_email@example.com

[✅] Correo electrónico configurado: tu_email@example.com

Presiona Enter para continuar...
```

### **Contraseña Maestra para Servicios**
```
🔑 Contraseña Maestra para Servicios

Introduce una contraseña maestra que se intentará usar para configurar
automáticamente las contraseñas de los servicios (AdGuard Home, Nginx Proxy Manager).
Esto simplificará la gestión, pero puedes cambiarlas individualmente después.

Introduce la contraseña maestra: ********
Confirma la contraseña maestra: ********

[✅] Contraseña maestra configurada

Presiona Enter para continuar...
```

### **Configuración de Notificaciones por Email (Opcional)**
```
📧 Configuración de Notificaciones por Email (Opcional)

Puedes configurar el envío de notificaciones por email para informes periódicos o alertas.
Si no deseas configurar esto ahora, simplemente presiona Enter en cada campo.

Servidor SMTP (ej: smtp.gmail.com): smtp.gmail.com
Puerto SMTP (ej: 587 para TLS, 465 para SSL): 587
Usuario SMTP (tu email completo): tu_email@example.com
Contraseña SMTP (o contraseña de aplicación si usas Gmail): ********

[✅] Configuración SMTP completada.

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

🦆 DuckDNS detectado!

Dominio DuckDNS: casa

Para habilitar actualización automática de IP necesitas tu token de DuckDNS.

¿Cómo obtener tu token DuckDNS?
1. Ve a https://www.duckdns.org/
2. Inicia sesión con tu cuenta
3. Copia el token que aparece en la parte superior

Introduce tu token de DuckDNS (o 'skip' para omitir): 12345678-1234-1234-1234-123456789012
[INFO] Verificando token DuckDNS...
[✅] Token DuckDNS verificado correctamente

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
  • Correo electrónico: tu_email@example.com
  • Contraseña Maestra: [Configurada]

AdGuard Home:
  • Contraseña: [Configurada automáticamente]
  • Puerto web: 8080 (HTTP) / 8443 (HTTPS)
  • Puerto inicial: 3000 (primer acceso)

WireGuard:
  • Número de clientes: 3
  • Servidor: casa.duckdns.org
  • Puerto: 51820/UDP

DuckDNS:
  • Dominio: casa.duckdns.org
  • Actualización automática: Habilitada (cada 5 min)
  • Token: [Configurado]

Otros servicios:
  • Portainer: Puerto 9000
  • Nginx Proxy Manager: Puerto 81
  • AdGuard Home: Puerto 8080/8443 (web), Puerto 3000 (inicial)

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

🛡️  AdGuard Home (Bloqueo de anuncios):
   URL inicial: http://192.168.1.100:3000 (primera configuración)
   URL final: https://adguardhome.vpn.local (después de configurar)
   Usuario: [Configuras en el primer acceso]
   Contraseña: [La contraseña maestra que configuraste]

🐳 Portainer (Gestión Docker):
   URL: http://192.168.1.100:9000
   (Crea tu usuario administrador en el primer acceso)

🚀 Nginx Proxy Manager:
   URL: https://adguardhome.vpn.local (AdGuard Home)
   URL: https://wgeasy.vpn.local (WG-Easy)
   URL de administración: http://192.168.1.100:81
   Usuario: tu_email@example.com
   Contraseña: [La contraseña maestra que configuraste]
   (La primera vez que accedas a las URLs HTTPS, acepta la advertencia de seguridad)
   ⚠️  Para que los dominios .vpn.local funcionen, añade las siguientes líneas a tu archivo /etc/hosts (o similar) o configura tu DNS local:
      10.13.13.100 adguardhome.vpn.local
      10.13.13.4 wgeasy.vpn.local

🔒 WireGuard VPN:
   Servidor: casa.duckdns.org:51820
   Clientes configurados: 3
   IP pública: 88.12.34.56

🦆 DuckDNS:
   Dominio: casa.duckdns.org
   Actualización automática: ✅ Habilitada
   Verificación: Cada 5 minutos
   Logs: /opt/vpn-server/duckdns.log

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
7. 🔒 Cambiar contraseña AdGuard Home
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