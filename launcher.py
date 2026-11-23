"""Run mcpo with Railway-friendly defaults.

* listens on $PORT on all IPv4 and IPv6 addresses (Railway's private network is IPv6);
* requires MCPO_API_KEY and protects every route, docs included (--strict-auth);
* adds an unauthenticated /healthz (200 once at least one MCP server is connected)
  and redirects / to /docs;
* removes MCPO_API_KEY from the environment before any MCP server process starts,
  so the key never reaches a child process.
"""
import json
import os
import sys

import uvicorn
from starlette.routing import Mount

api_key = os.environ.pop("MCPO_API_KEY", "")
if not api_key:
    sys.exit("launcher: MCPO_API_KEY is empty")
port = os.environ.get("PORT") or "8000"
config = os.path.join(os.environ.get("MCPO_DATA_DIR", "/data"), "config.json")
strict = os.environ.get("MCPO_STRICT_AUTH", "true").lower() not in ("0", "false", "no")


def railway_wrap(app):
    async def asgi(scope, receive, send):
        if scope["type"] == "http" and scope["path"] in ("/healthz", "/"):
            if scope["path"] == "/":
                await send({"type": "http.response.start", "status": 307,
                            "headers": [(b"location", b"/docs"), (b"content-length", b"0")]})
                await send({"type": "http.response.body", "body": b""})
                return
            subs = [r.app for r in app.routes if isinstance(r, Mount) and hasattr(r.app, "state")]
            up = sum(1 for s in subs if getattr(s.state, "is_connected", False))
            ok = up > 0
            body = json.dumps({"status": "ok" if ok else "no MCP server connected",
                               "connected": up, "configured": len(subs)}).encode()
            await send({"type": "http.response.start", "status": 200 if ok else 503,
                        "headers": [(b"content-type", b"application/json"),
                                    (b"content-length", str(len(body)).encode())]})
            await send({"type": "http.response.body", "body": body})
            return
        await app(scope, receive, send)
    return asgi


_Config = uvicorn.Config


class RailwayConfig(_Config):
    def __init__(self, app, *args, **kwargs):
        kwargs.setdefault("proxy_headers", True)
        kwargs.setdefault("forwarded_allow_ips", "*")
        super().__init__(railway_wrap(app), *args, **kwargs)


uvicorn.Config = RailwayConfig  # mcpo.main calls uvicorn.Config(...) at run time

import mcpo.main  # noqa: E402
from mcpo import app as mcpo_cli  # noqa: E402

# Remember whether we were asked to stop (SIGTERM/SIGINT), so any other way
# out of mcpo counts as a crash and exits non-zero for Railway's restart policy.
_stopping = {"signal": False}
_handle_signal = mcpo.main.GracefulShutdown.handle_signal


def _flag_signal(self, sig, frame=None):
    _stopping["signal"] = True
    return _handle_signal(self, sig, frame)


mcpo.main.GracefulShutdown.handle_signal = _flag_signal

argv = ["mcpo", "--host", "::", "--port", port, "--api-key", api_key,
        "--config", config, "--hot-reload"]
if strict:
    argv.append("--strict-auth")
code = 1
try:
    mcpo_cli(argv[1:], prog_name="mcpo", standalone_mode=False)
    code = 0 if _stopping["signal"] else 1
except SystemExit as e:
    code = e.code if isinstance(e.code, int) and e.code else 1
except BaseException as e:  # noqa: BLE001
    print(f"launcher: mcpo stopped with {type(e).__name__}: {e}", file=sys.stderr)
    code = 1
if code:
    print(f"launcher: mcpo exited unexpectedly, exiting {code} so Railway restarts it", file=sys.stderr)
sys.exit(code)
