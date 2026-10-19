#!/bin/bash
FECHA=$(date +%Y%m%d_%H%M%S)
echo "=== [1/3] Exportando Base de Datos MariaDB (nodosur_db) en Ubuntu 24.04 ==="
mariadb-dump -u root -pRootSuperSeguro2026! nodosur_db > "/backups/db_ultimo_respaldo.sql"
cp "/backups/db_ultimo_respaldo.sql" "/backups/db_${FECHA}.sql"

echo "=== [2/3] Empaquetando archivos compartidos de WordPress (NFS) ==="
tar -czf "/backups/wp_archivos_${FECHA}.tar.gz" -C /mnt/nfs_wp_html .

echo "=== [3/3] Generando firma SHA256 ==="
sha256sum "/backups/db_ultimo_respaldo.sql" > "/backups/db_ultimo_respaldo.sql.sha256"
ls -lh /backups
echo "¡Respaldo finalizado con éxito!"