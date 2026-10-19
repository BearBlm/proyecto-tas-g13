#!/bin/bash
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d "/var/lib/mysql/nodosur_db" ]; then
    echo "=== Inicializando Base de Datos MariaDB en Ubuntu 24.04 (VM 258) ==="
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
    mysqld_safe --skip-networking &
    pid="$!"
    sleep 4
    
    mariadb -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE};
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'10.33.199.%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'10.33.199.%';
FLUSH PRIVILEGES;
EOF
    mysqladmin -u root -p"${MARIADB_ROOT_PASSWORD}" shutdown
fi

echo "=== Iniciando MariaDB Server en Ubuntu 24.04 (10.33.199.108) ==="
exec mysqld --user=mysql