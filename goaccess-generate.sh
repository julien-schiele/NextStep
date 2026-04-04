#!/bin/sh
set -e

echo "Generating frontend report..."
goaccess /var/log/caddy/nextstep-frontend.log \
    -p /etc/goaccess/goaccess.conf \
    --output=/srv/stats/frontend.html

echo "Generating backend report..."
goaccess /var/log/caddy/nextstep-backend.log \
    -p /etc/goaccess/goaccess.conf \
    --output=/srv/stats/backend.html

echo "Done."