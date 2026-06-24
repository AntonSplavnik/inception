# Inception Evaluation Answers


## How can I make sure that NGINX is accessible only through port 443?

  Two layers ensure this:
  1. docker-compose.yml only maps port 443:443 — no port 80 is exposed to the host
  2. nginx.conf only has `listen 443 ssl;` — no port 80 listener exists

  Verify: `docker ps` should show only `0.0.0.0:443->443/tcp` for the nginx container.
  `curl http://asplavni.42.fr` should fail. `curl -k https://asplavni.42.fr` should work.


## How to ensure that the SSL/TLS certificate is used?

  Run: `curl -vk https://asplavni.42.fr 2>&1 | grep -E "SSL|TLS|certificate"`

  This shows the TLS version, cipher, and certificate info. You should see:
  - SSL connection using TLSv1.2 or TLSv1.3
  - subject: CN=asplavni.42.fr (the self-signed certificate)

  The certificate is configured in three places:
  1. Generated in the NGINX Dockerfile: `openssl req -x509 ... -subj "/CN=asplavni.42.fr"`
  2. Referenced in nginx.conf: `ssl_certificate` and `ssl_certificate_key`
  3. Enforced by: `ssl_protocols TLSv1.2 TLSv1.3;`


## What is a Docker network?

  A virtual network that lets containers talk to each other by service name.
  Containers on the same network can reach each other (e.g., wordpress can connect
  to mariadb), but containers on different networks are isolated from each other.

  Docker provides built-in DNS — each container's service name resolves to its IP
  automatically. That's why `fastcgi_pass wordpress:9000` and `--dbhost=mariadb`
  work without knowing any IP addresses.

  In this project, all three services share a network called "inception"
  (defined in docker-compose.yml). Only NGINX exposes a port (443) to the
  outside world — WordPress and MariaDB are only reachable from within the network.


## What is the -p flag in Docker?

  The -p flag maps a port from the host machine to a port inside the container.
  Format: -p <host_port>:<container_port>

  Example: -p 443:443 means traffic hitting port 443 on the host gets forwarded
  to port 443 inside the container.

  Without -p, the container's port is only accessible from within the Docker network
  (other containers can reach it, but the outside world cannot).

  In docker-compose.yml this is written as:
    ports:
      - "443:443"


## How can I demonstrate that TLSv1.2 or TLSv1.3 is being used?

  Show that TLSv1.2/1.3 works:
    curl -vk https://asplavni.42.fr 2>&1 | grep "SSL connection"
    Output: SSL connection using TLSv1.3 (or TLSv1.2)

  Show that older versions are rejected:
    curl -vk --tlsv1.0 --tls-max 1.0 https://asplavni.42.fr
    curl -vk --tlsv1.1 --tls-max 1.1 https://asplavni.42.fr
    Both should fail with a handshake error — NGINX refuses the connection.

  This proves the nginx.conf line `ssl_protocols TLSv1.2 TLSv1.3;` is working —
  only TLSv1.2 and TLSv1.3 are accepted, everything older is blocked.


## How to add a comment using an available WordPress user?

  1. Go to https://asplavni.42.fr
  2. Log in with the non-admin user (the author created in setup.sh)
     - Username: the value of WP_USER from .env
     - Password: the value in secrets/wp_user_password.txt
  3. Navigate to any post (e.g., "Hello world!")
  4. Scroll to the comment section at the bottom
  5. Write a comment and click Submit

  If no posts exist yet, log in as admin first, create a post, publish it,
  then log out and log in as the regular user to comment on it.


## How can I log in as admin or a regular user and edit comments?

  Login page: https://asplavni.42.fr/wp-admin

  Admin login:
    - Username: WP_ADMIN_USER from .env
    - Password: value in secrets/wp_admin_password.txt
    - Can do everything: edit/delete any comment, manage users, change settings
    - Edit comments: Dashboard → Comments → hover a comment → Edit/Trash

  Regular user login:
    - Username: WP_USER from .env
    - Password: value in secrets/wp_user_password.txt
    - Role is "author" — can write posts and comment, but cannot edit other
      users' comments or change site settings

  To log out: top-right corner → Howdy, [username] → Log Out


## How to log in to the database, verify it's not empty, and add something?

  Enter the MariaDB container:
    docker exec -it mariadb mysql -u <MYSQL_USER> -p
    (enter the password from secrets/db_password.txt)

  Note on localhost vs % users:
    MariaDB treats localhost and network connections as different hosts.
    The setup script creates the user with host '%' (any remote host), which is
    what WordPress uses to connect over the Docker network. However, when you
    docker exec into the container, you're connecting locally — MariaDB sees
    that as 'localhost', which does NOT match '%'.

    If you can't log in as your user from inside the container, you need to
    create a localhost entry. Log in as root first:
      docker exec -it mariadb mysql -u root -p

    Then create the localhost user:
      CREATE USER '<MYSQL_USER>'@'localhost' IDENTIFIED BY '<password>';
      GRANT ALL PRIVILEGES ON <MYSQL_DATABASE>.* TO '<MYSQL_USER>'@'localhost';
      FLUSH PRIVILEGES;

    The setup script already handles this — it creates both '%' and 'localhost'
    entries for the database user. Root works without this issue because
    mysql_install_db creates 'root@localhost' by default.

  Show databases and select the WordPress one:
    SHOW DATABASES;
    USE <MYSQL_DATABASE>;

  Verify it's not empty — show all tables:
    SHOW TABLES;
    (you should see wp_posts, wp_users, wp_comments, wp_options, etc.)

  Check existing data:
    SELECT * FROM wp_users;
    SELECT * FROM wp_posts;
    SELECT * FROM wp_comments;

  Add something on request — for example insert a comment:
    INSERT INTO wp_comments (comment_post_ID, comment_author, comment_content, comment_approved)
    VALUES (1, 'evaluator', 'This is a test comment', '1');

  Verify it was added:
    SELECT * FROM wp_comments WHERE comment_author = 'evaluator';


## What happens to the containers after a VM reboot?

  All services have `restart: unless-stopped` in docker-compose.yml, so Docker
  automatically restarts them after a reboot. No manual action needed.

  Just verify with: `docker ps`

  The only case they won't auto-restart is if you manually stopped them before
  the reboot (with `docker stop` or `docker-compose stop`). In that case,
  run `make up` to start them again.


## How to modify configuration, for example change a port?

  Port mapping format: "host_port:container_port"
  - Left port = the port on the host machine (what you access from outside)
  - Right port = the port inside the container (what the service listens on)

  Example — change the host port only (NGINX still listens on 443 inside):
    - docker-compose.yml: change `"443:443"` → `"8443:443"`
    - Now you access it via https://asplavni.42.fr:8443

  Example — change the actual service port (both sides must match):
    - nginx.conf: change `listen 443 ssl;` → `listen 8443 ssl;`
    - docker-compose.yml: change `"443:443"` → `"8443:8443"`

  After any change, rebuild and restart:
    make re

  You must rebuild because config files are COPYed into the image during build.
  Changing them on your host does nothing to the running container — you need
  to rebuild the image so the new config is baked in.

  Same applies to any config change:
  - MariaDB port → edit 50-server.cnf + docker-compose.yml
  - PHP-FPM port → edit www.conf + nginx.conf (fastcgi_pass)
  - SSL certificate → edit NGINX Dockerfile (openssl command)
