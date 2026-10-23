# INFORME TÉCNICO DE PROYECTO
## Infraestructura Web de Alta Disponibilidad, Balanceo de Carga, Almacenamiento NFS y DNS
**Proyecto:** Plataforma Web NodoSur (`www.nodosur.cl` / `tas13.local`)  
**Asignatura:** Taller de Administración de Sistemas (TAS) - Grupo 13  
**Sistema Operativo Base:** Ubuntu Server 24.04 LTS en Proxmox VE + Contenedores Docker Distribuidos  
**Fecha:** Octubre 2026  

---

## 1. Resumen Ejecutivo

El presente proyecto implementa una infraestructura real distribuida de servicios web de alta disponibilidad, balanceada, endurecida en seguridad (*hardened*) y tolerante a fallos sobre el hipervisor **Proxmox VE** de la universidad, integrando orquestación mediante **Docker y Docker Compose v2** en cada nodo de servicio.

La solución interconecta las máquinas virtuales del **Grupo 13** en el segmento de red privado aislado **`10.33.199.104/29`** (con salida WAN institucional a través de **`10.33.195.195`**), integrando:
1. **Pasarela de Entrada, Router NAT y Balanceo L7 (`10.33.199.109` / WAN `10.33.195.195`):** HAProxy 2.8 multihilo (`nbthread 2`) con terminación SSL/TLS (`HTTP/2` + `HTTP/1.1`), micro-caché en memoria RAM de 64 MB (`tune.bufsize 262144`), mitigación activa anti-DoS (`stick-table`), bloqueo de vectores como `/xmlrpc.php` y enrutamiento NAT Masquerade persistente (`iptables-persistent`).
2. **Servidor DNS Autoritativo y Recursivo:** BIND9 publicando en el puerto 53 (UDP/TCP) tanto en la interfaz WAN (`10.33.195.195`) como en la interfaz LAN (`10.33.199.109`), resolviendo las zonas `nodosur.cl` y `tas13.local`.
3. **Clúster Web Redundante en Docker (`10.33.199.106` y `10.33.199.107`):** Dos máquinas virtuales independientes ejecutando los contenedores `vm206-web1` y `vm248-web2` (Apache 2.4 + PHP 8.3 con `OPcache` de 256 MB y `output_buffering` de 256 KB + WordPress).
4. **Almacenamiento Compartido NFS Dedicado en 5ta VM (`10.33.199.110`):** Servidor `nfs-kernel-server` exportando `/srv/nfs/wordpress` optimizado con `async,no_subtree_check,no_root_squash`, montado en ambos nodos web para garantizar persistencia y sincronización total.
5. **Capa de Persistencia MariaDB en Docker (`10.33.199.108`):** Contenedor `vm258-db-backup` con MariaDB 10.11 afinado (`max_connections=1000`, `innodb_buffer_pool_size=512M`, `query_cache_size=64M`).
6. **Bóveda Aislada de Respaldos Pull con Integridad SHA-256 (`10.33.199.110`):** Sistema automatizado (`backup_seguro.sh` y `restore_seguro.sh`) que extrae copias en frío de la base de datos y archivos mediante credenciales de solo lectura, empaqueta, genera manifiestos criptográficos SHA-256 y purga con retención de 7 días.

En las pruebas de estrés ejecutadas sobre el clúster optimizado:
* **Bajo tráfico dinámico puro sin caché (`ApacheBench` HTTP/1.0, 5.000 peticiones y concurrencia 100):** Sostuvo **~38.28 – 40.70 req/s** golpeando directamente PHP 8.3 + NFS + MariaDB con **0% de peticiones fallidas** y reparto simétrico entre ambos nodos web.
* **Bajo tráfico HTTP/1.1 con Micro-Caché RAM activa (`wrk`, 100 conexiones concurrentes durante 10s):** Alcanzó **2.023,36 peticiones por segundo** (**20.357 peticiones completadas en 10,06 segundos**) y un ancho de banda de **134,65 MB/s** (`1,32 GB` transferidos) con **0% de tasa de error**.

---

## 2. Arquitectura de Red, Topología y Credenciales de Máquinas Virtuales

### 2.1. Parámetros del Segmento Privado (`/29`) y Red WAN
* **Segmento LAN Privado del Clúster:** `10.33.199.104/29` (Máscara `255.255.255.248`)
  * **Dirección de Red:** `10.33.199.104` *(Excluida)*
  * **Dirección de Broadcast:** `10.33.199.111` *(Excluida)*
  * **Gateway / DNS Interno del Clúster:** `10.33.199.109` (`tas13jara`)
* **Punto Único de Entrada WAN (Red Laboratorio USM):** `10.33.195.195/25` (Gateway WAN: `10.33.195.129`)

```text
                       [ CLIENTES EXTERNOS / NAVEGADORES / RED USM ]
                                             │
                                             ▼ (WAN: 10.33.195.195 - Puertos 80, 443, 8404, 53)
              ┌──────────────────────────────────────────────────────────────┐
              │   VM 1 Gateway: tas13jara (gw.tas13.local / ns1.nodosur.cl)  │
              │   WAN (ens18): 10.33.195.195/25 | LAN (ens19): 10.33.199.109 │
              │   - Router NAT Masquerade (iptables-persistent + ip_forward) │
              │   - DNS BIND9 Autoritativo (nodosur.cl y tas13.local :53)    │
              │   - HAProxy 2.8 SSL/TLS + Micro-Caché RAM 64MB (leastconn)   │
              └──────────────────────────────┬───────────────────────────────┘
                                             │
                     ┌───────────────────────┴───────────────────────┐
                     │ Balanceo L7 HTTP (:80)                        │ Balanceo L7 HTTP (:80)
                     ▼                                               ▼
    ┌─────────────────────────────────┐             ┌─────────────────────────────────┐
    │ VM 2 Web 1: web1.tas13.local    │             │ VM 3 Web 2: web2.tas13.local    │
    │ IP LAN: 10.33.199.106/29        │             │ IP LAN: 10.33.199.107/29        │
    │ 🐳 Docker: vm206-web1           │             │ 🐳 Docker: vm248-web2           │
    │ Apache 2.4 + PHP 8.3 + OPcache  │             │ Apache 2.4 + PHP 8.3 + OPcache  │
    └────────────────┬────────────────┘             └────────────────┬────────────────┘
                     │                                               │
                     ├───────────────────────┬───────────────────────┘
                     │                       │
                     ▼ Conexión SQL (:3306)  ▼ Montaje NFS (:2049)
    ┌─────────────────────────────────┐     ┌─────────────────────────────────┐
    │ VM 4 Database: db.tas13.local   │     │ VM 5 Storage & Bóveda Respaldos │
    │ IP LAN: 10.33.199.108/29        │     │ backup.tas13.local / storage    │
    │ 🐳 Docker: vm258-db-backup      │     │ IP LAN: 10.33.199.110/29        │
    │ - MariaDB 10.11 afinado         │     │ - Servidor NFS (/srv/nfs/wp)    │
    │ - nodosur_db (:3306)            │     │ - Bóveda Pull Backup (SHA-256)  │
    │ - Usuario backup_agent          │     │ - Scripts / Cron 02:00 AM       │
    └─────────────────────────────────┘     └─────────────────────────────────┘
```

---

### 2.2. Matriz de Máquinas Virtuales y Credenciales de Administración

| Rol en el Clúster | Hostname FQDN | IP LAN (`/29`) | IP WAN (`/25`) | Usuario SSH | Contraseña SSH | Contenedor Docker / Servicios Activos |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **1. Gateway, DNS & Balanceador** | `gw.tas13.local`<br>`tas13jara` | `10.33.199.109` | `10.33.195.195` | `renajara` | `tas13.` | Nativo: `haproxy` (`:80`, `:443`, `:8404`), `named` BIND9 (`:53`), `netfilter-persistent` (NAT Masquerade). |
| **2. Nodo Web 1** | `web1.tas13.local` | `10.33.199.106` | *(Aislada vía NAT)* | `tas_13` | `usm13` | 🐳 **`vm206-web1`** (`tas13-web-wp:latest`) en `10.33.199.106:80` + Cliente NFS montando desde `.110`. |
| **3. Nodo Web 2** | `web2.tas13.local` | `10.33.199.107` | `10.33.195.235`<br>*(Filtrada)* | `benjamin` | `benjamin` | 🐳 **`vm248-web2`** (`tas13-web-wp:latest`) en `10.33.199.107:80` + Cliente NFS montando desde `.110`. |
| **4. Base de Datos Dedicada** | `db.tas13.local`<br>`cg108` | `10.33.199.108` | `10.33.195.174`<br>*(Filtrada con DROP)* | `gatica` | `admin1234` | 🐳 **`vm258-db-backup`** (`tas13-db-backup:latest`) MariaDB 10.11 en `10.33.199.108:3306`. |
| **5. Storage NFS & Bóveda Backup** | `backup.tas13.local`<br>`storage.tas13.local` | `10.33.199.110` | *(Aislada / Sin IPv4 pública)* | `tas13_backup` | `tas13.` | `nfs-kernel-server` (`/srv/nfs/wordpress`), Bóveda Pull (`backup_seguro.sh` con firmas SHA-256 diario a las 02:00 AM), `restore_seguro.sh`, Docker Engine. |

### 2.3. Credenciales de Servicios y Aplicaciones

| Servicio / Plataforma | URL / Host de Conexión | Usuario | Contraseña | Notas Técnicas |
| :--- | :--- | :---: | :---: | :--- |
| **Panel de Métricas HAProxy** | `https://www.nodosur.cl/stats`<br>`http://10.33.195.195:8404/stats` | `admin` | `tas13pass` | Monitoreo en tiempo real (refresco 2s) habilitado en HTTPS y puerto 8404. |
| **MariaDB (Root administrativo)** | `10.33.199.108:3306` (`vm258-db-backup`) | `root` | `RootSuperSeguro2026!` | Uso interno del contenedor para mantenimiento de base de datos. |
| **MariaDB (App WordPress)** | `10.33.199.108:3306` (`nodosur_db`) | `wp_nodosur` | `NodoSurPassword2026!` | Concesión de privilegios desde los nodos web de la LAN (`10.33.199.%`). |
| **MariaDB (Agente Pull Backup)** | `10.33.199.108:3306` (`nodosur_db`) | `backup_agent` | `BackupSeguroTAS13!` | Usuario con permisos mínimos estrictos (`SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD`) para la bóveda en `.110`. |

---

### 2.4. Evaluación y Justificación Arquitectónica: Salida Única WAN (Gateway / NAT / Bastión)

La arquitectura donde **una única máquina virtual posee salida WAN y enruta a las demás vía NAT Masquerade** es la decisión de diseño más sólida, robusta y estándar en infraestructuras de servidores empresariales.

#### A. Ventajas Técnicas y de Seguridad
1. **Reducción Drástica de la Superficie de Ataque (*Attack Surface Reduction*):**
   * En lugar de exponer 5 máquinas a la red externa con sus respectivos demonios (SSH, Apache, MariaDB en el puerto 3306, NFS RPC en 2049, etc.), solo el Gateway (`10.33.195.195`) interactúa directamente con el tráfico entrante de la universidad/Internet.
   * Si las bases de datos o el almacenamiento NFS estuvieran expuestos en WAN, cualquier escáner de red o equipo infectado en el campus podría lanzar ataques de fuerza bruta o explotación de vulnerabilidades directas.
2. **Defensa en Profundidad y Aislamiento de Red (*Defense in Depth / Zero-Trust Segmentation*):**
   * La subred `10.33.199.104/29` opera como una red privada aislada (DMZ interna). Los clientes externos **nunca interactúan directamente con los servidores web ni con la base de datos**.
   * HAProxy actúa como Proxy Inverso de Capa 7 (L7): inspecciona y valida el protocolo HTTP/HTTPS, descifra el tráfico TLS, aplica filtrado de seguridad (bloqueo de `/xmlrpc.php`, rate-limiting contra fuerza bruta) y solo reenvía peticiones legítimas a la red privada.
3. **Punto Único de Control, Auditoría y Observabilidad:**
   * Centraliza los registros de acceso, telemetría de tráfico, políticas de firewall (`iptables` / `netfilter`), mitigación anti-DoS y caché en memoria RAM.
4. **Conservación y Gestión Eficiente de Direcciones IP Públicas:**
   * La red del campus no necesita asignar un pool de IPs públicas a cada nodo. Con una sola IP WAN (`10.33.195.195`), se publican de forma segura todos los servicios del clúster (HTTP, HTTPS, DNS, Métricas).

#### B. Trade-Off y Mitigación en Producción de Gran Escala
* **Punto Único de Fallo (*Single Point of Failure - SPoF*):**
  * Teóricamente, si el Gateway se apaga, todo el clúster pierde conectividad externa.
  * **Solución de Grado Corporativo:** En centros de datos de misión crítica, este modelo de Gateway único se robustece duplicando el router en un clúster activo-pasivo o activo-activo mediante protocolos de redundancia como **VRRP / Keepalived / CARP** compartiendo una IP Virtual (VIP).
  * Para el alcance de este laboratorio de 5 nodos, mantener una arquitectura de Pasarela/Bastión dedicada es técnicamente la opción óptima, limpia y profesional.

---

## 3. Detalles de Implementación y Optimización por Componente

### 3.1. Enrutamiento NAT y Servidor DNS BIND9 (`10.33.199.109` / `10.33.195.195`)
* **Enrutamiento y Salida a Internet para la Subred `/29`:**
  * Se activó `net.ipv4.ip_forward = 1` de forma persistente en `/etc/sysctl.d/99-ip-forward.conf`.
  * Se configuró `iptables -t nat -A POSTROUTING -s 10.33.199.104/29 -o ens18 -j MASQUERADE` junto con `iptables-persistent` para que todos los nodos internos (`.106`, `.107`, `.108`, `.110`) salgan a Internet exclusivamente a través del Gateway.
* **DNS Autoritativo BIND9 (`/etc/bind/named.conf.options` y `/etc/bind/named.conf.local`):**
  * Escucha en `127.0.0.1`, `10.33.195.195` (WAN) y `10.33.199.109` (LAN).
  * Zonas maestras activas (`serial 2026102102`):
    * **`nodosur.cl`** (`/etc/bind/zones/db.nodosur.cl`): resuelve `@`, `www`, `ns1`, `gw` $\rightarrow$ `10.33.195.195`; `gw-lan` $\rightarrow$ `10.33.199.109`; `web1` $\rightarrow$ `10.33.199.106`; `web2` $\rightarrow$ `10.33.199.107`; `db` $\rightarrow$ `10.33.199.108`; `backup`, `storage` $\rightarrow$ `10.33.199.110`.
    * **`tas13.local`** (`/etc/bind/zones/db.tas13.local`): resuelve todos los nodos internos y alias del clúster.

### 3.2. Balanceador HAProxy 2.8 y Micro-Caché en RAM (`/etc/haproxy/haproxy.cfg`)
* **Terminación SSL/TLS y HTTP/2:**
  * Opera en los puertos `80` (redirección automática `302` a HTTPS) y `443` con certificado X.509 (`nodosur.pem`) y negociación `alpn h2,http/1.1`.
* **Afinamiento de la Micro-Caché en RAM (`cache_nodosur`):**
  * Durante las pruebas iniciales se detectó que la portada HTML de WordPress pesaba `69.300 bytes` (~69 KB), superando el buffer por defecto de HAProxy (`tune.bufsize = 16 KB`), lo que impedía almacenar la página en caché (`X-Estado-Cache: MISS`).
  * **Solución implementada:** Se amplió `tune.bufsize 262144` (256 KB) en `global`, `total-max-size 64` (64 MB) y `max-object-size 200000` en `cache_nodosur`, junto con `output_buffering = 262144` en PHP 8.3. Con ello, las peticiones `GET` públicas se sirven directamente desde la RAM del Gateway (`X-Estado-Cache: HIT`, `X-Nodo-Backend: haproxy-ram-cache`).

### 3.3. Clúster Web en Docker (`vm206-web1` en `.106` y `vm248-web2` en `.107`)
* **Contenedores basados en Ubuntu 24.04 (`tas13-web-wp:latest`):**
  * Ejecutan Apache 2.4 (`mpm_prefork` afinado a `MaxRequestWorkers 200`, `KeepAlive On`) y PHP 8.3.
  * **OPcache optimizado (`/etc/php/8.3/apache2/conf.d/99-opcache-tas.ini`):** `opcache.memory_consumption=256`, `opcache.max_accelerated_files=20000`, `opcache.revalidate_freq=60` (evita llamadas `stat()` repetitivas por red hacia el servidor NFS).
* **Montaje NFS Compartido (`/etc/fstab`):**
  * Ambos nodos montan `10.33.199.110:/srv/nfs/wordpress` en `/srv/nfs/wordpress` (con opciones `rw,async,noatime,nodiratime,actimeo=60,hard,_netdev`) y lo inyectan como volumen en `/var/www/html` dentro de cada contenedor.

### 3.4. Capa de Persistencia MariaDB 10.11 (`vm258-db-backup` en `.108`)
* **Afinamiento de MariaDB (`/etc/mysql/mariadb.conf.d/99-tas-tuning.cnf`):**
  * `max_connections = 1000`, `innodb_buffer_pool_size = 512M`, `innodb_flush_log_at_trx_commit = 2`, `skip-name-resolve`, `query_cache_type = 1`, `query_cache_size = 64M`.
  * La base de datos opera de manera aislada y dedicada en la VM 4 (`10.33.199.108`), habiendo delegado la carga de almacenamiento masivo y bóveda a la 5ta VM.

### 3.5. Almacenamiento Compartido NFS y Bóveda Segura de Respaldos Pull (`10.33.199.110`)
* **Servidor de Almacenamiento NFS:**
  * Aloja el árbol centralizado `/srv/nfs/wordpress` exportado mediante `nfs-kernel-server` hacia `.106` y `.107`.
* **Bóveda de Respaldos Pull con Integridad SHA-256 (`/usr/local/bin/backup_seguro.sh`):**
  * **Modelo de Seguridad Pull:** En lugar de que la máquina de base de datos empuje backups (lo que requeriría que la base de datos tenga llaves de acceso a la bóveda), la bóveda (`10.33.199.110`) se conecta como agente a MariaDB (`10.33.199.108`) usando un usuario con permisos estrictamente limitados a lectura (`backup_agent`).
  * Genera el dump SQL de `nodosur_db` empaquetado en gzip y el tarball de los archivos web.
  * Calcula hashes criptográficos **SHA-256** en `manifest_<fecha>.sha256` y valida automáticamente la integridad antes de almacenar (`sha256sum -c`).
  * Conserva un enlace simbólico/copia a `ultimo_respaldo.sql.gz` y purga automáticamente respaldos con más de 7 días de antigüedad.
  * Programado mediante tarea cron diaria a las **02:00 AM** (`/var/log/backup_tas13.log`).
* **Procedimiento Automatizado de Contingencia / Disaster Recovery (`/usr/local/bin/restore_seguro.sh`):**
  * Verifica el manifiesto SHA-256 contra adulteraciones, recrea la base de datos `nodosur_db` e inyecta los datos limpios en la VM 108, restaurando además el árbol de archivos en NFS.

---

## 4. Auditoría de Brechas de Seguridad y Blindaje Aplicado (*Hardening*)

Durante el despliegue y auditoría de las 4 VMs se detectaron y corrigieron **5 brechas críticas de seguridad**:

1. **Aislamiento de Interfaces WAN Secundarias en `.107` y `.108`:**
   * **Hallazgo:** Las VMs `.107` (`ens19: 10.33.195.235`) y `.108` (`ens18: 10.33.195.174`) poseían interfaces en la red del laboratorio y Docker exponía por defecto los puertos `80` y `3306` en `0.0.0.0`.
   * **Mitigación Aplicada:**
     * Se modificaron los `docker-compose.yml` de las tres VMs para atar los puertos **exclusivamente a su IP privada de la subred `/29`**: `10.33.199.106:80:80`, `10.33.199.107:80:80` y `10.33.199.108:3306:3306`.
     * Se aplicaron reglas `iptables -I INPUT -i ens18 -p tcp/udp --dport <111|2049|3306> -j DROP` en la VM `.108` para bloquear cualquier intento de conexión a MariaDB o NFS desde fuera de la red privada `10.33.199.104/29`.
2. **Bloqueo del Vector `/xmlrpc.php` y Protección Anti-Fuerza Bruta en `/wp-login.php`:**
   * **Hallazgo:** `/xmlrpc.php` estaba accesible públicamente, permitiendo ataques de fuerza bruta multiplicada y pingbacks DDoS.
   * **Mitigación Aplicada:** Se añadió en HAProxy `http-request deny deny_status 403 if { path_beg /xmlrpc.php }` (verificado devolviendo `HTTP/2 403 Forbidden`) y limitación activa de tasa (`HTTP 429 Too Many Requests`) sobre `POST /wp-login.php` cuando una IP supera 15 intentos en 10 segundos usando la `stick-table`.
3. **Ocultamiento de Versiones de Servidor y PHP (*Banner Grabbing*):**
   * **Mitigación Aplicada:** Se configuró `ServerTokens Prod`, `ServerSignature Off` y `expose_php = Off` en los contenedores web, además de `http-response del-header Server` y `http-response del-header X-Powered-By` en HAProxy.
4. **Cabeceras de Seguridad HTTP en el Balanceador:**
   * Se inyectan en cada respuesta `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff` y `Referrer-Policy: strict-origin-when-cross-origin`.
5. **Eliminación de Servicios Residuales Expuestos:**
   * Se detuvieron y deshabilitaron las instancias antiguas locales de `apache2`, `mysql` y `bind9` que venían preinstaladas en las VMs de entregas anteriores, liberando memoria RAM y reduciendo la superficie de ataque.

---

## 5. Resultados de las Pruebas de Estrés (Antes vs. Después de la Optimización)

### 5.1. Pruebas de Estrés al Backend Dinámico Sin Caché (`ApacheBench` HTTP/1.0)
Al emplear `ab` (protocolo `HTTP/1.0`, que no utiliza caché HTTP/1.1 y obliga a cada petición a negociar TLS, pasar por HAProxy y ejecutar PHP 8.3 + NFS + MariaDB en los contenedores `vm206-web1` y `vm248-web2`):

| Métrica | Ronda 1 (`500 req`, `c=25`) | Ronda 2 (`2.000 req`, `c=50`) | Ronda 3 (`5.000 req`, `c=100`) |
| :--- | :---: | :---: | :---: |
| **Peticiones Completadas** | 500 | 2.000 | **5.000** |
| **Peticiones Fallidas** | **0 (0.0%)** | **0 (0.0%)** | **0 (0.0%)** |
| **Throughput (Peticiones/seg)** | 40.43 req/s | **40.70 req/s** | **38.28 req/s** |
| **Tiempo medio por petición concurrente** | 24.73 ms | 24.57 ms | 26.12 ms |
| **Tasa de Transferencia** | 2.75 MB/s | 2.77 MB/s | 2.61 MB/s |

### 5.2. Prueba de Estrés Extremo HTTP/1.1 con Micro-Caché RAM Activa (`wrk`)
Al evaluar el clúster con clientes modernos **HTTP/1.1 (`wrk -t2 -c100 -d10s https://www.nodosur.cl/`)** tras ajustar `tune.bufsize 262144` y `output_buffering=262144` (`X-Estado-Cache: HIT`):

| Métrica | Antes de Optimizar (`MISS`) | Después de Optimizar (`HIT` en RAM) | Mejora Obtenida |
| :--- | :---: | :---: | :---: |
| **Throughput Sostenido (`Requests/sec`)** | 37.18 req/s | **2.023,36 req/s** | **+5.342% (54,4x más rápido)** |
| **Total Peticiones en 10 segundos (`c=100`)** | ~372 req | **20.357 req** | **54,7x más volumen** |
| **Tasa de Transferencia (`Transfer/sec`)** | 2.53 MB/s | **134,65 MB/s (1,32 GB en 10s)** | **53,2x más ancho de banda** |
| **Latencia Promedio bajo 100 clientes** | 2.689,68 ms | **55,92 ms** | **48x menor latencia** |
| **Tasa de Fallos (Errores HTTP / Socket)** | 0 (0.0%) | **0 (0.0%)** | **100% Disponibilidad** |

---

## 6. Indicador Visual de Nodo en Tiempo Real y Panel de Control HAProxy en Español

### 6.1. Indicador Visual de Balanceo en WordPress (`tas13-nodo-badge.php`)
Para facilitar la demostración en vivo del balanceo de carga y la conmutación ante fallos (*failover*) sin alterar el núcleo de WordPress, se implementó un **Must-Use Plugin (`mu-plugin`)** en el volumen compartido NFS (`/srv/nfs/wordpress/wp-content/mu-plugins/tas13-nodo-badge.php`):
* Muestra una **tarjeta flotante en la esquina inferior derecha** de todas las páginas de `https://www.nodosur.cl`:
  * **🟢 NODO WEB 1 (`vm206-web1`) — `IP LAN: 10.33.199.106 • Host: web1.tas13.local`** (Color verde esmeralda).
  * **🔵 NODO WEB 2 (`vm248-web2`) — `IP LAN: 10.33.199.107 • Host: web2.tas13.local`** (Color azul eléctrico).
* Incluye una comprobación asíncrona `HEAD` en tiempo real (`Cache-Control: no-cache`) que lee la cabecera `X-Nodo-Backend` devuelta por HAProxy en cada recarga (`F5`), mostrando instantáneamente qué servidor está atendiendo la solicitud o cuándo el tráfico conmuta al apagar uno de los nodos.

### 6.2. Panel de Administración Interactivo Nativo de HAProxy (`/stats`)
Se habilitó el modo administrativo interactivo nativo (`stats admin if TRUE`) directamente en HAProxy, permitiendo controlar los servidores del clúster desde el navegador en **[https://www.nodosur.cl/stats](https://www.nodosur.cl/stats)** o **[http://10.33.195.195:8404/stats](http://10.33.195.195:8404/stats)**:

1. **Cómo apagar / poner en mantenimiento un nodo web desde el navegador:**
   * En la tabla **`cluster_wordpress`**, marcar la casilla a la izquierda de **`vm206-web1`** o **`vm248-web2`**.
   * En el menú desplegable **`Choose the action to perform on the checked servers`**, elegir **`Set state to MAINT`** y pulsar **`Apply`**.
   * El nodo seleccionado pasa a estado `MAINT` (color café) y el 100% de las peticiones pasan de inmediato al nodo activo restante.
2. **Cómo volver a encender / activar un nodo web:**
   * Marcar la casilla del servidor en mantenimiento, elegir **`Set state to READY`** en el menú desplegable y pulsar **`Apply`**.
   * El servidor vuelve a estado `UP` (color verde) y reanuda el balanceo `50% / 50%`.
3. **Otras acciones disponibles:**
   * **`Set state to DRAIN`:** Permite terminar las sesiones actuales sin recibir nuevos clientes.
   * **`Kill Sessions`:** Desconecta de inmediato las sesiones activas en ese nodo.
   * **`Enable / Disable health checks`:** Controla el monitoreo activo L7 sobre el nodo.

---

## 7. Manual Operativo del Administrador: Escenarios y Guía Rápida de Comandos

Esta sección reúne los comandos indispensables ("los que se deben saber sí o sí") para administrar, auditar, diagnosticar y operar el clúster en tiempo real, clasificados por situaciones prácticas y escenarios de contingencia.

---

### 7.1. Guía Rápida: Los Comandos "Must-Know" (Que se deben saber sí o sí)

Estos son los comandos esenciales organizados por nodo que todo administrador del proyecto debe dominar para auditorías o demostraciones en vivo:

#### A. En el Gateway / Balanceador (`10.33.195.195` / `10.33.199.109` - `renajara`)
```bash
# 1. Verificar estado de los servicios críticos del Gateway
sudo systemctl status haproxy named netfilter-persistent

# 2. Recargar configuración de HAProxy sin cortar conexiones activas (Zero-Downtime)
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy

# 3. Comprobar salud y código HTTP devuelto por el clúster web
curl -k -I -s -H "Host: www.nodosur.cl" https://127.0.0.1/ | grep -iE "HTTP/|x-nodo|x-estado-cache"

# 4. Validar resolución DNS autoritativa de las zonas
dig @127.0.0.1 www.nodosur.cl +short
dig @127.0.0.1 backup.tas13.local +short

# 5. Ver reglas de NAT Masquerade activas hacia Internet
sudo iptables -t nat -L POSTROUTING -v -n
```

#### B. En los Nodos Web (`10.33.199.106` y `10.33.199.107` - `tas_13` / `benjamin`)
```bash
# 1. Ver estado del contenedor Docker Web y recursos consumidos
docker ps -a
docker stats --no-stream

# 2. Ver logs en tiempo real de Apache y PHP (accesos y errores)
docker logs -f vm206-web1 --tail 50       # En Web 1 (.106)
docker logs -f vm248-web2 --tail 50       # En Web 2 (.107)

# 3. Comprobar que el almacenamiento NFS compartido está montado correctamente
df -h /srv/nfs/wordpress
mount | grep nfs
```

#### C. En el Nodo de Base de Datos (`10.33.199.108` - `gatica`)
```bash
# 1. Ver estado del contenedor MariaDB
docker ps -a --filter name=vm258-db-backup

# 2. Conectarse a la consola interactiva de MariaDB
docker exec -it vm258-db-backup mariadb -u root -pRootSuperSeguro2026! nodosur_db

# 3. Ver conexiones activas y consultas concurrentes en MySQL
docker exec vm258-db-backup mariadb -u root -pRootSuperSeguro2026! -e "SHOW PROCESSLIST;"
```

#### D. En la Bóveda de Almacenamiento y Respaldos (`10.33.199.110` - `tas13_backup`)
```bash
# 1. Comprobar que el servidor NFS está exportando a ambos nodos web
sudo exportfs -v

# 2. Ejecutar un respaldo seguro manual (Dump MariaDB + Tarball NFS + Manifiesto SHA-256)
sudo /usr/local/bin/backup_seguro.sh

# 3. Listar las copias de seguridad existentes y comprobar su integridad criptográfica
sudo ls -lh /var/backups/tas13/ /var/backups/tas13/db/ /var/backups/tas13/files/
sudo sha256sum -c /var/backups/tas13/ultimo_respaldo.sha256

# 4. Ver los logs de ejecución de las copias automáticas programadas (Cron 02:00 AM)
tail -n 50 /var/log/backup_tas13.log
```

---

### 7.2. Catálogo de Situaciones Operativas y Procedimientos Paso a Paso

#### Situación 1: Simulación de Caída de un Nodo Web (Prueba de Tolerancia a Fallos / Failover)
* **Objetivo:** Demostrar que si un servidor web cae, los usuarios no sufren interrupción del servicio y el tráfico es asumido al 100% por el nodo restante.
* **Opción A (Desde el Panel Web de HAProxy):**
  1. Ingresar en el navegador a `https://www.nodosur.cl/stats` (usuario `admin`, clave `tas13pass`).
  2. En la tabla **`cluster_wordpress`**, marcar la casilla a la izquierda de `vm206-web1`.
  3. En el desplegable inferior, seleccionar **`Set state to MAINT`** y pulsar **`Apply`**.
  4. Recargar `https://www.nodosur.cl/` (F5): el badge visual cambiará instantáneamente a **🔵 NODO WEB 2 (vm248-web2)** con cero errores.
  5. Para restaurarlo: seleccionar `vm206-web1`, elegir **`Set state to READY`** y pulsar **`Apply`**.
* **Opción B (Por Consola SSH apagando el contenedor Docker):**
  ```bash
  # En Web 1 (10.33.199.106):
  sudo docker stop vm206-web1

  # Comprobar desde Gateway o Navegador que todo sigue funcionando:
  curl -k -I -s -H "Host: www.nodosur.cl" https://127.0.0.1/ | grep -i x-nodo-backend
  # (Devuelve: x-nodo-backend: vm248-web2)

  # Para reactivar el nodo:
  sudo docker start vm206-web1
  ```

---

#### Situación 2: Purga o Refresco Inmediato de la Micro-Caché en RAM
* **Problema:** Se publicó un nuevo artículo o plugin en WordPress, pero HAProxy sigue entregando la versión anterior desde la memoria RAM (`X-Estado-Cache: HIT`).
* **Procedimiento:**
  ```bash
  # En el Gateway (10.33.195.195):
  # Recargar HAProxy limpia instantáneamente la tabla de caché de 64 MB sin perder sesiones
  sudo systemctl reload haproxy

  # Verificar que la primera petición posterior genera un MISS y refresca la caché:
  curl -k -I -s -H "Host: www.nodosur.cl" https://127.0.0.1/ | grep -i x-estado-cache
  # Petición 1 -> X-Estado-Cache: MISS (Se carga a la RAM)
  # Petición 2 -> X-Estado-Cache: HIT  (Servido a velocidad ultrarrápida)
  ```

---

#### Situación 3: Ejecución de Respaldo Seguro y Validación Criptográfica Manual
* **Procedimiento:**
  ```bash
  # En la VM 110 (10.33.199.110):
  sudo /usr/local/bin/backup_seguro.sh

  # Salida esperada:
  # --> [1/4] Extrayendo dump de MariaDB (10.33.199.108)...
  # --> [2/4] Empaquetando árbol de archivos compartidos de WordPress...
  # --> [3/4] Generando firmas criptográficas SHA-256...
  # --> [4/4] Validando integridad del respaldo...
  # /var/backups/tas13/db/nodosur_db_YYYYMMDD_HHMMSS.sql.gz: OK
  # /var/backups/tas13/files/wordpress_files_YYYYMMDD_HHMMSS.tar.gz: OK
  # ¡Respaldo seguro finalizado con éxito!
  ```

---

#### Situación 4: Procedimiento de Desastre y Restauración Completa (*Disaster Recovery*)
* **Escenario:** Un fallo catastrófico, corrupción accidental o ataque borró la base de datos `nodosur_db` o los archivos de WordPress.
* **Procedimiento de Recuperación:**
  ```bash
  # En la VM 110 (10.33.199.110):
  sudo /usr/local/bin/restore_seguro.sh

  # El script automáticamente:
  # 1. Verifica los hashes SHA-256 de ultimo_respaldo.sha256 para evitar restaurar archivos adulterados.
  # 2. Recrea la base de datos en MariaDB (10.33.199.108) e inyecta el SQL limpio.
  # 3. Descomprime los archivos limpios en /srv/nfs/wordpress y repara permisos (www-data:www-data).
  # 4. Los contenedores web vuelven a operar de inmediato sin necesidad de reiniciarlos.
  ```

---

#### Situación 5: Diagnóstico y Reparación de Montajes NFS
* **Problema:** Uno de los nodos web reporta error de lectura de archivos o el directorio `/srv/nfs/wordpress` aparece vacío.
* **Procedimiento de Diagnóstico:**
  ```bash
  # 1. Desde el nodo web afectado (.106 o .107), verificar si ve el servidor NFS:
  showmount -e 10.33.199.110

  # 2. Forzar desmontaje limpio y remontaje según /etc/fstab:
  sudo umount -l /srv/nfs/wordpress || true
  sudo mount -a
  df -h /srv/nfs/wordpress

  # 3. Reiniciar el contenedor web para que tome el descriptor de archivos actualizado:
  sudo docker restart vm206-web1   # (o vm248-web2 en .107)

  # 4. Si el servidor NFS (.110) fue reiniciado, verificar que el servicio esté arriba:
  # En 10.33.199.110:
  sudo exportfs -ra && sudo systemctl restart nfs-kernel-server
  ```

---

#### Situación 6: Verificación de DNS BIND9 y Actualización de Registros
* **Procedimiento:**
  ```bash
  # En el Gateway (10.33.195.195):
  # 1. Validar sintaxis de archivos de configuración y zonas:
  sudo named-checkconf
  sudo named-checkzone nodosur.cl /etc/bind/zones/db.nodosur.cl
  sudo named-checkzone tas13.local /etc/bind/zones/db.tas13.local

  # 2. Reiniciar el servicio DNS tras editar zonas:
  sudo systemctl restart named

  # 3. Comprobar que responde tanto en LAN como en WAN:
  dig @127.0.0.1 www.nodosur.cl +short
  dig @10.33.195.195 www.nodosur.cl +short
  dig @10.33.199.109 db.tas13.local +short
  ```

---

#### Situación 7: Auditoría de Seguridad, Ataques Bloqueados y Rate-Limiting
* **Procedimiento:**
  ```bash
  # En el Gateway (10.33.195.195):
  # 1. Probar bloqueo inmediato del vector /xmlrpc.php (debe devolver HTTP/2 403 Forbidden):
  curl -k -I -s -H "Host: www.nodosur.cl" https://127.0.0.1/xmlrpc.php | grep -i "HTTP/"

  # 2. Inspeccionar la stick-table en memoria de HAProxy para ver IPs bloqueadas por fuerza bruta:
  echo "show table cluster_wordpress" | sudo socat stdio /run/haproxy/admin.sock 2>/dev/null || \
  curl -u admin:tas13pass -s "http://127.0.0.1:8404/stats;csv" | grep -i "stick"

  # 3. Ver los logs de accesos bloqueados y denegados:
  sudo journalctl -u haproxy -n 50 --no-pager | grep -iE "deny|403|429"
  ```

---

#### Situación 8: Secuencia Ordenada de Apagado y Encendido del Clúster (*Cold Start / Clean Shutdown*)
Para evitar bloqueos de I/O en NFS o transacciones colgadas en base de datos, respetar estrictamente el orden de dependencias:

* **Orden de Apagado (*Clean Shutdown*):**
  1. `10.33.199.109` (Gateway): `sudo systemctl stop haproxy` *(detiene la entrada de tráfico)*.
  2. `10.33.199.106` y `10.33.199.107` (Web 1 y Web 2): `sudo docker stop $(sudo docker ps -q) && sudo umount -l /srv/nfs/wordpress`.
  3. `10.33.199.108` (MariaDB): `sudo docker stop vm258-db-backup`.
  4. `10.33.199.110` (NFS & Storage): `sudo systemctl stop nfs-kernel-server`.
  5. Apagar los sistemas operativos base (`sudo poweroff`).

* **Orden de Encendido (*Cold Start Boot*):**
  1. **Primero:** `10.33.199.110` (Storage NFS) y `10.33.199.108` (MariaDB) $\rightarrow$ para que los datos y persistencia estén listos.
  2. **Segundo:** `10.33.199.106` y `10.33.199.107` (Web 1 y Web 2) $\rightarrow$ montan NFS y se conectan a MariaDB.
  3. **Tercero:** `10.33.199.109` (Gateway) $\rightarrow$ levanta HAProxy y DNS cuando los backends ya responden.

---

### 7.3. Matriz Resumen de Credenciales y URLs de Acceso Rápido

| Recurso / Interfaz | URL / Host de Conexión | Protocolo / Puerto | Credenciales |
| :--- | :--- | :---: | :--- |
| **Sitio Web Principal** | `https://www.nodosur.cl` | HTTPS / 443 (HTTP/2) | Acceso público |
| **Panel HAProxy (HTTPS)** | `https://www.nodosur.cl/stats` | HTTPS / 443 | `admin` / `tas13pass` |
| **Panel HAProxy (HTTP Directo)** | `http://10.33.195.195:8404/stats` | HTTP / 8404 | `admin` / `tas13pass` |
| **SSH Gateway (Bastión)** | `10.33.195.195` | SSH / 22 | `renajara` / `tas13.` |
| **SSH Web 1** | `10.33.199.106` | SSH / 22 | `tas_13` / `usm13` |
| **SSH Web 2** | `10.33.199.107` | SSH / 22 | `benjamin` / `benjamin` |
| **SSH MariaDB** | `10.33.199.108` | SSH / 22 | `gatica` / `admin1234` |
| **SSH Storage & Backups** | `10.33.199.110` | SSH / 22 | `tas13_backup` / `tas13.` |
| **Base de Datos (App)** | `10.33.199.108:3306` (`nodosur_db`) | MySQL TCP / 3306 | `wp_nodosur` / `NodoSurPassword2026!` |
| **Base de Datos (Agente Backup)** | `10.33.199.108:3306` (`nodosur_db`) | MySQL TCP / 3306 | `backup_agent` / `BackupSeguroTAS13!` |
| **Almacenamiento NFS** | `10.33.199.110:/srv/nfs/wordpress` | NFS RPC / 2049 | Montaje restringido a `.106` y `.107` |

---

## 8. Protocolo de Validación y Auditoría HTTPS / TLS por Capas

Siguiendo la metodología estricta del curso **"Observar $\rightarrow$ Probar $\rightarrow$ Corregir $\rightarrow$ Validar $\rightarrow$ Documentar"**, la configuración de seguridad y cifrado HTTPS se evalúa capa por capa de forma ascendente: **Nombre $\rightarrow$ Ruta $\rightarrow$ Puerto $\rightarrow$ TLS $\rightarrow$ HTTP $\rightarrow$ Aplicación**.

```text
┌────────────────────────────────────────────────────────────────────────┐
│  CAPA 6: APLICACIÓN (WordPress, Badge de Nodo y Cabeceras L7)          │
├────────────────────────────────────────────────────────────────────────┤
│  CAPA 5: PROTOCOLO HTTP (Redirección Permanente 301 a HTTPS)           │
├────────────────────────────────────────────────────────────────────────┤
│  CAPA 4: CIFRADO TLS (X.509, OpenSSL s_client, SNI, TLSv1.3 / HTTP/2)  │
├────────────────────────────────────────────────────────────────────────┤
│  CAPA 3: PUERTO (Socket TCP 443 en escucha en HAProxy Gateway)         │
├────────────────────────────────────────────────────────────────────────┤
│  CAPA 2: RUTA Y CONECTIVIDAD (Tráfico WAN USM / VPN hacia 10.33.195.195│
├────────────────────────────────────────────────────────────────────────┤
│  CAPA 1: NOMBRE (Resolución BIND9 y /etc/hosts: nodosur.cl / tas13.tas)│
└────────────────────────────────────────────────────────────────────────┘
```

---

### Capa 1: Validación de Nombre (DNS y Resolución)
* **Objetivo:** Asegurar que los dominios asignados (`www.nodosur.cl`, `tas13.local` y el alias de grupo `nodosur13.tas`) resuelvan a la IP pública del Gateway (`10.33.195.195`).
* **Comando:**
  ```bash
  dig @10.33.195.195 www.nodosur.cl +short
  dig @127.0.0.1 nodosur13.tas +short
  ```
* **Resultado validado:** Devuelve `10.33.195.195`.

---

### Capa 2: Validación de Ruta y Conectividad Perimetral
* **Objetivo:** Comprobar que el cliente remoto (conectado a través de la VPN institucional WatchGuard o red interna USM) alcanza el Gateway.
* **Comando (desde el cliente Windows/Linux con VPN):**
  ```powershell
  Test-NetConnection -ComputerName 10.33.195.195 -Port 443
  # O en Linux:
  nc -zv 10.33.195.195 443
  ```
* **Resultado validado:** `TcpTestSucceeded : True` / `Connection to 10.33.195.195 443 port [tcp/https] succeeded!`.

---

### Capa 3: Validación de Puerto en Escucha Local
* **Objetivo:** Confirmar que el balanceador perimetral HAProxy está escuchando en el puerto seguro `443` en todas las interfaces (`0.0.0.0:443`).
* **Comando (en el Gateway `10.33.195.195`):**
  ```bash
  sudo ss -tlnp | grep :443
  ```
* **Resultado validado:**
  ```text
  LISTEN 0  4096  0.0.0.0:443  0.0.0.0:*  users:(("haproxy",pid=143695,fd=13))
  ```

---

### Capa 4: Validación de Cifrado TLS y Certificados (Diagnóstico OpenSSL s_client)
* **Objetivo:** Validar el *handshake* criptográfico TLS, el protocolo negociado (TLSv1.3), y extraer el Sujeto (*Subject*), Emisor (*Issuer*) y Nombres Alternativos (*Subject Alternative Names - SAN*) sin depender del navegador.
* **Comandos de diagnóstico:**
  ```bash
  # 1. Comprobar Sujeto y Emisor vía SNI para www.nodosur.cl:
  openssl s_client -connect localhost:443 -servername www.nodosur.cl </dev/null 2>/dev/null | grep -e subject= -e issuer=

  # 2. Comprobar Sujeto y Emisor vía SNI para nodosur13.tas:
  openssl s_client -connect localhost:443 -servername nodosur13.tas </dev/null 2>/dev/null | grep -e subject= -e issuer=

  # 3. Inspeccionar el certificado completo y su lista de dominios SAN válidos:
  sudo openssl x509 -in /etc/haproxy/certs/nodosur.pem -noout -subject -issuer -ext subjectAltName
  ```
* **Resultado validado:**
  ```text
  subject=C = CL, ST = Biobio, L = Concepcion, O = UTFSM, OU = TAS-G13, CN = www.nodosur.cl
  issuer=C = CL, ST = Biobio, L = Concepcion, O = UTFSM, OU = TAS-G13, CN = www.nodosur.cl
  X509v3 Subject Alternative Name:
      DNS:www.nodosur.cl, DNS:nodosur.cl, DNS:www.tas13.local, DNS:tas13.local, DNS:nodosur13.tas, DNS:www.nodosur13.tas, DNS:nodosur.tas, DNS:localhost, IP Address:10.33.195.195, IP Address:10.33.199.109, IP Address:127.0.0.1
  ```

---

### Capa 5: Validación de Redirección Forzosa HTTP $\rightarrow$ HTTPS (Código 301)
* **Objetivo:** Confirmar que cualquier cliente que intente entrar por el puerto inseguro `80` es redirigido obligatoriamente mediante una respuesta **`301 Moved Permanently`** hacia la URL segura `https://`.
* **Comando (desde el cliente Windows/Linux):**
  ```bash
  curl -I http://10.33.195.195/ -H "Host: www.nodosur.cl"
  ```
* **Resultado validado:**
  ```http
  HTTP/1.1 301 Moved Permanently
  content-length: 0
  location: https://www.nodosur.cl/
  ```

---

### Capa 6: Validación de la Aplicación Web Segura (HTTP/2 y Balanceo)
* **Objetivo:** Comprobar que bajo HTTPS el servidor entrega el código de estado `HTTP/2 200 OK`, con terminación TLS limpia, cabeceras de seguridad activas y balanceo de carga funcional.
* **Comando (desde el cliente Windows/Linux):**
  ```bash
  curl -I -k https://10.33.195.195/ -H "Host: www.nodosur.cl"
  ```
* **Resultado validado:**
  ```http
  HTTP/2 200 
  date: Thu, 22 Oct 2026 02:23:43 GMT
  content-type: text/html; charset=UTF-8
  x-nodo-backend: vm206-web1
  x-estado-cache: MISS
  cache-control: public, max-age=30, s-maxage=30
  x-frame-options: SAMEORIGIN
  x-content-type-options: nosniff
  referrer-policy: strict-origin-when-cross-origin
  ```
  *(Al repetir la solicitud, conmuta hacia `x-nodo-backend: vm248-web2` o sirve desde caché RAM `x-estado-cache: HIT`).*




