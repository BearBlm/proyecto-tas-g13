# ==============================================================================
# ARQUITECTURA DE RED Y TOPOLOGÍA PROXMOX VE - PROYECTO TAS-G13
# ==============================================================================

## 1. Esquema de Subred y Direccionamiento IP (/29)

* **Segmento de Red:** `10.33.199.104/29`
* **Máscara de Subred:** `255.255.255.248` (Prefijo /29 -> Bloque de 8 IPs)
* **Dirección de Red:** `10.33.199.104` ➔ **EXCLUIDA** (Identificador de Red)
* **Dirección de Broadcast:** `10.33.199.111` ➔ **EXCLUIDA** (Dirección de Difusión)
* **IPs Útiles Disponibles:** 6 direcciones exactas (`10.33.199.105` a `10.33.199.110`)

---

## 2. Matriz de Asignación de Máquinas Virtuales (5 VMs Proyecto + 1 VM Backup)

| VM ID (Sugerido) | Hostname / Nombre | Rol en la Infraestructura | Interfaz Proxmox | Dirección IP | Gateway | DNS | Servicios Activos |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **VM 105** | `gw.tas13.local` | **Gateway / Proxy Inverso / Router** | `net0` (`vmbr0` - WAN)<br>`net1` (`vmbr1` - LAN) | **WAN:** DHCP / `10.30.248.9`<br>**LAN:** `10.33.199.105/29` | Puerta de enlace WAN | `10.33.199.109` | HAProxy 2.8 (SSL/TLS, micro-caché, balanceo), iptables NAT Masquerade, DNAT DNS. |
| **VM 106** | `web1.tas13.local` | **Nodo Web 1** | `net0` (`vmbr1` - LAN) | `10.33.199.106/29` | `10.33.199.105` | `10.33.199.109` | Apache 2.4, PHP 8.3, OPcache, WordPress, Cliente NFS. |
| **VM 107** | `web2.tas13.local` | **Nodo Web 2** | `net0` (`vmbr1` - LAN) | `10.33.199.107/29` | `10.33.199.105` | `10.33.199.109` | Apache 2.4, PHP 8.3, OPcache, WordPress, Cliente NFS. |
| **VM 108** | `db.tas13.local` | **Servidor de Base de Datos** | `net0` (`vmbr1` - LAN) | `10.33.199.108/29` | `10.33.199.105` | `10.33.199.109` | MariaDB 10.11 (`nodosur_db`), acceso restringido a `10.33.199.%`. |
| **VM 109** | `dns.tas13.local` | **Servidor DNS Autoritativo** | `net0` (`vmbr1` - LAN) | `10.33.199.109/29` | `10.33.199.105` | `127.0.0.1` | BIND9 resolviendo `nodosur.cl` y `tas13.local` con reenviadores `8.8.8.8` y `1.1.1.1`. |
| **VM 110** | `backup.tas13.local` | **Servidor de Respaldos Seguro y Almacenamiento Centralizado** | `net0` (`vmbr1` - LAN) | `10.33.199.110/29` | `10.33.199.105` | `10.33.199.109` | Servidor NFS seguro (`/srv/nfs/wordpress`), respaldos Pull automáticos por SSH/cron, verificación SHA-256, inmutabilidad y rotación. |

---

## 3. Diagrama Visual de la Topología en Proxmox VE

```text
                                [ CLIENTES EXTERNOS / RED INSTITUCIONAL / VPN ]
                                                       │
                                                       ▼
                      ╔═════════════════════════════════════════════════════════════════╗
                      ║                     HIPERVISOR PROXMOX VE                      ║
                      ║                                                                 ║
                      ║  [ vmbr0 - Linux Bridge Físico (WAN) ]                          ║
                      ║   └─ net0: IP Pública / VPN (Ej: 10.30.248.9)                   ║
                      ║                       │                                         ║
                      ║                       ▼                                         ║
                      ║     ┌─────────────────────────────────────────────────────┐     ║
                      ║     │  VM 105: GATEWAY & BALANCEADOR (ÚNICA CONEXIÓN WAN) │     ║
                      ║     │  - HAProxy (Puertos 80, 443 HTTPS, 8404 Stats)      │     ║
                      ║     │  - Firewall iptables (NAT Masquerade hacia LAN)     │     ║
                      ║     │  - DNAT Port 53 -> Redirige consultas DNS a VM 109  │     ║
                      ║     └──────────────────────────┬──────────────────────────┘     ║
                      ║                                │ net1 (LAN: 10.33.199.105/29)   ║
                      ║                                ▼                                ║
                      ║  [ vmbr1 - Linux Bridge Privado / Aislado (LAN: 10.33.199.104/29) ]
                      ║      │                 │                 │                 │    ║
                      ║      ├─────────────────┼─────────────────┼─────────────────┤    ║
                      ║      │                 │                 │                 │    ║
                      ║      ▼                 ▼                 ▼                 ▼    ║
                      ║ ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐ ║
                      ║ │  VM 106  │     │  VM 107  │     │  VM 109  │     │  VM 108  │ ║
                      ║ │  Web 1   │     │  Web 2   │     │ DNS BIND │     │ MariaDB  │ ║
                      ║ │ Apache2  │     │ Apache2  │     │  named   │     │ 10.11 DB │ ║
                      ║ │ .106     │     │ .107     │     │ .109     │     │ .108     │ ║
                      ║ └────┬─────┘     └────┬─────┘     └──────────┘     └────▲─────┘ ║
                      ║      │                │                                 │       ║
                      ║      │ Montaje NFS    │ Montaje NFS      Conexión SQL   │       ║
                      ║      │ (/var/www/html)│ (/var/www/html)  TCP 3306       │       ║
                      ║      ▼                ▼                                 │       ║
                      ║    ┌────────────────────────────────────────────────────┴─────┐ ║
                      ║    │         VM 110: SERVIDOR DE BACKUP SEGURO Y STORAGE       │ ║
                      ║    │                     IP: 10.33.199.110                    │ ║
                      ║    │  - Servidor NFS (/srv/nfs/wordpress)                     │ ║
                      ║    │  - Copias de seguridad cifradas y automatizadas (cron)   │ ║
                      ║    │  - Extracción "Pull" segura de dumps SQL y archivos      │ ║
                      ║    │  - Firmas criptográficas de verificación SHA-256         │ ║
                      ║    │  - Aislada 100% de la WAN exterior                       │ ║
                      ║    └──────────────────────────────────────────────────────────┘ ║
                      ╚═════════════════════════════════════════════════════════════════╝
```

---

## 4. Consideraciones Clave de Seguridad y Aislamiento

1. **Punto Único de Entrada WAN:**  
   Solo la **VM 105 (Gateway)** tiene interfaz conectada al bridge `vmbr0`. Ninguna otra máquina virtual tiene salida directa ni es accesible desde el exterior, impidiendo ataques directos hacia los servidores web, base de datos o almacenamiento.
2. **Modelo Pull de Respaldo Seguro (VM 110):**  
   Si un atacante lograra vulnerar WordPress a través de una falla en un plugin, estará atrapado dentro del contenedor o VM web (`10.33.199.106` o `.107`). **No tendrá credenciales ni acceso al servidor de backups (`10.33.199.110`)**. El servidor de backups es quien inicia la conexión de lectura (*Pull*) mediante llaves SSH blindadas.
3. **Consistencia de Datos Web:**  
   Ambos nodos Web (`web1` y `web2`) leen y escriben sobre el almacenamiento NFS centralizado provisto por la VM 110. Todo archivo multimedia o plugin instalado en Web 1 está disponible de inmediato en Web 2.
