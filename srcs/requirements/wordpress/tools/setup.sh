#!/bin/bash

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

while ! mysql -h mariadb -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; do
    sleep 2
done

if [ ! -f /var/www/wordpress/wp-config.php ]; then
    wp config create \
	--dbname=${MYSQL_DATABASE} \
	--dbuser=${MYSQL_USER} \
	--dbpass=${MYSQL_PASSWORD} \
	--dbhost=mariadb \
	--path=/var/www/wordpress \
	--allow-root

    wp core install \
	--url=${DOMAIN_NAME} \
	--title="Inception" \
	--admin_user=${WP_ADMIN_USER} \
	--admin_password=${WP_ADMIN_PASSWORD} \
	--admin_email=${WP_ADMIN_EMAIL} \
	--path=/var/www/wordpress \
	--allow-root

    wp user create ${WP_USER} ${WP_USER_EMAIL} \
	--role=author \
	--user_pass=${WP_USER_PASSWORD} \
	--path=/var/www/wordpress \
	--allow-root
fi

exec php-fpm7.4 -F
