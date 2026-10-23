#!/bin/bash
# ==============================================================================
# SCRIPT DE RESPALDO AUTOMATIZADO Y SEGURO (PULL SEGURO + INTEGRIDAD CRIPTOGRÁFICA)
# Ejecuta en: VM 109 (10.33.199.109)
# ==============================================================================

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/tas13"
DB_HOST="10.33.199.108"
DB_NAME="nodosur_db"
DB_USER="backup_agent"
DB_PASS="BackupSeguroTAS13!"
NFS_DATA_DIR="/srv/nfs/wordpress"

DB_OUT="${BACKUP_DIR}/db/nodosur_db_${TIMESTAMP}.sql.gz"
FILES_OUT="${BACKUP_DIR}/files/wordpress_files_${TIMESTAMP}.tar.gz"
MANIFEST="${BACKUP_DIR}/manifest_${TIMESTAMP}.sha256"

echo "========================================================================"
echo " [TAS-G13] INICIANDO PROCESO DE RESPALDO SEGURO - ${TIMESTAMP}"
echo "========================================================================"

mkdir -p "${BACKUP_DIR}/db" "${BACKUP_DIR}/files"

# ------------------------------------------------------------------------------
# 1. Extracción de Base de Datos (Pull Seguro desde VM 108 hacia VM 110)
# ------------------------------------------------------------------------------
echo "--> [1/4] Extrayendo dump de MariaDB (${DB_HOST})..."
mariadb-dump \
    -h "${DB_HOST}" \
    -u "${DB_USER}" \
    -p"${DB_PASS}" \
    --single-transaction \
    --quick \
    --routines \
    --triggers \
    "${DB_NAME}" | gzip -c > "${DB_OUT}"

echo "    Dump de base de datos generado: ${DB_OUT}"

# ------------------------------------------------------------------------------
# 2. Respaldo de Archivos Multimedia y Código WordPress
# ------------------------------------------------------------------------------
echo "--> [2/4] Empaquetando árbol de archivos compartidos de WordPress..."
tar -czf "${FILES_OUT}" -C "${NFS_DATA_DIR}" .
echo "    Paquete comprimido generado: ${FILES_OUT}"

# ------------------------------------------------------------------------------
# 3. Generación de Firma Criptográfica SHA-256 (Garantía contra Manipulaciones)
# ------------------------------------------------------------------------------
echo "--> [3/4] Generando firmas hash SHA-256 de integridad..."
sha256sum "${DB_OUT}" > "${MANIFEST}"
sha256sum "${FILES_OUT}" >> "${MANIFEST}"

# Copia de apuntador a último respaldo
cp "${DB_OUT}" "${BACKUP_DIR}/db/ultimo_respaldo.sql.gz"
cp "${FILES_OUT}" "${BACKUP_DIR}/files/ultimo_respaldo.tar.gz"
cp "${MANIFEST}" "${BACKUP_DIR}/ultimo_respaldo.sha256"

# ------------------------------------------------------------------------------
# 4. Verificación Inmediata y Política de Retención (7 días)
# ------------------------------------------------------------------------------
echo "--> [4/4] Validando integridad del respaldo recién creado..."
sha256sum -c "${MANIFEST}"

echo "--> Aplicando política de rotación (purgando respaldos mayores a 7 días)..."
find "${BACKUP_DIR}/db" -type f -name "nodosur_db_*.sql.gz" -mtime +7 -delete
find "${BACKUP_DIR}/files" -type f -name "wordpress_files_*.tar.gz" -mtime +7 -delete
find "${BACKUP_DIR}" -type f -name "manifest_*.sha256" -mtime +7 -delete

echo "========================================================================"
echo " [OK] Respaldo finalizado con éxito a las $(date)"
echo " Destino: ${BACKUP_DIR}"
echo "========================================================================"
