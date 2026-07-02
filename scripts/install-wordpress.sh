#!/usr/bin/env bash

# This script installs WordPress on a fresh Ubuntu EC2 instance.
# It uses placeholder database values that should be replaced by Terraform user data
# or a secure runtime configuration method before real deployment.

set -euo pipefail

DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wordpress_user}"
DB_PASSWORD="${DB_PASSWORD:-CHANGE_ME_USE_A_SECRET_MANAGER}"
DB_HOST="${DB_HOST:-example-rds-endpoint.amazonaws.com}"
SITE_URL="${SITE_URL:-http://example.com}"

echo "Updating packages..."
sudo apt-get update -y

echo "Installing Apache, PHP, and MySQL client packages..."
sudo apt-get install -y apache2 mysql-client unzip curl \
  php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

echo "Enabling and starting Apache..."
sudo systemctl enable apache2
sudo systemctl start apache2

echo "Downloading WordPress..."
cd /tmp
curl -fsSLO https://wordpress.org/latest.zip
unzip -q latest.zip

echo "Copying WordPress files into the Apache web root..."
sudo rsync -a /tmp/wordpress/ /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
sudo find /var/www/html/ -type d -exec chmod 755 {} \;
sudo find /var/www/html/ -type f -exec chmod 644 {} \;

echo "Creating wp-config.php with placeholder database settings..."
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sudo sed -i "s/localhost/${DB_HOST}/" /var/www/html/wp-config.php

echo "Restarting Apache..."
sudo systemctl restart apache2

echo "WordPress files are installed."
echo "Open ${SITE_URL} in a browser to finish the WordPress setup wizard."

