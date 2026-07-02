#!/usr/bin/env bash

# Installs WordPress on Ubuntu and connects it to an RDS MySQL database.
# This matches dev-rds: EC2 for WordPress, RDS for MySQL.

set -euo pipefail

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wordpress_user}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME_USE_A_SECRET_MANAGER}"
DB_HOST="${DB_HOST:-example-rds-endpoint.amazonaws.com}"
SITE_URL="${SITE_URL:-http://example.com}"

echo "Updating packages..."
sudo apt-get update -y

echo "Installing Apache, PHP, MySQL client, and helper packages..."
sudo apt-get install -y apache2 mysql-client unzip curl rsync \
  php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

echo "Starting Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

echo "Downloading WordPress..."
cd /tmp
curl -fsSLO https://wordpress.org/latest.zip
unzip -q latest.zip

echo "Installing WordPress files..."
sudo rsync -a /tmp/wordpress/ /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/ -type f -exec chmod 644 {} \;

echo "Writing wp-config.php for RDS..."
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sudo sed -i "s/localhost/${DB_HOST}/" /var/www/html/wp-config.php

sudo systemctl restart apache2

echo "WordPress dev-rds install is ready at ${SITE_URL}."

