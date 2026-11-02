#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - VM 108 (MARIADB 10.11 DEDICADA)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# ==============================================================================

set -e

echo "=== [1/5] Instalando MariaDB Server y Cliente ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client curl dnsutils

echo "=== [2/5] Configurando MariaDB para escuchar en la red interna LAN (10.33.199.108) ==="
# Permitir conexiones desde la LAN
sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Afinamiento de alto rendimiento y concurrencia (1000+ sesiones simultáneas)
cat << 'EOF' > /etc/mysql/mariadb.conf.d/99-tas-tuning.cnf
[mysqld]
max_connections = 1200
max_user_connections = 1100
open_files_limit = 65535
table_open_cache = 4096
innodb_buffer_pool_size = 512M
skip-name-resolve
query_cache_size = 64M
query_cache_type = 1
EOF

# Afinamiento del kernel para altas conexiones y descriptores de archivo
cat << 'EOF' > /etc/sysctl.d/99-tas-concurrency.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
fs.file-max = 2097152
EOF
sysctl -p /etc/sysctl.d/99-tas-concurrency.conf || true

systemctl enable mariadb
systemctl restart mariadb

echo "=== [3/5] Creando Base de Datos y Usuarios con Acceso Restringido a la LAN ==="
ROOT_PASS="RootSuperSeguro2026!"
DB_NAME="nodosur_db"
DB_USER="wp_nodosur"
DB_PASS="NodoSurPassword2026!"
BACKUP_USER="backup_agent"
BACKUP_PASS="BackupSeguroTAS13!"

mariadb -u root << EOF
-- Seguridad de Root local
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';

-- Creación de Base de datos
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Usuario para WordPress (solo accesible desde el segmento LAN 10.33.199.%)
CREATE USER IF NOT EXISTS '${DB_USER}'@'10.33.199.%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'10.33.199.%';

-- Usuario dedicado para la máquina de backups (VM 109) con privilegios de solo lectura y dump
CREATE USER IF NOT EXISTS '${BACKUP_USER}'@'10.33.199.109' IDENTIFIED BY '${BACKUP_PASS}';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD ON *.* TO '${BACKUP_USER}'@'10.33.199.109';

FLUSH PRIVILEGES;
EOF

echo "=== [4/5] Importando respaldo existente de base de datos si existe ==="
if [ -f "./db_ultimo_respaldo.sql" ]; then
    echo "Importando ./db_ultimo_respaldo.sql..."
    mariadb -u root -p"${ROOT_PASS}" "${DB_NAME}" < ./db_ultimo_respaldo.sql
elif [ -f "../../db_backup/db_ultimo_respaldo.sql" ]; then
    echo "Importando desde db_backup..."
    mariadb -u root -p"${ROOT_PASS}" "${DB_NAME}" < ../../db_backup/db_ultimo_respaldo.sql
fi

echo "=== [5/5] Verificando estado y escuchas en el puerto 3306 ==="
ss -tulpn | grep 3306 || true
echo "¡VM 108 (MariaDB) configurada exitosamente y protegida en 10.33.199.108!"
