#!/bin/bash
# ==============================================================================
# SCRIPT DE RESTAURACIÓN SEGURA ANTE DESASTRES (VERIFICACIÓN SHA-256 OBLIGATORIA)
# Ejecuta en: VM 110 (10.33.199.110)
# ==============================================================================

set -e

BACKUP_DIR="/var/backups/tas13"
DB_HOST="10.33.199.108"
DB_NAME="nodosur_db"
DB_USER="root"
DB_PASS="RootSuperSeguro2026!"
NFS_DATA_DIR="/srv/nfs/wordpress"

MANIFEST="${BACKUP_DIR}/ultimo_respaldo.sha256"
DB_FILE="${BACKUP_DIR}/db/ultimo_respaldo.sql.gz"
FILES_FILE="${BACKUP_DIR}/files/ultimo_respaldo.tar.gz"

echo "========================================================================"
echo " [TAS-G13] INICIANDO RESTAURACIÓN ANTE DESASTRES"
echo "========================================================================"

if [ ! -f "${MANIFEST}" ]; then
    echo "[ERROR CRÍTICO] No se encontró el manifiesto criptográfico ${MANIFEST}."
    exit 1
fi

echo "--> [1/3] Verificando integridad criptográfica SHA-256 de los respaldos..."
if ! sha256sum -c "${MANIFEST}"; then
    echo "[ALERTA DE SEGURIDAD] ¡El hash SHA-256 no coincide! Los archivos de respaldo están dañados o fueron manipulados."
    echo "Operación de restauración cancelada inmediatamente por seguridad."
    exit 1
fi
echo "    [OK] Integridad SHA-256 verificada. Procediendo a restaurar."

echo "--> [2/3] Restaurando Base de Datos en MariaDB (${DB_HOST})..."
mariadb -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" -e "DROP DATABASE IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
gunzip -c "${DB_FILE}" | mariadb -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}"
echo "    [OK] Base de datos ${DB_NAME} restaurada exitosamente."

echo "--> [3/3] Restaurando archivos de WordPress en almacenamiento NFS (${NFS_DATA_DIR})..."
tar -xzf "${FILES_FILE}" -C "${NFS_DATA_DIR}"
chown -R www-data:www-data "${NFS_DATA_DIR}"
echo "    [OK] Archivos de WordPress restaurados con permisos correctos."

echo "========================================================================"
echo " [ÉXITO TOTAL] Plataforma Web NodoSur restaurada y lista para operar."
echo "========================================================================"
