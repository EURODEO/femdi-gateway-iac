FROM alpine:3.20

# Set arguments for product and version
ARG PRODUCT=vault
ARG VERSION=1.18.0

# Install dependencies and Vault
# Vault installation snippet from https://www.hashicorp.com/blog/installing-hashicorp-tools-in-alpine-linux-containers
# Vault binary is enormous ~436MB, might need to think some other option.. 
# Someone else also not happy about it https://github.com/hashicorp/vault/issues/22893
# aws-cli is around ~100MB
RUN apk add --update --virtual .deps --no-cache gnupg wget unzip && \
    apk add --no-cache aws-cli bash && \
    cd /tmp && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    rm -f /tmp/${PRODUCT}_${VERSION}_linux_amd64.zip ${PRODUCT}_${VERSION}_SHA256SUMS ${PRODUCT}_${VERSION}_SHA256SUMS.sig && \
    apk del .deps

# Add a script to take the snapshot and upload to S3
COPY vault-snapshot.sh /usr/local/bin/vault-snapshot.sh
RUN chmod +x /usr/local/bin/vault-snapshot.sh

CMD ["/usr/local/bin/vault-snapshot.sh"]