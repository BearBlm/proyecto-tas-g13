#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - NODOS WEB (VM 106 / VM 107)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# Parámetro 1: Dirección IP del nodo (10.33.199.106 o 10.33.199.107)
# Parámetro 2: Hostname (web1 o web2)
# ==============================================================================

set -e

NODE_IP=${1:-"10.33.199.106"}
NODE_HOST=${2:-"web1"}

echo "=== [1/6] Configurando Hostname a ${NODE_HOST}.tas13.local ==="
hostnamectl set-hostname "${NODE_HOST}.tas13.local"

echo "=== [2/6] Instalando Apache 2.4, PHP 8.3, OPcache y Cliente NFS ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    php8.3 \
    php8.3-mysql \
    php8.3-curl \
    php8.3-gd \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-xmlrpc \
    php8.3-soap \
    php8.3-intl \
    php8.3-zip \
    php8.3-opcache \
    libapache2-mod-php8.3 \
    nfs-common \
    curl \
    dnsutils

echo "=== [3/6] Optimizando OPcache para alta concurrencia ==="
cat << 'EOF' > /etc/php/8.3/apache2/conf.d/99-opcache-tas.ini
[opcache]
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.enable_cli=1
EOF

echo "=== [4/6] Configurando Montaje NFS Compartido desde VM 109 (Storage/Backup) ==="
mkdir -p /var/www/html
STORAGE_IP="10.33.199.109"

# Asegurar que esté en fstab para montaje persistente en reinicios
if ! grep -q "/srv/nfs/wordpress" /etc/fstab; then
    echo "${STORAGE_IP}:/srv/nfs/wordpress /var/www/html nfs rw,sync,hard,intr,_netdev 0 0" >> /etc/fstab
fi

# Intentar montaje
mount -a || echo "[!] Advertencia: Si VM 109 aún no tiene NFS activo, el montaje se completará al iniciarla."

echo "=== [5/6] Habilitando módulos requeridos de Apache ==="
a2enmod rewrite
a2enmod headers
systemctl enable apache2
systemctl restart apache2

echo "=== [6/6] Verificando conectividad hacia el Gateway y Base de Datos ==="
ping -c 2 10.33.199.105 || true
echo "¡Nodo Web ${NODE_HOST} (${NODE_IP}) aprovisionado exitosamente!"
