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
 && rm -rf /var/lib/apt/lists/*
