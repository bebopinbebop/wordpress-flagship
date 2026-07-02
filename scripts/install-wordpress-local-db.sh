#!/usr/bin/env bash

# Installs WordPress and MariaDB on the same Ubuntu server.
# This matches dev-lite: low cost, easy demos, and no RDS.

set -euo pipefail

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wordpress_user}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME_USE_A_SECRET_MANAGER}"
SITE_URL="${SITE_URL:-http://example.com}"

echo "Updating packages..."
sudo apt-get update -y

echo "Installing Apache, PHP, MariaDB, and helper packages..."
sudo apt-get install -y apache2 mariadb-server mysql-client unzip curl rsync \
  php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

echo "Starting Apache and MariaDB..."
sudo systemctl enable apache2 mariadb
sudo systemctl start apache2 mariadb

echo "Creating the local WordPress database and user..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "Downloading WordPress..."
cd /tmp
curl -fsSLO https://wordpress.org/latest.zip
unzip -q latest.zip

echo "Installing WordPress files..."
sudo rsync -a /tmp/wordpress/ /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/ -type f -exec chmod 644 {} \;

echo "Writing wp-config.php for the local database..."
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sudo sed -i "s/localhost/localhost/" /var/www/html/wp-config.php

sudo systemctl restart apache2

echo "WordPress dev-lite install is ready at ${SITE_URL}."

