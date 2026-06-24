# WordPress


## www.conf — PHP-FPM Pool Configuration

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


## setup.sh — WordPress Initialization Script

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


## Dockerfile — Build Steps

  The Dockerfile builds the image in this order:

  1. Base image: Debian Bullseye
  2. Install packages: PHP-FPM 7.4, the MySQL PHP extension (so WordPress can talk to MariaDB), curl (to download
  WP-CLI), and the MariaDB client (used by the mysql command in setup.sh to poll for readiness)
  3. Install WP-CLI: Downloads the wp command-line tool
  4. Download WordPress core files into /var/www/wordpress and set ownership to www-data
  5. Copy config files (www.conf and setup.sh) into the image
  6. CMD runs setup.sh at container startup


## Full Flow

  Container starts → setup.sh reads secrets → waits for MariaDB → generates wp-config.php →
  installs WordPress + creates users → hands off to PHP-FPM listening on port 9000 → NGINX forwards PHP requests
  to this port.
