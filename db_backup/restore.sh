#!/bin/bash
echo "=== [1/2] Comprobando integridad SHA256 del respaldo ==="
sha256sum -c "/backups/db_ultimo_respaldo.sql.sha256"

echo "=== [2/2] Reconstruyendo Base de Datos nodosur_db tras la falla ==="
mariadb -u root -pRootSuperSeguro2026! -e "CREATE DATABASE IF NOT EXISTS nodosur_db;"
mariadb -u root -pRootSuperSeguro2026! nodosur_db < "/backups/db_ultimo_respaldo.sql"
echo "¡Base de datos recuperada y operativa!"