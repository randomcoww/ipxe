FROM hashicorp/terraform:latest as TF
COPY matchbox_ca.tf .
ARG AWS_ENDPOINT_URL_S3
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

RUN set -x \
  \
  && AWS_ENDPOINT_URL_S3=$AWS_ENDPOINT_URL_S3 \
  && AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  && AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  && terraform init \
  && terraform apply -auto-approve

FROM alpine:latest as BUILD
ARG COMMIT=bd90abf487a6b0500f457193f86ff54fd2be3143

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
COPY --from=TF matchbox-ca.crt .

RUN set -x \
  \
  && make \
    bin-$(arch)-efi/ipxe.efi \
    CERT=matchbox-ca.crt TRUST=matchbox-ca.crt \
  && mkdir -p /build \
  && mv ipxe/src/bin-$(arch)-efi/*.efi /build/

FROM alpine:latest

WORKDIR /var/tftpboot
COPY --from=BUILD --chown=nobody:nogroup /build/ .

RUN set -x \
  \
  && apk add --no-cache \
    tftp-hpa

ENTRYPOINT [ "in.tftpd", "--foreground", "--user", "nobody", "--secure", "/var/tftpboot" ]
