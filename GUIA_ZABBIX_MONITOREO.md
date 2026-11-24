# ==============================================================================
# GUÍA TÉCNICA Y DOCUMENTACIÓN DE IMPLEMENTACIÓN: ZABBIX 7.0 LTS + GRAFANA OSS
# PROYECTO TAS-G13: INFRAESTRUCTURA DE ALTA DISPONIBILIDAD (PROXMOX VE)
# ARQUITECTURA OPTIMIZADA: TOPE ESTRICTO DE 5 MÁQUINAS VIRTUALES
# ==============================================================================

## 1. Introducción y Justificación de Arquitectura (Tope de 5 VMs)

Para cumplir con las exigencias de la **Entrega 4: Observabilidad y continuidad operacional** respetando la restricción estricta de **máximo 5 Máquinas Virtuales** en Proxmox VE, se diseñó una arquitectura consolidada, segura y de alto rendimiento.

### ¿Por qué integrar Zabbix con Grafana?
1. **Zabbix 7.0 LTS como Motor de Telemetría y Alertas:**
   - Supervisión profunda del sistema operativo y servicios mediante **Zabbix Agent 2** (escrito en Go, bajo consumo de CPU/RAM).
   - Motor de evaluación de eventos y *Triggers* con umbrales configurables (Disaster, High, Warning).
   - Base de datos histórica optimizada con políticas de retención (*History* y *Trends*).
2. **Grafana OSS como Capa de Visualización Ejecutiva y Operativa:**
   - Paneles dinámicos y tableros interactivos para la defensa ante el docente.
   - Conexión nativa con Zabbix mediante el plugin oficial `alexanderzobnin-zabbix-app` a través de la API JSON-RPC de Zabbix (`/zabbix/api_jsonrpc.php`).
   - Monitoreo en tiempo real de disponibilidad, tiempos de respuesta, saturación de CPU/RAM y estado del clúster Web y BD.

---

## 2. Topología y Ubicación en la Red (`10.33.199.104/29`)

Bajo el direccionamiento de la subred privada `/29` (máscara `255.255.255.248`), las 5 VMs quedan distribuidas de la siguiente forma:

| VM ID | Hostname | IP Privada LAN | Rol Principal | Servicios Activos | Rol en Observabilidad |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **VM 105** | `gw.tas13.local`<br>`ns1.nodosur.cl` | `10.33.199.105` (LAN)<br>WAN DHCP/IP PVE | Gateway, Proxy Inverso L7, Router NAT, DNS BIND9 | HAProxy 2.8, BIND9, iptables NAT | **Zabbix Agent 2** + Reverse Proxy SSL para `zabbix.nodosur.cl` y `grafana.nodosur.cl`. |
| **VM 106** | `web1.tas13.local` | `10.33.199.106` | Nodo Web 1 | Apache 2.4, PHP 8.3, WordPress, Cliente NFS | **Zabbix Agent 2** (Métricas Apache, HTTP latency, NFS mount). |
| **VM 107** | `web2.tas13.local` | `10.33.199.107` | Nodo Web 2 | Apache 2.4, PHP 8.3, WordPress, Cliente NFS | **Zabbix Agent 2** (Métricas Apache, balanceo, NFS mount). |
| **VM 108** | `db.tas13.local` | `10.33.199.108` | Servidor de Base de Datos Dedicado | MariaDB 10.11 (`nodosur_db`) | **Zabbix Agent 2** con plugin nativo MySQL (Queries/sec, Buffer Pool, Slow Queries). |
| **VM 109** | `backup.tas13.local`<br>`storage.tas13.local` | `10.33.199.109` | **Nodo Central de Gestión, Respaldos y Observabilidad** | NFS Server (`/srv/nfs/wordpress`), Bóveda de Backups (`/var/backups/tas13`) | **Zabbix Server 7.0 + MariaDB Local + Zabbix Web UI + Grafana OSS + Zabbix Agent 2**. |

```text
                                [ CLIENTE / BROWSER / DOCENTE ]
                                               │
                                               ▼ (HTTPS :443 / DNS :53)
                      ┌────────────────────────────────────────────────────────┐
                      │    VM 105: GATEWAY & REVERSE PROXY (HAProxy + BIND9)   │
                      │    - https://nodosur.cl        ──► Nodos Web (106/107) │
                      │    - https://zabbix.nodosur.cl  ──► VM 109 (:80/zabbix) │
                      │    - https://grafana.nodosur.cl ──► VM 109 (:3000)     │
                      │    - Zabbix Agent 2 (Supervisa Gateway y HAProxy)      │
                      └────────────────────────┬───────────────────────────────┘
                                               │ LAN vmbr1 (10.33.199.104/29)
         ┌─────────────────────────────────────┼─────────────────────────────────────┐
         ▼                                     ▼                                     ▼
 ┌───────────────┐                     ┌───────────────┐                     ┌───────────────┐
 │  VM 106 & 107 │                     │    VM 108     │                     │    VM 109     │
 │  Nodos Web    │                     │ MariaDB Prod  │                     │ Gestión/Obs.  │
 │  Apache + PHP │                     │ BD WordPress  │                     │ NFS + Backups │
 │  Agent 2      │                     │ Agent 2+MySQL │                     │ Zabbix+Grafana│
 └───────┬───────┘                     └───────┬───────┘                     └───────┬───────┘
         │ Telemetría (:10050)                 │ Telemetría (:10050)                 │
         └─────────────────────────────────────┴─────────────────────────────────────┘
                                               ▲
                                  Sondeo Zabbix Server (:10051)
```

### Justificación de Seguridad y Rendimiento de Instalar en VM 109:
1. **Aislamiento de la Base de Datos de Producción (VM 108):**
   - Zabbix Server almacena miles de métricas por minuto. Al alojar su MariaDB local dentro de la VM 109 en `127.0.0.1`, la base de datos de producción de WordPress (VM 108) queda libre de contención de I/O de disco, locking o memoria.
   - **Alta Resiliencia:** Si la base de datos de producción (VM 108) colapsa, el sistema de monitoreo en VM 109 sigue 100% operativo y envía la alerta inmediatamente.
2. **Aprovechamiento de la VM de Gestión:**
   - La VM 109 se encarga de almacenamiento NFS y respaldos automáticos fuera de horas pico. Tiene baja demanda de CPU/RAM la mayor parte del tiempo y cuenta con capacidad de almacenamiento sobredimensionada, siendo el host ideal para consolidar Zabbix y Grafana.
3. **Cero Latencia entre Grafana y Zabbix:**
   - Grafana y Zabbix Server conviven en la misma máquina (`10.33.199.109`), comunicándose por `localhost` sin saturar la red LAN privada ni exponer la API de Zabbix al exterior.

---

## 3. Despliegue de Observabilidad en VM 109 (Zabbix Server + Grafana OSS)

En la **VM 109**, se ejecuta el script de aprovisionamiento automatizado:

```bash
# Dar permisos de ejecución y correr el script instalador
chmod +x /ruta/a/proyecto-tas-g13/proxmox/vm5_backup/setup_zabbix_grafana.sh
sudo /ruta/a/proyecto-tas-g13/proxmox/vm5_backup/setup_zabbix_grafana.sh
```

### Qué realiza este script automáticamente:
1. Agrega repositorios oficiales de **Zabbix 7.0 LTS** y **Grafana OSS**.
2. Instala los paquetes de Zabbix Server, Frontend Web PHP sobre Apache, MariaDB Server y Grafana.
3. Crea la base de datos `zabbix` con codificación `utf8mb4` e importa el esquema relacional inicial.
4. Instala el plugin oficial de Zabbix para Grafana:
   ```bash
   grafana-cli plugins install alexanderzobnin-zabbix-app
   ```
5. Configura `grafana.ini` con el dominio `grafana.nodosur.cl` y subrutas seguras.
6. Instala y enlaza el **Zabbix Agent 2** local de la VM 109.
7. Habilita los servicios `mariadb`, `zabbix-server`, `zabbix-agent2`, `apache2` y `grafana-server` en systemd.

---

## 4. Despliegue de Zabbix Agent 2 en Todas las VMs (VM 105 a VM 109)

En cada una de las 5 máquinas virtuales del proyecto, ejecutar el script unificado:

```bash
chmod +x /ruta/a/proyecto-tas-g13/proxmox/setup_zabbix_agent.sh
sudo /ruta/a/proyecto-tas-g13/proxmox/setup_zabbix_agent.sh
```

El script detecta el `hostname` local de la máquina y apunta el agente al servidor Zabbix en `10.33.199.109`.

### Configuración Específica para VM 108 (Monitoreo de MariaDB):
En la **VM 108**, para permitir que Zabbix Agent 2 consulte las estadísticas de MariaDB sin comprometer la seguridad:
```bash
sudo mysql -e "CREATE USER 'zbx_monitor'@'localhost' IDENTIFIED BY 'ZbxPassDb2026!';"
sudo mysql -e "GRANT REPLICATION CLIENT, PROCESS, SHOW DATABASES, SHOW VIEW ON *.* TO 'zbx_monitor'@'localhost';"
```
Crear `/etc/zabbix/zabbix_agent2.d/plugins.d/mysql.conf`:
```ini
Plugins.Mysql.Sessions.Local.Uri=tcp://10.33.199.108:3306
Plugins.Mysql.Sessions.Local.User=zbx_monitor
Plugins.Mysql.Sessions.Local.Password=ZbxPassDb2026!
```
Reiniciar el agente: `sudo systemctl restart zabbix-agent2`.

---

## 5. Configuración del Gateway HAProxy y DNS BIND9 (VM 105)

### 5.1. Zonas DNS en BIND9 (`/etc/bind/db.nodosur.cl` y `db.tas13.local`)
Asegurar que los subdominios apunten a la IP del Gateway para resolución externa y local:
```bind
zabbix          IN      A       10.30.248.9
grafana         IN      A       10.30.248.9
```
Recargar DNS: `sudo systemctl reload named`.

### 5.2. Enrutamiento L7 en `/etc/haproxy/haproxy.cfg`
HAProxy analiza el encabezado `Host:` y la ruta de la petición:
```haproxy
frontend https_nodosur
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/nodosur.pem
    
    # Detección por Subdominio o Ruta
    acl is_zabbix   hdr(host) -i zabbix.nodosur.cl zabbix.tas13.local
    acl is_grafana  hdr(host) -i grafana.nodosur.cl grafana.tas13.local
    acl is_zabbix_path  path_beg /zabbix
    acl is_grafana_path path_beg /grafana

    use_backend backend_zabbix  if is_zabbix || is_zabbix_path
    use_backend backend_grafana if is_grafana || is_grafana_path
    default_backend cluster_wordpress

backend backend_zabbix
    mode http
    balance roundrobin
    option httpchk GET /zabbix/
    http-check expect rstatus (2|3)[0-9][0-9]
    server vm-zabbix 10.33.199.110:80 check inter 4s fall 3 rise 2

backend backend_grafana
    mode http
    balance roundrobin
    option httpchk GET /api/health
    http-check expect status 200
    server vm-grafana 10.33.199.110:3000 check inter 4s fall 3 rise 2
```
Validar y recargar: `sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy`.

---

## 6. Integración Grafana con Zabbix (Paso a Paso)

Una vez que ambos servicios están corriendo en la VM 109:

1. **Acceder a Grafana:**
   * URL: `https://grafana.nodosur.cl` (o `http://10.33.199.110:3000`)
   * Usuario: `admin` | Contraseña: `AdminTas13!` (definida en el script).
2. **Habilitar el Plugin de Zabbix:**
   * Ir a **Administration** ➔ **Plugins and data** ➔ **Plugins**.
   * Buscar **Zabbix** (de Alexander Zobnin).
   * Clic en **Enable**.
3. **Añadir Zabbix como Data Source:**
   * Ir a **Connections** ➔ **Data sources** ➔ **Add data source**.
   * Seleccionar **Zabbix**.
   * **HTTP settings:**
     * URL: `http://localhost/zabbix/api_jsonrpc.php`
   * **Zabbix API Details:**
     * Username: `Admin`
     * Password: `zabbix` (o la contraseña actualizada de Zabbix).
   * Clic en **Save & test**. Aparecerá un mensaje verde de confirmación: *"API version: 7.0.x"*.

---

## 7. Construcción de Paneles Clave en Grafana (Rúbrica Entrega 4)

Con el Data Source conectado, se crean tableros con las señales requeridas por la rúbrica:

### Panel 1: Salud de Infraestructura y Clúster Web
* **Métrica:** `system.cpu.util` y `vm.memory.util` en hosts `web1.tas13.local` y `web2.tas13.local`.
* **Tipo:** Time series con umbrales en amarillo (75%) y rojo (90%).
* **Concurrencia HTTP:** Tráfico por nodo backend reportado por HAProxy (`haproxy[web1,current_sessions]` vs `haproxy[web2,current_sessions]`).

### Panel 2: Rendimiento y Saturación de Base de Datos (VM 108)
* **InnoDB Buffer Pool Hit Ratio:** Métrica `mysql.buffer_pool_reads` vs `mysql.buffer_pool_read_requests` (debe mantenerse > 99%).
* **Consultas por Segundo (QPS):** `mysql.queries.rate`.
* **Consultas Lentas:** `mysql.slow_queries`.

### Panel 3: Continuidad Operacional y Bóveda de Respaldos (VM 109)
* **Espacio Libre en Disco:** `vfs.fs.size[/var/backups/tas13,pfree]` y `vfs.fs.size[/srv/nfs,pfree]`.
* **Disponibilidad de Nodos (ICMP Ping / Agent Ping):** Panel tipo *Stat* o *Status dot* mostrando las 5 VMs en verde.

---

## 8. Protocolo de Pruebas de Degradación y Alertas en Vivo (Para Defensa)

Para la evaluación presencial con el docente, la rúbrica exige demostrar:
> *"Provocar una degradación controlada y detectar el incidente mediante la plataforma de observabilidad."*

### Escenario 1: Simulación de Caída de un Nodo Web (Web 1)
1. En Proxmox o por SSH en **VM 106**, detener el servicio Apache:
   ```bash
   sudo systemctl stop apache2
   ```
2. **Evidencias Inmediatas:**
   * **En HAProxy:** El health check L7 marca `vm-web1` en estado **DOWN** en menos de 9 segundos.
   * **En Zabbix:** El trigger `Apache service is down on web1.tas13.local` pasa a estado **PROBLEM (High)**.
   * **En Grafana:** El panel de tráfico muestra la redirección del 100% de las peticiones a `web2.tas13.local` sin interrupción del servicio WordPress para los usuarios.
3. **Recuperación:**
   ```bash
   sudo systemctl start apache2
   ```
   El trigger en Zabbix pasa automáticamente a **RESOLVED**.

### Escenario 2: Simulación de Saturación de CPU/Tráfico
1. Desde el Gateway o un equipo cliente, simular concurrencia con ApacheBench:
   ```bash
   ab -n 5000 -c 50 https://nodosur.cl/
   ```
2. Observar en vivo en Grafana el aumento de conexiones simultáneas y la efectividad de la micro-caché de HAProxy mitigando el impacto en los nodos web.

---

## 9. Resumen de Credenciales y Puertos de Gestión

| Servicio | URL / Endpoint | Usuario | Contraseña por Defecto |
| :--- | :--- | :--- | :--- |
| **Zabbix Web UI** | `https://zabbix.nodosur.cl/zabbix`<br>`http://10.33.199.109/zabbix` | `Admin` | `zabbix` |
| **Grafana OSS** | `https://grafana.nodosur.cl`<br>`http://10.33.199.110:3000` | `admin` | `AdminTas13!` |
| **HAProxy Live Stats** | `http://10.30.248.9:8404/stats` | `admin` | `tas13pass` |
| **Zabbix Server Daemon** | `10.33.199.110:10051` | Interno | - |
| **Zabbix Agents (VM 105-109)** | `Port 10050/TCP` | Interno | - |