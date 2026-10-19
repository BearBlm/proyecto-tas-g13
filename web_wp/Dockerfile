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

# Activamos OPcache en PHP 8.3 para soportar alto tráfico en pruebas de estrés
RUN echo "opcache.enable=1\nopcache.memory_consumption=128\nopcache.max_accelerated_files=10000\nopcache.revalidate_freq=2" > /etc/php/8.3/apache2/conf.d/99-opcache-tas.ini

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]