#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - VM 105 (GATEWAY / PROXY / DNS BIND9 / ROUTER NAT)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# ==============================================================================

set -e

echo "=== [1/7] Actualizando repositorios e instalando paquetes (HAProxy + BIND9 + Firewall) ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    haproxy \
    bind9 \
    bind9utils \
    dnsutils \
    iptables-persistent \
    curl \
    net-tools

echo "=== [2/7] Habilitando reenvío de paquetes IPv4 (IP Forwarding) ==="
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf

echo "=== [3/7] Configurando Servidor DNS BIND9 Local ==="
cp ./named.conf /etc/bind/named.conf
cp ./db.nodosur.cl /etc/bind/db.nodosur.cl
cp ./db.tas13.local /etc/bind/db.tas13.local

chown -R bind:bind /etc/bind/
chmod 644 /etc/bind/named.conf /etc/bind/db.*

# Verificación de sintaxis BIND9
named-checkconf /etc/bind/named.conf
named-checkzone nodosur.cl /etc/bind/db.nodosur.cl
named-checkzone tas13.local /etc/bind/db.tas13.local

systemctl enable named
systemctl restart named

echo "=== [4/7] Configurando Firewall y NAT Masquerade (Salida a Internet y Puertos Locales) ==="
WAN_IF="eth0"
LAN_IF="eth1"
LAN_NET="10.33.199.104/29"

# Limpieza preventiva de reglas
iptables -F
iptables -t nat -F

# NAT Masquerade: Permite a las VMs de la LAN (10.33.199.104/29) salir a Internet por la interfaz WAN
iptables -t nat -A POSTROUTING -s $LAN_NET -o $WAN_IF -j MASQUERADE

# Forwarding: Permitir tráfico establecido y tráfico LAN -> WAN
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# Permitir tráfico entrante a servicios locales en VM 105:
# - DNS BIND9 (puerto 53 UDP/TCP) tanto en WAN como en LAN
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
# - HAProxy (puertos 80 HTTP, 443 HTTPS, 8404 Stats)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 8404 -j ACCEPT

# Guardar reglas persistentes para reinicios
netfilter-persistent save

echo "=== [5/7] Configurando HAProxy y Certificados SSL ==="
mkdir -p /etc/haproxy/certs
if [ -f "./certs/nodosur.pem" ]; then
    cp ./certs/nodosur.pem /etc/haproxy/certs/nodosur.pem
elif [ -f "../../gw_dns/certs/nodosur.pem" ]; then
    cp ../../gw_dns/certs/nodosur.pem /etc/haproxy/certs/nodosur.pem
else
    echo "[!] Generando certificado SSL temporal autofirmado si no existe..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/haproxy/certs/nodosur.key \
      -out /etc/haproxy/certs/nodosur.crt \
      -subj "/CN=www.nodosur.cl/O=UTFSM/OU=TAS-G13"
    cat /etc/haproxy/certs/nodosur.crt /etc/haproxy/certs/nodosur.key > /etc/haproxy/certs/nodosur.pem
fi
chmod 600 /etc/haproxy/certs/nodosur.pem

cp ./haproxy.cfg /etc/haproxy/haproxy.cfg

echo "=== [6/7] Validando y reiniciando servicio HAProxy ==="
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy

echo "=== [7/7] Verificando servicios en VM 105 (Gateway + DNS) ==="
systemctl status haproxy --no-pager
systemctl status named --no-pager
echo "Probando resolución DNS local:"
dig @127.0.0.1 www.nodosur.cl +short
echo "¡VM 105 (Gateway / Router NAT / HAProxy / DNS BIND9) configurada y operando exitosamente!"
