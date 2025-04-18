#!/bin/bash

# Detect if running inside container
IN_CONTAINER=false
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IN_CONTAINER=true
fi

# Source the common command definitions
source ./_dev/docker/php/8.4/x_commands

case $1 in
    up)
        shift
        cmd_up "$IN_CONTAINER" "$@"
        ;;
    down)
        shift
        cmd_down "$IN_CONTAINER" "$@"
        ;;
    install)
        shift
        cmd_install "$IN_CONTAINER" "$@"
        ;;
    run)
        shift
        cmd_run "$IN_CONTAINER" "$@"
        ;;
    artisan | composer | npm)
        cmd_other_commands "$IN_CONTAINER" "$@"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Available commands: up, down, install, run, artisan, composer, npm"
        exit 1
        ;;
esac
