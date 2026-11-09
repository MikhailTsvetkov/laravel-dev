#!/bin/bash
set -euo pipefail
# This root-owned helper accepts no paths or commands from the caller.
[[ $# == 0 ]] || exit 1
cd /var/www/html
for directory in storage bootstrap/cache; do
    [[ -e $directory ]] || continue
    # Never follow a linked runtime directory outside the project.
    if [[ -L $directory || ( $directory == bootstrap/cache && -L bootstrap ) ]]; then
        printf 'Runtime directory must not be a symlink: %s\n' "$directory" >&2
        exit 1
    fi
    # Repair only root-owned files created by the old queue/scheduler setup.
    find "$directory" -xdev -user root ! -type l -exec chown www-data:www-data {} +
    find "$directory" -xdev -user www-data ! -type l -exec chmod u+rwX {} +
done
for directory in storage bootstrap/cache; do
    [[ -d $directory ]] || continue
    if ! runuser -u www-data -- test -w "$directory"; then
        printf 'Runtime directory is not writable: %s\n' "$directory" >&2
        exit 1
    fi
done
