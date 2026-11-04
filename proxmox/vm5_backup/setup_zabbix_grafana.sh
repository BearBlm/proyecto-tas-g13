#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE INSTALACION Y CONFIGURACION AUTOMATICA
# ZABBIX 7.0 LTS + GRAFANA OSS + PLUGIN ZABBIX
# NODO: VM 109 (Storage, Backups & Observabilidad Central)
# IP: 10.33.199.109/29 - Proyecto TAS-G13
# ==============================================================================
set -euo pipefail

ZABBIX_DB_PASS="ZabbixPass2026!"
GRAFANA_ADMIN_PASS="AdminTas13!"

echo "======================================================================"
echo " [1/6] Preparando repositorios oficiales para Zabbix 7.0 y Grafana OSS"
echo "======================================================================"
apt-get update
DEBIAN_FRONTEND=noninteractive locale-gen en_US.UTF-8 es_ES.UTF-8 && update-locale LANG=en_US.UTF-8 && apt-get install -y \
    wget \
    curl \
    gnupg \
    software-properties-common \
    apt-transport-https \
    mariadb-server

# Repositorio Zabbix 7.0 LTS
if [ ! -f "/etc/apt/sources.list.d/zabbix.list" ]; then
    echo "[+] Descargando repositorio oficial de Zabbix 7.0 LTS (Noble 24.04)..."
    wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
    dpkg -i /tmp/zabbix-release.deb
    rm -f /tmp/zabbix-release.deb
fi

# Repositorio Grafana OSS
if [ ! -f "/etc/apt/sources.list.d/grafana.list" ]; then
    echo "[+] Descargando clave y repositorio oficial de Grafana..."
    mkdir -p /etc/apt/keyrings
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list > /dev/null
fi

apt-get update

echo "======================================================================"
echo " [2/6] Instalando Zabbix Server, Frontend Apache y Grafana OSS"
echo "======================================================================"
DEBIAN_FRONTEND=noninteractive locale-gen en_US.UTF-8 es_ES.UTF-8 && update-locale LANG=en_US.UTF-8 && apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent2 \
    grafana

echo "======================================================================"
echo " [3/6] Configurando Base de Datos Local para Zabbix (MariaDB)"
echo "======================================================================"
systemctl start mariadb

# Creacion de base de datos y usuario dedicado local
mysql -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"

# Cargar esquema inicial si la tabla users no existe
if ! mysql -u zabbix -p"${ZABBIX_DB_PASS}" zabbix -e "DESCRIBE users;" >/dev/null 2>&1; then
    echo "[+] Importando esquema inicial de Zabbix (puede tomar unos instantes)..."
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p"${ZABBIX_DB_PASS}" zabbix
fi

mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configurar contrasena en zabbix_server.conf
sed -i "s/^# DBPassword=/DBPassword=${ZABBIX_DB_PASS}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBPassword=.*/DBPassword=${ZABBIX_DB_PASS}/" /etc/zabbix/zabbix_server.conf

echo "======================================================================"
echo " [4/6] Instalando Plugin Zabbix en Grafana y Configurando Servicios"
echo "======================================================================"
# Instalacion del plugin oficial de Zabbix para Grafana
grafana-cli plugins install alexanderzobnin-zabbix-app

# Ajustar grafana.ini para acceso proxy seguro y subdominio
sed -i 's/^;domain = localhost/domain = grafana.nodosur.cl/' /etc/grafana/grafana.ini
sed -i 's|^;root_url = .*|root_url = https://grafana.nodosur.cl/|' /etc/grafana/grafana.ini

# Establecer contrasena inicial del admin de Grafana
grafana-cli admin reset-admin-password "${GRAFANA_ADMIN_PASS}" || true

echo "======================================================================"
echo " [5/6] Configurando Zabbix Agent 2 Local en VM 109"
echo "======================================================================"
sed -i "s/^Server=127.0.0.1/Server=127.0.0.1,10.33.199.109/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=127.0.0.1,10.33.199.109/" /etc/zabbix/zabbix_agent2.conf
sed -i "s/^Hostname=Zabbix server/Hostname=backup.tas13.local/" /etc/zabbix/zabbix_agent2.conf

echo "======================================================================"
echo " [6/6] Habilitando e Iniciando Todos los Servicios"
echo "======================================================================"
systemctl daemon-reload
systemctl restart mariadb zabbix-server zabbix-agent2 apache2 grafana-server
systemctl enable mariadb zabbix-server zabbix-agent2 apache2 grafana-server

echo "======================================================================"
echo " INSTALACION COMPLETADA EXITOSAMENTE EN VM 109!"
echo "======================================================================"
echo " Acceso Zabbix Web UI :"
echo "   - URL Directa : http://10.33.199.109/zabbix"
echo "   - URL Dominio : https://zabbix.nodosur.cl/zabbix"
echo "   - Usuario     : Admin (A mayuscula)"
echo "   - Password    : zabbix (cambiar al primer login)"
echo ""
echo " Acceso Grafana Dashboard :"
echo "   - URL Directa : http://10.33.199.109:3000"
echo "   - URL Dominio : https://grafana.nodosur.cl"
echo "   - Usuario     : admin"
echo "   - Password    : ${GRAFANA_ADMIN_PASS}"
echo ""
echo " Para conectar Grafana con Zabbix:"
echo "   1. En Grafana: Menu > Administration > Plugins > Zabbix > Enable"
echo "   2. Connections > Data sources > Add data source > Zabbix"
echo "   3. URL API: http://localhost/zabbix/api_jsonrpc.php"
echo "   4. Credenciales: Admin / tu password de Zabbix"
echo "   5. Clic en 'Save & Test' -> Debera salir conexion exitosa (verde)."
echo "======================================================================"
