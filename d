#!/bin/bash

CMD_XDEBUG_OFF="XDEBUG_MODE=off"

case $1 in
    up)
        build=""
        if [ "$2" == "-b" ]; then
            build="--build"
        fi

        docker compose up -d $build

        if [ "$2" == "-b" ]; then
            if [ -f ./composer.json ]; then
                docker compose exec -u www-data app bash -c "$CMD_XDEBUG_OFF && composer install"
            fi
            if [ -f ./package.json ]; then
                docker compose exec -u root app bash -c "mkdir -p /var/www/.npm && chown -R 1000:33 /var/www/.npm"
                docker compose exec -u www-data app bash -c "npm install"
            fi
        fi
        ;;

    down)
        docker compose down $2
        ;;

    install)
        package_name=$(echo "$2" | cut -d':' -f1)
        package_version_number=$(echo "$2" | cut -d':' -f2)

        if [[ -z "$package_name" || -z "$package_version_number" ]]; then
            echo "Invalid format. Expected 'package_name:version'."
            exit 1
        fi

        if [ "$package_name" == "laravel" ]; then
            docker compose exec -u www-data app bash -c "$CMD_XDEBUG_OFF && \
                chmod +x ./_dev/env_updater && \
                composer create-project --prefer-dist laravel/laravel:^$package_version_number.0 laravel-dev && \
                ./_dev/env_updater && \
                shopt -s dotglob && \
                mv ./laravel-dev/* . && \
                rm -rf ./laravel-dev && \
                git add ."

            docker compose up -d --build --no-cache
            docker compose exec -u www-data app bash -c "$CMD_XDEBUG_OFF && composer install"
            docker compose exec -u root app bash -c "mkdir -p /var/www/.npm && chown -R 1000:33 /var/www/.npm"
            docker compose exec -u www-data app bash -c "npm install"
        fi
        ;;

    run)
        if [ "$2" == "build" ]; then
            docker compose exec -u www-data app npm run build
        fi
        if [ "$2" == "dev" ]; then
            docker compose exec -u www-data app bash -c "
                $CMD_XDEBUG_OFF && \
                composer run dev
            "
        fi
        ;;

    artisan | composer | npm)
        case $1 in
            artisan) app="php artisan" ;;
            *) app=$1 ;;
        esac

        shift

        docker compose exec -u www-data app bash -c "
            $CMD_XDEBUG_OFF && \
            $app $*
        "
        ;;
esac
