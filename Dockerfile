FROM php:8.0-fpm-alpine3.16
RUN set -ex; \
    \
    export CFLAGS="-Os"; \
    export CPPFLAGS="${CFLAGS}"; \
    export LDFLAGS="-Wl,--strip-all"; \
    \
    # Runtime dependencies
    apk add --no-cache \
        c-client \
        icu \
        libintl \
        libpng \
        libzip \
        msmtp \
        nginx \
        openldap \
        runit \
    ; \
    \
    # Build dependencies
    apk add --no-cache --virtual .build-deps \
        ${PHPIZE_DEPS} \
        gettext-dev \
        icu-dev \
        imap-dev \
        libpng-dev \
        libzip-dev \
        openldap-dev \
    ; \
    \
    # Install PHP extensions
    docker-php-ext-configure imap --with-imap-ssl; \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        gettext \
        imap \
        intl \
        ldap \
        mysqli \
        sockets \
        zip \
    ; \
    pecl install apcu; \
    docker-php-ext-enable \
        apcu \
        opcache \
    ; \
    \
    # Create msmtp log
    touch /var/log/msmtp.log; \
    chown www-data:www-data /var/log/msmtp.log; \
    \
    # Create data dir
    mkdir /var/lib/osticket; \
    \
    # Clean up
    apk del .build-deps; \
    rm -rf /tmp/pear /var/cache/apk/*
# DO NOT FORGET TO CHECK THE LANGUAGE PACK DOWNLOAD URL BELOW
# DO NOT FORGET TO UPDATE "image-version" FILE
ENV OSTICKET_VERSION=1.17 \
    OSTICKET_SHA256SUM=296d55cc50782411f0ba81101bc64fc4f6ac65a37772fd75bb5f4dc04d8b364d
RUN set -ex; \
    \
    wget -q -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/\
v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip; \
    echo "${OSTICKET_SHA256SUM}  osTicket.zip" | sha256sum -c; \
    unzip osTicket.zip 'upload/*'; \
    rm osTicket.zip; \
    mkdir /usr/local/src; \
    mv upload /usr/local/src/osticket; \
    # Hard link the sources to the public directory
    cp -al /usr/local/src/osticket/. /var/www/html; \
    # Hide setup
    rm -r /var/www/html/setup; \
    \
    for lang in ar_EG ar_SA az bg bn bs ca cs da de el es_AR es_ES es_MX et eu fa fi fr gl he hi \
        hr hu id is it ja ka km ko lt lv mk mn ms nl no pl pt_BR pt_PT ro ru sk sl sq sr sr_CS \
        sv_SE sw th tr uk ur_IN ur_PK vi zh_CN zh_TW; do \
        # This URL is the same as what is used by the official osTicket Downloads page. This URL is
        # used even for minor versions >= 14.
        wget -q -O /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/1.14.x/${lang}.phar; \
    done
ENV OSTICKET_PLUGINS_VERSION=cc4bf22f17cc0bebd1e1958786a271f02d7f2645 \
    OSTICKET_PLUGINS_SHA256SUM=c34f9bee929eb256d62aee57b458d89e6a8dc258948a5850f9f314aa44fd20d8
RUN set -ex; \
    \
    wget -q -O osTicket-plugins.tar.gz https://github.com/devinsolutions/osTicket-plugins/archive/\
${OSTICKET_PLUGINS_VERSION}.tar.gz; \
    echo "${OSTICKET_PLUGINS_SHA256SUM}  osTicket-plugins.tar.gz" | sha256sum -c; \
    tar -xzf osTicket-plugins.tar.gz --one-top-level --strip-components 1; \
    rm osTicket-plugins.tar.gz; \
    \
    cd osTicket-plugins; \
    php make.php hydrate; \
    find * -maxdepth 0 -type d ! -path doc ! -path lib -exec mv '{}' \
        /var/www/html/include/plugins +; \
    cd ..; \
    \
    rm -r osTicket-plugins /root/.composer
ENV OSTICKET_SLACK_VERSION=de1d9a276a64520eea6e6368e609a0f4c4829d96 \
    OSTICKET_SLACK_SHA256SUM=8d06500fd5b8a589a5f7103c242160086ca1696a5b93d0e3767119a54059532b
RUN set -ex; \
    \
    wget -q -O osTicket-slack-plugin.tar.gz https://github.com/devinsolutions/\
osTicket-slack-plugin/archive/${OSTICKET_SLACK_VERSION}.tar.gz; \
    echo "${OSTICKET_SLACK_SHA256SUM}  osTicket-slack-plugin.tar.gz" | sha256sum -c; \
    tar -xzf osTicket-slack-plugin.tar.gz -C /var/www/html/include/plugins --strip-components 1 \
        osTicket-slack-plugin-${OSTICKET_SLACK_VERSION}/slack; \
    rm osTicket-slack-plugin.tar.gz
COPY root /
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 80
HEALTHCHECK CMD curl -fIsS http://localhost/ || exit 1
