# MariaDB


## 50-server.cnf

  [mysqld]
  bind-address = 0.0.0.0

  This is a MariaDB server configuration file. It has a single setting:

  - bind-address = 0.0.0.0 — tells MariaDB to listen on all network interfaces, not just localhost. By default
  MariaDB only listens on 127.0.0.1 (localhost), which means only processes on the same machine can connect. Since
  MariaDB runs inside a Docker container and WordPress needs to reach it from a different container over the
  Docker network, you must bind to 0.0.0.0.

  The file is named 50-server.cnf because MariaDB loads config files from /etc/mysql/mariadb.conf.d/ in
  alphabetical order — the 50- prefix controls the load order.


## setup.sh

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


## Summary

  50-server.cnf makes MariaDB reachable from other containers, and setup.sh is a one-time
  initialization script that creates the database/user on first launch, then starts MariaDB as the container's
  main process.


## Port

  The 3306 port is MariaDB's default — it listens on it automatically without any configuration.

  The connection chain is configured in different places:

  NGINX → WordPress:9000       configured in nginx.conf (fastcgi_pass wordpress:9000)
  WordPress → MariaDB:3306     configured in wp-config.php (--dbhost=mariadb)

  When your WordPress setup script runs wp config create --dbhost=mariadb,
  WordPress knows to connect to the mariadb hostname. Docker resolves that name to
  the MariaDB container's IP, and MariaDB is already listening on 3306 by default.

  You don't need to specify port 3306 anywhere because:
  - MariaDB listens on 3306 by default
  - WordPress connects to 3306 by default
  - They're on the same Docker network, so no port mapping needed

  The only port you explicitly map in docker-compose.yml is 443:443 for NGINX,
  because that's the only one exposed to the outside world.


## MariaDB Commands

  CREATE DATABASE wordpress;
  SHOW DATABASES;
