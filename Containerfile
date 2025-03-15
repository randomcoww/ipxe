FROM hashicorp/terraform:latest as CA
COPY matchbox_ca.tf .

ARG AWS_ENDPOINT_URL_S3
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_ENDPOINT_URL_S3=$AWS_ENDPOINT_URL_S3
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

RUN set -x \
  \
  && terraform init \
  && terraform apply -auto-approve

FROM alpine:latest as BUILD
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
COPY --from=CA matchbox-ca.pem .

RUN set -x \
  \
  && make \
    bin-$(arch)-efi/ipxe.efi \
    CERT=matchbox-ca.pem \
    TRUST=matchbox-ca.pem \
    DEBUG=x509,certstore \
  \
  && mkdir -p /build \
  && mv bin-$(arch)-efi/*.efi /build/

FROM alpine:latest as TFTP

WORKDIR /var/tftpboot
COPY --from=BUILD --chown=nobody:nogroup /build/ .

RUN set -x \
  \
  && apk add --no-cache \
    tftp-hpa

ENTRYPOINT [ "in.tftpd", "--foreground", "--user", "nobody", "--secure", "/var/tftpboot" ]

FROM nginx:stable-alpine as HTTP
COPY --from=BUILD /build/ /usr/share/nginx/html/