#!/bin/bash
set -euo pipefail

WEB=/var/www/html
DIST=/opt/neofire/dist

log() { echo "[neofire] $*"; }

if [ ! -f "$WEB/index.php" ]; then
    log "first start: copying neofire Core into $WEB"
    cp -a "$DIST/." "$WEB/"
    chown -R www-data:www-data "$WEB"
elif [ "${NEOFIRE_AUTO_UPDATE:-1}" = "1" ] && [ -f "$WEB/.env" ] && ! cmp -s "$DIST/.neofire-build" "$WEB/.neofire-build" 2>/dev/null; then
    log "updating the core (vendor/neofire) to build $(cat "$DIST/.neofire-build")"
    rsync -a "$DIST/vendor/neofire/" "$WEB/vendor/neofire/"
    cp -a "$DIST/VERSION" "$DIST/.neofire-build" "$WEB/"
    chown -R www-data:www-data "$WEB/vendor/neofire" "$WEB/VERSION" "$WEB/.neofire-build"
fi

wait_for_database() {
    local tries=0
    until php -r '
        $h = getenv("DB_HOST") ?: "localhost"; $p = getenv("DB_PORT") ?: "3306";
        try { new PDO("mysql:host=$h;port=$p;dbname=" . getenv("DB_NAME"), getenv("DB_USER"), getenv("DB_PASS") ?: ""); exit(0); }
        catch (Throwable $e) { exit(1); }' 2>/dev/null; do
        tries=$((tries + 1))
        if [ "$tries" -ge 90 ]; then log "database not reachable after 3 minutes"; return 1; fi
        sleep 2
    done
}

if [ "${NEOFIRE_AUTO_INSTALL:-1}" = "1" ] && [ -n "${DB_NAME:-}" ] && [ -n "${ADMIN_PASS:-}" ]; then
    log "waiting for the database"
    wait_for_database
    log "setting up neofire Core (skipped automatically if already installed)"
    php "$WEB/vendor/neofire/core/setup/cli.php"
    chown -R www-data:www-data "$WEB"
fi

database() {
    MYSQL_PWD="${DB_PASS:-}" mariadb -h "${DB_HOST:-localhost}" -P "${DB_PORT:-3306}" -u "${DB_USER:-}" -N -B "${DB_NAME:-}" "$@" 2>/dev/null
}

cron_token() {
    local token
    token=$(database -e "SELECT value FROM plugin_config WHERE plugin_name = '_core' AND conf = 'cron_token' LIMIT 1") || return 1
    if [ -z "$token" ]; then
        token=$(php -r 'echo bin2hex(random_bytes(16));')
        database -e "INSERT IGNORE INTO plugin_config (plugin_name, conf, value) VALUES ('_core', 'cron_token', '$token')" || return 1
        token=$(database -e "SELECT value FROM plugin_config WHERE plugin_name = '_core' AND conf = 'cron_token' LIMIT 1") || return 1
    fi
    [ -n "$token" ] && echo "$token"
}

if [ "${NEOFIRE_CRON:-1}" = "1" ]; then
    (
        while true; do
            sleep 60
            token=$(cron_token) || continue
            host=$(php -r '$u = parse_url(getenv("SHOP_URL") ?: "http://localhost/"); echo $u["host"] ?? "localhost";')
            curl -fsS -o /dev/null -m 280 -H "Host: $host" -H "X-Forwarded-Proto: https" "http://127.0.0.1/admin/cron?token=$token" || true
        done
    ) &
fi

MAIL_INI=/usr/local/etc/php/conf.d/zz-neofire-mail.ini
if [ -n "${SMTP_HOST:-}" ]; then
    msmtp_quote() { local v=${1//\\/\\\\}; printf '"%s"' "${v//\"/\\\"}"; }
    smtp_port=${SMTP_PORT:-587}
    case "${SMTP_ENCRYPTION:-tls}" in
        ssl) smtp_tls=on; smtp_starttls=off ;;
        none|off) smtp_tls=off; smtp_starttls=off ;;
        *) smtp_tls=on; smtp_starttls=on ;;
    esac
    smtp_from=${SMTP_FROM:-${SHOP_EMAIL:-}}
    {
        echo "defaults"
        echo "tls $smtp_tls"
        echo "tls_starttls $smtp_starttls"
        echo "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
        echo "account default"
        echo "host $SMTP_HOST"
        echo "port $smtp_port"
        if [ -n "$smtp_from" ]; then echo "from $smtp_from"; fi
        if [ -n "${SMTP_USER:-}" ]; then
            echo "auth on"
            echo "user $SMTP_USER"
            echo "password $(msmtp_quote "${SMTP_PASSWORD:-}")"
        else
            echo "auth off"
        fi
    } > /etc/msmtprc
    chown www-data:www-data /etc/msmtprc
    chmod 600 /etc/msmtprc
    echo 'sendmail_path = "/usr/bin/msmtp -t"' > "$MAIL_INI"
    log "outgoing mail via $SMTP_HOST:$smtp_port"
else
    rm -f "$MAIL_INI"
fi

exec docker-php-entrypoint "$@"
