#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - VM 109 (BACKUPS SEGUROS & STORAGE NFS)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# ==============================================================================

set -e

echo "=== [1/5] Instalando NFS Kernel Server, MariaDB Client y Utilitarios de Respaldo ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nfs-kernel-server \
    mariadb-client \
    rsync \
    curl \
    tar \
    gzip \
    cron \
    dnsutils

echo "=== [2/5] Creando directorios de almacenamiento y bóveda de respaldos blindada ==="
# Directorio NFS compartido para WordPress (Web 1 y Web 2)
mkdir -p /srv/nfs/wordpress
chown -R www-data:www-data /srv/nfs/wordpress
chmod -R 775 /srv/nfs/wordpress

# Bóveda de respaldos (Acceso restringido estricto: solo root de VM 109)
mkdir -p /var/backups/tas13/db
mkdir -p /var/backups/tas13/files
chmod 700 /var/backups/tas13

echo "=== [3/5] Extrayendo archivos base de WordPress si existen ==="
# Si existen los tar.gz del proyecto original, los desplegamos en el share NFS
LATEST_TAR=$(ls -t ../../db_backup/wp_archivos_*.tar.gz 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_TAR" ]; then
    echo "Desempaquetando archivos web previos ($LATEST_TAR)..."
    tar -xzf "$LATEST_TAR" -C /srv/nfs/wordpress/
    chown -R www-data:www-data /srv/nfs/wordpress
fi

echo "=== [4/5] Configurando exportación NFS segura (/etc/exports) ==="
# Solo se permite acceso a las IPs exactas de Web 1 (10.33.199.106) y Web 2 (10.33.199.107)
cat << 'EOF' > /etc/exports
/srv/nfs/wordpress 10.33.199.106(rw,sync,no_subtree_check,no_root_squash) 10.33.199.107(rw,sync,no_subtree_check,no_root_squash)
EOF

exportfs -ra
systemctl enable nfs-kernel-server
systemctl restart nfs-kernel-server

echo "=== [5/5] Configurando tarea automática de respaldo (cronjob nocturno) ==="
chmod +x ./backup_seguro.sh ./restore_seguro.sh || true
cp ./backup_seguro.sh /usr/local/bin/backup_seguro.sh
cp ./restore_seguro.sh /usr/local/bin/restore_seguro.sh
chmod +x /usr/local/bin/backup_seguro.sh /usr/local/bin/restore_seguro.sh

# Cronjob diario a las 02:00 AM
(crontab -l 2>/dev/null | grep -v "backup_seguro.sh" ; echo "0 2 * * * /usr/local/bin/backup_seguro.sh >> /var/log/backup_tas13.log 2>&1") | crontab -

echo "¡VM 109 (Servidor de Backup Seguro & NFS) lista y protegida en 10.33.199.109!"
