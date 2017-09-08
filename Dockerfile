FROM tscangussu/alpine-tini:latest

LABEL LABEL maintainer="Thiago Cangussu <thiago.cangussu@gmail.com>" \
      description="Caddy Server based on Alpine Linux." \
      version="v0.10.7"

ENV CADDYPATH /etc/caddy
ENV ROOT /srv/www/html

RUN apk add --no-cache --virtual .deps \
    curl \
    bash \
    && curl https://getcaddy.com | bash -s http.cache,http.expires,http.minify \
    && apk del .deps

COPY html ${ROOT}

VOLUME ${CADDYPATH}

WORKDIR ${ROOT}

EXPOSE 80 443 2015

CMD ["caddy", "-http2"]
