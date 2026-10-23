#!/bin/bash
# ==============================================================================
# SCRIPT DE CREACIÓN AUTOMÁTICA DE VMs / CONTENEDORES EN PROXMOX VE (CLI)
# Ejecutar en la shell del servidor Proxmox VE (como root)
# ==============================================================================

set -e

STORAGE_POOL="local-lvm"  # Ajustar según tu pool (ej: local-lvm, ceph, zfs, local)
TEMPLATE_ID=9000          # ID de la plantilla Cloud-Init de Ubuntu 24.04 (si usas VMs)
BRIDGE_WAN="vmbr0"
BRIDGE_LAN="vmbr1"

echo "=========================================================================="
echo " [TAS-G13] DESPLIEGUE DE INFRAESTRUCTURA EN PROXMOX VE (LÍMITE: 5 MÁQUINAS)"
echo " Segmento LAN: 10.33.199.104/29 (IPs asignadas: 10.33.199.105 a 10.33.199.109)"
echo "=========================================================================="

# ------------------------------------------------------------------------------
# 1. Crear el Bridge Privado vmbr1 si no existe en Proxmox
# ------------------------------------------------------------------------------
if ! grep -q "vmbr1" /etc/network/interfaces; then
    echo "--> Creando bridge interno vmbr1 en /etc/network/interfaces..."
    cat << 'EOF' >> /etc/network/interfaces

auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF
    ifup vmbr1 || true
    echo "    Bridge vmbr1 creado y activado."
else
    echo "--> Bridge vmbr1 ya existe en Proxmox."
fi

# ------------------------------------------------------------------------------
# 2. Especificaciones de las 5 Máquinas Virtuales (Cupo Exacto por Grupo)
# ------------------------------------------------------------------------------
# ID 105: Gateway / HAProxy + DNS BIND9 (Conecta a WAN vmbr0 y LAN vmbr1)
# ID 106: Web 1 (Conecta solo a LAN vmbr1)
# ID 107: Web 2 (Conecta solo a LAN vmbr1)
# ID 108: MariaDB (Conecta solo a LAN vmbr1)
# ID 109: Backup & Storage NFS Seguro (Conecta solo a LAN vmbr1)

echo "--> [VM 105] Creando Gateway / HAProxy + DNS BIND9..."
qm create 105 --name gw-dns-tas13 --memory 1536 --cores 2 --net0 virtio,bridge=${BRIDGE_WAN} --net1 virtio,bridge=${BRIDGE_LAN} || echo "VM 105 ya existe"

echo "--> [VM 106] Creando Nodo Web 1..."
qm create 106 --name web1-tas13 --memory 2048 --cores 2 --net0 virtio,bridge=${BRIDGE_LAN} || echo "VM 106 ya existe"

echo "--> [VM 107] Creando Nodo Web 2..."
qm create 107 --name web2-tas13 --memory 2048 --cores 2 --net0 virtio,bridge=${BRIDGE_LAN} || echo "VM 107 ya existe"

echo "--> [VM 108] Creando MariaDB Server..."
qm create 108 --name db-tas13 --memory 2048 --cores 2 --net0 virtio,bridge=${BRIDGE_LAN} || echo "VM 108 ya existe"

echo "--> [VM 109] Creando Servidor de Backup y Almacenamiento Seguro NFS..."
qm create 109 --name backup-storage-tas13 --memory 2048 --cores 2 --net0 virtio,bridge=${BRIDGE_LAN} || echo "VM 109 ya existe"

echo "=========================================================================="
echo " [OK] Las 5 Máquinas Virtuales del Grupo 13 han sido registradas en Proxmox VE."
echo " Proceda a asociar sus discos y aplicar las configuraciones de red."
echo "=========================================================================="
