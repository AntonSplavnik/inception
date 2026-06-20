FROM debian:bullseye


RUN apt-get update && apt-get install -y mariadb-server \
    && mkdir -p /run/mysqld \
    && chown mysql:mysql /run/mysqld \
    && rm -rf /var/lib/mysql/*

COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/setup.sh /usr/local/bin/setup.sh

RUN chmod +x /usr/local/bin/setup.sh

CMD ["/usr/local/bin/setup.sh"]
