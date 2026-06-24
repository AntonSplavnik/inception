# NGINX


## nginx.conf — NGINX Configuration


### events block (lines 1–3)

  events {
      worker_connections 1024;
  }
  Sets the maximum number of simultaneous connections a single NGINX worker process can handle. 1024 is a sensible
  default — each visitor uses at least one connection, so one worker can serve up to 1024 clients at once. For a
  small Inception project this is more than enough.


### http block (lines 5–34)

  Lines 6–8 — Global HTTP settings:
  include /etc/nginx/mime.types;
  sendfile on;
  keepalive_timeout 65;
  - include mime.types — loads a mapping of file extensions to MIME types (e.g., .css → text/css, .jpg →
  image/jpeg). Without this, NGINX would serve everything as text/plain and browsers wouldn't render CSS/JS/images
  correctly.
  - sendfile on — uses the kernel's sendfile() syscall to serve static files directly from disk to the network
  socket, bypassing user-space copying. More efficient for static content.
  - keepalive_timeout 65 — keeps idle connections open for 65 seconds before closing them. Avoids the overhead of
  re-establishing TCP+TLS handshakes for clients making multiple requests.


### server block (lines 10–33) — The virtual host

  Lines 11–12 — Listening:
  listen 443 ssl;
  server_name asplavni.42.fr;
  - Listens only on port 443 (HTTPS). There is no port 80 listener — the Inception subject requires TLS only, no
  plain HTTP.
  - server_name matches requests for asplavni.42.fr (your 42 login + .42.fr).

  Lines 14–18 — TLS/SSL configuration:
  ssl_certificate /etc/ssl/certs/nginx.crt;
  ssl_certificate_key /etc/ssl/private/nginx.key;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;
  - ssl_certificate / ssl_certificate_key — paths to the self-signed cert and private key (generated in the
  Dockerfile).
  - ssl_protocols TLSv1.2 TLSv1.3 — only allows TLS 1.2 and 1.3. Older protocols (SSLv3, TLS 1.0, 1.1) are
  disabled because they have known vulnerabilities. The subject specifically requires TLSv1.2 or TLSv1.3.
  - ssl_ciphers HIGH:!aNULL:!MD5 — use only strong ciphers. !aNULL excludes ciphers with no authentication
  (vulnerable to MITM). !MD5 excludes the broken MD5 hash.
  - ssl_prefer_server_ciphers on — the server chooses the cipher, not the client. Prevents a client from
  downgrading to a weak cipher.

  Lines 20–21 — Document root:
  root /var/www/wordpress;
  index index.php index.html;
  - root points to the WordPress files. NGINX and WordPress share this directory via a Docker volume.
  - index tells NGINX which file to serve when a directory is requested. It tries index.php first (WordPress),
  then falls back to index.html.

  Lines 23–25 — Static file handling:
  location / {
      try_files $uri $uri/ /index.php?$args;
  }
  For every request:
  1. Try to serve it as an exact file ($uri) — e.g., /style.css
  2. Try to serve it as a directory ($uri/) — e.g., /wp-admin/
  3. If neither exists, forward to index.php with the original query string (?$args)

  This is WordPress's pretty permalinks mechanism. A URL like /2024/06/my-post/ doesn't map to an actual file —
  step 3 catches it and sends it to WordPress's index.php, which parses the URL and returns the right page.

  Lines 27–32 — PHP processing:
  location ~ \.php$ {
      fastcgi_pass wordpress:9000;
      fastcgi_index index.php;
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
  }
  - location ~ \.php$ — regex match: any request ending in .php.
  - fastcgi_pass wordpress:9000 — forwards PHP requests to the WordPress container on port 9000 (where PHP-FPM is
  listening, as configured in www.conf). wordpress resolves via Docker's internal DNS.
  - include fastcgi_params — loads standard FastCGI parameters (HTTP headers, request method, etc.).
  - SCRIPT_FILENAME — tells PHP-FPM the full file path of the PHP script to execute. This is built from
  $document_root (/var/www/wordpress) + $fastcgi_script_name (e.g., /index.php), resulting in
  /var/www/wordpress/index.php.


## Dockerfile — Build Steps

  FROM debian:bullseye

  RUN apt-get update && apt-get install -y nginx openssl

  RUN openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/ssl/private/nginx.key \
        -out /etc/ssl/certs/nginx.crt \
        -subj "/CN=asplavni.42.fr"

  COPY conf/nginx.conf /etc/nginx/nginx.conf

  CMD ["nginx", "-g", "daemon off;"]

  1. Install nginx and openssl
  2. Generate a self-signed SSL certificate:
    - -x509 — produce a self-signed certificate (not a certificate signing request)
    - -nodes — "no DES" — don't encrypt the private key with a passphrase (NGINX needs to read it without human
    input)
    - -days 365 — valid for one year
    - -newkey rsa:2048 — generate a new 2048-bit RSA key pair
    - -keyout / -out — where to save the private key and certificate
    - -subj "/CN=asplavni.42.fr" — sets the Common Name to your domain, skipping the interactive prompts
  3. Copy the nginx.conf into the image
  4. CMD — daemon off; keeps NGINX in the foreground (same reason as MariaDB and PHP-FPM: PID 1 for Docker signal
  handling)


## Request Flow

  Browser → https://asplavni.42.fr:443 → NGINX terminates TLS → if .php, forward via FastCGI to
  wordpress:9000 (PHP-FPM) → PHP-FPM processes the script → response flows back through NGINX → encrypted →
  browser.
