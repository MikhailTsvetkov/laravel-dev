#!/usr/bin/env bash
set -euo pipefail
if ! cd /var/www/html || [[ ! -w . ]]; then
    printf 'Project directory is not writable by UID %s:GID %s. Rebuild with ./x up on the host.\n' "$(id -u)" "$(id -g)" >&2
    exit 1
fi
sudo /usr/local/bin/dev-permissions
exec "$@"
