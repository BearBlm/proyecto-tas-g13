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

# Configuramos MariaDB en Ubuntu 24.04 para escuchar en la red LAN y soportar 1000 conexiones
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf && \
    echo "[mysqld]\nmax_connections=1000\ninnodb_buffer_pool_size=512M\nskip-name-resolve" > /etc/mysql/mariadb.conf.d/99-tas-tuning.cnf

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /backups/backup.sh
COPY restore.sh /backups/restore.sh
RUN sed -i 's/\r$//' /entrypoint.sh /backups/backup.sh /backups/restore.sh && \
    chmod +x /entrypoint.sh /backups/backup.sh /backups/restore.sh

ENTRYPOINT ["/entrypoint.sh"]