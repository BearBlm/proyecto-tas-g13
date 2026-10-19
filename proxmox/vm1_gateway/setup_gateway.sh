#!/bin/bash
# ==============================================================================
# SCRIPT DE CONFIGURACIÓN AUTOMÁTICA - VM 105 (GATEWAY / PROXY / ROUTER NAT)
# Sistema Operativo: Ubuntu Server 24.04 LTS (Proxmox VE)
# ==============================================================================

set -e

echo "=== [1/6] Actualizando repositorios e instalando paquetes ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy iptables-persistent curl dnsutils net-tools

echo "=== [2/6] Habilitando reenvío de paquetes IPv4 (IP Forwarding) ==="
sysctl -w net.ipv4.ip_forward=1
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf

echo "=== [3/6] Configurando Firewall y NAT Masquerade (Salida a Internet para la LAN) ==="
WAN_IF="eth0"
LAN_IF="eth1"
LAN_NET="10.33.199.104/29"
DNS_VM="10.33.199.109"

# Limpieza preventiva de reglas
iptables -F
iptables -t nat -F

# NAT Masquerade: Permite a las VMs de la LAN (10.33.199.104/29) salir a Internet por la interfaz WAN
iptables -t nat -A POSTROUTING -s $LAN_NET -o $WAN_IF -j MASQUERADE

# Forwarding: Permitir tráfico establecido y tráfico LAN -> WAN
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

# Port Forwarding (DNAT): Redirigir consultas DNS externas (puerto 53 UDP/TCP) a la VM 109
iptables -t nat -A PREROUTING -i $WAN_IF -p udp --dport 53 -j DNAT --to-destination ${DNS_VM}:53
iptables -t nat -A PREROUTING -i $WAN_IF -p tcp --dport 53 -j DNAT --to-destination ${DNS_VM}:53
iptables -A FORWARD -p udp -d $DNS_VM --dport 53 -j ACCEPT
iptables -A FORWARD -p tcp -d $DNS_VM --dport 53 -j ACCEPT

# Guardar reglas persistentes para reinicios
netfilter-persistent save

echo "=== [4/6] Configurando HAProxy y Certificados SSL ==="
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

echo "=== [5/6] Validando y reiniciando servicio HAProxy ==="
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy

echo "=== [6/6] Verificando estado del Gateway ==="
systemctl status haproxy --no-pager
echo "¡VM 105 (Gateway / Router NAT / HAProxy) configurada y operando exitosamente!"
