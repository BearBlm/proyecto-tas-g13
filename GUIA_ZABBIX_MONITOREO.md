# ==============================================================================
# GUÍA TÉCNICA Y DOCUMENTACIÓN DE IMPLEMENTACIÓN DE ZABBIX 7.0 LTS
# PROYECTO TAS-G13: INFRAESTRUCTURA DE ALTA DISPONIBILIDAD (PROXMOX VE)
# ==============================================================================

## 1. Introducción y Arquitectura de Monitoreo

**Zabbix** es una solución de grado empresarial para monitorización distribuida en tiempo real de redes, servidores, máquinas virtuales y servicios de aplicaciones.

### Componentes Clave
1. **Zabbix Server:** Demonio central encargado de consultar y recibir métricas, evaluar condiciones de alarma (*Triggers*), gestionar la base de datos histórica y generar notificaciones.
2. **Base de Datos (MariaDB):** Almacén relacional donde se guardan las configuraciones, plantillas, histórico granular (*History*) y tendencias agrupadas (*Trends*).
3. **Zabbix Web Frontend:** Panel gráfico en PHP/Apache para visualización de métricas, diseño de *Dashboards*, mapas de topología y control de inventario.
4. **Zabbix Agent 2:** Agente ligero de alto rendimiento escrito en Go, instalado en cada nodo cliente para extraer telemetría del sistema operativo y métricas nativas de servicios (MariaDB, Apache, HAProxy, BIND9, etc.).

```text
                                [ ADMINISTRADOR / BROWSER ]
                                             │
                                             ▼ (HTTPS / HTTP)
                       ┌───────────────────────────────────────────┐
                       │   VM 105: GATEWAY & REVERSE PROXY         │
                       │   - HAProxy (zabbix.nodosur.cl)           │
                       │   - DNS BIND9 (Resolución local)          │
                       └─────────────────────┬─────────────────────┘
                                             │ Red LAN (vmbr1: 10.33.199.104/29)
                                             ▼
                       ┌───────────────────────────────────────────┐
                       │   VM 110: SERVIDOR ZABBIX DEDICADO        │
                       │   - IP: 10.33.199.110 (IP Libre Subred)   │
                       │   - Zabbix Server 7.0 LTS (Puerto 10051)  │
                       │   - Zabbix Web UI (Apache2)               │
                       │   - MariaDB Local para Zabbix             │
                       └─────────────┬───────────────┬─────────────┘
                                     │               │ (Sondeo / Agente Activo)
         ┌───────────────────────────┼───────────────┴───────────────────────────┐
         ▼                           ▼                                           ▼
   ┌───────────┐               ┌───────────┐                               ┌───────────┐
   │  VM 105   │               │ VM 106/107│                               │ VM 108/109│
   │  GW / DNS │               │ Web 1 & 2 │                               │ DB / BKP  │
   │  Agent 2  │               │  Agent 2  │                               │  Agent 2  │
   └───────────┘               └───────────┘                               └───────────┘
```

---

## 2. Ubicación en la Red del Proyecto

En el direccionamiento de red del proyecto (`10.33.199.104/29` con máscara `255.255.255.248`):

| Nodo | IP Asignada | Rol en el Proyecto | Integración Zabbix |
| :--- | :--- | :--- | :--- |
| **VM 105** | `10.33.199.105` | Gateway, DNS BIND9, HAProxy | Zabbix Agent 2 + Reverse Proxy Frontend |
| **VM 106** | `10.33.199.106` | Nodo Web 1 (Apache + WP) | Zabbix Agent 2 |
| **VM 107** | `10.33.199.107` | Nodo Web 2 (Apache + WP) | Zabbix Agent 2 |
| **VM 108** | `10.33.199.108` | Servidor MariaDB Base de Datos | Zabbix Agent 2 (plugin MySQL) |
| **VM 109** | `10.33.199.109` | Storage NFS Central y Respaldos | Zabbix Agent 2 (monitoreo discos/cron) |
| **VM 110** | `10.33.199.110` | **IP Libre / Disponible de la subred** | **Servidor Zabbix Server + Web + BD** |

> [!NOTE]
> **Alternativa sin crear nueva VM:** Si existe una restricción académica estricta que limite la infraestructura a exactamente 5 máquinas virtuales, Zabbix Server y su Web pueden instalarse directamente dentro de la **VM 109 (Backup & Storage)** o en un contenedor ligero LXC en el hipervisor Proxmox.

---

## 3. Despliegue del Servidor Zabbix (Paso a Paso)

Ejecutar estos comandos en la máquina designada como servidor de monitoreo (`10.33.199.110`):

### Paso 3.1: Repositorio Oficial e Instalación de Paquetes
```bash
# Descargar repositorio oficial de Zabbix 7.0 LTS para Ubuntu 24.04 LTS
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update

# Instalar Zabbix Server, Frontend Web en Apache y motor MariaDB
sudo apt install -y mariadb-server zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent2
```

### Paso 3.2: Creación de la Base de Datos
```bash
# Crear base de datos y usuario de Zabbix con codificación utf8mb4
sudo mysql -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
sudo mysql -e "create user 'zabbix'@'localhost' identified by 'ZabbixPass2026!';"
sudo mysql -e "grant all privileges on zabbix.* to 'zabbix'@'localhost';"
sudo mysql -e "set global log_bin_trust_function_creators = 1;"

# Importar el esquema y datos iniciales de Zabbix (puede tomar ~1 minuto)
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | sudo mysql -u zabbix -p'ZabbixPass2026!' zabbix

# Reestablecer variable tras la importación
sudo mysql -e "set global log_bin_trust_function_creators = 0;"
```

### Paso 3.3: Configuración del Demonio Zabbix Server
Editar `/etc/zabbix/zabbix_server.conf`:
```bash
sudo sed -i 's/# DBPassword=/DBPassword=ZabbixPass2026!/' /etc/zabbix/zabbix_server.conf
```

### Paso 3.4: Iniciar y Habilitar Servicios
```bash
sudo systemctl restart zabbix-server zabbix-agent2 apache2
sudo systemctl enable zabbix-server zabbix-agent2 apache2
```

---

## 4. Integración con Gateway HAProxy y DNS (VM 105)

Para acceder al panel a través del dominio del proyecto sin exponer puertos no estándar:

### 4.1. Registro en DNS BIND9
En la **VM 105**, editar los archivos de zona `/etc/bind/db.nodosur.cl` y `/etc/bind/db.tas13.local` agregando:
```bind
zabbix          IN      A       10.33.199.105
```
Recargar BIND9: `sudo systemctl reload bind9`.

### 4.2. Enrutamiento en HAProxy
En `/etc/haproxy/haproxy.cfg`, añadir dentro del frontend HTTPS y backend:
```haproxy
frontend https_front
    # ... configuraciones existentes ...
    acl host_zabbix hdr(host) -i zabbix.nodosur.cl
    use_backend zabbix_backend if host_zabbix

backend zabbix_backend
    mode http
    balance roundrobin
    option httpchk GET /zabbix/
    server srv_zabbix 10.33.199.110:80 check inter 4000 rise 2 fall 3
```
Recargar HAProxy: `sudo systemctl reload haproxy`.

---

## 5. Script Automatizado para Zabbix Agent 2 en Todas las VMs

Para monitorear los 5 nodos del proyecto (VM 105 a VM 109), ejecutar el siguiente script en cada una de ellas:

```bash
#!/usr/bin/env bash
# ==============================================================================
# INSTALADOR AUTOMÁTICO DE ZABBIX AGENT 2 - PROYECTO TAS-G13
# ==============================================================================
set -euo pipefail

ZABBIX_SERVER_IP="10.33.199.110"
CURRENT_HOSTNAME=$(hostname)

echo "=== Configurando Zabbix Agent 2 en ${CURRENT_HOSTNAME} ==="

# 1. Instalar repositorio oficial de Zabbix 7.0 LTS
if [ ! -f "/etc/apt/sources.list.d/zabbix.list" ]; then
    wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
    sudo dpkg -i /tmp/zabbix-release.deb
    rm /tmp/zabbix-release.deb
    sudo apt update
fi

# 2. Instalar el paquete de Zabbix Agent 2
sudo apt install -y zabbix-agent2

# 3. Configurar archivo /etc/zabbix/zabbix_agent2.conf
sudo sed -i "s/^Server=127.0.0.1/Server=127.0.0.1,${ZABBIX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sudo sed -i "s/^ServerActive=127.0.0.1/ServerActive=${ZABBIX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=${CURRENT_HOSTNAME}/" /etc/zabbix/zabbix_agent2.conf

# 4. Ajustar Firewall UFW si está activo
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow from 10.33.199.104/29 to any port 10050 proto tcp comment "Zabbix Agent LAN" || true
fi

# 5. Reiniciar y verificar servicio
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2

echo "✔ Zabbix Agent 2 configurado exitosamente enlazado al Server: ${ZABBIX_SERVER_IP}"
```

---

## 6. Métricas y Plantillas por Cada Nodo

Al registrar cada máquina en la interfaz web de Zabbix, asociar las siguientes plantillas oficiales preconfiguradas:

| Nodo | IP | Plantillas Zabbix (Templates) | Métricas Específicas a Supervisar |
| :--- | :--- | :--- | :--- |
| **VM 105 (Gateway / DNS)** | `10.33.199.105` | 1. `Linux by Zabbix agent`<br>2. `HAProxy by HTTP`<br>3. `BIND 9 by HTTP / SNMP` | - Tasa de paquetes y ancho de banda WAN/LAN.<br>- Conexiones simultáneas y salud UP/DOWN de los nodos web.<br>- Latencia de resolución DNS y consultas por segundo. |
| **VM 106 (Web 1)** | `10.33.199.106` | 1. `Linux by Zabbix agent`<br>2. `Apache by HTTP`<br>3. `PHP-FPM by HTTP` | - Tasa de solicitudes HTTP/sec y workers ocupados (`mod_status`).<br>- Tiempos de respuesta del blog WordPress.<br>- Estado del montaje NFS `/var/www/html`. |
| **VM 107 (Web 2)** | `10.33.199.107` | 1. `Linux by Zabbix agent`<br>2. `Apache by HTTP`<br>3. `PHP-FPM by HTTP` | - Comparativa de balanceo con Web 1.<br>- Consumo de memoria RAM por hilos de Apache y OPcache. |
| **VM 108 (MariaDB)** | `10.33.199.108` | 1. `Linux by Zabbix agent`<br>2. `MySQL by Zabbix agent 2` | - Hit ratio del InnoDB Buffer Pool (debe ser > 95%).<br>- Conexiones activas (`Threads_connected` vs `max_connections`).<br>- Consultas lentas (*Slow queries*) y espacio en `/var/lib/mysql`. |
| **VM 109 (Backup & Storage)** | `10.33.199.109` | 1. `Linux by Zabbix agent`<br>2. Plantilla personalizada de disco | - Ocupación de almacenamiento en `/srv/backups` y `/srv/nfs`.<br>- Rendimiento de lectura/escritura (I/O Wait) durante el cron.<br>- Estado de salida del script `restore_seguro.sh` y `backup_seguro.sh`. |

---

## 7. Configuración de Triggers y Alertas Críticas

En **Alerts** ➔ **Actions** o en la sección de Triggers por Host, configurar alertas clave para el proyecto:

1. **Caída de Nodo Web:**
   * Condición: `HAProxy: Backend web_cluster member web1.tas13.local is DOWN`
   * Severidad: **High**
2. **Caída del Servicio MariaDB:**
   * Condición: `MySQL: Service is down or not responding`
   * Severidad: **Disaster**
3. **Saturación de Espacio en Respaldos (VM 109):**
   * Condición: `vfs.fs.size[/srv/backups,pfree] < 15` (menos del 15% libre)
   * Severidad: **Warning**
4. **Falla en Montaje NFS:**
   * Condición: Comprobación de existencia de `/var/www/html/wp-config.php` en Web 1 / Web 2.
   * Severidad: **High**

---

## 8. Manual de Uso del Panel Web Zabbix

1. **Acceso Web:**
   * URL Directa: `http://10.33.199.110/zabbix`
   * URL con Dominio: `https://zabbix.nodosur.cl/zabbix`
   * **Usuario inicial:** `Admin` (Sensible a mayúsculas)
   * **Contraseña inicial:** `zabbix`
   *(Cambiar la contraseña inmediatamente en User Settings).*

2. **Dar de Alta un Host (VM):**
   * Navegar a **Data collection** ➔ **Hosts** ➔ Botón **Create host**.
   * `Host name`: Escribir el FQDN exacto (ej. `web1.tas13.local`).
   * `Templates`: Buscar y seleccionar `Linux by Zabbix agent`.
   * `Host groups`: Seleccionar o crear `TAS-G13 Servers`.
   * `Interfaces`: Clic en **Add** ➔ **Agent** ➔ IP: `10.33.199.106`, Puerto: `10050`.
   * Clic en **Add**.

3. **Verificación de Conectividad:**
   * En la tabla de Hosts, la etiqueta **ZBX** debe encenderse en **verde**.
   * Si queda en gris o rojo, verificar conectividad con `zabbix_get`:
     ```bash
     zabbix_get -s 10.33.199.106 -k agent.ping
     # Si responde "1", la comunicación es correcta.
     ```

4. **Diseño de Mapas de Red (Topología en Vivo):**
   * Ir a **Monitoring** ➔ **Maps** ➔ **Create map**.
   * Dibujar los nodos: VM 105 (GW) enlazada a VM 106, 107, 108 y 109.
   * Si cualquiera de los servicios falla, el icono de la máquina virtual o el enlace cambiará a color rojo y parpadeará en tiempo real en la pantalla.

---

## 9. Comandos Útiles de Diagnóstico

* Ver logs del servidor:
  ```bash
  sudo tail -f /var/log/zabbix/zabbix_server.log
  ```
* Ver logs del agente en cualquier VM:
  ```bash
  sudo tail -f /var/log/zabbix/zabbix_agent2.log
  ```
* Comprobar puertos de escucha:
  ```bash
  # En el servidor (debe escuchar en 10051)
  ss -tulpn | grep 10051
  # En los agentes (debe escuchar en 10050)
  ss -tulpn | grep 10050
  ```
