FROM ghcr.io/pburgisser/misp-container-base:latest

# Entrypoints
COPY files/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY files/supervisor/misp-workers.conf /etc/supervisor/conf.d/misp-workers.conf
COPY files/entrypoint.sh /

ENTRYPOINT [ "/entrypoint.sh" ]

# Change Workdirectory
WORKDIR /var/www/MISP

EXPOSE 9001
