FROM hashicorp/terraform:latest as certs
COPY trusted_ca.tf .

ARG AWS_ENDPOINT_URL_S3
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_ENDPOINT_URL_S3=$AWS_ENDPOINT_URL_S3
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

RUN set -x \
  \
  && terraform init \
  && terraform apply -auto-approve \
  && cat outputs/* > ca-cert.pem

FROM alpine:latest as build
ARG COMMIT

RUN set -x \
  \
  && apk add --no-cache \
    g++ \
    xz-dev \
    make \
    perl \
    bash \
    cdrkit \
    git \
    openssl \
    coreutils \
  \
  && git clone -b master https://github.com/ipxe/ipxe /ipxe \
  && cd /ipxe \
  && git reset --hard $COMMIT

WORKDIR /ipxe/src
COPY config/ config/local/
COPY --from=certs ca-cert.pem .

RUN set -x \
  \
  && make \
    bin-$(arch)-efi/ipxe.efi \
    CERT=ca-cert.pem \
    TRUST=ca-cert.pem \
    DEBUG=x509,certstore \
  \
  && mkdir -p /build \
  && mv bin-$(arch)-efi/*.efi /build/

## PXE boot build

FROM alpine:latest as tftp

WORKDIR /var/tftpboot
COPY --from=build --chown=nobody:nogroup /build/ .

RUN set -x \
  \
  && apk add --no-cache \
    tftp-hpa

ENTRYPOINT [ "in.tftpd", "--foreground", "--user", "nobody", "--secure", "/var/tftpboot" ]

## HTTP boot build

FROM busybox:stable-musl as http

WORKDIR /var/www
COPY --from=build --chown=www-data:www-data /build/ .
USER www-data

ENTRYPOINT [ "httpd", "-f", "-v" ]