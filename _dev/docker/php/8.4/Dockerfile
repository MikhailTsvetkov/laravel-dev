FROM php:8.4-fpm

RUN usermod -u 1000 www-data

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
    jq \
    cron

# Install PHP extensions
RUN docker-php-ext-install exif \
    pcntl \
    bcmath \
    ctype \
    curl \
    zip

# Install Postgre PDO
RUN \
    apt-get install -y libpq-dev && \
    docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql && \
    docker-php-ext-install pdo pdo_pgsql pgsql

# Install NPM
RUN \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Install XDebug
RUN yes | pecl install xdebug
RUN \
    echo "zend_extension = $(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.start_with_request = \${XDEBUG_START_WITH_REQUEST}" >> /usr/local/etc/php/conf.d/xdebug.ini && \
    echo "xdebug.discover_client_host = \${XDEBUG_DISCOVER_CLIENT_HOST}" >> /usr/local/etc/php/conf.d/xdebug.ini

# Cleanup
RUN \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /build /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=composer:2.8.4 /usr/bin/composer /usr/bin/composer

# Create system user to run Composer and Artisan Commands
RUN \
    mkdir -p /home/www-data/.composer && \
    chown -R www-data:www-data /home/www-data/.composer && \
    mkdir -p /var/www/.composer/cache && \
    chown -R www-data:www-data /var/www/.composer

# Add sudo supporting for www-data user
RUN echo 'www-data ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/www-data

# Set working directory
WORKDIR /var/www/html

USER www-data
