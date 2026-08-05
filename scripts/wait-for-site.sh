#!/usr/bin/env bash

# Waits for the deployed WordPress site to respond after EC2 first boot.
# Useful when cloud-init is still installing packages after Terraform completes.

set -euo pipefail

URL="${1:-}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-80}"
SLEEP_SECONDS="${SLEEP_SECONDS:-15}"

if [ -z "$URL" ]; then
  echo "Usage: ./scripts/wait-for-site.sh http://ec2-public-dns.compute-1.amazonaws.com"
  exit 1
fi

URL="${URL%/}"

echo "Waiting for WordPress at $URL"
echo "Checking every $SLEEP_SECONDS seconds for up to $MAX_ATTEMPTS attempts."

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if curl -fsS --connect-timeout 5 --max-time 10 "$URL/index.php" >/dev/null 2>&1; then
    echo
    echo "WordPress is responding:"
    echo "  $URL/"
    echo "WordPress admin:"
    echo "  $URL/wp-admin/"
    echo "Static infrastructure demo:"
    echo "  $URL/demo/"
    exit 0
  fi

  printf 'Still waiting... attempt %s/%s\r' "$attempt" "$MAX_ATTEMPTS"
  sleep "$SLEEP_SECONDS"
done

echo
echo "Timed out waiting for WordPress."
echo "If SSH is available, inspect the EC2 bootstrap log:"
echo "  sudo tail -n 120 /var/log/wordpress-bootstrap.log"
exit 1

