# Developer Documentation

## Setting Up the Environment

### Prerequisites
- Virtual machine running Debian/Ubuntu
- Docker and Docker Compose installed
- Make installed
- Git installed

### Initial Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd Inception
```

2. Create the secrets directory and files:
```bash
mkdir -p secrets
echo "your_db_password" > secrets/db_password.txt
echo "your_db_root_password" > secrets/db_root_password.txt
echo "your_wp_admin_password" > secrets/wp_admin_password.txt
echo "your_wp_user_password" > secrets/wp_user_password.txt
```

3. Configure `srcs/.env` with your settings:
```
DOMAIN_NAME=login.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=login
WP_ADMIN_USER=boss
WP_ADMIN_EMAIL=boss@login.42.fr
WP_USER=login
WP_USER_EMAIL=login@student.42.fr
```

4. Create data directories on the host:
```bash
sudo mkdir -p /home/login/data/wordpress /home/login/data/mysql
```

5. Add the domain to `/etc/hosts`:
```bash
sudo sh -c 'echo "127.0.0.1 login.42.fr" >> /etc/hosts'
```

## Building and Launching

Build all images:
```bash
make build
```

Start all services:
```bash
make up
```

Build and start in one step:
```bash
make build && make up
```

Full rebuild from scratch:
```bash
make re
```

## Project Structure

```
Inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── docker-compose.yml
    ├── .env
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/setup.sh
        └── mariadb/
            ├── Dockerfile
            ├── conf/50-server.cnf
            └── tools/setup.sh
```

## Managing Containers and Volumes

List running containers:
```bash
docker ps
```

List all containers including stopped:
```bash
docker ps -a
```

Access a container shell:
```bash
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash
```

Access the MariaDB console:
```bash
docker exec -it mariadb mysql -u root -p
```

List volumes:
```bash
docker volume ls
```

Inspect a volume:
```bash
docker volume inspect srcs_db_data
```

## Data Persistence

Data is stored in two named volumes mapped to host directories:

| Volume | Container Path | Host Path |
|--------|---------------|-----------|
| wp_data | /var/www/wordpress | /home/login/data/wordpress |
| db_data | /var/lib/mysql | /home/login/data/mysql |

Data persists across container restarts and rebuilds. Only `make fclean` removes the stored data.

The MariaDB setup script checks if `/var/lib/mysql/mysql` exists to determine if initialization is needed. The WordPress setup script checks for `wp-config.php`. On subsequent starts, both skip their setup phase and go directly to running the service.
