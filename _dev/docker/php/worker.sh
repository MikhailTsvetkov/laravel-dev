#!/usr/bin/env bash
set -euo pipefail
cd /var/www/html
# A fresh wrapper has no Laravel application yet; start workers once installed.
while [[ ! -f artisan || ! -f vendor/autoload.php || ! -f .env || -d laravel-dev ]]; do
    sleep 2
done
export XDEBUG_MODE=off
exec php artisan "$@"
