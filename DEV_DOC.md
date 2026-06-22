# Developer Documentation

## 42 Machine Setup

### VirtualBox Storage (sgoinfre)

42 machines have limited home directory space. Move VirtualBox VM storage to `sgoinfre` (persistent shared storage):

In VirtualBox: **Preferences → General → Default Machine Folder** → set to `~/sgoinfre/VirtualBox VMs`

Unlike `goinfre`, `sgoinfre` persists across sessions so no setup script is needed.

### Docker Symlink (if using Docker on the host)

```bash
rm -rf ~/.docker
mkdir -p ~/sgoinfre/.docker
ln -sfn ~/sgoinfre/.docker ~/.docker
```

### Moving Large Directories to sgoinfre

To free space on your home directory, move large directories to sgoinfre and symlink them:

```bash
mv ~/.config/some-big-app ~/sgoinfre/some-big-app
ln -sfn ~/sgoinfre/some-big-app ~/.config/some-big-app
```

Important: the symlink path must **not exist** before running `ln`. Use `-n` flag to prevent creating symlinks inside existing directories.

## Creating the Virtual Machine

1. Open VirtualBox → **New**
2. **Name:** `Inception`
3. **Machine Folder:** `~/sgoinfre/VirtualBox VMs`
4. **Type:** Linux | **Version:** Debian (64-bit)
5. **Memory:** 2048 MB
6. **Hard disk:** Create a virtual hard disk → VDI → Dynamically allocated → **30 GB**

### Installing Debian

1. Download the Debian **netinst** ISO: `debian-XX.X.X-amd64-netinst.iso`
2. Select your VM → **Settings → Storage** → click the empty disk icon → choose the ISO
3. **Start** the VM
4. Choose **Install** (text mode, not "Graphical install")
5. Follow the installer. At the **Software selection** screen, select only:
   - `[*] SSH server`
   - `[*] standard system utilities`
   - Uncheck everything else (desktop environments, etc.)
6. After install, remove the ISO from Settings → Storage

### SSH Access

1. In VirtualBox: **Settings → Network → Adapter 1 (NAT) → Advanced → Port Forwarding**
   - Protocol: TCP | Host Port: `4243` | Guest Port: `22`
   - (Port 4242 may be in use on 42 machines — use 4243 or another free port)
2. Connect from your host: `ssh asplavni@localhost -p 4243`

If you get a host key warning after reinstalling the VM:
```bash
ssh-keygen -f ~/.ssh/known_hosts -R "[localhost]:4243"
```

## VM Post-Install

### Install Essentials

Switch to root and install everything:
```bash
su -
apt install -y sudo vim git docker.io docker-compose make openssh-server
usermod -aG sudo asplavni
usermod -aG docker asplavni
exit
```

Log out and back in for group changes to take effect.

Verify:
```bash
sudo whoami
docker --version
docker-compose --version
```

## Setting Up the Project

### Clone the Repository

```bash
git clone <repository-url>
cd inception
```

### Create Secrets

```bash
mkdir -p secrets
echo -n "your_db_password" > secrets/db_password.txt
echo -n "your_db_root_password" > secrets/db_root_password.txt
echo -n "your_wp_admin_password" > secrets/wp_admin_password.txt
echo -n "your_wp_user_password" > secrets/wp_user_password.txt
```

### Create Environment File

```bash
cat > srcs/.env << 'EOF'
DOMAIN_NAME=asplavni.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=asplavni
WP_ADMIN_USER=boss
WP_ADMIN_EMAIL=boss@asplavni.42.fr
WP_USER=asplavni
WP_USER_EMAIL=asplavni@student.42.fr
EOF
```

### Create Data Directories

```bash
sudo mkdir -p /home/asplavni/data/wordpress /home/asplavni/data/mysql
sudo chown -R asplavni:asplavni /home/asplavni/data
```

### Update Volume Paths

In `srcs/docker-compose.yml`, make sure the volume devices point to `/home/asplavni/data/` (not `/tmp/inception/`):
```yaml
device: /home/asplavni/data/wordpress
device: /home/asplavni/data/mysql
```

### Add Domain to Hosts File

```bash
echo "127.0.0.1 asplavni.42.fr" | sudo tee -a /etc/hosts
```

## Building and Launching

Build and start:
```bash
make build && make up
```

Or just:
```bash
make
```

Full rebuild from scratch (deletes all data):
```bash
make re
```

If containers use cached/wrong images, force a clean build:
```bash
docker-compose -f srcs/docker-compose.yml build --no-cache
make up
```

### Verify Everything Works

Check all containers are running:
```bash
docker ps
```

All three (nginx, wordpress, mariadb) should show `Up` status. If mariadb is `Restarting`, check logs:
```bash
docker logs mariadb
```

Test the website:
```bash
curl -k https://asplavni.42.fr
```

You should get HTML back. Then open `https://asplavni.42.fr` in a browser.

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
