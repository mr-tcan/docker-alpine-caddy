FROM golang:1.9-alpine as builder

RUN apk add --no-cache git

ARG SERVER_REPO="github.com/mholt/caddy"
ARG BUILDS_REPO="github.com/caddyserver/builds"
ARG VERSION="0.10.10"

# Get Caddy source code and dependencies
RUN go get -u ${SERVER_REPO} \
    && go get -u ${BUILDS_REPO}

# List of desired plugins
# Empty or repos separated with spaces: "user/repo anotheruser/anotherrepo"
ARG PLUGINS

RUN set -ex \
    && if [[ ! -z "${PLUGINS}" ]]; then \
       { \
            echo 'package caddymain'; \
            echo 'import ('; \
          } > $GOPATH/src/${SERVER_REPO}/caddy/caddymain/plugins.go \
      && for i in ${PLUGINS}; \
          do echo "_ \"github.com/${i}\"" >> $GOPATH/src/${SERVER_REPO}/caddy/caddymain/plugins.go; done \
      && echo ")" >> $GOPATH/src/${SERVER_REPO}/caddy/caddymain/plugins.go \
      && for i in ${PLUGINS}; \
          do go get -u github.com/${i}; \
          done \
      fi

WORKDIR $GOPATH/src/${SERVER_REPO}/caddy/

RUN set -ex \
    && if [[ "${VERSION}" != "git" ]]; then \
        git checkout tags/"v${VERSION}"; \
      fi

# Build the source
RUN go run build.go -goos=linux -goarch=amd64 \
    && mv caddy /usr/local/bin

FROM tscangussu/tini:0.16.1-1.alpine

LABEL maintainer="Thiago Cangussu <thiago.cangussu@gmail.com>" \
      description="Caddy Server based on Alpine Linux." \
      version="v0.10.10"


ARG CADDYBIN="/usr/local/bin/caddy"

COPY --from=builder ${CADDYBIN} ${CADDYBIN}

# Give Caddy permission to bind to port 80 and 443 without being root
RUN apk add --no-cache libcap && setcap cap_net_bind_service=+ep ${CADDYBIN}

ARG ROOT="/srv/www/html"

COPY html ${ROOT}

# Ensure www-data user exists and set proper permissions
RUN set -x \
	&& addgroup -g 82 -S www-data \
  && adduser -u 82 -D -S -G www-data www-data \
  && chown -R www-data:www-data ${ROOT} \
  && chmod -R 755 ${ROOT}

# Path to store SSL certificates. It needs a volume to persist.
ENV CADDYPATH /etc/caddY

VOLUME ${CADDYPATH}

WORKDIR ${ROOT}

# Expose ports 80 & 443 for production, 2015 for development (Caddy's default).
EXPOSE 80 443 2015

# Run Caddy as non-root user.
USER www-data

CMD ["caddy", "-http2"]
