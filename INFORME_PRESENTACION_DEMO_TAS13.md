# Informe Técnico y Guion de Presentación en Vivo — Proyecto TAS (Grupo 13)

**Plataforma:** NodoSur (`https://www.nodosur.cl` / `tas13.local`)  
**Fecha de auditoría y actualización en vivo:** Viernes 27 de noviembre de 2026  
**Estado actual:** ✅ Infraestructura sondeada, incidencias de CMS/tienda corregidas y verificadas en vivo sobre las 5 Máquinas Virtuales vía Gateway (`10.33.195.195`).

---

## 1. Resumen Ejecutivo del Sondeo y Correcciones Aplicadas

**Veredicto general:** ✅ **TODOS los servicios principales están levantados, operativos y verificados end-to-end (0 servicios caídos).**  
El CMS WordPress + WooCommerce (`https://www.nodosur.cl`), el balanceador HAProxy (`/stats`), el DNS BIND9, ambos nodos Web Docker, MariaDB, NFS, Zabbix 7.0 LTS y Grafana OSS responden correctamente.

### Correcciones e implementaciones aplicadas hoy previo a la demo:
1. **✅ Resolución de errores `404 Not Found` en prendas y páginas internas:** Se habilitó `AllowOverride All` para `/var/www/html` en Apache (`/etc/apache2/conf-available/wordpress-override.conf`) en ambos contenedores (`vm206-web1` y `vm248-web2`), haciendo efectivas las reglas de reescritura `.htaccess` (`/%postname%/`).
2. **✅ Desactivación del modo "Próximamente" de WooCommerce (`woocommerce_coming_soon`):** Se detectó que `woocommerce_coming_soon=yes` y `woocommerce_store_pages_only=yes` interceptaban los clics en fichas de productos mostrando *"Tenemos grandes proyectos por anunciar"*. Al desactivarlo, todas las prendas y `/shop/` renderizan su ficha completa.
3. **✅ Carrito funcional, Checkout y Blindaje de Caché en HAProxy (`/etc/haproxy/haproxy.cfg`):**
   * Se excluyeron de la micro-caché RAM de HAProxy las rutas dinámicas (`/cart`, `/carrito`, `/checkout`, `/finalizar-compra`, `/my-account`, `/mi-cuenta`, `/wp-json`), las acciones (`add-to-cart`, `remove_item`, `wc-ajax`, `undo_item`) y las cookies de WooCommerce (`woocommerce_items_in_cart`, `woocommerce_cart_hash`, `wp_woocommerce_session_`).
   * Se activaron **Sticky Sessions** (`cookie SRVID insert indirect nocache`) y se aumentó `timeout client/server` a `120s`, mitigando además los conflictos NFS (`Stale file handle`) al operar en `/wp-admin`.
   * Se habilitaron los métodos de pago **Pago contra entrega / Retiro en tienda (`cod`)** y **Transferencia Bancaria Directa (`bacs`)**, checkout para invitados y zona de envío **Chile** (*Envío Estándar `$3.990`* + *Envío Gratis sobre `$45.000`*).
4. **✅ Rediseño Celeste Minimalista y Funcionalidades de Tienda de Ropa (`/srv/nfs/wordpress/wp-content/mu-plugins/nodosur-celeste-minimal.php`):**
   * Paleta celeste minimalista (`#F0F9FF` – `#0284C7`), tipografía editorial (`Cormorant Garamond` + `Plus Jakarta Sans`), **botón flotante "Mi Bolsa" + Mini-Carrito deslizable AJAX**, barra de progreso de envío gratis, **selector de tallas (`XS`–`XL`) + Modal Guía de Tallas**, buscador/filtros rápidos en `/shop/` y sellos de confianza.
   * Se convirtieron los 4 atuendos `variable` a `simple` (agregado directo al carrito por AJAX) con precios normalizados en CLP y se añadieron **6 prendas nuevas** de la colección celeste minimalista (`#1128` a `#1133`).

### Avisos operativos vigentes para tener presentes en la demo:
1. **⚠️ Alerta activa en Zabbix de memoria RAM en nodos web (`>90%`):** `web1` (`244 MiB` disp.) y `web2` (`343 MiB` disp.) operan con memoria ajustada por la carga de Elementor + WooCommerce + plugins.
2. **⚠️ Respaldo automático de las 02:00 UTC (27 Nov):** Abortó en `tar` (`file changed as we read it`) durante ediciones nocturnas; `ultimo_respaldo.sql.gz` aún corresponde al **26 de noviembre**. **Acción recomendada antes de presentar:** ejecutar `sudo /usr/local/bin/backup_seguro.sh` en VM5 para dejar el respaldo actualizado a hoy con las prendas y cambios actuales.

---

## 2. Estado Verificado de las 5 Máquinas Virtuales y Servicios

| VM / Rol | Hostname | IP LAN (`/29`) | IP WAN | Servicios / Contenedores | Estado | Recursos (RAM / Disco) |
| :--- | :--- | :---: | :---: | :--- | :---: | :--- |
| **VM 1 — Gateway, DNS & HAProxy** | `tas13jara.cs.ilab.usm.cl` | `10.33.199.109` | `10.33.195.195` | `haproxy`, `named` (BIND9), `zabbix-agent2`, `netfilter-persistent` | ✅ **Todos `active`** | RAM: `515M / 1.9G` (1.4G disp.)<br>Disco: `7%` (86G libres) |
| **VM 2 — Nodo Web 1** | `web1.tas13.local` | `10.33.199.106` | *(NAT)* | Docker `vm206-web1` (`Up 3 weeks`), NFSv4.2 montado, `zabbix-agent2` | ✅ **Operativo**<br>⚠️ RAM alta | RAM: `1.7G / 1.9G` (244M disp.)<br>Swap: `290M / 4G` |
| **VM 3 — Nodo Web 2** | `web2.tas13.local` | `10.33.199.107` | `10.33.195.235` *(filtrada)* | Docker `vm248-web2` (`Up 3 weeks`), NFSv4.2 montado, `zabbix-agent2` | ✅ **Operativo**<br>⚠️ RAM alta | RAM: `1.6G / 1.9G` (343M disp.)<br>Swap: `204M / 2G` |
| **VM 4 — Base de Datos** | `db.tas13.local` | `10.33.199.108` | `10.33.195.174` *(filtrada)* | Docker `vm258-db-backup` MariaDB 10.11 (`Up 3 days`), `zabbix-agent2` | ✅ **Operativo** | RAM: `742M / 1.9G` (1.2G disp.)<br>Disco: `9%` (85G libres) |
| **VM 5 — Storage NFS, Backup & Observabilidad** | `backup.tas13.local` | `10.33.199.110` | *(Aislada)* | `nfs-kernel-server`, `zabbix-server`, `zabbix-agent2`, `grafana-server`, `apache2`, `mariadb` | ✅ **Todos `active`** | RAM: `1.0G / 1.9G` (894M disp.)<br>Disco: `12%` (82G libres) |

### Verificación de Backends HAProxy y Endpoints HTTP/HTTPS

| Servicio / Backend | Endpoint / Verificación | Estado en Vivo | Detalle Técnico |
| :--- | :--- | :---: | :--- |
| **HTTP → HTTPS** | `http://www.nodosur.cl/` | ✅ `301` | Redirección forzada a `https://www.nodosur.cl/` |
| **WordPress (CMS)** | `https://www.nodosur.cl/` | ✅ `HTTP/2 200` | `cluster_wordpress`: `vm206-web1` **UP**, `vm248-web2` **UP**, Micro-caché RAM activa (`HIT`) |
| **HAProxy Stats** | `https://www.nodosur.cl/stats` / `:8404/stats` | ✅ `OPEN` | Panel interactivo habilitado (`admin` / `tas13pass`) |
| **Zabbix 7.0 Web UI** | `https://zabbix.nodosur.cl/zabbix/` | ✅ `HTTP/2 200` | `backend_zabbix/vm-zabbix` **UP** — 5 hosts monitoreados (`status=0`) |
| **Grafana OSS** | `https://grafana.nodosur.cl/api/health` | ✅ `HTTP/2 200` | `backend_grafana/vm-grafana` **UP** — Plugin Zabbix activo |
| **MariaDB (`nodosur_db`)** | `10.33.199.108:3306` | ✅ **Activa** | `Uptime: 310591s`, `Questions: 15.8M`, bases `nodosur_db` y `nodosur_db_eval` presentes |

---

## 3. Diagnóstico Técnico: ¿Por qué falla el cambio/instalación de temas en WordPress?

El análisis de los logs reales de Apache en `vm206-web1` y `vm248-web2`, la configuración activa de HAProxy (`/etc/haproxy/haproxy.cfg`), PHP (`php.ini`) y los parámetros del montaje NFS reveló **5 causas combinadas** (todas verificadas con evidencia real):

### Causa 1 (Principal): Falta de Sticky Sessions en HAProxy + Caché NFS de 60 segundos (`Stale file handle`)
* **Evidencia en `/etc/haproxy/haproxy.cfg`:** El backend `cluster_wordpress` usa `balance leastconn` **sin persistencia de sesión** (falta `cookie SRVID insert indirect nocache`).
* **Evidencia en el montaje NFS (`web1` y `web2`):** Montado con `acregmin=60,acdirmin=60` (caché de atributos y directorios de 60 segundos).
* **Evidencia en `/var/log/apache2/error.log` (ambos nodos, 27 Nov 00:39 y 01:54–01:56 UTC):**
  ```text
  PHP Warning: dir(/var/www/html/wp-content/upgrade/cartflows.3.3.4-...): Failed to open directory: Stale file handle
  PHP Warning: unlink(/var/www/html/wp-content/uploads/elementor/design-system-sync/design-system-sync.css): No such file or directory
  PHP Fatal error: Uncaught Error: Class "SRFM\Admin\Analytics" not found in /var/www/html/wp-content/plugins/sureforms/plugin-loader.php:102
  PHP Fatal error: Uncaught Error: Class "SureRank\Inc\Frontend\Image" not found in /var/www/html/wp-content/plugins/surerank/inc/frontend/facebook.php:358
  ```
* **Qué ocurre exactamente:** Al cambiar de tema o importar una plantilla (*Astra Starter Templates*), la petición 1 cae en `web1` (escribe/descomprime archivos en NFS), y la petición AJAX siguiente cae en `web2`, cuyo cliente NFS todavía mantiene cacheados los inodos antiguos por 60 segundos → `Stale file handle` / archivos no encontrados / clases PHP inexistentes.

### Causa 2: Límite de subida de archivos PHP en `2M` (`upload_max_filesize`)
* **Evidencia en `web1` y `web2`:**
  * `/etc/php/8.3/apache2/php.ini`: `upload_max_filesize = 2M`, `post_max_size = 8M`.
  * `/etc/php/8.3/apache2/conf.d/99-nodosur-limits.ini`: solo subió `memory_limit = 300M` y `max_execution_time = 300`, pero **omitió `upload_max_filesize` y `post_max_size`**.
* **Efecto:** Cualquier tema `.zip` mayor a 2 MB falla al subirse desde *Apariencia → Temas → Subir tema*.

### Causa 3: `timeout server 30s` en HAProxy
* **Evidencia:** PHP permite ejecutar scripts por `300s`, pero HAProxy corta la conexión al backend a los **30 segundos** (`timeout server 30s`), provocando cortes (`504 Gateway Timeout`) durante la instalación de temas pesados o importación de demos.

### Causa 4: Micro-Caché RAM de HAProxy (`max-age 30`)
* **Efecto:** Tras activar un nuevo tema en `/wp-admin`, si se visualiza el sitio sin sesión de WordPress (o en modo incógnito), HAProxy sirve el HTML del tema antiguo desde RAM (`X-Estado-Cache: HIT`) durante 30 segundos hasta que expira o se ejecuta `sudo systemctl reload haproxy`.

### Causa 5: Presión de Memoria RAM en `web1` y `web2` (>85–90%)
* **Evidencia:** Zabbix registra actualmente 2 alertas `High memory utilization (>90% for 5m)`. Los plugins pesados instalados hoy (`elementor`, `woocommerce`, `cartflows`, `astra-sites`, `sureforms`, `surerank`) dejan poca RAM libre en máquinas de 1.9 GiB al procesar cambios de tema.

### Estado de las Correcciones Aplicadas sobre estas Causas
1. **✅ APLICADO en VM1 (`/etc/haproxy/haproxy.cfg`):**
   * Se subió `timeout client 120s` y `timeout server 120s` (soluciona Causa 3).
   * Se activaron **Sticky Sessions** (`cookie SRVID insert indirect nocache` con `cookie web1` / `cookie web2`) en `backend cluster_wordpress` (mitiga Causa 1).
   * Se excluyeron de la micro-caché RAM todas las rutas y cookies de WooCommerce (`/cart`, `/carrito`, `/checkout`, `/finalizar-compra`, `/my-account`, `/mi-cuenta`, `/wp-json`, `add-to-cart`, `wc-ajax`, `woocommerce_items_in_cart`, `wp_woocommerce_session_`).
2. **✅ APLICADO en VM2 (`vm206-web1`) y VM3 (`vm248-web2`):**
   * Se habilitó `AllowOverride All` para `/var/www/html` (`/etc/apache2/conf-available/wordpress-override.conf`), resolviendo los `404 Not Found` en productos y páginas internas.
3. **✅ APLICADO en WordPress / WooCommerce (`nodosur_db` y NFS):**
   * Se desactivó `woocommerce_coming_soon` (`no`) y `woocommerce_store_pages_only` (`no`), eliminando el desvío a *"Tenemos grandes proyectos por anunciar"* al hacer clic en cualquier prenda.
   * Se habilitaron **Pago contra entrega (`cod`)**, **Transferencia Bancaria Directa (`bacs`)** y zona de envío **Chile** (*Envío Estándar `$3.990`* / *Envío Gratis sobre `$45.000`*).
   * Se desplegó el Must-Use Plugin `/srv/nfs/wordpress/wp-content/mu-plugins/nodosur-celeste-minimal.php` (v2.0.0) con:
     * Temática **tienda de ropa celeste minimalista** (`#F0F9FF` – `#0284C7`, `Cormorant Garamond` + `Plus Jakarta Sans`).
     * **Botón flotante "Mi Bolsa" + Mini-Carrito deslizable AJAX** y barra de progreso de envío gratis.
     * **Selector de tallas (`XS`–`XL`) + Modal Guía de Tallas**, buscador/filtros rápidos en `/shop/` y sellos de confianza.
     * Conversión de los 4 atuendos `variable` a `simple` (agregado directo por AJAX) y **6 prendas nuevas** añadidas (`Polera Minimalista Celeste Hielo`, `Camisa Lino Brisa Celeste`, `Chaqueta Oversize Nube`, `Pantalón Sastrero Minimalista`, `Sweater Tejido Cielo Suave` y `Vestido Midi Atelier Celeste`).
4. **Pendiente opcional (solo si se suben temas `.zip` > 2 MB):** Agregar `upload_max_filesize = 64M` y `post_max_size = 64M` en `/etc/php/8.3/apache2/conf.d/99-nodosur-limits.ini` en ambos nodos web, y reducir `actimeo=60` a `actimeo=3` en `/etc/fstab`.

---

## 4. Guion de Defensa en Vivo — Alineado 100% a la Rúbrica

> **Objetivo de la defensa:** Demostrar en vivo cómo opera el CMS en condiciones normales, qué evidencia deja una falla controlada de la base de datos y cómo se verifica que tanto el servicio como sus datos se recuperaron.

---

### Etapa 1: Servicios Operativos
* **Qué debe mostrar el equipo:** Ubicar cada componente en la topología (`10.33.199.104/29` + WAN `10.33.195.195`), demostrar que todos los servicios están arriba y ejecutar una operación real del CMS desde el cliente que dependa de MariaDB.
* **Evidencia mínima exigida:** Estado de servicios + operación funcional contra la BD (ej. consultar un producto en la tienda WooCommerce o crear un producto/entrada de prueba).

#### Topología a explicar en 30 segundos:
```text
Cliente (Navegador) ──► VM1 Gateway/DNS/HAProxy (WAN 10.33.195.195 | LAN .109)
                                ├──► VM2 Web1 Docker vm206-web1 (.106:80) ──┐
                                ├──► VM3 Web2 Docker vm248-web2 (.107:80) ──┼──► VM4 MariaDB (.108:3306)
                                └──► VM5 Storage NFS + Backups + Zabbix/Grafana (.110)
```

#### Comandos y demostración en vivo:
1. **Mostrar estado en Gateway (VM1):**
   ```bash
   sudo systemctl status haproxy named zabbix-agent2 --no-pager | grep -E "●|Active:"
   ```
2. **Mostrar HAProxy Stats en navegador:** Abrir `https://www.nodosur.cl/stats` (`admin` / `tas13pass`) → mostrar `vm206-web1`, `vm248-web2`, `vm-zabbix` y `vm-grafana` en verde (**UP**).
3. **Mostrar contenedores en Web1, Web2 y DB + servicios en VM5:**
   * En VM2/VM3: `sudo docker ps` y `df -h /srv/nfs/wordpress`
   * En VM4: `sudo docker ps` (muestra `vm258-db-backup` Up)
   * En VM5: `systemctl is-active nfs-kernel-server zabbix-server grafana-server mariadb apache2`
4. **Operación funcional del CMS desde el cliente:**
   * Abrir `https://www.nodosur.cl/`, consultar una prenda real (ej. *Polera Minimalista Celeste Hielo* o *Power Suit Ensemble*), elegir talla (`M`), añadirla al carrito (verificando el Mini-Carrito deslizable y `/cart/`), o crear un producto de prueba en `/wp-admin` y verificarlo en `nodosur_db`.

---

### Etapa 2: Registro A del DNS
* **Qué debe mostrar el equipo:** Mostrar el registro `A` en BIND9, consultarlo desde un cliente apuntando al DNS del proyecto (`10.33.195.195`), explicar a qué componente pertenece la IP devuelta y abrir el CMS usando el nombre de dominio.
* **Evidencia mínima exigida:** Archivo de zona con el registro `A`, salida de `dig`/`nslookup` y acceso por nombre identificando a HAProxy como punto de entrada.

#### Comandos y demostración en vivo:
1. **Mostrar archivo de zona en VM1 (`/etc/bind/zones/db.nodosur.cl`):**
   ```bash
   cat /etc/bind/zones/db.nodosur.cl
   ```
   *(Mostrar los registros: `@`, `www`, `ns1`, `gw`, `*` → `IN A 10.33.195.195`).*
2. **Consultar desde el cliente Windows (PowerShell) o Linux apuntando al DNS del proyecto:**
   ```powershell
   nslookup www.nodosur.cl 10.33.195.195
   ```
   *(O en Linux: `dig @10.33.195.195 www.nodosur.cl A` → devuelve **`10.33.195.195`**).*
3. **Explicación obligatoria:** *"La IP devuelta `10.33.195.195` corresponde a la interfaz WAN de nuestra **VM1 Gateway (HAProxy)**, que actúa como punto único de entrada, termina TLS/HTTPS en el puerto 443 y balancea la carga hacia los nodos internos `10.33.199.106` y `10.33.199.107` en la subred aislada `/29`."*
4. **Abrir el CMS por nombre:** Ingresar a `https://www.nodosur.cl` en el navegador y mostrar el sitio cargando normalmente.

---

### Etapa 3: Observabilidad e Incidente
* **Qué debe mostrar el equipo:** Primero mostrar Zabbix y Grafana en estado normal; luego ejecutar una falla controlada de MariaDB; repetir la operación en el CMS para evidenciar el fallo; y ubicar en métricas, logs y alertas **qué cambió y cuándo (marcas de tiempo)**.
* **Evidencia mínima exigida:** Prueba fallida desde el cliente + señales con timestamps (Zabbix, Grafana y logs).

#### Secuencia paso a paso:
1. **Estado normal (antes de la falla):**
   * Abrir **Grafana** (`https://grafana.nodosur.cl`, `admin` / `AdminTas13!`) y **Zabbix** (`https://zabbix.nodosur.cl/zabbix`, `Admin` / `zabbix`).
   * Mostrar los 5 hosts en verde y el servicio MariaDB / puerto `3306` operativo.
2. **Provocar falla controlada de la Base de Datos en VM4 (`10.33.199.108`):**
   ```bash
   date -u   # Registrar hora exacta del incidente
   sudo docker stop vm258-db-backup
   ```
   *(Si HAProxy entrega portada en caché RAM, purgarla en VM1 con `sudo systemctl reload haproxy` o probar una ruta dinámica como `/wp-admin` o `curl -k -H "Cache-Control: no-cache" https://www.nodosur.cl/`).*
3. **Repetir operación del CMS desde el cliente:**
   * Recargar `https://www.nodosur.cl/` (o un producto / `/wp-admin`) → WordPress devuelve **"Error al establecer una conexión con la base de datos"** (HTTP `500`).
4. **Mostrar evidencia forense con marcas de tiempo:**
   * **Logs de Apache (VM2/VM3):** `sudo docker logs --tail 15 vm206-web1` / `tail -n 10 /var/log/apache2/error.log`.
   * **Logs de HAProxy (VM1):** `sudo tail -n 15 /var/log/haproxy.log` (se observan respuestas `500`).
   * **Zabbix / Grafana:** Mostrar la alerta disparada en `db.tas13.local` (caída de servicio MySQL/puerto 3306) y la caída en el gráfico de métricas de base de datos con la marca de tiempo exacta del `docker stop`.

---

### Etapa 4: Restauración de Datos
* **Qué debe mostrar el equipo:** Estabilizar el motor MariaDB, identificar el respaldo con su fecha/integridad, y usar la copia de evaluación (`nodosur_db_eval`) para demostrar que un dato de prueba **ausente antes de restaurar reaparece después**.
* **Evidencia mínima exigida:** Identificación y fecha del respaldo, resultado de la restauración y comprobación del dato antes y después.

> **Nota importante previa a la demo:** Antes de presentar, ejecutar en VM5:
> ```bash
> sudo /usr/local/bin/backup_seguro.sh
> ```
> Así `ultimo_respaldo.sql.gz` y `ultimo_respaldo.sha256` quedarán con fecha **27 de noviembre de 2026** y el dato de prueba ya incluido en el respaldo.

#### Secuencia paso a paso:
1. **Estabilizar el motor MariaDB en VM4 (`10.33.199.108`):**
   ```bash
   sudo docker start vm258-db-backup
   sudo docker ps --filter name=vm258-db-backup
   ```
2. **Identificar el respaldo y validar su integridad SHA-256 en VM5 (`10.33.199.110`):**
   ```bash
   ls -lh /var/backups/tas13/db/ultimo_respaldo.sql.gz /var/backups/tas13/ultimo_respaldo.sha256
   sudo sha256sum -c /var/backups/tas13/ultimo_respaldo.sha256
   ```
3. **Demostrar dato ausente ANTES de restaurar (en la copia de evaluación `nodosur_db_eval`):**
   ```bash
   # En VM4 (10.33.199.108): borrar una prenda de prueba en nodosur_db_eval
   sudo docker exec vm258-db-backup mariadb -u root -pRootSuperSeguro2026! -e "
     DELETE FROM nodosur_db_eval.wp_posts WHERE post_title = 'Polera Minimalista Celeste Hielo';
     SELECT ID, post_title, post_status FROM nodosur_db_eval.wp_posts WHERE post_title = 'Polera Minimalista Celeste Hielo';
   "
   # Resultado: Empty set (dato ausente)
   ```
4. **Ejecutar restauración sobre la copia de evaluación `nodosur_db_eval` desde VM5 (`10.33.199.110`):**
   ```bash
   zcat /var/backups/tas13/db/ultimo_respaldo.sql.gz | mysql -h 10.33.199.108 -u root -pRootSuperSeguro2026! nodosur_db_eval
   ```
   *(O mostrar el script completo `/usr/local/bin/restore_seguro.sh` para recuperación total).*
5. **Demostrar que el dato REAPARECE DESPUÉS de restaurar:**
   ```bash
   # En VM4 (10.33.199.108):
   sudo docker exec vm258-db-backup mariadb -u root -pRootSuperSeguro2026! -e "
     SELECT ID, post_title, post_status FROM nodosur_db_eval.wp_posts WHERE post_title = 'Polera Minimalista Celeste Hielo';
   "
   # Resultado: el registro #1128 reaparece intacto
   ```

---

### Etapa 5: Validación Final
* **Qué debe mostrar el equipo:** Repetir la operación del CMS que falló en la Etapa 3, confirmar el dato recuperado y verificar en Zabbix/Grafana que las alertas volvieron a estado normal (`RESOLVED` / OK).
* **Evidencia mínima exigida:** CMS accesible por nombre (`https://www.nodosur.cl`), operación funcional, dato recuperado y señales posteriores a la recuperación.

#### Secuencia paso a paso:
1. Abrir `https://www.nodosur.cl/` en el navegador y consultar/operar el CMS (verificando HTTP 200 y respuesta normal desde `vm206-web1` / `vm248-web2`).
2. Confirmar el dato recuperado en la base de datos y en la interfaz web.
3. Volver a **Zabbix** y **Grafana** para mostrar que el trigger de caída de MariaDB pasó a **`RESOLVED`** y las métricas de consultas/disponibilidad se normalizaron con marca de tiempo posterior a la recuperación.

---

### Etapa 6: Defensa Individual (Banco de Preguntas Clave para el Equipo)

Para repartirse los roles y responder con seguridad cualquier pregunta del docente:

| Área / Rol sugerido | Posible pregunta del docente | Respuesta técnica sustentada en el proyecto |
| :--- | :--- | :--- |
| **Arquitectura y Red (VM1 Gateway)** | *¿Por qué solo VM1 tiene salida WAN y qué riesgo implica?* | Reduce drásticamente la superficie de ataque: ni los nodos web, ni MariaDB ni NFS están expuestos a la red externa (aislados en `10.33.199.104/29`). **Riesgo (SPoF):** si cae VM1 se pierde el acceso externo; en producción se mitiga con un segundo Gateway en **Keepalived/VRRP** con VIP compartida. |
| **DNS y HAProxy (VM1)** | *¿Por qué el registro A apunta a HAProxy y no a Web1/Web2?* | Porque HAProxy centraliza la terminación TLS/HTTPS, el balanceo `leastconn` entre `.106` y `.107`, la micro-caché RAM (64 MB), el bloqueo de `/xmlrpc.php` y el enrutamiento L7 hacia WordPress, Zabbix y Grafana bajo una sola IP WAN (`10.33.195.195`). |
| **Clúster Web y NFS (VM2/VM3)** | *¿Qué pasa si cae Web1? ¿Qué riesgo tiene el NFS actual?* | Si cae `vm206-web1`, HAProxy lo marca `DOWN` en ≤9s (`inter 3s fall 3`) y desvía el 100% del tráfico a `vm248-web2`. **Riesgos reales detectados:** 1) VM5 (NFS) es un punto único de fallo para los archivos; 2) con `actimeo=60` en NFS, escrituras simultáneas entre nodos pueden generar `Stale file handle` (mitigado activando Sticky Sessions `cookie SRVID` en HAProxy). |
| **Base de Datos y Respaldos (VM4/VM5)** | *¿Por qué los respaldos usan modelo Pull y firmas SHA-256?* | En el modelo **Pull**, la bóveda (`10.33.199.110`) extrae el dump usando `backup_agent` (solo lectura). Si vulneran WordPress o DB, el atacante no tiene credenciales para borrar los backups. Las firmas **SHA-256** garantizan integridad antes de restaurar. |
| **Observabilidad (VM5 Zabbix + Grafana)** | *¿Por qué Zabbix tiene su propia MariaDB en VM5 en vez de usar VM4?* | Por **aislamiento y resiliencia**: si la MariaDB de producción (VM4) colapsa (como en la Etapa 3), Zabbix sigue 100% operativo usando su BD local en `127.0.0.1` y puede emitir la alerta del incidente sin caerse junto con la aplicación. |

---

## 5. Checklist Pre-Demo (5 minutos antes de presentar)

- [ ] **VM5 (`10.33.199.110`):** Ejecutar `sudo /usr/local/bin/backup_seguro.sh` y verificar `sudo sha256sum -c /var/backups/tas13/ultimo_respaldo.sha256` (para que `ultimo_respaldo.sql.gz` quede con fecha **27 Nov 2026** e incluya la prenda `Polera Minimalista Celeste Hielo` y todos los cambios de hoy).
- [ ] **Tienda en vivo:** Verificar en navegador (`Ctrl + F5`) que `https://www.nodosur.cl/` muestra la estética celeste minimalista, el botón flotante **Mi Bolsa**, las fichas de prendas con selector de tallas y `/shop/` con las 15 prendas.
- [ ] **Pestañas abiertas en el navegador del cliente:**
  1. `https://www.nodosur.cl/` (CMS por nombre)
  2. `https://www.nodosur.cl/stats` (HAProxy Live Stats — `admin` / `tas13pass`)
  3. `https://zabbix.nodosur.cl/zabbix/` (Zabbix — `Admin` / `zabbix`)
  4. `https://grafana.nodosur.cl/` (Grafana — `admin` / `AdminTas13!`)
- [ ] **Terminales SSH listas:** Una sesión en **VM1** (`renajara@10.33.195.195`), una en **VM4** (`gatica@10.33.199.108`) y una en **VM5** (`tas13_backup@10.33.199.110`).
- [ ] *(Opcional)* Si quieren cambiar el tema de WordPress antes de la demo sin errores: poner `vm248-web2` en `MAINT` desde `/stats`, cambiar el tema, recargar HAProxy (`sudo systemctl reload haproxy`) y volver `vm248-web2` a `READY`.
