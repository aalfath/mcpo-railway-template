[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/mcpo?utm_medium=integration&utm_source=button&utm_campaign=mcpo)

# mcpo on Railway

One-click Railway template for [mcpo](https://github.com/open-webui/mcpo), Open WebUI's MCP-to-OpenAPI proxy. It runs MCP (Model Context Protocol) tool servers and exposes each one as a plain REST API with an OpenAPI schema and Swagger docs, so Open WebUI, OpenAPI-aware agents or a simple `curl` can call MCP tools over HTTPS.

**Version:** mcpo v0.0.20 (release commit `788ff92e`), built from source in this repo's `Dockerfile` with pinned, digest-locked base images. Upstream only publishes moving `main`/`latest` images, so pinning the release source is the only way to get a fixed version.

## What you get

One service, `mcpo`, with:

- a public HTTPS URL, every route locked by a generated API key (`Authorization: Bearer <MCPO_API_KEY>`, or HTTP Basic with any user name and the key as password, which is how the browser opens `/docs`);
- three example MCP servers, preinstalled so the first boot downloads nothing:
  - `time` (current time and time-zone conversion),
  - `memory` (a small knowledge graph saved to `/data/memory.jsonl`),
  - `fetch` (fetch a web page and return it as Markdown);
- a Railway volume at `/data` that holds `config.json`, the memory graph and the uv/npm caches of any MCP server you add;
- `/healthz` (no key needed): 200 once at least one MCP server is connected, 503 otherwise;
- Python (`uvx`) and Node.js 22 (`npx`) in the image, so most stdio MCP servers can be added by config alone.

Each MCP server gets its own route and docs: `https://YOUR-DOMAIN/time/docs`, `/memory/docs`, `/fetch/docs`. The tool list is at `https://YOUR-DOMAIN/docs`.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `MCPO_API_KEY` | `${{secret(48)}}` | The API key every request needs. Generated on deploy; read it in the service's Variables tab. |
| `PORT` | `8000` | Port mcpo listens on. |
| `MCPO_CONFIG` | empty (optional) | Your own mcpo config as JSON (or base64 JSON). When set, it replaces `/data/config.json` on every start. Leave empty to keep the example servers. |

No LLM key is needed: mcpo only runs tools. The client (for example Open WebUI) brings the model.

## After deploy

1. Copy `MCPO_API_KEY` from the service's **Variables** tab.
2. Open `https://YOUR-DOMAIN/docs`, sign in with any user name and the key as password, and try a tool.
3. From a shell:
   ```sh
   curl -X POST https://YOUR-DOMAIN/time/get_current_time \
     -H "Authorization: Bearer YOUR-KEY" -H "Content-Type: application/json" \
     -d '{"timezone":"Europe/Berlin"}'
   ```
4. In Open WebUI: **Settings → Tools (or Admin Settings → External Tools) → add an OpenAPI tool server** with URL `https://YOUR-DOMAIN/time` (one entry per MCP server) and the key as Bearer token.

## Adding your own MCP servers

Set `MCPO_CONFIG` to a config in the [Claude Desktop format mcpo reads](https://github.com/open-webui/mcpo#-config-file-format) and redeploy. Example:

```json
{"mcpServers":{
  "time":{"command":"mcp-server-time","args":["--local-timezone=UTC"]},
  "github":{"type":"streamable-http","url":"https://api.githubcopilot.com/mcp/","headers":{"Authorization":"Bearer YOUR-GITHUB-TOKEN"}},
  "sqlite":{"command":"uvx","args":["mcp-server-sqlite","--db-path","/data/test.db"]}
}}
```

- stdio servers: `command` + `args` (+ `env`); `uvx …` and `npx -y …` work, and their packages are cached on the volume after the first start.
- remote servers: `"type": "streamable-http"` or `"sse"` with `url` and optional `headers`.
- Railway's API sits behind Cloudflare, which can reject variable values that look like code. If saving the variable fails, base64-encode the JSON (`base64 -w0 config.json`) and paste that instead.
- Without `MCPO_CONFIG`, mcpo reads `/data/config.json` and reloads it when it changes (`railway ssh` then edit the file).

If the config is invalid or no server can connect, the service fails its health check and Railway keeps the previous deployment running.

## Resources

mcpo with the three example servers idles at about 150 MB and fits Railway's Free plan (0.5 GB). Each stdio MCP server is its own process, so heavy servers (browsers, Node servers with big dependency trees) add their own memory: size the service for what you add.

## Not included

- mcpo's OAuth 2.1 flow for remote MCP servers opens a browser and listens on a local callback port, which doesn't work on a headless server; use header tokens instead.
- Docker-based MCP servers (`docker run …` in a config) can't run on Railway: no Docker-in-Docker.

## Updates

This template builds from this repo. When we bump mcpo or the example servers, the change lands on `main` with a `CHANGELOG.md` entry (breaking changes first), and Railway shows an "update available" notice on your service. Read the changelog, then apply it from the dashboard. Your `/data` volume (config and memory) is kept.

## Licence

mcpo is MIT-licensed by Timothy Jaeryang Baek (Open WebUI). The example MCP servers are from [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) (MIT). This wrapper is MIT.
