FROM alpine:3.20

# Set arguments for product and version
ARG PRODUCT=vault
ARG VAULT_VERSION=1.18.0
ARG ETCD_VERSION=v3.5.17

# Install dependencies and AWS CLI & PostgreSQL client
# aws-cli is around ~100MB
RUN apk add --update --virtual .deps --no-cache gnupg wget unzip && \
    apk add --no-cache aws-cli postgresql-client bash && \
    cd /tmp && \
    # Install Vault
    # Vault installation snippet from https://www.hashicorp.com/blog/installing-hashicorp-tools-in-alpine-linux-containers
    # Vault binary is enormous ~436MB, might need to think some other option.. 
    # Someone else also not happy about it https://github.com/hashicorp/vault/issues/22893
    wget https://releases.hashicorp.com/${PRODUCT}/${VAULT_VERSION}/${PRODUCT}_${VAULT_VERSION}_linux_amd64.zip && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VAULT_VERSION}/${PRODUCT}_${VAULT_VERSION}_SHA256SUMS && \
    wget https://releases.hashicorp.com/${PRODUCT}/${VAULT_VERSION}/${PRODUCT}_${VAULT_VERSION}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify ${PRODUCT}_${VAULT_VERSION}_SHA256SUMS.sig ${PRODUCT}_${VAULT_VERSION}_SHA256SUMS && \
    grep ${PRODUCT}_${VAULT_VERSION}_linux_amd64.zip ${PRODUCT}_${VAULT_VERSION}_SHA256SUMS | sha256sum -c && \
    unzip /tmp/${PRODUCT}_${VAULT_VERSION}_linux_amd64.zip -d /tmp && \
    mv /tmp/${PRODUCT} /usr/local/bin/${PRODUCT} && \
    # Install etcd
    wget https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -O /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz && \
    tar xzvf /tmp/etcd-${ETCD_VERSION}-linux-amd64.tar.gz && \
    mv /tmp/etcd-${ETCD_VERSION}-linux-amd64/etcdctl /usr/local/bin/etcdctl && \
    # Remove temporary files & build dependencies
    rm -rf /tmp/* && \
    rm -f ${PRODUCT}_${VAULT_VERSION}_SHA256SUMS ${PRODUCT}_${VAULT_VERSION}_SHA256SUMS.sig && \
    apk del .deps

# Verify installations
RUN etcdctl version && vault version && aws --version && pg_dump --version

# Add scripts and make them executable
COPY common-functions.sh /usr/local/bin/common-functions.sh
COPY vault-snapshot.sh /usr/local/bin/vault-snapshot.sh
COPY apisix-snapshot.sh /usr/local/bin/apisix-snapshot.sh
COPY keycloak-snapshot.sh /usr/local/bin/keycloak-snapshot.sh
RUN chmod +x /usr/local/bin/common-functions.sh \
             /usr/local/bin/vault-snapshot.sh \
             /usr/local/bin/apisix-snapshot.sh \
             /usr/local/bin/keycloak-snapshot.sh

CMD ["/usr/local/bin/vault-snapshot.sh"]
