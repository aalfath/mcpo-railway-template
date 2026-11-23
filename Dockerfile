# mcpo for Railway: Open WebUI's MCP-to-OpenAPI proxy.
# Upstream publishes only moving `main`/`latest` images, so we build the pinned
# release tag v0.0.20 (commit 788ff92e) from source with its own uv.lock.
FROM ghcr.io/astral-sh/uv:0.9.5@sha256:f459f6f73a8c4ef5d69f4e6fbbdb8af751d6fa40ec34b39a1ab469acd6e289b7 AS uv
FROM node:22.23.5-bookworm-slim@sha256:e9f565d32859f0cbfb52125eafe8be39390f24dac302dc3cdf566e8ba3ab21ee AS node

FROM python:3.12.16-slim-bookworm@sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df

ARG MCPO_VERSION=0.0.20
ARG MCPO_COMMIT=788ff92e5288a899a743a252edd5748f4ad4ab1f
ARG MCPO_SHA256=47df635161824c274473ee929bd555e4c0b4517a3967425f8604f9796281dad0
# Example MCP servers baked into the image (see config.default.json)
ARG MCP_SERVER_TIME_VERSION=2026.11.18
ARG MCP_SERVER_FETCH_VERSION=2026.11.18
ARG MCP_SERVER_MEMORY_VERSION=2.2.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends tini git ca-certificates \
 && rm -r /var/lib/apt/lists/*

# uv/uvx and Node.js/npm/npx, so configs can start Python or Node MCP servers
COPY --from=uv /uv /uvx /usr/local/bin/
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && node -v && npm -v

ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_TOOL_DIR=/opt/uv-tools \
    UV_TOOL_BIN_DIR=/usr/local/bin

# mcpo itself, from the pinned release commit, checksum-verified, locked deps
ADD https://codeload.github.com/open-webui/mcpo/tar.gz/${MCPO_COMMIT} /tmp/mcpo.tar.gz
RUN echo "${MCPO_SHA256}  /tmp/mcpo.tar.gz" | sha256sum -c - \
 && mkdir -p /app/src && tar xzf /tmp/mcpo.tar.gz -C /app/src --strip-components=1 && rm /tmp/mcpo.tar.gz \
 && cd /app/src && uv sync --frozen --no-dev --no-editable \
 && /app/.venv/bin/mcpo --help >/dev/null \
 && rm -r /root/.cache

# Example MCP servers, preinstalled so the first boot downloads nothing
RUN uv tool install "mcp-server-time==${MCP_SERVER_TIME_VERSION}" \
 && uv tool install "mcp-server-fetch==${MCP_SERVER_FETCH_VERSION}" \
 && npm install -g --no-fund --no-audit "@modelcontextprotocol/server-memory@${MCP_SERVER_MEMORY_VERSION}" \
 && rm -r /root/.cache /root/.npm

COPY config.default.json launcher.py start.sh /app/
RUN chmod 755 /app/start.sh

# State (config.json, memory graph, uv/npm caches for servers added later) lives on the /data volume
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    MCPO_DATA_DIR=/data \
    UV_CACHE_DIR=/data/.cache/uv \
    npm_config_cache=/data/.cache/npm \
    npm_config_update_notifier=false

EXPOSE 8000
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/app/start.sh"]
