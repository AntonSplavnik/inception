FROM debian:bullseye

RUN apt-get update && apt-get install -y nginx openssl

RUN openssl req -x509 -nodes -days 365 \
      -newkey rsa:2048 \
      -keyout /etc/ssl/private/nginx.key \
      -out /etc/ssl/certs/nginx.crt \
      -subj "/CN=asplavni.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]


