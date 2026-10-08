FROM php:8.3-apache-bookworm

ARG NEOFIRE_ZIP_URL=https://www.neofire.de/downloads/neofire-core-1.0.0.1.zip
ARG NEOFIRE_BUILD=local

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip rsync mariadb-client \
        libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev libwebp-dev \
        libicu-dev libc-client-dev libkrb5-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql zip gd intl imap exif opcache; \
    php -r 'foreach (["pdo_mysql","curl","zip","mbstring","openssl","json","gd","intl","imap"] as $e) { if (!extension_loaded($e)) { fwrite(STDERR, "missing $e\n"); exit(1); } }'; \
    rm -rf /var/lib/apt/lists/*; \
    a2enmod rewrite headers expires remoteip

RUN set -eux; \
    mkdir -p /opt/neofire/dist; \
    curl -fsSL "$NEOFIRE_ZIP_URL" -o /tmp/neofire.zip; \
    unzip -q /tmp/neofire.zip -d /opt/neofire/dist; \
    rm /tmp/neofire.zip; \
    test -f /opt/neofire/dist/vendor/neofire/core/setup/cli.php; \
    echo "$NEOFIRE_BUILD" > /opt/neofire/dist/.neofire-build

COPY docker/php.ini /usr/local/etc/php/conf.d/neofire.ini
COPY docker/apache-neofire.conf /etc/apache2/conf-enabled/neofire.conf
COPY docker/entrypoint.sh /usr/local/bin/neofire-entrypoint

RUN chmod +x /usr/local/bin/neofire-entrypoint

ENV TZ=Europe/Berlin \
    NEOFIRE_AUTO_INSTALL=1 \
    NEOFIRE_AUTO_UPDATE=1 \
    NEOFIRE_CRON=1

VOLUME ["/var/www/html"]
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=3m --retries=3 \
    CMD curl -fsS -o /dev/null http://localhost/robots.txt || exit 1

ENTRYPOINT ["neofire-entrypoint"]
CMD ["apache2-foreground"]
