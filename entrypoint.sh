#!/bin/sh
set -e

# Ensure logs exist
mkdir -p /var/log/nginx
rm -f /var/log/nginx/access.log /var/log/nginx/error.log
touch /var/log/nginx/access.log /var/log/nginx/error.log
chown nginx:nginx /var/log/nginx /var/log/nginx/* 2>/dev/null || true

# Set PRIMARY and BACKUP based on ACTIVE_POOL
if [ "$ACTIVE_POOL" = "blue" ]; then
    PRIMARY="app_blue"
    BACKUP="app_green"
else
    PRIMARY="app_green"
    BACKUP="app_blue"
fi
export PRIMARY
export BACKUP

# Debug: Print variables
echo "Substituting PORT=$PORT, PRIMARY=$PRIMARY, BACKUP=$BACKUP"

# Substitute variables into a temporary config
envsubst '${PORT} ${PRIMARY} ${BACKUP}' < /etc/nginx/nginx.conf > /tmp/nginx.conf

# Validate Nginx config
nginx -t -c /tmp/nginx.conf
if [ $? -ne 0 ]; then
    echo "Nginx config validation failed"
    cat /tmp/nginx.conf
    exit 1
fi

# Ensure permissions
chown nginx:nginx /tmp/nginx.conf
chmod 644 /tmp/nginx.conf

# Debug: Show final config
echo "Final Nginx config:"
cat /tmp/nginx.conf

# Start Nginx with custom config
exec nginx -c /tmp/nginx.conf -g 'daemon off;'
