#!/usr/bin/env python3
import argparse
import json
import ssl
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PASS_HEADERS = (
    "Subscription-Userinfo",
    "Profile-Title",
    "Profile-Update-Interval",
    "Support-Url",
    "Profile-Web-Page-Url",
    "Content-Disposition",
    "Cache-Control",
    "Etag",
    "Last-Modified",
)


def build_vless_vnext(settings):
    if not isinstance(settings, dict):
        return settings
    if "vnext" in settings:
        return settings
    address = settings.get("address")
    port = settings.get("port")
    client_id = settings.get("id")
    if address in (None, "") or port in (None, "") or client_id in (None, ""):
        return settings

    user = {
        "id": client_id,
        "encryption": settings.get("encryption") or "none",
    }
    if settings.get("flow"):
        user["flow"] = settings["flow"]
    if settings.get("level") not in (None, ""):
        user["level"] = settings["level"]
    if settings.get("email"):
        user["email"] = settings["email"]

    return {
        "vnext": [
            {
                "address": address,
                "port": port,
                "users": [user],
            }
        ]
    }


def rewrite_outbound(outbound):
    if not isinstance(outbound, dict):
        return outbound
    if outbound.get("protocol") != "vless":
        return outbound
    settings = outbound.get("settings")
    if not isinstance(settings, dict):
        return outbound
    outbound["settings"] = build_vless_vnext(settings)
    return outbound


def rewrite_config(config):
    if not isinstance(config, dict):
        return config
    outbounds = config.get("outbounds")
    if isinstance(outbounds, list):
        config["outbounds"] = [rewrite_outbound(outbound) for outbound in outbounds]
    return config


def rewrite_document(document):
    if isinstance(document, list):
        return [rewrite_config(item) for item in document]
    if isinstance(document, dict):
        return rewrite_config(document)
    return document


class RewriteHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, server_address, handler_cls, upstream_port, timeout):
        super().__init__(server_address, handler_cls)
        self.upstream_port = upstream_port
        self.timeout = timeout
        self.ssl_context = ssl._create_unverified_context()

    def fetch_upstream(self, path, host_header):
        upstream_url = f"https://127.0.0.1:{self.upstream_port}{path}"
        request = urllib.request.Request(
            upstream_url,
            headers={
                "Host": host_header,
                "Accept": "application/json",
                "Accept-Encoding": "identity",
                "User-Agent": "xui-subjson-rewrite/1.0",
            },
        )
        with urllib.request.urlopen(
            request,
            timeout=self.timeout,
            context=self.ssl_context,
        ) as response:
            body = response.read()
            headers = {key: value for key, value in response.headers.items() if key in PASS_HEADERS}
            return response.getcode(), headers, body


class Handler(BaseHTTPRequestHandler):
    server_version = "xui-subjson-rewrite/1.0"

    def do_GET(self):
        host_header = self.headers.get("Host", "")
        try:
            status_code, headers, body = self.server.fetch_upstream(self.path, host_header)
        except urllib.error.HTTPError as exc:
            status_code = exc.code
            headers = {key: value for key, value in exc.headers.items() if key in PASS_HEADERS}
            body = exc.read()
        except Exception as exc:
            error_body = json.dumps(
                {"error": "subjson rewrite upstream failure", "detail": str(exc)},
                ensure_ascii=False,
            ).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(error_body)))
            self.end_headers()
            self.wfile.write(error_body)
            return

        rewritten_body = body
        try:
            parsed = json.loads(body.decode("utf-8"))
            rewritten = rewrite_document(parsed)
            rewritten_body = json.dumps(rewritten, ensure_ascii=False, indent=2).encode("utf-8")
        except Exception:
            pass

        self.send_response(status_code)
        for key, value in headers.items():
            if key.lower() == "content-length":
                continue
            self.send_header(key, value)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(rewritten_body)))
        self.end_headers()
        self.wfile.write(rewritten_body)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser(description="Rewrite 3x-ui JSON subscriptions into valid VLESS vnext configs.")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--upstream-port", type=int, required=True)
    parser.add_argument("--timeout", type=int, default=15)
    args = parser.parse_args()

    server = RewriteHTTPServer((args.bind, args.port), Handler, args.upstream_port, args.timeout)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
