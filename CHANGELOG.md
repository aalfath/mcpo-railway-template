# Changelog

Each entry is one version of this Railway template. Breaking changes come first.

## 0.0.20-1 (2026-11-23)

First release of the template.

- mcpo **v0.0.20** (commit `788ff92e`), built from the release source with its `uv.lock`, because upstream publishes only moving `main`/`latest` images.
- Base images pinned by digest: `python:3.12.16-slim-bookworm`, `node:24.22.3-bookworm-slim` (Node/npx for MCP servers), `ghcr.io/astral-sh/uv:0.9.5`.
- Example MCP servers preinstalled: `mcp-server-time` 2026.11.18, `mcp-server-fetch` 2026.11.18, `@modelcontextprotocol/server-memory` 2.2.1.
- Every route, `/docs` and `/openapi.json` included, needs the generated `MCPO_API_KEY` (`--strict-auth`); `/healthz` is open and answers 200 once an MCP server is connected.
- Config, memory graph and package caches live on the `/data` volume; `MCPO_CONFIG` replaces the config on each start.
