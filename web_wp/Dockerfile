FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalamos Apache, PHP 8.3 con OPcache, cliente MySQL y herramientas de diagnóstico en Ubuntu 24.04
RUN apt-get update && apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-zip \
    php-opcache \
    mariadb-client \
    curl \
    wget \
    unzip \
    iproute2 \
    iputils-ping \
    dnsutils \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Descargamos WordPress en español listo para copiar al volumen compartido NFS
RUN wget -q https://es.wordpress.org/latest-es_ES.tar.gz -O /tmp/wordpress.tar.gz \
    && tar -xzf /tmp/wordpress.tar.gz -C /usr/src/ \
    && rm /tmp/wordpress.tar.gz \
    && a2enmod rewrite headers

# Activamos OPcache y afinamiento de PHP 8.3 para soportar 1000+ sesiones concurrentes
RUN printf "opcache.enable=1\nopcache.memory_consumption=256\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=20000\nopcache.revalidate_freq=2\nopcache.fast_shutdown=1\nopcache.enable_cli=1\noutput_buffering=262144\nmemory_limit=256M\nmax_execution_time=60\n" > /etc/php/8.3/apache2/conf.d/99-opcache-tas.ini

# Configuramos Apache MPM Prefork y KeepAlive para soportar 1000+ sesiones concurrentes
RUN printf "<IfModule mpm_prefork_module>\n    ServerLimit           1200\n    StartServers          25\n    MinSpareServers       25\n    MaxSpareServers       100\n    MaxRequestWorkers     1200\n    MaxConnectionsPerChild 10000\n</IfModule>\n" > /etc/apache2/mods-available/mpm_prefork.conf \
    && printf "KeepAlive On\nMaxKeepAliveRequests 1000\nKeepAliveTimeout 5\nTimeout 60\n" > /etc/apache2/conf-available/tas-tuning.conf \
    && a2enconf tas-tuning

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]