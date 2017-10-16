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

FROM tscangussu/tini:0.16.1-alpine

LABEL LABEL maintainer="Thiago Cangussu <thiago.cangussu@gmail.com>" \
      description="Caddy Server based on Alpine Linux." \
      version="v0.10.10"

ENV CADDYPATH /etc/caddy
ENV ROOT /srv/www/html

COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy

COPY html ${ROOT}

VOLUME ${CADDYPATH}

WORKDIR ${ROOT}

EXPOSE 80 443 2015

CMD ["caddy", "-http2"]
