# Docker Commands


## Containers

  docker ps                         List running containers
  docker ps -a                      List ALL containers (including stopped)
  docker stop <container>           Stop a running container
  docker start <container>          Start a stopped container
  docker restart <container>        Restart a container
  docker rm <container>             Remove a stopped container
  docker rm -f <container>          Force remove (even if running)
  docker kill <container>           Kill a container immediately (SIGKILL)
  docker logs <container>           Show container logs
  docker logs -f <container>        Follow logs in real time
  docker inspect <container>        Show detailed container info (JSON)
  docker exec -it <container> bash  Open a shell inside a running container
  docker run --rm <image>           Run a container and auto-remove when it exits
  docker run -d <image>             Run a container in detached (background) mode
  docker run -it <image> bash       Run a container interactively with a shell


## Images

  docker images                     List all local images
  docker build -t <name> .          Build an image from Dockerfile in current dir
  docker rmi <image>                Remove an image
  docker pull <image>               Download an image from Docker Hub
  docker tag <image> <new_name>     Tag an image with a new name
  docker history <image>            Show the layers/build history of an image


## Volumes

  docker volume ls                  List all volumes
  docker volume create <name>       Create a named volume
  docker volume rm <name>           Remove a volume
  docker volume inspect <name>      Show volume details (mount point, etc.)


## Networks

  docker network ls                 List all networks
  docker network create <name>      Create a network
  docker network rm <name>          Remove a network
  docker network inspect <name>     Show network details (connected containers, IPs)


## Cleanup

  docker system prune               Remove stopped containers, dangling images, unused networks, build cache
  docker system prune -a            Same + remove ALL unused images (not just dangling)
  docker system prune -a --volumes  Nuclear — remove everything unused (containers, images, networks, volumes)
  docker container prune            Remove stopped containers only
  docker image prune -a             Remove unused images only
  docker volume prune               Remove unused volumes only
  docker network prune              Remove unused networks only


## Info

  docker system df                  Show disk usage by Docker (images, containers, volumes)
  docker version                    Show Docker version
  docker info                       Show system-wide Docker info


# Docker Compose Commands


## Starting & Stopping

  docker-compose up                 Create and start all containers
  docker-compose up --build         Rebuild images before starting (use after changing a Dockerfile)
  docker-compose up -d              Start in detached mode (runs in background)
  docker-compose up --build -d      Rebuild + start in background (most common)
  docker-compose down               Stop and remove containers, networks
  docker-compose down -v            Same + delete volumes (wipes all data)
  docker-compose stop               Stop containers without removing them
  docker-compose start              Restart previously stopped containers
  docker-compose restart            Stop + start


## Monitoring

  docker-compose ps                 List running containers and their status/ports
  docker-compose logs               Show logs from all containers
  docker-compose logs <service>     Show logs from one specific service
  docker-compose logs -f            Follow logs in real time (like tail -f)
  docker-compose top                Show running processes inside each container


## Debugging

  docker-compose exec <service> bash      Open a shell inside a running container
  docker-compose exec mariadb mysql -u root -p    Run a command inside a container
  docker-compose run <service> bash       Spin up a new temporary container with a shell


## Building

  docker-compose build              Build/rebuild all images without starting
  docker-compose build <service>    Rebuild only one service's image
  docker-compose config             Validate and display the resolved docker-compose.yml


## Cleanup

  docker-compose down --rmi all           Remove containers + networks + all built images
  docker-compose down -v --rmi all        Nuclear — remove everything (containers, networks, volumes, images)


## Key Distinctions

  stop    — pauses containers (data preserved, can start again)
  down    — removes containers entirely (recreated fresh on next up)
  down -v — also wipes persistent data (volumes)
