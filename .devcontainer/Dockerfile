# Custom devcontainer image for the Asset Manager workshop.
#
# We layer on top of the Microsoft Java 21 devcontainer base image (multi-arch:
# amd64 + arm64) but strip the broken Yarn apt source it ships with. That
# source's GPG signing key rotates periodically; whenever the local trust
# store falls behind, the first `apt-get update` run by any dev container
# feature (e.g. docker-outside-of-docker) fails with
#
#   GPG error: https://dl.yarnpkg.com/debian stable InRelease:
#   The following signatures couldn't be verified because the public key
#   is not available: NO_PUBKEY 62D54FD4003F6525
#
# The workshop doesn't use Yarn, so removing the source list is the simplest
# durable fix. Everything else (JDK 21, sdkman + JDK 8, Azure CLI, etc.)
# continues to come from the base image + the features declared in
# devcontainer.json.
FROM mcr.microsoft.com/devcontainers/java:1-21-bookworm

RUN rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates bash-completion \
 && rm -rf /var/lib/apt/lists/* \
 && ARCH="$(dpkg --print-architecture)" \
 && case "$ARCH" in \
      amd64) KARCH=amd64 ;; \
      arm64) KARCH=arm64 ;; \
      *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/${KARCH}/kubectl" -o /usr/local/bin/kubectl \
 && curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/${KARCH}/kubectl.sha256" -o /tmp/kubectl.sha256 \
 && echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - \
 && chmod 0755 /usr/local/bin/kubectl \
 && curl -fsSL "https://get.helm.sh/helm-v3.15.4-linux-${KARCH}.tar.gz" -o "/tmp/helm-v3.15.4-linux-${KARCH}.tar.gz" \
 && curl -fsSL "https://get.helm.sh/helm-v3.15.4-linux-${KARCH}.tar.gz.sha256sum" -o /tmp/helm.sha256 \
 && cd /tmp \
 && sha256sum -c /tmp/helm.sha256 \
 && tar -xzf "/tmp/helm-v3.15.4-linux-${KARCH}.tar.gz" -C /tmp \
 && mv "/tmp/linux-${KARCH}/helm" /usr/local/bin/helm \
 && chmod 0755 /usr/local/bin/helm \
 && rm -rf /tmp/helm-v3.15.4-linux-${KARCH}.tar.gz /tmp/helm.sha256 /tmp/linux-${KARCH} /tmp/kubectl.sha256 \
 && kubectl completion bash > /etc/bash_completion.d/kubectl \
 && helm completion bash > /etc/bash_completion.d/helm
