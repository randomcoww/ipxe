FROM hashicorp/terraform:latest as TF
COPY matchbox_ca.tf .

RUN set -x \
  \
  && terraform init \
  && terraform apply -auto-approve

FROM alpine:latest as BUILD
ARG VERSION=master

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
  && git clone --depth 1 -b $VERSION https://github.com/ipxe/ipxe /ipxe

WORKDIR /ipxe/src
COPY config/ config/local/
COPY --from=TF matchbox-ca.crt .

RUN set -x \
  \
  && make \
    bin-x86_64-efi/ipxe.efi \
    CERT=matchbox-ca.crt TRUST=matchbox-ca.crt

FROM alpine:latest

WORKDIR /var/tftpboot
COPY --from=BUILD --chown=nobody:nogroup \
  /ipxe/src/bin-x86_64-efi/*.efi .

RUN set -x \
  \
  && apk add --no-cache \
    tftp-hpa

ENTRYPOINT [ "in.tftpd", "--foreground", "--user", "nobody", "--secure", "/var/tftpboot" ]
