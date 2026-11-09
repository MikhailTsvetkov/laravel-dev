#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ $# != 1 || ! $1 =~ ^[1-9][0-9]*$ ]]; then
    printf 'Expected a Laravel major version.\n' >&2; exit 1
fi
if [[ -e composer.json || -e artisan || -e laravel-dev ]]; then
    printf 'Project or laravel-dev already exists; refusing to overwrite it.\n' >&2; exit 1
fi
export XDEBUG_MODE=off
# Leave staging in place on failure so the user can inspect/recover it.
composer create-project --prefer-dist --no-scripts "laravel/laravel:^$1.0" laravel-dev
if [[ ! -f laravel-dev/.env ]]; then
    (umask 077; cp laravel-dev/.env.example laravel-dev/.env)
fi
bash _dev/env_updater
php _dev/finish_install.php
composer require predis/predis
composer install
php artisan key:generate
npm install
printf 'Laravel installed. Run ./x artisan migrate, then ./x run dev.\n'
