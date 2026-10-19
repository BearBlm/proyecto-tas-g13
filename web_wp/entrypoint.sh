#!/bin/bash
rm -f /var/www/html/index.html

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "=== Inicializando archivos de WordPress en volumen compartido NFS ==="
    cp -rn /usr/src/wordpress/* /var/www/html/
    
    cat << 'EOF' > /var/www/html/wp-config.php
<?php
define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') );
define( 'DB_USER', getenv('WORDPRESS_DB_USER') );
define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') );
define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );
define( 'WP_MEMORY_LIMIT', '256M' );

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
if (isset($_SERVER['HTTP_HOST'])) {
    define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']);
}

$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF
    chown -R www-data:www-data /var/www/html
fi

echo "=== Iniciando Apache2 en Ubuntu Server 24.04 ($(hostname)) ==="
exec apachectl -D FOREGROUND