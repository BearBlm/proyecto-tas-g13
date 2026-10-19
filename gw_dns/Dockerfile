FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalamos HAProxy, BIND9 y herramientas de diagnóstico de red de Ubuntu 24.04
RUN apt-get update && apt-get install -y \
    haproxy \
    bind9 \
    bind9utils \
    dnsutils \
    iproute2 \
    iputils-ping \
    curl \
    procps \
    nano \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]