# GUÍA COMPLETA DE DESPLIEGUE EN PROXMOX VE
## Infraestructura Web de Alta Disponibilidad TAS-G13 (6 VMs: 5 Servicios + 1 Backup Seguro)

Esta guía documenta la migración y adaptación del proyecto contenerizado hacia un entorno nativo multi-máquina en **Proxmox VE**, cumpliendo con la segmentación estricta de red requerida.

---

## 1. Segmentación de Red y Asignación de IPs

La red privada del clúster opera sobre una subred `/29`:
* **Subred CIDR:** `10.33.199.104/29`
* **Máscara de Red:** `255.255.255.248`
* **Dirección de Red:** `10.33.199.104` ➔ **Excluida** (Identificador de Red).
* **Dirección de Broadcast:** `10.33.199.111` ➔ **Excluida** (Dirección de Broadcast).
* **Pool de IPs Útiles:** Exactamente **6 direcciones IP** (`.105` al `.110`), asignadas de manera unívoca a las 6 máquinas:

```
Subred 10.33.199.104/29:
 10.33.199.104 [RED - EXCLUIDA]
 ├── 10.33.199.105 ➔ VM 105: Gateway HAProxy / Firewall NAT (Única conexión WAN)
 ├── 10.33.199.106 ➔ VM 106: Nodo Web 1 (Apache2 + PHP 8.3 + WordPress)
 ├── 10.33.199.107 ➔ VM 107: Nodo Web 2 (Apache2 + PHP 8.3 + WordPress)
 ├── 10.33.199.108 ➔ VM 108: Servidor MariaDB 10.11 Dedicado
 ├── 10.33.199.109 ➔ VM 109: Servidor DNS Autoritativo BIND9
 └── 10.33.199.110 ➔ VM 110: Servidor de Backup Seguro & Storage NFS
 10.33.199.111 [BROADCAST - EXCLUIDA]
```

---

## 2. Configuración de Red en el Host Proxmox VE

En Proxmox VE se deben utilizar dos switches virtuales (Linux Bridges):
1. **`vmbr0` (WAN):** Conectado a la tarjeta de red física del servidor. Brinda conectividad hacia la red externa/universitaria/VPN.
2. **`vmbr1` (LAN Privada):** Bridge virtual aislado **sin tarjeta física asociada**. Funciona como un switch interno no enrutable desde el exterior.

### Edición de `/etc/network/interfaces` en Proxmox:
```bash
nano /etc/network/interfaces
```
Añadir la definición del bridge interno `vmbr1`:
```ini
# Red WAN / Gestión Proxmox (Existente)
auto vmbr0
iface vmbr0 inet static
    address 10.30.248.10/24
    gateway 10.30.248.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0

# Red LAN Privada Aislada para el Clúster TAS-G13
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```
Aplicar los cambios con:
```bash
ifreload -a
# o también: ifup vmbr1
```

---

## 3. Creación de las Máquinas Virtuales en Proxmox

Puedes crearlas mediante la interfaz web de Proxmox o ejecutando el script [`crear_vms_proxmox.sh`](file:///c:/Users/axelc/OneDrive/Documentos/project%C3%A7/proyecto-tas-g13/proxmox/crear_vms_proxmox.sh) desde la consola de Proxmox:

### Especificaciones Recomendadas:
| VM ID | Nombre | RAM | vCPU | Disco | Interfaces de Red |
| :---: | :--- | :---: | :---: | :---: | :--- |
| **105** | `gw-tas13` | 1024 MB | 2 | 20 GB | `net0` en `vmbr0` (WAN)<br>`net1` en `vmbr1` (LAN) |
| **106** | `web1-tas13` | 2048 MB | 2 | 20 GB | `net0` en `vmbr1` (LAN) |
| **107** | `web2-tas13` | 2048 MB | 2 | 20 GB | `net0` en `vmbr1` (LAN) |
| **108** | `db-tas13` | 2048 MB | 2 | 30 GB | `net0` en `vmbr1` (LAN) |
| **109** | `dns-tas13` | 1024 MB | 1 | 15 GB | `net0` en `vmbr1` (LAN) |
| **110** | `backup-storage-tas13` | 2048 MB | 2 | 50 GB | `net0` en `vmbr1` (LAN) |

> **Nota:** También puedes desplegar estas 6 instancias como **Contenedores LXC de Ubuntu 24.04** si dispones de recursos de hardware reducidos en tu hipervisor.

---

## 4. Despliegue y Configuración VM por VM

### Paso 4.1: VM 105 — Gateway / Proxy Inverso / Router NAT (IP LAN: `10.33.199.105`)
Esta es la **única máquina con conexión a WAN**:
1. Copiar los archivos de [`proxmox/vm1_gateway/`](file:///c:/Users/axelc/OneDrive/Documentos/project%C3%A7/proyecto-tas-g13/proxmox/vm1_gateway) a la VM.
2. Aplicar la configuración de red con Netplan:
   ```bash
   sudo cp netplan_gateway.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   ```
3. Ejecutar el script de configuración automática:
   ```bash
   sudo chmod +x setup_gateway.sh
   sudo ./setup_gateway.sh
   ```
   * Habilita `net.ipv4.ip_forward = 1`.
   * Aplica reglas de iptables: NAT Masquerade para dar salida a internet a los nodos de la LAN.
   * Redirige el puerto 53 (DNS) de la WAN hacia la VM 109 (`10.33.199.109:53`).
   * Configura HAProxy escuchando en puertos 80 y 443 con terminación SSL/TLS y panel de métricas en `:8404`.

---

### Paso 4.2: VM 109 — Servidor DNS Autoritativo BIND9 (IP LAN: `10.33.199.109`)
1. Copiar los archivos de [`proxmox/vm2_dns/`](file:///c:/Users/axelc/OneDrive/Documentos/project%C3%A7/proyecto-tas-g13/proxmox/vm2_dns) a la VM.
2. Configurar la red:
   ```bash
   sudo cp netplan_dns.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   ```
3. Ejecutar el script:
   ```bash
   sudo chmod +x setup_dns.sh
   sudo ./setup_dns.sh
   ```
   * Carga las zonas autoritativas `nodosur.cl` y `tas13.local`.
   * Permite resolución recursiva segura a través de `8.8.8.8` y `1.1.1.1`.

---

### Paso 4.3: VM 110 — Servidor de Backup Seguro & Almacenamiento Centralizado (IP LAN: `10.33.199.110`)
Esta máquina cumple dos roles clave para mantener el proyecto idéntico:
* **Almacenamiento Compartido NFS:** Exporta `/srv/nfs/wordpress` exclusivamente hacia Web 1 (`10.33.199.106`) y Web 2 (`10.33.199.107`).
* **Bóveda de Respaldos Blindada:** Realiza extracciones automáticas tipo *Pull* desde la base de datos y genera archivos protegidos con verificación criptográfica SHA-256.

1. Copiar los archivos de [`proxmox/vm6_backup/`](file:///c:/Users/axelc/OneDrive/Documentos/project%C3%A7/proyecto-tas-g13/proxmox/vm6_backup) a la VM.
2. Configurar la red:
   ```bash
   sudo cp netplan_backup.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   ```
3. Ejecutar el script de aprovisionamiento:
   ```bash
   sudo chmod +x setup_backup_storage.sh
   sudo ./setup_backup_storage.sh
   ```
4. Probar un respaldo manual inmediato:
   ```bash
   sudo /usr/local/bin/backup_seguro.sh
   ```

---

### Paso 4.4: VM 108 — Servidor de Base de Datos MariaDB 10.11 (IP LAN: `10.33.199.108`)
1. Copiar los archivos de [`proxmox/vm5_db/`](file:///c:/Users/axelc/OneDrive/Documentos/project%C3%A7/proyecto-tas-g13/proxmox/vm5_db) a la VM.
2. Configurar la red:
   ```bash
   sudo cp netplan_db.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   ```
3. Ejecutar el script:
   ```bash
   sudo chmod +x setup_mariadb.sh
   sudo ./setup_mariadb.sh
   ```
   * Aplica afinamiento (`max_connections = 1000`, `innodb_buffer_pool_size = 512M`).
   * Crea base de datos `nodosur_db`.
   * Crea usuario de WordPress restringido a `'10.33.199.%'`.
   * Crea usuario dedicado para la máquina de backups (`backup_agent@10.33.199.110`).
   * Importa el archivo SQL del proyecto original.

---

### Paso 4.5: VM 106 y VM 107 — Nodos Web WordPress (IPs LAN: `10.33.199.106` y `10.33.199.107`)
1. En **VM 106**:
   ```bash
   sudo cp netplan_web1.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   sudo chmod +x setup_web_node.sh
   sudo ./setup_web_node.sh 10.33.199.106 web1
   ```
2. En **VM 107**:
   ```bash
   sudo cp netplan_web2.yaml /etc/netplan/01-netcfg.yaml
   sudo netplan apply
   sudo chmod +x setup_web_node.sh
   sudo ./setup_web_node.sh 10.33.199.107 web2
   ```
Ambos nodos montarán `/var/www/html` desde la VM 110 por NFS y procesarán PHP con aceleración OPcache.

---

## 5. Medidas de Seguridad Implementadas en la Máquina de Backup (VM 110)

Para responder a la exigencia de que la máquina de backups sea **completamente segura**:

1. **Aislamiento Físico y Lógico Total:**  
   La VM 110 no tiene interfaz WAN ni puertos expuestos al exterior. Solo existe dentro de `vmbr1`.
2. **Arquitectura Pull Unidireccional:**  
   Los servidores web o de base de datos **no tienen contraseñas ni permisos para conectarse a la VM de backups**. Si un nodo web es comprometido, el atacante no puede acceder ni borrar los respaldos en VM 110.
3. **Firmas Criptográficas SHA-256:**  
   Cada respaldo genera automáticamente un archivo de manifiesto `.sha256`. Ante una recuperación, el script `restore_seguro.sh` valida primero los hashes. Si el hash difiere por 1 solo bit, la restauración se cancela por sospecha de corrupción o ataque.
4. **Política de Retención y Rotación Automática:**  
   El cronjob nocturno purga automáticamente copias mayores a 7 días, evitando que el almacenamiento colapse por falta de espacio en disco.

---

## 6. Verificación y Pruebas del Clúster en Proxmox

### 1. Probar Resolución DNS desde un equipo externo:
```bash
nslookup www.nodosur.cl <IP_WAN_DEL_GATEWAY>
```
*Debe retornar la IP del Gateway.*

### 2. Acceso Web Seguro (HTTPS):
Abrir en el navegador:
* `https://www.nodosur.cl/` (o `https://<IP_WAN_GATEWAY>/`)
* Panel de Monitoreo HAProxy: `http://<IP_WAN_GATEWAY>:8404/stats` (Usuario: `admin`, Contraseña: `tas13pass`).

### 3. Prueba de Caída y Balanceo de Carga:
En Proxmox, apaga la VM 106 (`web1`).  
Recarga el sitio en el navegador: el sitio seguirá operando normalmente gracias a que HAProxy conmuta instantáneamente al 100% de peticiones hacia la VM 107 (`web2`).
