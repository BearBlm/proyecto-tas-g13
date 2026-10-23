$TTL    604800
@       IN      SOA     ns1.nodosur.cl. admin.nodosur.cl. (
                     2026101901         ; Serial (YYYYMMDDNN)
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.nodosur.cl.

; Punto de entrada WAN para clientes externos (apuntando al Gateway VM 105)
@       IN      A       10.30.248.9
ns1     IN      A       10.30.248.9
gw      IN      A       10.30.248.9
www     IN      A       10.30.248.9
*       IN      A       10.30.248.9

; Segmento LAN interno Proxmox (10.33.199.104/29)
gw-lan  IN      A       10.33.199.105
web1    IN      A       10.33.199.106
web2    IN      A       10.33.199.107
db      IN      A       10.33.199.108
dns     IN      A       10.33.199.105
backup  IN      A       10.33.199.109
storage IN      A       10.33.199.109
