#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd -- "$ROOT_DIR"

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

[[ ${DEV_CONTAINER:-0} != 1 && $# == 0 ]] || fail 'Run ./x deploy on the server, without arguments.'
for executable in php composer npm git ssh-agent ssh-add ssh systemctl flock chown; do
    command -v "$executable" >/dev/null || fail "Required server command is missing: $executable"
done
[[ -f .env && -f vendor/autoload.php ]] || fail 'Deployment requires an existing .env and installed PHP dependencies.'

# Read dotenv as data, even when Laravel configuration is cached.
settings=$(php <<'PHP'
<?php
declare(strict_types=1);

require 'vendor/autoload.php';

$values = Dotenv\Dotenv::createArrayBacked(getcwd())->load();
foreach (['DEPLOY_SSH_KEY', 'DEPLOY_SERVICES'] as $name) {
    $value = getenv($name);
    $value = $value === false ? ($values[$name] ?? '') : $value;
    if ($value === '' || strpbrk($value, "\r\n\0") !== false) {
        fwrite(STDERR, "$name must contain a non-empty, single-line value.\n");
        exit(1);
    }
    echo $value, "\n";
}
PHP
)
mapfile -t settings <<< "$settings"
ssh_key=${settings[0]}
[[ $ssh_key == /* && -f $ssh_key && -r $ssh_key ]] || fail 'DEPLOY_SSH_KEY must be an absolute path to a readable SSH private key.'
read -r -a services <<< "${settings[1]}"
((${#services[@]})) || fail 'DEPLOY_SERVICES must list at least one systemd service.'
for service in "${services[@]}"; do
    [[ $service =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.@:-]*$ ]] || fail "Invalid systemd service name: $service"
done

privileged=()
if ((EUID != 0)); then
    command -v sudo >/dev/null || fail 'Deployment requires root or passwordless sudo for systemctl and chown.'
    privileged=(sudo -n)
fi

lock_path=$(git rev-parse --git-path x-deploy.lock)
exec 9>"$lock_path"
flock -n 9 || fail 'Another deployment is already running.'
[[ -z $(git status --porcelain) ]] || fail 'Commit or remove local changes before deploying.'
git rev-parse --verify '@{upstream}' >/dev/null
for service in "${services[@]}"; do
    "${privileged[@]}" systemctl cat -- "$service" >/dev/null
done
for directory in storage bootstrap/cache; do
    [[ -d $directory && ! -L $directory ]] || fail "Runtime directory must be an existing directory, not a symlink: $directory"
done
[[ ! -L bootstrap ]] || fail 'bootstrap must not be a symlink.'

trap 'printf "Deployment failed. Maintenance mode may still be active and services may be stopped. Fix the error and rerun ./x deploy.\n" >&2' EXIT
php artisan down --retry=60 --no-interaction
"${privileged[@]}" systemctl stop -- "${services[@]}"

# Clear bootstrap caches before replacing code; preserve application cache data.
for command in config:clear event:clear route:clear view:clear filament:clear-cached-components icons:clear; do
    php artisan "$command" --no-interaction
done
ssh-agent bash -euc 'ssh-add "$1"; GIT_SSH_COMMAND="ssh -o BatchMode=yes" git pull --ff-only' bash "$ssh_key"

COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader
npm ci --include=dev
npm run build
php artisan migrate --force --no-interaction

# Run each task directly: aggregate optimize commands can hide failed task exit codes.
for command in config:cache event:cache route:cache view:cache filament:cache-components icons:cache; do
    php artisan "$command" --no-interaction
done
"${privileged[@]}" chown -R --no-dereference www-data:www-data storage bootstrap/cache
"${privileged[@]}" systemctl restart -- "${services[@]}"
php artisan up --no-interaction
trap - EXIT
printf 'Deployment completed.\n'
