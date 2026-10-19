#!/bin/bash
echo "=== Iniciando Servidor DNS BIND9 en Ubuntu 24.04 (VM 250) ==="
named -u bind -c /etc/bind/named.conf

echo "=== Iniciando Balanceador HAProxy en Ubuntu 24.04 (VM 250) ==="
exec haproxy -f /etc/haproxy/haproxy.cfg -W -db