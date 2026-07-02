#!/usr/bin/env bash

# Seeds a fresh WordPress site with demo content using WP-CLI.
# Run this after WordPress is installed and the setup wizard is complete.

set -euo pipefail

WP_PATH="${WP_PATH:-/var/www/html}"
SITE_URL="${SITE_URL:-http://example.com}"
SITE_TITLE="${SITE_TITLE:-Cloud WordPress Demo}"
ADMIN_USER="${ADMIN_USER:-demo_admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-CHANGE_ME_USE_A_SECRET_MANAGER}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

cd "$WP_PATH"

if ! command -v wp >/dev/null 2>&1; then
  echo "Installing WP-CLI..."
  curl -fsSLo /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /tmp/wp-cli.phar
  sudo mv /tmp/wp-cli.phar /usr/local/bin/wp
fi

echo "Ensuring WordPress core is installed..."
if ! sudo -u www-data wp core is-installed --path="$WP_PATH"; then
  sudo -u www-data wp core install \
    --path="$WP_PATH" \
    --url="$SITE_URL" \
    --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL"
fi

echo "Creating sample pages..."
HOME_ID=$(sudo -u www-data wp post create --path="$WP_PATH" --post_type=page --post_title="Home" --post_status=publish --porcelain)
ABOUT_ID=$(sudo -u www-data wp post create --path="$WP_PATH" --post_type=page --post_title="About" --post_status=publish --porcelain)
SERVICES_ID=$(sudo -u www-data wp post create --path="$WP_PATH" --post_type=page --post_title="Services" --post_status=publish --porcelain)
CONTACT_ID=$(sudo -u www-data wp post create --path="$WP_PATH" --post_type=page --post_title="Contact" --post_status=publish --porcelain)

sudo -u www-data wp post update "$HOME_ID" --path="$WP_PATH" --post_content="Welcome to a Terraform-powered WordPress demo running on AWS."
sudo -u www-data wp post update "$ABOUT_ID" --path="$WP_PATH" --post_content="This site demonstrates repeatable cloud infrastructure for WordPress."
sudo -u www-data wp post update "$SERVICES_ID" --path="$WP_PATH" --post_content="Demo services include cloud hosting, backups, monitoring, and infrastructure automation."
sudo -u www-data wp post update "$CONTACT_ID" --path="$WP_PATH" --post_content="Use this page as placeholder contact content for portfolio demos."

echo "Creating sample posts..."
sudo -u www-data wp post create --path="$WP_PATH" --post_type=post --post_title="Launching WordPress on AWS" --post_status=publish --post_content="This sample post explains the demo architecture."
sudo -u www-data wp post create --path="$WP_PATH" --post_type=post --post_title="Why Terraform for WordPress" --post_status=publish --post_content="Terraform keeps infrastructure repeatable, reviewable, and easy to destroy after demos."
sudo -u www-data wp post create --path="$WP_PATH" --post_type=post --post_title="Cost Control for Demos" --post_status=publish --post_content="The dev-lite environment keeps costs low by running WordPress and MariaDB on one EC2 instance."

echo "Creating navigation menu..."
MENU_NAME="Primary Navigation"
if ! sudo -u www-data wp menu list --path="$WP_PATH" --field=name | grep -Fxq "$MENU_NAME"; then
  sudo -u www-data wp menu create "$MENU_NAME" --path="$WP_PATH"
fi

sudo -u www-data wp menu item add-post "$MENU_NAME" "$HOME_ID" --path="$WP_PATH"
sudo -u www-data wp menu item add-post "$MENU_NAME" "$ABOUT_ID" --path="$WP_PATH"
sudo -u www-data wp menu item add-post "$MENU_NAME" "$SERVICES_ID" --path="$WP_PATH"
sudo -u www-data wp menu item add-post "$MENU_NAME" "$CONTACT_ID" --path="$WP_PATH"

echo "Setting homepage and basic options..."
sudo -u www-data wp option update show_on_front page --path="$WP_PATH"
sudo -u www-data wp option update page_on_front "$HOME_ID" --path="$WP_PATH"
sudo -u www-data wp option update blogname "$SITE_TITLE" --path="$WP_PATH"
sudo -u www-data wp option update blogdescription "AWS WordPress Terraform demo" --path="$WP_PATH"

echo "WordPress demo content is ready."

