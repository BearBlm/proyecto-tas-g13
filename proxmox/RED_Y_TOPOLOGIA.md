# ==============================================================================
# ARQUITECTURA DE RED Y TOPOLOGÍA PROXMOX VE - PROYECTO TAS-G13
# ==============================================================================

## 1. Esquema de Subred y Direccionamiento IP (/29)

* **Segmento de Red:** `10.33.199.104/29`
* **Máscara de Subred:** `255.255.255.248` (Prefijo /29 -> Bloque de 8 IPs)
* **Dirección de Red:** `10.33.199.104` ➔ **EXCLUIDA** (Identificador de Red)
* **Dirección de Broadcast:** `10.33.199.111` ➔ **EXCLUIDA** (Dirección de Difusión)
* **IPs Asignadas (5 VMs de Proyecto):** `10.33.199.105` a `10.33.199.109`
* **IP de Reserva / Libre en Subred:** `10.33.199.110`

---

## 2. Matriz de Asignación de Máquinas Virtuales (Exactamente 5 VMs - Límite del Proyecto)

| VM ID | Hostname / Nombre | Rol en la Infraestructura | Interfaz Proxmox | Dirección IP | Gateway | DNS | Servicios Activos |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **VM 105** | `gw.tas13.local`<br>`ns1.nodosur.cl` | **Gateway / Proxy Inverso / DNS BIND9 / Router NAT** | `net0` (`vmbr0` - WAN)<br>`net1` (`vmbr1` - LAN) | **WAN:** DHCP / `10.30.248.9`<br>**LAN:** `10.33.199.105/29` | Puerta de enlace WAN | `127.0.0.1`<br>`1.1.1.1` | HAProxy 2.8 (SSL/TLS, micro-caché, balanceo leastconn), DNS BIND9 autoritativo (`nodosur.cl` / `tas13.local` en puerto 53), iptables NAT Masquerade. |
| **VM 106** | `web1.tas13.local` | **Nodo Web 1** | `net0` (`vmbr1` - LAN) | `10.33.199.106/29` | `10.33.199.105` | `10.33.199.105` | Apache 2.4, PHP 8.3, OPcache, WordPress, Cliente NFS hacia VM 109. |
| **VM 107** | `web2.tas13.local` | **Nodo Web 2** | `net0` (`vmbr1` - LAN) | `10.33.199.107/29` | `10.33.199.105` | `10.33.199.105` | Apache 2.4, PHP 8.3, OPcache, WordPress, Cliente NFS hacia VM 109. |
| **VM 108** | `db.tas13.local` | **Servidor de Base de Datos** | `net0` (`vmbr1` - LAN) | `10.33.199.108/29` | `10.33.199.105` | `10.33.199.105` | MariaDB 10.11 (`nodosur_db`), usuario `wp_nodosur` para `10.33.199.%`, usuario `backup_agent` para VM 109. |
| **VM 109** | `backup.tas13.local`<br>`storage.tas13.local` | **Servidor de Respaldos Seguro y Storage Centralizado** | `net0` (`vmbr1` - LAN) | `10.33.199.109/29` | `10.33.199.105` | `10.33.199.105` | Servidor NFS seguro (`/srv/nfs/wordpress`), respaldos Pull automáticos por SSH/cron, verificación SHA-256, inmutabilidad y rotación. |

---

## 3. Diagrama Visual de la Topología en Proxmox VE (5 Máquinas)

```text
                                [ CLIENTES EXTERNOS / RED INSTITUCIONAL / VPN ]
                                                       │
                                                       ▼ (HTTP 80, HTTPS 443, DNS 53 UDP/TCP, Stats 8404)
                      ╔═════════════════════════════════════════════════════════════════╗
                      ║                     HIPERVISOR PROXMOX VE                      ║
                      ║                                                                 ║
                      ║  [ vmbr0 - Linux Bridge Físico (WAN) ]                          ║
                      ║   └─ net0: IP Pública / VPN (Ej: 10.30.248.9)                   ║
                      ║                       │                                         ║
                      ║                       ▼                                         ║
                      ║     ┌─────────────────────────────────────────────────────┐     ║
                      ║     │ VM 105: GATEWAY, DNS & BALANCEADOR (CONEXIÓN WAN)   │     ║
                      ║     │ - HAProxy 2.8 (Puertos 80, 443 HTTPS, 8404 Stats)   │     ║
                      ║     │ - DNS BIND9 Autoritativo (Puerto 53 UDP/TCP nativo) │     ║
                      ║     │ - Firewall iptables (NAT Masquerade hacia LAN)      │     ║
                      ║     └──────────────────────────┬──────────────────────────┘     ║
                      ║                                │ net1 (LAN: 10.33.199.105/29)   ║
                      ║                                ▼                                ║
                      ║  [ vmbr1 - Linux Bridge Privado / Aislado (LAN: 10.33.199.104/29) ]
                      ║      │                 │                 │                 │    ║
                      ║      ├─────────────────┼─────────────────┼─────────────────┤    ║
                      ║      │                 │                 │                 │    ║
                      ║      ▼                 ▼                 ▼                 ▼    ║
                      ║ ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐ ║
                      ║ │  VM 106  │     │  VM 107  │     │  VM 108  │     │  VM 109  │ ║
                      ║ │  Web 1   │     │  Web 2   │     │ MariaDB  │     │ Storage  │ ║
                      ║ │ Apache2  │     │ Apache2  │     │ 10.11 DB │     │ & Backup │ ║
                      ║ │ .106     │     │ .107     │     │ .108     │     │ .109     │ ║
                      ║ └────┬─────┘     └────┬─────┘     └────▲─────┘     └────▲─────┘ ║
                      ║      │                │                │                │       ║
                      ║      │                │                │                │       ║
                      ║      │ Montaje NFS    │ Montaje NFS    │ Conexión SQL   │       ║
                      ║      │ (/var/www/html)│ (/var/www/html)│ (TCP 3306)     │       ║
                      ║      └────────────────┴────────────────┼────────────────┘       ║
                      ║                                        │ Extracción Pull Dump   ║
                      ║                                        │ y share NFS            ║
                      ║                                        ▼                        ║
                      ║              ┌───────────────────────────────────┐              ║
                      ║              │  VM 109: BACKUP SEGURO & STORAGE  │              ║
                      ║              │  - NFS Server (/srv/nfs/wordpress)│              ║
                      ║              │  - Respaldos Pull con SHA-256     │              ║
                      ║              │  - Aislada 100% de la WAN exterior│              ║
                      ║              └───────────────────────────────────┘              ║
                      ╚═════════════════════════════════════════════════════════════════╝
```

---

## 4. Consideraciones Clave de Seguridad y Aislamiento

1. **Punto Único de Entrada WAN:**  
   Solo la **VM 105 (Gateway / DNS)** tiene interfaz conectada al bridge `vmbr0`. Ninguna otra máquina virtual tiene salida directa ni es accesible desde el exterior, impidiendo ataques directos hacia los servidores web, base de datos o almacenamiento.
2. **DNS BIND9 Integrado en Gateway:**  
   Al operar BIND9 en la VM 105, atiende consultas de nombres de dominio tanto desde el exterior (WAN) como internamente para todas las máquinas de la subred (`10.33.199.105`), eliminando la necesidad de reglas complejas de DNAT y optimizando el uso de recursos para ajustarse estrictamente a las 5 máquinas permitidas.
3. **Modelo Pull de Respaldo Seguro (VM 109):**  
   Si un atacante lograra vulnerar WordPress a través de una falla en un plugin, estará atrapado dentro del contenedor o VM web (`10.33.199.106` o `.107`). **No tendrá credenciales ni acceso al servidor de backups (`10.33.199.109`)**. El servidor de backups es quien inicia la conexión de lectura (*Pull*) mediante llaves SSH y el usuario restringido `backup_agent` en MariaDB.
4. **Consistencia de Datos Web:**  
   Ambos nodos Web (`web1` y `web2`) leen y escriben sobre el almacenamiento NFS centralizado provisto por la VM 109. Todo archivo multimedia o plugin instalado en Web 1 está disponible de inmediato en Web 2.
