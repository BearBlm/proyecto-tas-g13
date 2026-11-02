#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE INSTALACIÓN Y CONFIGURACIÓN AUTOMÁTICA DE ZABBIX AGENT 2
# PROYECTO TAS-G13 (UBUNTU SERVER 24.04 LTS / PROXMOX VE)
# ==============================================================================
set -euo pipefail

# IP del Servidor Zabbix en la subred privada /29
ZABBIX_SERVER_IP="${1:-10.33.199.110}"
CURRENT_HOSTNAME=$(hostname)

echo "======================================================================"
echo " Instalando Zabbix Agent 2 en: ${CURRENT_HOSTNAME}"
echo " Servidor de Monitoreo configurado en: ${ZABBIX_SERVER_IP}"
echo "======================================================================"

# 1. Asegurar repositorio oficial de Zabbix 7.0 LTS para Ubuntu 24.04 (Noble)
if [ ! -f "/etc/apt/sources.list.d/zabbix.list" ]; then
    echo "[+] Descargando e instalando repositorio oficial Zabbix 7.0 LTS..."
    wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb -O /tmp/zabbix-release.deb
    sudo dpkg -i /tmp/zabbix-release.deb
    rm -f /tmp/zabbix-release.deb
    sudo apt update
fi

# 2. Instalar el paquete de Zabbix Agent 2
echo "[+] Instalando paquete zabbix-agent2..."
sudo apt install -y zabbix-agent2

# 3. Configurar archivo /etc/zabbix/zabbix_agent2.conf
echo "[+] Configurando directivas de conexión en /etc/zabbix/zabbix_agent2.conf..."
sudo sed -i "s/^Server=127.0.0.1/Server=127.0.0.1,${ZABBIX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sudo sed -i "s/^ServerActive=127.0.0.1/ServerActive=${ZABBIX_SERVER_IP}/" /etc/zabbix/zabbix_agent2.conf
sudo sed -i "s/^Hostname=Zabbix server/Hostname=${CURRENT_HOSTNAME}/" /etc/zabbix/zabbix_agent2.conf

# 4. Ajustar regla en el firewall si UFW está activo
if command -v ufw >/dev/null 2>&1; then
    echo "[+] Apertura del puerto 10050/TCP en UFW para la subred LAN..."
    sudo ufw allow from 10.33.199.104/29 to any port 10050 proto tcp comment "Zabbix Agent 2 LAN" || true
fi

# 5. Reiniciar y habilitar el servicio
echo "[+] Iniciando y habilitando servicio zabbix-agent2..."
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2

# 6. Comprobar estado
if systemctl is-active --quiet zabbix-agent2; then
    echo "======================================================================"
    echo " ✔ Zabbix Agent 2 está ACTIVO y ejecutándose en puerto 10050/TCP."
    echo "   Hostname registrado: ${CURRENT_HOSTNAME}"
    echo "======================================================================"
else
    echo "❌ Error al iniciar zabbix-agent2. Revisa: sudo journalctl -u zabbix-agent2"
    exit 1
fi
