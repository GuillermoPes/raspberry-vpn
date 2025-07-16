# 🔧 Optimizaciones para Raspberry Pi 3B

Este archivo contiene optimizaciones específicas para mejorar el rendimiento del sistema en una Raspberry Pi 3B.

## 📊 Especificaciones Raspberry Pi 3B

- **CPU**: Quad-core ARM Cortex-A53 @ 1.2GHz
- **RAM**: 1GB LPDDR2
- **Almacenamiento**: MicroSD
- **Red**: 10/100 Ethernet + WiFi 2.4GHz

## ⚡ Optimizaciones del Sistema

### 1. Configuración de Memoria

```bash
# Editar /boot/config.txt
sudo nano /boot/config.txt

# Agregar las siguientes líneas:
gpu_mem=16          # Reducir memoria GPU (no necesitamos gráficos)
disable_camera=1    # Desactivar cámara
disable_splash=1    # Desactivar splash screen
boot_delay=0        # Reducir tiempo de boot
```

### 2. Optimización de Swap

```bash
# Aumentar swap para mejorar rendimiento
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile

# Cambiar CONF_SWAPSIZE a 1024
CONF_SWAPSIZE=1024

# Reiniciar swap
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### 3. Optimización de MicroSD

```bash
# Configurar noatime para reducir escrituras
sudo nano /etc/fstab

# Modificar la línea del root filesystem:
/dev/mmcblk0p2  /  ext4  defaults,noatime,nodiratime  0  1
```

### 4. Límites de Recursos Docker

Añade estos límites al `docker-compose.yml`:

```yaml
# Ejemplo para Pi-hole
pihole:
  # ... otras configuraciones ...
  deploy:
    resources:
      limits:
        memory: 256M
        cpus: "0.5"
      reservations:
        memory: 128M
        cpus: "0.25"

# Ejemplo para WireGuard
wireguard:
  # ... otras configuraciones ...
  deploy:
    resources:
      limits:
        memory: 128M
        cpus: "0.5"
      reservations:
        memory: 64M
        cpus: "0.25"
```

## 🌡️ Monitoreo de Temperatura

### Script de monitoreo automático

```bash
#!/bin/bash
# monitor-temp.sh

temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
echo "$(date): Temperatura CPU: ${temp}°C"

# Alerta si supera 70°C
if (( $(echo "$temp > 70" | bc -l) )); then
    echo "⚠️  ALERTA: Temperatura alta: ${temp}°C"
    # Opcional: enviar notificación
fi
```

### Configurar cron para monitoreo

```bash
# Ejecutar cada 5 minutos
*/5 * * * * /home/pi/monitor-temp.sh >> /home/pi/temp.log
```

## 🔄 Optimizaciones de Red

### 1. Configurar DNS estático

```bash
# Editar /etc/dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Agregar configuración estática:
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=1.1.1.1 8.8.8.8
```

### 2. Optimizar parámetros de red

```bash
# Agregar a /etc/sysctl.conf
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
```

## 📱 Configuración WiFi Optimizada

```bash
# Configurar WiFi en /etc/wpa_supplicant/wpa_supplicant.conf
network={
    ssid="TU_RED_WIFI"
    psk="TU_PASSWORD"
    key_mgmt=WPA-PSK
    proto=WPA2
    pairwise=CCMP
    group=CCMP
    # Optimizaciones
    scan_ssid=1
    priority=5
}
```

## 🔋 Gestión de Energía

### Desactivar servicios innecesarios

```bash
# Desactivar servicios no necesarios
sudo systemctl disable bluetooth
sudo systemctl disable hciuart
sudo systemctl disable cups
sudo systemctl disable avahi-daemon
sudo systemctl disable triggerhappy
```

### Configurar CPU governor

```bash
# Instalar cpufrequtils
sudo apt install cpufrequtils

# Configurar governor
echo 'GOVERNOR="ondemand"' | sudo tee /etc/default/cpufrequtils

# Aplicar cambios
sudo systemctl restart cpufrequtils
```

## 📊 Comandos de Monitoreo

```bash
# Temperatura
vcgencmd measure_temp

# Voltaje
vcgencmd measure_volts

# Frecuencia CPU
vcgencmd measure_clock arm

# Memoria
free -h

# Procesos que más consumen
htop

# Uso de disco
df -h

# Estadísticas de red
iftop

# Logs del sistema
journalctl -f
```

## 🚨 Alertas Automáticas

### Script de alerta por email (opcional)

```bash
#!/bin/bash
# alert-system.sh

# Configuración
EMAIL="tu@email.com"
TEMP_LIMIT=75
MEM_LIMIT=85

# Verificar temperatura
temp=$(vcgencmd measure_temp | cut -d= -f2 | cut -d\' -f1)
if (( $(echo "$temp > $TEMP_LIMIT" | bc -l) )); then
    echo "Temperatura alta: ${temp}°C" | mail -s "Alerta RPi" $EMAIL
fi

# Verificar memoria
mem_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ $mem_usage -gt $MEM_LIMIT ]; then
    echo "Memoria alta: ${mem_usage}%" | mail -s "Alerta RPi" $EMAIL
fi
```

## 🛡️ Seguridad Adicional

### Configurar fail2ban

```bash
# Instalar fail2ban
sudo apt install fail2ban

# Configurar para SSH
sudo nano /etc/fail2ban/jail.local

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

# Reiniciar servicio
sudo systemctl restart fail2ban
```

### Configurar firewall específico

```bash
# Reglas específicas para servicios
sudo ufw allow from 192.168.1.0/24 to any port 22    # SSH solo red local
sudo ufw allow from 192.168.1.0/24 to any port 9000  # Portainer solo red local
sudo ufw allow 51820/udp                              # WireGuard desde internet
sudo ufw allow 80/tcp                                 # HTTP
sudo ufw allow 443/tcp                                # HTTPS
sudo ufw deny in on eth0 from 192.168.1.0/24 to any port 53  # DNS solo desde VPN
```

## 📝 Checklist de Optimización

- [ ] Configurar memoria GPU a 16MB
- [ ] Aumentar swap a 1GB
- [ ] Configurar noatime en filesystem
- [ ] Configurar límites de recursos Docker
- [ ] Configurar IP estática
- [ ] Desactivar servicios innecesarios
- [ ] Configurar monitoreo de temperatura
- [ ] Optimizar parámetros de red
- [ ] Configurar CPU governor
- [ ] Instalar fail2ban
- [ ] Configurar firewall específico
- [ ] Configurar alertas automáticas

---

**Aplicar estas optimizaciones mejorará significativamente el rendimiento de tu Raspberry Pi 3B** 🚀 