all: up

build:
	docker-compose -f srcs/docker-compose.yml build

up:
	mkdir -p /home/asplavni/data/wordpress /home/asplavni/data/mysql
	docker-compose -f srcs/docker-compose.yml up --build -d

down:
	docker-compose -f srcs/docker-compose.yml down

stop:
	docker-compose -f srcs/docker-compose.yml stop

start:
	docker-compose -f srcs/docker-compose.yml start

clean:
	docker-compose -f srcs/docker-compose.yml down --rmi all

fclean:
	docker-compose -f srcs/docker-compose.yml down --rmi all --volumes
	rm -rf /home/asplavni/data/wordpress/* /home/asplavni/data/mysql/*

re: fclean build up

.PHONY: all build up down stop start clean fclean re
