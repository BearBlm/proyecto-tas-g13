$TTL    604800
@       IN      SOA     ns1.nodosur.cl. admin.nodosur.cl. (
                     2026101601         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.nodosur.cl.

; Servidor DNS y Balanceador Gateway HAProxy (VM 250 - 10.30.248.9)
@       IN      A       10.30.248.9
ns1     IN      A       10.30.248.9
gw      IN      A       10.30.248.9
www     IN      A       10.30.248.9
*       IN      A       10.30.248.9

; VMs del clúster (Apache WordPress y Base de Datos)
web1    IN      A       10.33.199.106
web2    IN      A       10.33.199.107
db      IN      A       10.33.199.108
