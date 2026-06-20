# User Documentation

## Services Overview

This stack provides a WordPress website accessible over HTTPS. It consists of three services:

| Service | Purpose |
|---------|---------|
| NGINX | Web server, handles HTTPS and serves static files |
| WordPress | Content management system with PHP-FPM |
| MariaDB | Database server storing WordPress data |

## Starting and Stopping

Start the project:
```bash
make build
make up
```

Stop the project (containers are removed):
```bash
make down
```

Pause the project (containers are preserved):
```bash
make stop
```

Resume paused containers:
```bash
make start
```

## Accessing the Website

Open your browser and navigate to:
```
https://asplavni.42.fr
```

The certificate is self-signed, so your browser will show a security warning. This is expected -- accept the warning to proceed.

## Accessing the Admin Panel

Navigate to:
```
https://asplavni.42.fr/wp-admin
```

Log in with the admin credentials configured during setup.

## Credentials

Credentials are stored in two locations:

- **Non-sensitive config** (usernames, domain): `srcs/.env`
- **Passwords**: `secrets/` directory
  - `db_password.txt` -- database user password
  - `db_root_password.txt` -- database root password
  - `wp_admin_password.txt` -- WordPress admin password
  - `wp_user_password.txt` -- WordPress regular user password

## Checking Service Status

View running containers:
```bash
docker ps
```

All three containers (nginx, wordpress, mariadb) should show `Up` status.

View logs for a specific service:
```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Follow logs in real time:
```bash
docker logs -f wordpress
```
