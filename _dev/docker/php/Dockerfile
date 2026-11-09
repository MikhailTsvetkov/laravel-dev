ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-bookworm

ARG XDEBUG_VERSION

# Install system dependencies
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install \
    apt-utils \
    sudo \
    nano \
    build-essential \
    git \
    curl \
    libcurl4 \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libzip-dev \
    zip \
    libbz2-dev \
    locales \
    libmcrypt-dev \
    libicu-dev \
    libonig-dev \
    libxml2-dev \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libgtk-3-0 \
    libpango-1.0-0 \
    libcairo2 \
    fonts-liberation \
    jq \
    supervisor

# Install PHP extensions
RUN docker-php-ext-configure intl \
    && docker-php-ext-install exif \
        pcntl \
        bcmath \
        ctype \
        curl \
        intl \
        xml \
        zip

# Install Postgre PDO
RUN \
    apt-get install -y libpq-dev && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install pdo pdo_pgsql pgsql

# Install NPM
RUN \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Install XDebug
RUN curl -fsSL https://github.com/xdebug/xdebug/archive/refs/tags/$XDEBUG_VERSION.tar.gz -o xdebug.tar.gz \
    && mkdir -p /tmp/xdebug \
    && tar -xf xdebug.tar.gz -C /tmp/xdebug --strip-components=1 \
    && rm xdebug.tar.gz \
    && docker-php-ext-configure /tmp/xdebug --enable-xdebug \
    && docker-php-ext-install /tmp/xdebug \
    && rm -r /tmp/xdebug
RUN \
    echo "xdebug.start_with_request = \${XDEBUG_START_WITH_REQUEST}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini && \
    echo "xdebug.discover_client_host = \${XDEBUG_DISCOVER_CLIENT_HOST}" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install the image pipeline runtime without replacing the distribution security policy.
RUN apt-get update && apt-get install -y --no-install-recommends imagemagick libmagickwand-dev \
    && pecl install imagick-3.8.1 \
    && docker-php-ext-enable imagick
COPY _dev/docker/php/imagemagick-policy.xml /tmp/imagemagick-policy.xml
# Preserve the distribution file's syntax: ImageMagick 6 does not use a standard XML parser.
# Resource limits use the first definition, so replace them while retaining all other rules.
RUN grep -q '</policymap>' /etc/ImageMagick-6/policy.xml \
    && sed -i -E '/<policy domain="resource" name="(memory|map|disk|area|width|height|list-length|thread|time)"/d' /etc/ImageMagick-6/policy.xml \
    && sed -n '/<policy /p' /tmp/imagemagick-policy.xml > /tmp/imagemagick-rules.xml \
    && sed -i '/<\/policymap>/e cat /tmp/imagemagick-rules.xml' /etc/ImageMagick-6/policy.xml \
    && rm /tmp/imagemagick-policy.xml /tmp/imagemagick-rules.xml

# Cleanup
RUN \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /build /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer:2.8.4 /usr/bin/composer /usr/bin/composer

ARG LOCAL_UID=1000
ARG LOCAL_GID=1000
RUN test "$LOCAL_UID" -gt 0 && test "$LOCAL_GID" -gt 0 && \
    groupmod -o -g "$LOCAL_GID" www-data && \
    usermod -o -u "$LOCAL_UID" -g www-data www-data

# Writable tool caches belong to the same user as the bind-mounted project.
ENV HOME=/var/www \
    COMPOSER_HOME=/var/www/.composer \
    npm_config_cache=/var/www/.npm \
    DEV_CONTAINER=1
RUN mkdir -p /var/www/.composer /var/www/.npm && \
    chown -R www-data:www-data /var/www/.composer /var/www/.npm

# Used only to repair Laravel runtime files left behind by older root workers.
RUN echo 'www-data ALL=(root) NOPASSWD: /usr/local/bin/dev-permissions' > /etc/sudoers.d/www-data && \
    chmod 0440 /etc/sudoers.d/www-data
COPY _dev/docker/php/permissions.sh /usr/local/bin/dev-permissions
RUN chmod 0755 /usr/local/bin/dev-permissions
COPY _dev/docker/php/entrypoint.sh /usr/local/bin/dev-entrypoint
COPY _dev/docker/php/worker.sh /usr/local/bin/dev-worker
COPY _dev/docker/php/supervisord.conf /etc/supervisor/supervisord.conf
COPY _dev/docker/php/zz-request-timeout.conf /usr/local/etc/php-fpm.d/zz-request-timeout.conf

WORKDIR /var/www/html
USER www-data
ENTRYPOINT ["bash", "/usr/local/bin/dev-entrypoint"]
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
