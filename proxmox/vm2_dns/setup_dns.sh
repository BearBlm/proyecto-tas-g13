#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - VM 109 (SERVIDOR DNS BIND9)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# ==============================================================================

set -e

echo "=== [1/4] Instalando BIND9 y utilitarios ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils dnsutils curl

echo "=== [2/4] Copiando archivos de configuración de zonas ==="
cp ./named.conf /etc/bind/named.conf
cp ./db.nodosur.cl /etc/bind/db.nodosur.cl
cp ./db.tas13.local /etc/bind/db.tas13.local

chown -R bind:bind /etc/bind/
chmod 644 /etc/bind/named.conf /etc/bind/db.*

echo "=== [3/4] Verificando sintaxis de BIND9 ==="
named-checkconf /etc/bind/named.conf
named-checkzone nodosur.cl /etc/bind/db.nodosur.cl
named-checkzone tas13.local /etc/bind/db.tas13.local

echo "=== [4/4] Reiniciando y habilitando servicio DNS ==="
systemctl enable named
systemctl restart named

echo "=== Prueba de resolución local ==="
dig @127.0.0.1 www.nodosur.cl +short
echo "¡VM 109 (DNS BIND9) operativa exitosamente en 10.33.199.109!"
