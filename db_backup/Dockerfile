FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    mariadb-server \
    mariadb-client \
    iproute2 \
    iputils-ping \
    dnsutils \
    procps \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Configuramos MariaDB en Ubuntu 24.04 para escuchar en la red LAN y soportar 1000+ conexiones simultáneas
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf && \
    printf "[mysqld]\nmax_connections=1200\nmax_user_connections=1100\nopen_files_limit=65535\ntable_open_cache=4096\ninnodb_buffer_pool_size=512M\nskip-name-resolve\n" > /etc/mysql/mariadb.conf.d/99-tas-tuning.cnf

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /backups/backup.sh
COPY restore.sh /backups/restore.sh
RUN sed -i 's/\r$//' /entrypoint.sh /backups/backup.sh /backups/restore.sh && \
    chmod +x /entrypoint.sh /backups/backup.sh /backups/restore.sh

ENTRYPOINT ["/entrypoint.sh"]