*This project has been created as part of the 42 curriculum by asplavni.*

## Description

Inception is a system administration project that sets up a small infrastructure using Docker. The project deploys a WordPress website with a MariaDB database behind an NGINX reverse proxy, all running in separate containers orchestrated by Docker Compose.

The infrastructure runs inside a virtual machine and consists of:
- **NGINX** container serving as the sole entry point via HTTPS (port 443) with TLSv1.2/TLSv1.3
- **WordPress + PHP-FPM** container handling PHP processing
- **MariaDB** container managing the database

All containers are built from custom Dockerfiles based on Debian Bullseye. No pre-made images from DockerHub are used.

### Design Choices

**Virtual Machines vs Docker**
Virtual machines emulate entire operating systems with their own kernel, consuming significant resources. Docker containers share the host kernel and isolate only the application layer, making them lightweight and fast to start. Docker is ideal for microservice architectures where each service runs in its own isolated environment.

**Secrets vs Environment Variables**
Environment variables are visible through `docker inspect` and can leak into logs. Docker secrets are mounted as files at `/run/secrets/` inside containers, accessible only by processes that read the file. This project uses secrets for passwords and environment variables for non-sensitive configuration.

**Docker Network vs Host Network**
Host networking shares the host's network stack, removing isolation between containers. Docker bridge networks create an isolated network where containers communicate using service names as hostnames. This project uses a bridge network called `inception` for security and portability.

**Docker Volumes vs Bind Mounts**
Bind mounts map a host directory directly into a container, creating tight coupling to the host filesystem. Named volumes are managed by Docker, making them portable and trackable with `docker volume ls`. This project uses named volumes with driver options to store data at `/home/asplavni/data/`.

## Instructions

### Prerequisites
- A virtual machine with Docker and Docker Compose installed
- Make

### Setup
1. Clone the repository
2. Create the secrets files in `secrets/`:
   - `db_password.txt` - MariaDB user password
   - `db_root_password.txt` - MariaDB root password
   - `wp_admin_password.txt` - WordPress admin password
   - `wp_user_password.txt` - WordPress user password
3. Configure `srcs/.env` with your domain and usernames
4. Add your domain to `/etc/hosts`: `127.0.0.1 asplavni.42.fr`
5. Run `make build` then `make up`

### Available Commands
| Command | Description |
|---------|-------------|
| `make build` | Build all Docker images |
| `make up` | Start all containers |
| `make down` | Stop and remove containers |
| `make stop` | Stop containers (keep them) |
| `make start` | Resume stopped containers |
| `make clean` | Remove containers, network, and images |
| `make fclean` | Remove everything including volumes and data |
| `make re` | Full rebuild from scratch |

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose documentation](https://docs.docker.com/compose/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress CLI documentation](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- AI tools (Claude) were used to assist with Dockerfile configuration, setup script debugging, and NGINX/PHP-FPM configuration. All generated content was reviewed and tested.
