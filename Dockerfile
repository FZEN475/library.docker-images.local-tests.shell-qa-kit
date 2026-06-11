FROM docker.io/bats/bats:latest@sha256:6e4b9369468b7f3fd8f402ac6cc8ea7b2e4903eae28d08785f31a0245eb51a44

ARG shellcheck_tag=latest
ARG shellcheck_url_base=https://github.com/koalaman/shellcheck/releases/download/

RUN apk add --no-cache \
        ruby=3.4.9-r0 \
        libcrypto3=3.5.7-r0 \
        libssl3=3.5.7-r0 \
        musl=1.2.5-r23 \
        musl-utils=1.2.5-r23 \
        zlib=1.3.2-r0 \
    && gem update --system --no-document \
    && gem install --no-document rexml:3.4.1 \
    && gem install --no-document \
        simplecov:0.22.0 \
        simplecov-cobertura:2.1.0 \
        bashcov:3.3

RUN set -x; \
    arch="$(uname -m)"; \
    echo "arch is $arch"; \
    if [ "${arch}" = "armv7l" ]; then \
        arch="armv6hf"; \
    fi; \
    tar_file="${shellcheck_tag}/shellcheck-${shellcheck_tag}.linux.${arch}.tar.xz"; \
    wget -q "${shellcheck_url_base}${tar_file}" -O /tmp/shellcheck.tar.xz && \
    tar -C /bin --strip-components=1 -xJf /tmp/shellcheck.tar.xz "shellcheck-${shellcheck_tag}/shellcheck" && \
    ls -laF /bin/shellcheck

COPY ci/ /ci

RUN chmod +x /ci/entrypoint.sh

WORKDIR /source

HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
  CMD shellcheck --version && bats --version && bashcov --version || exit 1

ENTRYPOINT ["/ci/entrypoint.sh"]
