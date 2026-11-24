# Informe Final de Proyecto y Demostración — NodoSur (Grupo 13)

* **Universidad:** Universidad Técnica Federico Santa María (UTFSM)
* **Asignatura:** EIN-090B · Taller de Administración de Sistemas (TAS)
* **Grupo:** Grupo 13
* **Integrantes:**
  * Renato Jara
  * Axel Chamblas
  * Benjamín Tello
  * Cristóbal Gatica
* **Dominio del Proyecto:** `https://www.nodosur.cl` (`tas13.local`)
* **Repositorio GitHub:** `https://github.com/BearBlm/proyecto-tas-g13`
* **Fecha:** Noviembre 2026

---

## 1. Resumen de la Plataforma e Inventario de Máquinas Virtuales

El proyecto implementa la plataforma web **NodoSur** (WordPress + WooCommerce) distribuida en **5 máquinas virtuales Ubuntu Server 24.04 LTS** sobre Proxmox VE, conectadas en la red privada **`10.33.199.104/29`** y publicadas hacia la red de la universidad mediante la IP WAN **`10.33.195.195`**.

### 1.1. Inventario de Nodos y Credenciales SSH

| VM | Rol en el Proyecto | Hostname | IP LAN (`/29`) | IP WAN (`/25`) | Usuario SSH | Clave SSH | Servicios Principales |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **VM 1** | Gateway, DNS y Balanceador | `tas13jara`<br>`gw.tas13.local` | `10.33.199.109` | `10.33.195.195` | `renajara` | `tas13.` | HAProxy (`:80`, `:443`, `:8404`, `:3000`), BIND9 (`:53`), NAT (`iptables`), Zabbix Agent 2 (`:10050`). |
| **VM 2** | Nodo Web 1 (CMS) | `web1.tas13.local` | `10.33.199.106` | *(Solo LAN)* | `tas_13` | `usm13` | Contenedor Docker `vm206-web1` (`:80`), Apache + PHP 8.3 + WordPress, cliente NFS, Zabbix Agent 2. |
| **VM 3** | Nodo Web 2 (CMS) | `web2.tas13.local` | `10.33.199.107` | `10.33.195.235`<br>*(Filtrada)* | `benjamin` | `benjamin` | Contenedor Docker `vm248-web2` (`:80`), Apache + PHP 8.3 + WordPress, cliente NFS, Zabbix Agent 2. |
| **VM 4** | Base de Datos | `db.tas13.local` | `10.33.199.108` | `10.33.195.174`<br>*(Filtrada)* | `gatica` | `admin1234` | Contenedor Docker `vm258-db-backup` (`10.33.199.108:3306`), MariaDB 10.11 (`nodosur_db`), Zabbix Agent 2. |
| **VM 5** | Storage NFS, Backups y Monitoreo | `backup.tas13.local` | `10.33.199.110` | *(Solo LAN)* | `tas13_backup` | `tas13.` | Servidor NFS (`/srv/nfs/wordpress`), Bóveda de Respaldos (`/var/backups/tas13`), Zabbix Server (`/zabbix`), Grafana (`:3000`). |

### 1.2. Credenciales de Servicios y Aplicaciones

| Servicio | URL / Dirección | Usuario | Contraseña | Uso |
| :--- | :--- | :---: | :---: | :--- |
| **WordPress (Sitio y Admin)** | `https://www.nodosur.cl`<br>`https://www.nodosur.cl/wp-admin` | `NodosurUser` | *(Admin WP)* | Catálogo y tienda WooCommerce. |
| **Panel HAProxy Stats** | `https://www.nodosur.cl/stats`<br>`http://10.33.195.195:8404/stats` | `admin` | `tas13pass` | Estado de los nodos web y balanceo. |
| **Zabbix Web** | `https://www.nodosur.cl/zabbix/` | `Admin` | `zabbix` | Monitoreo de las 5 VMs y alertas de MariaDB. |
| **Grafana** | `http://10.33.195.195:3000` | `admin` | `AdminTas13!` | Paneles de métricas conectados a Zabbix. |
| **MariaDB (Root)** | `10.33.199.108:3306` | `root` | `RootSuperSeguro2026!` | Administración y restauración desde la bóveda (`.110`). |
| **MariaDB (WordPress)** | `10.33.199.108:3306` (`nodosur_db`) | `wp_nodosur` | `NodoSurPassword2026!` | Conexión de los nodos web `.106` y `.107`. |
| **MariaDB (Backup Pull)** | `10.33.199.108:3306` (`nodosur_db`) | `backup_agent` | `BackupSeguroTAS13!` | Usuario de solo lectura para extraer respaldos desde `.110`. |
| **MariaDB (Monitoreo Zabbix)** | `10.33.199.108:3306` | `zbx_monitor` | `ZbxPassDb2026!` | Usuario de lectura para el chequeo `mysql.ping` de Zabbix. |

---

## 2. Etapa 1: Servicios Operativos

* **Objetivo:** Mostrar los componentes en la topología, el estado de los servicios y ejecutar una operación del CMS que dependa de la base de datos.

### 2.1. Verificación de Servicios en las 5 VMs

```bash
# En VM 1 Gateway (10.33.195.195):
sudo systemctl status haproxy named netfilter-persistent zabbix-agent2 --no-pager
sudo ss -tulpn | grep -E ':(53|80|443|3000|8404|10050)\b'

# En VM 2 Web 1 (10.33.199.106) y VM 3 Web 2 (10.33.199.107):
sudo docker ps
df -h /srv/nfs/wordpress

# En VM 4 Base de Datos (10.33.199.108):
sudo docker ps
sudo ss -tlnp | grep :3306

# En VM 5 Storage, Backups y Monitoreo (10.33.199.110):
sudo systemctl is-active nfs-kernel-server mariadb zabbix-server zabbix-agent2 grafana-server
sudo exportfs -v
```

**Evidencia obtenida:**
* En VM 1: `haproxy` y `named` activos escuchando en los puertos `53`, `80`, `443`, `8404` y `3000`.
* En VM 2 y VM 3: contenedores `vm206-web1` (`10.33.199.106:80`) y `vm248-web2` (`10.33.199.107:80`) en estado `Up`, ambos con la carpeta compartida `10.33.199.110:/srv/nfs/wordpress` montada.
* En VM 4: contenedor `vm258-db-backup` activo en `10.33.199.108:3306`.
* En VM 5: servicios `nfs-kernel-server`, `zabbix-server` y `grafana-server` activos.

### 2.2. Operación Funcional en el CMS (Consulta de Producto en Base de Datos)

Desde el navegador del cliente abrimos `https://www.nodosur.cl/?product=hola-123` (producto de prueba en WooCommerce con `ID = 22`) o consultamos por consola:

```bash
curl -k -I -s "https://www.nodosur.cl/?product=hola-123"
```

**Evidencia en cliente y en base de datos (`10.33.199.108`):**
```bash
sudo docker exec vm258-db-backup mariadb -u root -p'RootSuperSeguro2026!' nodosur_db \
  -e "SELECT ID, post_title, post_type, post_status, post_date FROM wp_posts WHERE post_status='publish' AND post_type IN ('post','page','product') ORDER BY ID;"
```
```text
ID  post_title         post_type  post_status  post_date
1   Hola, mundo!       post       publish      2026-10-16 17:28:23
2   Página de ejemplo  page       publish      2026-10-16 17:28:23
10  Tienda             page       publish      2026-10-22 03:34:45
11  Carrito            page       publish      2026-10-22 03:34:45
12  Finalizar compra   page       publish      2026-10-22 03:34:45
13  Mi cuenta          page       publish      2026-10-22 03:34:46
22  hola 123           product    publish      2026-10-21 23:58:51
```

---

## 3. Etapa 2: Registro A del DNS

* **Objetivo:** Mostrar el registro A configurado en BIND9, consultar el dominio desde un cliente con `dig` o `nslookup`, explicar a qué componente pertenece la IP devuelta y abrir el CMS por nombre.

### 3.1. Configuración del Registro A en BIND9 (`10.33.195.195`)

En la VM 1 (`10.33.195.195`), revisamos el archivo de zona `/etc/bind/zones/db.nodosur.cl`:

```bash
cat /etc/bind/named.conf.local
cat /etc/bind/zones/db.nodosur.cl
sudo named-checkzone nodosur.cl /etc/bind/zones/db.nodosur.cl
```

**Contenido del archivo `/etc/bind/zones/db.nodosur.cl`:**
```dns
$TTL    604800
@       IN      SOA     ns1.nodosur.cl. admin.nodosur.cl. (
                     2026102101         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.nodosur.cl.

; Punto de entrada Balanceador HAProxy (VM 1 - tas13jara)
@       IN      A       10.33.195.195
ns1     IN      A       10.33.195.195
gw      IN      A       10.33.195.195
www     IN      A       10.33.195.195

; Nodos internos en LAN 10.33.199.104/29
gw-lan  IN      A       10.33.199.109
web1    IN      A       10.33.199.106
web2    IN      A       10.33.199.107
db      IN      A       10.33.199.108
backup  IN      A       10.33.199.110
storage IN      A       10.33.199.110
```

### 3.2. Consulta DNS desde el Cliente y Explicación de la IP

```bash
dig @10.33.195.195 www.nodosur.cl A +noall +answer
nslookup www.nodosur.cl 10.33.195.195
```

**Salida obtenida:**
```text
www.nodosur.cl.         604800  IN      A       10.33.195.195
```

**Explicación:**
* La IP **`10.33.195.195`** devuelta por el DNS pertenece a **HAProxy en la VM 1 (Gateway)**, que funciona como el **punto de entrada único** de la plataforma.
* El DNS no entrega las IPs privadas de los servidores web (`10.33.199.106` y `10.33.199.107`) porque esos nodos están aislados en la red interna `/29`. HAProxy recibe a los clientes por HTTPS (`:443`), valida el certificado TLS y reparte las peticiones hacia los dos nodos web internos.

---

## 4. Etapa 3: Observabilidad e Incidente (Falla Controlada de Base de Datos)

* **Objetivo:** Mostrar las señales en estado normal, detener de forma controlada la base de datos, repetir la operación en el CMS desde el cliente y mostrar en métricas, logs y alertas qué cambió y cuándo.

### 4.1. Señales en Estado Normal (Antes de la Falla)

1. **Panel de HAProxy (`https://www.nodosur.cl/stats`):** Ambos servidores `vm206-web1` y `vm248-web2` aparecen en verde (`UP`, código `L7OK/200`).
2. **Zabbix (`https://www.nodosur.cl/zabbix/`):** Los 5 servidores están activos y el chequeo de MariaDB en la VM 4 (`10.33.199.108`) devuelve **`1` (activo)**:
   ```bash
   date -Is && sudo zabbix_agent2 -t 'mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!]'
   ```
   ```text
   2026-11-24T02:28:28+00:00
   mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!][s|1]
   ```

### 4.2. Ejecución de la Falla Controlada en MariaDB

Apagamos el contenedor de base de datos en la VM 4 (`10.33.199.108`) y recargamos HAProxy en la VM 1 (`10.33.195.195`) para limpiar la caché en memoria RAM:

```bash
# En VM 4 Base de Datos (10.33.199.108):
date -Is && sudo docker stop vm258-db-backup

# En VM 1 Gateway (10.33.195.195):
sudo systemctl reload haproxy
```

### 4.3. Evidencia de la Falla en el Cliente, Logs y Zabbix

1. **Error en el Cliente al consultar el producto:**
   ```bash
   date -Is && curl -k -i -s "https://www.nodosur.cl/?product=hola-123" | grep -iE "HTTP/|x-nodo|Error establishing"
   ```
   ```text
   2026-11-24T02:28:31+00:00
   HTTP/2 500 
   x-nodo-backend: vm248-web2
   	<div class="wp-die-message"><h1>Error establishing a database connection</h1></div></body>
   ```

2. **Cambio en Zabbix (`mysql.ping` pasa a `0` y activa la alerta `MySQL: Service is down`):**
   ```bash
   date -Is && sudo zabbix_agent2 -t 'mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!]'
   ```
   ```text
   2026-11-24T02:28:31+00:00
   mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!][s|0]
   ```

3. **Evidencia en los Logs de HAProxy (`10.33.195.195`):**
   ```bash
   sudo journalctl -u haproxy -n 10 --no-pager
   ```
   ```text
   Nov 24 02:28:31 tas13jara haproxy[173679]: 127.0.0.1:58518 [24/Nov/2026:02:28:31.023] https_nodosur~ cluster_wordpress/vm248-web2 0/0/1/13/14 500 2738 - - ---- 1/1/0/0/0 0/0 "GET https://www.nodosur.cl/?product=hola-123 HTTP/2.0"
   Nov 24 02:28:31 tas13jara haproxy[173679]: [WARNING] (173679) : Server cluster_wordpress/vm248-web2 is DOWN, reason: Layer7 wrong status, code: 500, info: "Internal Server Error", check duration: 6ms.
   Nov 24 02:28:31 tas13jara haproxy[173679]: [ALERT] (173679) : backend 'cluster_wordpress' has no server available!
   ```
   * **Diagnóstico:** El log indica `Layer7 wrong status, code: 500`, lo que confirma que los contenedores web Apache siguen encendidos pero WordPress falla al no poder conectarse al puerto `3306` de MariaDB (`10.33.199.108`).

---

## 5. Etapa 4: Restauración de Datos

* **Objetivo:** Levantar nuevamente el motor de base de datos, identificar el respaldo con su fecha y firma SHA-256, y demostrar en una copia de evaluación que un dato eliminado antes de restaurar vuelve a aparecer después.

### 5.1. Inicio del Motor e Identificación del Respaldo

1. **Encender el contenedor MariaDB en la VM 4 (`10.33.199.108`):**
   ```bash
   date -Is && sudo docker start vm258-db-backup
   ```
2. **Identificar el respaldo en la Bóveda (VM 5 — `10.33.199.110`):**
   ```bash
   sudo ls -la /var/backups/tas13/db/
   sudo cat /var/backups/tas13/ultimo_respaldo.sha256
   sudo sha256sum -c /var/backups/tas13/ultimo_respaldo.sha256
   ```
   **Salida obtenida:**
   ```text
   -rw-r--r-- 1 root root 163588 Nov 24 02:00 nodosur_db_20261124_020001.sql.gz
   6084fa605142a9a0d94b895fda4069c34b4800ac69f762f128cefe0a01d45127  /var/backups/tas13/db/nodosur_db_20261124_020001.sql.gz
   /var/backups/tas13/db/nodosur_db_20261124_020001.sql.gz: OK
   /var/backups/tas13/files/wordpress_files_20261124_020001.tar.gz: OK
   ```

### 5.2. Prueba de Restauración en Copia de Evaluación (`nodosur_db_eval`)

En la VM 5 (`10.33.199.110`), usamos la base de datos de evaluación `nodosur_db_eval` para borrar el producto `ID = 22` (`hola 123`), comprobar que no está, restaurar el respaldo `nodosur_db_20261124_020001.sql.gz` y verificar que el producto reaparece:

```bash
sudo bash -c '
mariadb -h 10.33.199.108 -u root -p"RootSuperSeguro2026!" -e "CREATE DATABASE IF NOT EXISTS nodosur_db_eval CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mariadb -h 10.33.199.108 -u root -p"RootSuperSeguro2026!" nodosur_db_eval -e "DELETE FROM wp_posts WHERE ID=22;"

echo "--- 1. ANTES DE RESTAURAR (Producto ID=22 ausente) ---"
mariadb -h 10.33.199.108 -u root -p"RootSuperSeguro2026!" nodosur_db_eval -e "SELECT COUNT(*) AS registros_con_ID_22 FROM wp_posts WHERE ID=22;"

echo "--- 2. RESTAURANDO RESPALDO nodosur_db_20261124_020001.sql.gz ---"
zcat /var/backups/tas13/db/nodosur_db_20261124_020001.sql.gz | mariadb -h 10.33.199.108 -u root -p"RootSuperSeguro2026!" nodosur_db_eval

echo "--- 3. DESPUES DE RESTAURAR (Producto ID=22 recuperado) ---"
mariadb -h 10.33.199.108 -u root -p"RootSuperSeguro2026!" nodosur_db_eval -e "SELECT ID, post_title, post_type, post_status, post_date FROM wp_posts WHERE ID=22;"
'
```

**Resultado obtenido:**
```text
--- 1. ANTES DE RESTAURAR (Producto ID=22 ausente) ---
registros_con_ID_22
0
--- 2. RESTAURANDO RESPALDO nodosur_db_20261124_020001.sql.gz ---
--- 3. DESPUES DE RESTAURAR (Producto ID=22 recuperado) ---
ID      post_title      post_type       post_status     post_date
22      hola 123        product         publish         2026-10-21 23:58:51
```
*(Si se requiere restaurar directamente sobre la base de producción `nodosur_db`, se ejecuta `sudo /usr/local/bin/restore_seguro.sh` en la VM 5).*

---

## 6. Etapa 5: Validación Final

* **Objetivo:** Repetir la operación en el CMS desde el cliente, comprobar que el producto carga por nombre de dominio y verificar que las señales de monitoreo volvieron a la normalidad.

```bash
# 1. En VM 1 Gateway (10.33.195.195): Recargar HAProxy
sudo systemctl reload haproxy

# 2. En VM 4 Base de Datos (10.33.199.108): Comprobar que Zabbix detecta MariaDB arriba (1)
date -Is && sudo zabbix_agent2 -t 'mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!]'

# 3. Desde el Cliente: Consultar nuevamente el producto en www.nodosur.cl
date -Is && curl -k -I -s "https://www.nodosur.cl/?product=hola-123"
```

**Evidencia de recuperación:**
```text
2026-11-24T02:28:38+00:00
mysql.ping[tcp://10.33.199.108:3306,zbx_monitor,ZbxPassDb2026!][s|1]

2026-11-24T02:28:39+00:00
HTTP/2 200 
content-type: text/html; charset=UTF-8
x-nodo-backend: vm206-web1
```
* **Tiempos medidos:**
  * **Tiempo de Detección (TTD):** `< 10 segundos` (meta $\le 5\text{ min}$).
  * **Tiempo de Recuperación (RTO):** `< 2 minutos` (meta $\le 60\text{ min}$).
  * **Punto de Recuperación (RPO):** $\le 24\text{ horas}$ mediante el cron diario de las `02:00 AM` en `/var/backups/tas13/`.

---

## 7. Etapa 6: Defensa Individual por Integrante

| Integrante | Responsabilidad en la Demo | Prueba que Ejecuta / Explica |
| :--- | :--- | :--- |
| **Renato Jara** | **VM 1 (`10.33.195.195`):** Gateway, DNS BIND9 y HAProxy | Muestra `/etc/bind/zones/db.nodosur.cl`, ejecuta `dig @10.33.195.195 www.nodosur.cl` y explica por qué la IP devuelta pertenece a HAProxy como punto de entrada y NAT. |
| **Axel Chamblas** | **VM 2 (`10.33.199.106`):** Nodo Web 1 Docker y NFS | Muestra el estado del contenedor `vm206-web1`, el montaje NFS `/srv/nfs/wordpress` y ejecuta la operación de prueba del producto WooCommerce (`ID = 22`) en el navegador. |
| **Benjamín Tello** | **VM 3 (`10.33.199.107`):** Nodo Web 2 Docker y Logs del Incidente | Muestra el contenedor `vm248-web2`, reproduce el error `HTTP 500` durante la caída de la base de datos e interpreta el log `Layer7 wrong status, code: 500` en HAProxy. |
| **Cristóbal Gatica** | **VM 4 (`.108`) y VM 5 (`.110`):** MariaDB, Bóveda de Backups y Zabbix | Ejecuta la detención y arranque de `vm258-db-backup`, muestra el estado de `mysql.ping` en Zabbix, valida el hash SHA-256 del respaldo y ejecuta la restauración en `nodosur_db_eval`. |

### Preguntas Frecuentes para la Defensa Individual

1. **¿Qué pasa si cae uno de los nodos web (`.106`) versus si cae la base de datos (`.108`)?**
   * Si cae un nodo web, HAProxy lo detecta con su health check y envía todo el tráfico al otro nodo web (`.107`), por lo que el sitio sigue funcionando sin caída (`HTTP 200`).
   * Si cae la base de datos MariaDB (`.108`), es un punto único de falla para ambos nodos web: cualquier consulta dinámica que no esté en la caché RAM de HAProxy falla con `HTTP 500 (Error establishing a database connection)`.
2. **¿Por qué los respaldos se hacen desde la VM 5 (`.110`) conectándose a la VM 4 (`.108`) y no al revés?**
   * Por seguridad (modelo *Pull*): la VM 5 se conecta a MariaDB con el usuario `backup_agent` que solo tiene permisos de lectura (`SELECT, LOCK TABLES`). Así, si alguien vulnera un servidor web o la base de datos, no tiene credenciales para entrar a la VM 5 y borrar los respaldos.
3. **¿Cuáles son los puntos únicos de falla (SPOF) actuales y cómo se mejorarían?**
   * Los SPOF actuales son el Gateway (`10.33.195.195`), el contenedor MariaDB (`10.33.199.108`) y el servidor NFS (`10.33.199.110`).
   * Para eliminarlos en una siguiente etapa se propone agregar un segundo Gateway con **Keepalived (VRRP)**, replicación Primaria-Réplica en **MariaDB** y almacenamiento replicado con **GlusterFS**.
