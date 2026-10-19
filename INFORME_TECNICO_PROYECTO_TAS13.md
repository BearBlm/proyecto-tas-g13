# INFORME TÉCNICO DE PROYECTO
## Infraestructura Web de Alta Disponibilidad, Balanceo de Carga y DNS
**Proyecto:** Plataforma Web NodoSur (`www.nodosur.cl` / `tas13.local`)  
**Asignatura:** Taller de Administración de Sistemas (TAS) — Grupo 13  
**Sistema Operativo Base:** Ubuntu Server 24.04 LTS (Contenerizado vía Docker Compose)  
**Fecha:** Octubre 2026  

---

## 1. Resumen Ejecutivo

El presente proyecto implementa una infraestructura de servicios web de alta disponibilidad, balanceada y tolerante a fallos, diseñada para sostener tráfico masivo y garantizar continuidad operacional bajo pruebas de estrés severas.

La solución emula y orquesta un entorno de **cuatro Máquinas Virtuales (VMs)** interconectadas en una red privada aislada (`10.33.199.104/29`), integrando:
1. **Pasarela de Entrada y Balanceo L7:** HAProxy 2.8 con terminación SSL/TLS segura y micro-caché en memoria RAM.
2. **Servidor DNS Autoritativo:** BIND9 resolviendo los dominios oficiales `nodosur.cl` y `tas13.local`.
3. **Clúster Web Redundante:** Dos nodos independientes Apache 2.4 con PHP 8.3 (OPcache activado) y WordPress en español.
4. **Almacenamiento Compartido:** Volumen común tipo NFS para sincronizar medios y código PHP entre los nodos web.
5. **Capa de Persistencia y Contingencia:** Servidor MariaDB 10.11 dedicado con sistema de copias de seguridad automatizadas y verificación criptográfica SHA-256.

En las pruebas de estrés ejecutadas con **ApacheBench (`ab`)** a máxima concurrencia (100 conexiones simultáneas y 5.000 peticiones HTTPS continuas), la infraestructura demostró un **0% de tasa de fallo**, un rendimiento sostenido superior a **162 peticiones por segundo** y un reparto de carga equilibrado al **50.0% / 50.0%** entre ambos servidores web.

---

## 2. Arquitectura de Red y Topología de Servidores

La infraestructura opera sobre una red bridge dedicada con direccionamiento IP estático clase CIDR `/29`:

* **Segmento de Red:** `10.33.199.104/29`
* **Puerta de Enlace (Gateway Docker):** `10.33.199.105`
* **Máscara de Subred:** `255.255.255.248`

```
                                  [ CLIENTES EXTERNOS / NAVEGADORES ]
                                                  │
                                                  ▼ (Puertos 80, 443, 8404, 53 UDP/TCP)
                     ┌─────────────────────────────────────────────────────────────┐
                     │          VM 250: Gateway HAProxy + DNS BIND9               │
                     │          10.33.199.109 / Host VPN: 10.30.248.9              │
                     │  - DNS BIND9 (nodosur.cl / tas13.local en puerto 53)        │
                     │  - HAProxy (Terminación SSL, Micro-Caché, leastconn)       │
                     └───────────────┬─────────────────────────────┬───────────────┘
                                     │                             │
             Balanceo HTTP Port 80   │                             │  Balanceo HTTP Port 80
             (leastconn + cookie)    │                             │  (leastconn + cookie)
                                     ▼                             ▼
                    ┌──────────────────────────────┐     ┌──────────────────────────────┐
                    │      VM 206: Nodo Web 1      │     │      VM 248: Nodo Web 2      │
                    │        10.33.199.106         │     │        10.33.199.107         │
                    │ Apache 2.4 + PHP 8.3 OPcache │     │ Apache 2.4 + PHP 8.3 OPcache │
                    └──────────────┬───────────────┘     └──────────────┬───────────────┘
                                   │                                    │
                                   └─────────────────┬──────────────────┘
                                                     │
                             Lectura/Escritura PHP   ▼   Montaje Compartido
                                     ┌─────────────────────────────────┐
                                     │   Volumen Compartido Tipo NFS   │
                                     │      (tas13_nfs_shared_wp)      │
                                     │      Código y Medios de WP      │
                                     └────────────────┬────────────────┘
                                                      │
                                                      │ Conexión MySQL TCP 3306
                                                      ▼
                                     ┌─────────────────────────────────┐
                                     │   VM 258: MariaDB + Respaldos   │
                                     │          10.33.199.108          │
                                     │  - Base de Datos nodosur_db     │
                                     │  - Script Automático backup.sh  │
                                     │  - Recuperación con restore.sh  │
                                     └─────────────────────────────────┘
```

### Detalle de las 4 Máquinas Virtuales del Informe

| Identificador VM | Nombre de Contenedor | Hostname FQDN | Dirección IP | Servicios y Roles Principales |
| :--- | :--- | :--- | :--- | :--- |
| **VM 250** | `vm250-gw-dns` | `gw.tas13.local` | `10.33.199.109`<br>*(Expuesto: `10.30.248.9`)* | Gateway Reverso HAProxy, Terminación SSL/TLS, DNS BIND9 autoritativo publicado en puerto 53 estándar. |
| **VM 206** | `vm206-web1` | `web1.tas13.local` | `10.33.199.106` | Servidor Web 1 (Apache 2.4, PHP 8.3, OPcache, cliente NFS). |
| **VM 248** | `vm248-web2` | `web2.tas13.local` | `10.33.199.107` | Servidor Web 2 (Apache 2.4, PHP 8.3, OPcache, cliente NFS). |
| **VM 258** | `vm258-db-backup` | `db.tas13.local` | `10.33.199.108` | Servidor de Base de Datos MariaDB 10.11, Lector NFS de Respaldo y Scripts. |

---

## 3. Implementación y Configuración de Componentes

### 3.1. Servidor DNS Autoritativo (BIND 9)
Configurado en la VM 250 para resolver consultas locales del clúster y clientes externos en la red universitaria (Wi-Fi institucional o VPN WatchGuard USM).

* **Publicación en Puerto Estándar:** El servicio DNS publica los puertos `53:53/udp` y `53:53/tcp` hacia la máquina anfitriona, permitiendo que cualquier estación de trabajo configure la IP del servidor como DNS preferido sin necesidad de especificar puertos alternativos.
* **Archivo de Configuración:** `named.conf`
  * Recursión habilitada con reenviadores seguros (`forwarders { 8.8.8.8; 1.1.1.1; };`), asegurando que los clientes que configuren este DNS no pierdan navegación general a Internet.
  * Validación DNSSEC desactivada para entornos de laboratorio locales.
  * Zonas declaradas: `nodosur.cl` y `tas13.local`.

* **Zona Autoritativa `nodosur.cl` (`db.nodosur.cl`):**
  * **SOA / NS:** `ns1.nodosur.cl.` apuntando a `10.30.248.9`.
  * **Registros Tipo A:**
    * `@` (raíz `nodosur.cl`) $\rightarrow$ `10.30.248.9` (Gateway en red institucional/VPN)
    * `ns1` $\rightarrow$ `10.30.248.9`
    * `gw` $\rightarrow$ `10.30.248.9`
    * `www` $\rightarrow$ `10.30.248.9`
    * `*` (Wildcard) $\rightarrow$ `10.30.248.9`
    * `web1` $\rightarrow$ `10.33.199.106` (IP interna del clúster)
    * `web2` $\rightarrow$ `10.33.199.107` (IP interna del clúster)
    * `db` $\rightarrow$ `10.33.199.108` (IP interna del clúster)

* **Zona Autoritativa `tas13.local` (`db.tas13.local`):**
  * Registros `ns1` y `gw` resolviendo en `10.30.248.9`, con alias CNAME `www` y `nodosur` vinculados a `gw.tas13.local.`.

### 3.2. Pasarela de Balanceo L7 y Aceleración (HAProxy)
Opera como punto único de entrada seguro (puertos 80 y 443).

* **Terminación y Redirección HTTPS:**
  * Toda petición en puerto 80 es redirigida mediante `HTTP 302 Found` a `https://www.nodosur.cl/`.
  * Cabecera `Strict-Transport-Security: max-age=31536000; includeSubDomains` (HSTS).
  * Cabeceras de seguridad: `X-Frame-Options: SAMEORIGIN` y `X-Content-Type-Options: nosniff`.
* **Certificado Digital SSL/TLS X.509 v3 con SAN (Subject Alternative Names):**
  * Emisor y Sujeto: `CN = www.nodosur.cl`, `O = UTFSM`, `OU = TAS-G13`.
  * Extensiones SAN: `www.nodosur.cl`, `nodosur.cl`, `www.tas13.local`, `tas13.local`, `localhost`, `10.33.199.109`, `127.0.0.1`.
* **Estrategia de Balanceo y Salud:**
  * Algoritmo: `leastconn` (asigna la conexión al servidor con menos peticiones activas).
  * Health Check activo L7: `http-check send meth HEAD uri / ver HTTP/1.1 hdr Host localhost` comprobando códigos `2xx` y `3xx` cada 3 segundos.
  * Persistencia de sesión por cookies: `cookie SRVID insert indirect nocache` (asigna `web1` o `web2`).
* **Micro-Caché en Memoria RAM:**
  * Caché de 20 MB en RAM (`cache_nodosur`) con expiración de 15 segundos para responder contenido estático y páginas de inicio sin golpear el backend PHP.
* **Panel de Métricas en Vivo:**
  * Disponible en `http://localhost:8404/stats` con autenticación HTTP Basic (`admin:tas13pass`).

### 3.3. Clúster de Nodos Web (Apache 2.4 + PHP 8.3)
Ambos nodos (`vm206-web1` y `vm248-web2`) ejecutan la misma pila optimizada:

* **Acelerador OPcache:**
  * Configurado en `/etc/php/8.3/apache2/conf.d/99-opcache-tas.ini` con 128 MB de memoria compartida y 10.000 scripts precompilados en RAM.
* **Volumen Compartido (NFS Simulado):**
  * Ambos contenedores montan el volumen Docker `tas13_nfs_shared_wp` en `/var/www/html`.
  * Si un usuario sube una imagen o instala un plugin en el Nodo 1, está inmediatamente disponible en el Nodo 2.
* **Integración Reversa WordPress:**
  * `wp-config.php` detecta la cabecera `HTTP_X_FORWARDED_PROTO: https` inyectada por HAProxy, forzando `$_SERVER['HTTPS'] = 'on'` para evitar bucles infinitos de redirección.
  * **Detección Dinámica de Host:** `WP_HOME` y `WP_SITEURL` se resuelven dinámicamente mediante `$_SERVER['HTTP_HOST']`. Esto permite que la plataforma sirva recursos CSS/JS e hipervínculos de forma consistente tanto si el cliente ingresa por el dominio FQDN (`https://www.nodosur.cl`) como si lo hace directamente por IP institucional o `localhost`.

### 3.4. Base de Datos y Respaldo / Recuperación (MariaDB 10.11)
Alojada en la VM 258 (`10.33.199.108`):

* **Aislamiento y Seguridad:**
  * Usuario: `wp_nodosur`, base de datos: `nodosur_db`.
  * Concesión de privilegios restringida a la subred de los nodos web (`'wp_nodosur'@'10.33.199.%'`).
* **Automatización de Respaldos (`backup.sh`):**
  1. Exporta la base de datos completa con `mariadb-dump`.
  2. Empaqueta el árbol completo de archivos web (`/mnt/nfs_wp_html`) en un archivo comprimido `.tar.gz`.
  3. Genera una firma criptográfica `SHA256` del dump SQL para validar integridad.
* **Restauración ante Desastres (`restore.sh`):**
  1. Comprueba la integridad del archivo mediante `sha256sum -c`.
  2. Recrea la base de datos y restaura el dump en caso de corrupción o pérdida de datos.

---

## 4. Resultados de las Pruebas de Estrés y Rendimiento

Se realizaron tres rondas de pruebas de carga mediante **ApacheBench (`ab`)** ejecutadas desde un nodo cliente dentro de la red privada, evaluando el comportamiento bajo protocolos seguros HTTPS/TLSv1.3:

### Tabla Comparativa de Resultados

| Métrica de Rendimiento | Ronda 1: Carga Media | Ronda 2: Carga Alta | Ronda 3: Estrés Extremo |
| :--- | :---: | :---: | :---: |
| **Total de Peticiones** | 500 req | 2.000 req | **5.000 req** |
| **Nivel de Concurrencia** | 25 clientes | 50 clientes | **100 clientes** |
| **Peticiones Fallidas** | **0 (0.0%)** | **0 (0.0%)** | **0 (0.0%)** |
| **Tiempo de Ejecución** | 3.29 segundos | 13.02 segundos | 30.83 segundos |
| **Tasa de Despacho (Throughput)** | **151.91 req/s** | **153.51 req/s** | **162.14 req/s** |
| **Velocidad de Transferencia** | 10.35 MB/s | 10.45 MB/s | **11.05 MB/s** |
| **Volumen Total Transferido** | 34.88 MB | 139.52 MB | **348.80 MB** |
| **Tiempo Medio por Petición** | 6.58 ms | 6.51 ms | **6.16 ms** |
| **Latencia Máxima (Peor Caso)** | 304 ms | 848 ms | 1.681 ms |

### Distribución de Carga en HAProxy tras 7.550 Peticiones

```
Total Peticiones Atendidas: 7.551
├── vm206-web1 (Nodo 1): 3.777 peticiones (50.03%) ── Estado: UP
└── vm248-web2 (Nodo 2): 3.772 peticiones (49.97%) ── Estado: UP
```

* **Simetría:** La desviación entre servidores fue de tan solo 5 peticiones (menos del 0.06%).
* **Disponibilidad:** Ningún servidor presentó fallos de conexión (`Connection resets: 0`, `Downtime: 0s`).

---

## 5. Guía de Operación y Comandos Útiles

### Iniciar y Detener la Infraestructura
```powershell
# Levantar todos los servicios en segundo plano
docker compose up -d

# Detener todos los servicios preservando volúmenes
docker compose down

# Ver estado de los 4 contenedores
docker compose ps
```

### Ejecutar Respaldo Manual
```powershell
docker exec vm258-db-backup /backups/backup.sh
```

### Restaurar Respaldo
```powershell
docker exec vm258-db-backup /backups/restore.sh
```

### Verificar Resolución DNS (Local y Recursiva)
```powershell
# Comprobar resolución autoritativa del dominio del proyecto:
nslookup www.nodosur.cl 127.0.0.1

# Comprobar resolución recursiva hacia Internet (reenviadores seguros):
nslookup google.com 127.0.0.1
```

### Configuración de Firewall en Servidor Anfitrión (Windows Defender)
Para permitir que equipos externos en la red universitaria o VPN accedan a los servicios:
```powershell
# En PowerShell como Administrador:
New-NetFirewallRule -DisplayName "TAS13 DNS UDP" -Direction Inbound -LocalPort 53 -Protocol UDP -Action Allow
New-NetFirewallRule -DisplayName "TAS13 DNS TCP" -Direction Inbound -LocalPort 53 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "TAS13 Web Ports" -Direction Inbound -LocalPort 80,443,8404 -Protocol TCP -Action Allow
```

### Conexión de Clientes en la Red Universitaria (Wi-Fi USM o VPN WatchGuard USM)

#### Método 1: Resolución Nativa con BIND9 (Recomendado - Sin modificar archivos hosts)
Cualquier estación cliente conectada a la VPN WatchGuard o a la Wi-Fi de la USM puede utilizar el servidor BIND9 del clúster como su DNS preferido:
* **En Windows (PowerShell como Administrador):**
  ```powershell
  Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses ("10.30.248.9", "1.1.1.1")
  ```
* **En la interfaz gráfica de Windows:**
  1. Ir a *Configuración > Red e Internet > Wi-Fi / Ethernet*.
  2. Editar *Asignación de servidor DNS* en modo *Manual* (IPv4).
  3. Establecer **DNS preferido:** `10.30.248.9` y **DNS alternativo:** `1.1.1.1`.
* *Para restaurar el DNS automático:* `Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses`.

#### Método 2: Resolución Local mediante archivo `hosts` (Alternativa)
Si no se desea alterar la configuración de adaptadores de red:
* **En Windows (PowerShell como Administrador):**
  ```powershell
  Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "`n10.30.248.9    www.nodosur.cl    tas13.local" -Encoding ascii
  ```
* **En Linux / macOS:**
  ```bash
  echo "10.30.248.9    www.nodosur.cl    tas13.local" | sudo tee -a /etc/hosts
  ```

### Acceso a Paneles y Sitios
* **Sitio Web WordPress:** [https://www.nodosur.cl](https://www.nodosur.cl) *(o `https://10.30.248.9` vía HTTPS)*.  
  > *Nota de Laboratorio:* Al emplear un certificado SSL autofirmado X.509 generado para la entrega, el navegador solicitará aceptar la advertencia de seguridad inicial (*Avanzado > Continuar a www.nodosur.cl*).
* **Panel de Métricas HAProxy en Vivo:** [http://www.nodosur.cl:8404/stats](http://www.nodosur.cl:8404/stats) o [http://localhost:8404/stats](http://localhost:8404/stats).  
  * **Usuario:** `admin`  
  * **Contraseña:** `tas13pass`

---

## 6. Conclusiones Técnicas

1. **Alta Eficiencia en Recursos:** El desacoplamiento entre el balanceador HAProxy y los nodos Apache permitió absorber picos de tráfico de 100 clientes concurrentes manteniendo tiempos de respuesta promedio en torno a los 6 milisegundos.
2. **Resiliencia de Datos:** El uso de almacenamiento desacoplado tipo NFS junto a una política de respaldos con firma SHA-256 garantiza que ante la eventual caída o recreación de cualquier nodo web, el contenido dinámico y multimedia permanezca íntegro.
3. **Seguridad End-to-End:** La redirección forzada a HTTPS, la cabecera HSTS y los certificados SAN protegen las comunicaciones y previenen ataques de intermediarios (MitM).
4. **Cumplimiento de Especificaciones:** La infraestructura responde de forma exacta a los requerimientos de segmentación IP del informe (VMs 250, 206, 248 y 258), configurando un entorno idéntico a una implementación en servidores físicos o hipervisores empresariales.
