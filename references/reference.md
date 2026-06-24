# Bind mounts and Named volume

The subject forbids bind mounts for the two required volumes.
  So you can't do this:

 ## Forbidden by the subject
  services:
    mariadb:
      volumes:
        - /home/asplavni/data/mysql:/var/lib/mysql

  But you still need the data at /home/asplavni/data/. The
  driver_opts trick solves this -- it creates a named volume
  (which Docker manages and tracks) but tells it to store data at
  your specific host path:

  volumes:
    db_data:
      driver: local          # use the local filesystem
      driver_opts:
        type: none           # no special filesystem type
        o: bind              # mount mechanism
        device: /home/asplavni/data/mysql   # actual host path

  The difference:

  Bind mount:
    - /host/path:/container/path
    - Docker doesn't know about it
    - Not in `docker volume ls`

  Named volume with driver_opts:
    - Docker manages it, gives it a name
    - Shows in `docker volume ls`
    - But still stores data at your chosen path

  Both end up storing files in the same place on disk. The
  difference is that the named volume goes through Docker's
  volume system, satisfying the project requirement while still
  controlling the host path.


# docker commands

	docker ps -a

	docker build -t mariadb .
	docker run --rm mariadb

	docker rm <container_id>


# docker container communication

	- docker exec — runs a command inside an
  already-running container
  - -it — -i keeps stdin open (interactive), -t
  allocates a pseudo-TTY (so you get a proper terminal)
  - 6019bffaca22 — the container ID (or prefix of it)
  - mysql — the command to run inside that container —
  the MySQL/MariaDB command-line client

	docker exec -it <container_id> nginx
	docker exec -it <container_id> mysql
	docker exec -it <container_id> bash (or sh if bash isn't installed in the container)


# mariadb commands

	CREATE DATABASE wordpress;
	SHOW DATABASES;


# mariadb setup script

 - mysqld --bootstrap -- runs MariaDB in a special mode that executes SQL
  commands without needing a full server running, then exits
  - exec mysqld --user=mysql -- after setup is done, starts MariaDB for real
  as PID 1
  - No leading spaces -- shebang must start at column 1
  - IDENTIFIED BY on same line as the password variable

# mariadb port

The 3306 port is MariaDB's default -- it listens on it automatically without any
  configuration.

  The connection chain is configured in different places:

  NGINX → WordPress:9000       configured in nginx.conf (fastcgi_pass
  wordpress:9000)
  WordPress → MariaDB:3306     configured in wp-config.php (--dbhost=mariadb)

  When your WordPress setup script runs wp config create --dbhost=mariadb,
  WordPress knows to connect to the mariadb hostname. Docker resolves that name to
  the MariaDB container's IP, and MariaDB is already listening on 3306 by
  default.

  You don't need to specify port 3306 anywhere because:
  - MariaDB listens on 3306 by default
  - WordPress connects to 3306 by default
  - They're on the same Docker network, so no port mapping needed

  The only port you explicitly map in docker-compose.yml is 443:443 for NGINX,
  because that's the only one exposed to the outside world.



# MariaDB
50-server.cnf

  [mysqld]
  bind-address = 0.0.0.0

  This is a MariaDB server configuration file. It has a single setting:

  - bind-address = 0.0.0.0 — tells MariaDB to listen on all network interfaces, not just localhost. By default
  MariaDB only listens on 127.0.0.1 (localhost), which means only processes on the same machine can connect. Since
  MariaDB runs inside a Docker container and WordPress needs to reach it from a different container over the
  Docker network, you must bind to 0.0.0.0.

  The file is named 50-server.cnf because MariaDB loads config files from /etc/mysql/mariadb.conf.d/ in
  alphabetical order — the 50- prefix controls the load order.

  ---
  setup.sh

  This script initializes the MariaDB database on first run and then starts the server. Step by step:

  Lines 3–4 — Read secrets:
  MYSQL_PASSWORD=$(cat /run/secrets/db_password)
  MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
  Reads database passwords from Docker secrets (files mounted at /run/secrets/). This avoids hardcoding passwords
  in environment variables or images.

  Line 6 — First-run check:
  if [ ! -d "/var/lib/mysql/mysql" ]; then
  Checks if the mysql system database exists. If it doesn't, this is a fresh container that needs initialization.
  On subsequent restarts, this block is skipped entirely — the data persists via a Docker volume.

  Line 7 — Initialize database files:
  mysql_install_db --user=mysql --datadir=/var/lib/mysql
  Creates the initial MariaDB system tables (the mysql, performance_schema databases, etc.).

  Lines 9–12 — Start server temporarily:
  mysqld --user=mysql &
  while ! mysqladmin ping --silent; do
      sleep 1
  done
  Starts MariaDB in the background, then polls with mysqladmin ping until the server is ready to accept
  connections.

  Lines 15–21 — Create database and user:
  CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
  GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
  FLUSH PRIVILEGES;
  - Creates the WordPress database (MYSQL_DATABASE comes from an environment variable in docker-compose)
  - Creates a non-root user that can connect from any host ('%') — necessary for cross-container access
  - Grants that user full permissions on the WordPress database only
  - Sets the root password (initially root has no password after mysql_install_db)
  - FLUSH PRIVILEGES reloads the grant tables so changes take effect immediately

  Line 23 — Graceful shutdown:
  mysqladmin -u root -p${MYSQL_ROOT_PASSWORD} shutdown
  Stops the temporary server cleanly so data is written to disk properly.

  Line 26 — Start for real:
  exec mysqld --user=mysql
  exec replaces the shell process with mysqld, so mysqld becomes PID 1 in the container. This is important because
  Docker sends signals (like SIGTERM for graceful stop) to PID 1 — if mysqld weren't PID 1, it wouldn't receive
  them and would be killed abruptly.

  ---
  In summary: 50-server.cnf makes MariaDB reachable from other containers, and setup.sh is a one-time
  initialization script that creates the database/user on first launch, then starts MariaDB as the container's
  main process.



 # WordPress
 www.conf — PHP-FPM Pool Configuration

  [www]
  user = www-data
  group = www-data

  listen = 0.0.0.0:9000

  clear_env = no

  pm = dynamic
  pm.max_children = 5
  pm.start_servers = 2
  pm.min_spare_servers = 1
  pm.max_spare_servers = 3

  This configures the PHP-FPM worker pool that processes PHP requests:

  - user/group = www-data — PHP worker processes run as the www-data user, matching the file ownership set in the
  Dockerfile. This is the standard unprivileged user for web servers.
  - listen = 0.0.0.0:9000 — PHP-FPM listens on TCP port 9000 on all interfaces. This is how NGINX (in another
  container) sends PHP requests to WordPress. NGINX doesn't run PHP itself — it forwards .php requests to this
  port via the FastCGI protocol.
  - clear_env = no — Critical setting. By default PHP-FPM clears all environment variables for security. Setting
  this to no preserves environment variables (like MYSQL_DATABASE, MYSQL_USER, DOMAIN_NAME, etc.) passed from
  docker-compose so they're available to the setup script and WordPress.
  - Process Manager (pm) settings — Controls how many PHP worker processes are running:
    - pm = dynamic — spawn workers on demand rather than a fixed number
    - pm.max_children = 5 — never more than 5 workers (caps memory usage)
    - pm.start_servers = 2 — start with 2 workers ready
    - pm.min_spare_servers = 1 — always keep at least 1 idle worker
    - pm.max_spare_servers = 3 — kill excess idle workers beyond 3

  ---
  setup.sh — WordPress Initialization Script

  Lines 3–5 — Read secrets:
  MYSQL_PASSWORD=$(cat /run/secrets/db_password)
  WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
  WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
  Reads three passwords from Docker secrets. Notice WordPress needs the same DB password as MariaDB, plus two
  WordPress-specific passwords for the admin and regular user.

  Lines 7–9 — Wait for MariaDB:
  while ! mysql -h mariadb -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; do
      sleep 2
  done
  Polls MariaDB every 2 seconds by trying to run a simple query. The hostname mariadb resolves via Docker's
  internal DNS (it's the service name in docker-compose). This solves the startup order problem — even with
  depends_on, MariaDB may not be ready when WordPress starts. This loop blocks until the database actually accepts
  connections.

  Lines 11–18 — Generate wp-config.php:
  wp config create \
      --dbname=${MYSQL_DATABASE} \
      --dbuser=${MYSQL_USER} \
      --dbpass=${MYSQL_PASSWORD} \
      --dbhost=mariadb \
      --path=/var/www/wordpress \
      --allow-root
  Uses WP-CLI to generate WordPress's main configuration file. Key points:
  - --dbhost=mariadb — connects to the MariaDB container by its Docker service name
  - --allow-root — WP-CLI normally refuses to run as root for safety; this flag overrides that since we're in a
  container where running as root during setup is acceptable

  Lines 20–27 — Install WordPress:
  wp core install \
      --url=${DOMAIN_NAME} \
      --title="Inception" \
      --admin_user=${WP_ADMIN_USER} \
      --admin_password=${WP_ADMIN_PASSWORD} \
      --admin_email=${WP_ADMIN_EMAIL} \
      --path=/var/www/wordpress \
      --allow-root
  Runs the WordPress installation (the equivalent of the web installer you'd normally see in a browser). Creates
  the database tables and the admin account. DOMAIN_NAME is typically something like yourlogin.42.fr as required
  by the Inception subject.

  Lines 29–33 — Create a regular user:
  wp user create ${WP_USER} ${WP_USER_EMAIL} \
      --role=author \
      --user_pass=${WP_USER_PASSWORD} \
      --path=/var/www/wordpress \
      --allow-root
  Creates a second WordPress user with the author role (can write/publish posts but can't change settings). The
  Inception subject requires at least two users: one admin and one regular user.

  Line 36 — Start PHP-FPM:
  exec php-fpm7.4 -F
  - -F means foreground — don't daemonize, keep the process in the foreground so Docker can track it
  - exec replaces the shell with php-fpm7.4 so it becomes PID 1 and receives Docker signals (same pattern as the
  MariaDB setup)

  ---
  Dockerfile — Build Steps

  The Dockerfile builds the image in this order:

  1. Base image: Debian Bullseye
  2. Install packages: PHP-FPM 7.4, the MySQL PHP extension (so WordPress can talk to MariaDB), curl (to download
  WP-CLI), and the MariaDB client (used by the mysql command in setup.sh to poll for readiness)
  3. Install WP-CLI: Downloads the wp command-line tool
  4. Download WordPress core files into /var/www/wordpress and set ownership to www-data
  5. Copy config files (www.conf and setup.sh) into the image
  6. CMD runs setup.sh at container startup

  ---
  The full flow: Container starts → setup.sh reads secrets → waits for MariaDB → generates wp-config.php →
  installs WordPress + creates users → hands off to PHP-FPM listening on port 9000 → NGINX forwards PHP requests
  to this port.

# NginX

nginx.conf — NGINX Configuration

  events block (lines 1–3)

  events {
      worker_connections 1024;
  }
  Sets the maximum number of simultaneous connections a single NGINX worker process can handle. 1024 is a sensible
  default — each visitor uses at least one connection, so one worker can serve up to 1024 clients at once. For a
  small Inception project this is more than enough.

  ---
  http block (lines 5–34)

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

  ---
  server block (lines 10–33) — The virtual host

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

  ---
  Dockerfile — Build Steps

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

  ---
  The request flow: Browser → https://asplavni.42.fr:443 → NGINX terminates TLS → if .php, forward via FastCGI to
  wordpress:9000 (PHP-FPM) → PHP-FPM processes the script → response flows back through NGINX → encrypted →
  browser.


# Docker-compose

Docker Compose File — What It Is

  A docker-compose.yml is a declarative configuration file that defines your entire multi-container application in
  one place. Instead of running multiple docker run commands with long flags, you describe everything in YAML and
  use a single docker-compose up to launch it all.

  What it defines

  ┌──────────┬─────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Section  │                                             Purpose                                             │
  ├──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ services │ Each container in your app (nginx, wordpress, mariadb). Defines what image to build, ports to   │
  │          │ expose, environment variables, volumes, dependencies, etc.                                      │
  ├──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ volumes  │ Named persistent storage. Data survives container restarts (e.g., your MariaDB database files,  │
  │          │ WordPress files).                                                                               │
  ├──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ networks │ Virtual networks that containers connect to. Containers on the same network can reach each      │
  │          │ other by service name (e.g., wordpress can connect to mariadb).                                 │
  ├──────────┼─────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ secrets  │ Files containing sensitive data (passwords) mounted at /run/secrets/ inside containers — avoids │
  │          │  putting passwords in environment variables or images.                                          │
  └──────────┴─────────────────────────────────────────────────────────────────────────────────────────────────┘

  Why it exists

  Without docker-compose, you'd have to:
  - Run each container manually with docker run
  - Manually create networks and connect containers to them
  - Manually create volumes and mount them
  - Remember the exact flags for each container every time

  Docker Compose replaces all of that with one file and one command.

  How it relates to your Inception project

  Your three services (NGINX, WordPress, MariaDB) each have their own Dockerfile that builds the image, but
  docker-compose is the orchestrator that ties them together — it says:

  - Build each service from its Dockerfile
  - Connect them on a shared network so wordpress can reach mariadb by hostname
  - Mount volumes so database data and WordPress files persist across restarts
  - Inject secrets (passwords) from files into each container
  - Set environment variables like MYSQL_DATABASE, DOMAIN_NAME, etc.
  - Control startup order with depends_on

  Minimal mental model

  docker-compose.yml
  ├── services:
  │   ├── nginx      → builds from nginx/Dockerfile, exposes port 443
  │   ├── wordpress  → builds from wordpress/Dockerfile, connects to mariadb
  │   └── mariadb    → builds from mariadb/Dockerfile, stores data in a volume
  ├── volumes:       → persistent storage for DB + WP files
  ├── networks:      → private network so containers can talk to each other
  └── secrets:       → password files mounted into containers

  One command — docker-compose up --build — reads this file, builds all images, creates networks/volumes/secrets,
  and starts everything in the right order.

  Want me to walk through your actual docker-compose.yml file line by line?


# Docker-compose comands

Essential Docker Compose Commands

  Starting & Stopping

  ┌───────────────────────────┬───────────────────────────────────────────────────────────────────────┐
  │          Command          │                             What it does                              │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose up         │ Creates and starts all containers                                     │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose up --build │ Rebuilds images before starting (use after changing a Dockerfile)     │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose up -d      │ Starts in detached mode (runs in background)                          │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose down       │ Stops and removes containers, networks                                │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose down -v    │ Same, but also deletes volumes (wipes all data — DB, WordPress files) │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose stop       │ Stops containers without removing them                                │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose start      │ Restarts previously stopped containers                                │
  ├───────────────────────────┼───────────────────────────────────────────────────────────────────────┤
  │ docker-compose restart    │ Stop + start                                                          │
  └───────────────────────────┴───────────────────────────────────────────────────────────────────────┘

  Monitoring

  ┌───────────────────────────────┬────────────────────────────────────────────────┐
  │            Command            │                  What it does                  │
  ├───────────────────────────────┼────────────────────────────────────────────────┤
  │ docker-compose ps             │ List running containers and their status/ports │
  ├───────────────────────────────┼────────────────────────────────────────────────┤
  │ docker-compose logs           │ Show logs from all containers                  │
  ├───────────────────────────────┼────────────────────────────────────────────────┤
  │ docker-compose logs wordpress │ Show logs from one specific service            │
  ├───────────────────────────────┼────────────────────────────────────────────────┤
  │ docker-compose logs -f        │ Follow logs in real time (like tail -f)        │
  ├───────────────────────────────┼────────────────────────────────────────────────┤
  │ docker-compose top            │ Show running processes inside each container   │
  └───────────────────────────────┴────────────────────────────────────────────────┘

  Debugging

  ┌──────────────────────────────────┬────────────────────────────────────────────────────────────────────────┐
  │             Command              │                              What it does                              │
  ├──────────────────────────────────┼────────────────────────────────────────────────────────────────────────┤
  │ docker-compose exec mariadb bash │ Open a shell inside a running container                                │
  ├──────────────────────────────────┼────────────────────────────────────────────────────────────────────────┤
  │ docker-compose exec mariadb      │ Run a specific command inside a container                              │
  │ mysql -u root -p                 │                                                                        │
  ├──────────────────────────────────┼────────────────────────────────────────────────────────────────────────┤
  │ docker-compose run wordpress     │ Spin up a new temporary container and open a shell (useful for         │
  │ bash                             │ debugging without touching the running one)                            │
  └──────────────────────────────────┴────────────────────────────────────────────────────────────────────────┘

  Building

  ┌─────────────────────────┬─────────────────────────────────────────────────────────────────────────────────┐
  │         Command         │                                  What it does                                   │
  ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ docker-compose build    │ Build/rebuild all images without starting                                       │
  ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ docker-compose build    │ Rebuild only the nginx image                                                    │
  │ nginx                   │                                                                                 │
  ├─────────────────────────┼─────────────────────────────────────────────────────────────────────────────────┤
  │ docker-compose config   │ Validate and display the final resolved docker-compose.yml (useful to check     │
  │                         │ variable substitution)                                                          │
  └─────────────────────────┴─────────────────────────────────────────────────────────────────────────────────┘

  Cleanup

  ┌─────────────────────────────────┬─────────────────────────────────────────────────────────────────────────┐
  │             Command             │                              What it does                               │
  ├─────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ docker-compose down --rmi all   │ Remove containers + networks + all built images                         │
  ├─────────────────────────────────┼─────────────────────────────────────────────────────────────────────────┤
  │ docker-compose down -v --rmi    │ Nuclear option — removes everything (containers, networks, volumes,     │
  │ all                             │ images)                                                                 │
  └─────────────────────────────────┴─────────────────────────────────────────────────────────────────────────┘

  The ones you'll use 90% of the time

  docker-compose up --build -d    # rebuild and start in background
  docker-compose logs -f          # watch what's happening
  docker-compose exec mariadb bash  # poke around inside a container
  docker-compose down             # tear it all down

  The key distinction: stop pauses containers (data preserved, can start again), down removes them entirely
  (recreated fresh on next up), down -v also wipes persistent data.


  
