#!/usr/bin/env python3
import argparse
import json
import sqlite3
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

CLIENT_SOCKOPT_KEYS = (
    "tcpFastOpen",
    "tcpMptcp",
    "tcpNoDelay",
    "domainStrategy",
    "tcpMaxSeg",
    "tcpKeepAliveInterval",
    "tcpKeepAliveIdle",
    "tcpUserTimeout",
    "tcpcongestion",
    "V6Only",
    "tcpWindowClamp",
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


def build_client_sockopt(sockopt):
    if not isinstance(sockopt, dict):
        return None
    client_sockopt = {}
    for key in CLIENT_SOCKOPT_KEYS:
        value = sockopt.get(key)
        if value in (None, ""):
            continue
        client_sockopt[key] = value
    return client_sockopt or None


def maybe_inject_sockopt(outbound, sockopt_map):
    if not isinstance(outbound, dict):
        return outbound
    if outbound.get("protocol") != "vless":
        return outbound
    stream_settings = outbound.get("streamSettings")
    if not isinstance(stream_settings, dict):
        return outbound
    network = stream_settings.get("network")
    security = stream_settings.get("security")
    if not network or not security:
        return outbound
    existing_sockopt = stream_settings.get("sockopt")
    if isinstance(existing_sockopt, dict) and existing_sockopt:
        return outbound
    injected_sockopt = sockopt_map.get((network, security))
    if injected_sockopt:
        stream_settings["sockopt"] = injected_sockopt
    return outbound


def rewrite_config(config, sockopt_map):
    if not isinstance(config, dict):
        return config
    outbounds = config.get("outbounds")
    if isinstance(outbounds, list):
        rewritten_outbounds = []
        for outbound in outbounds:
            rewritten_outbound = rewrite_outbound(outbound)
            rewritten_outbounds.append(maybe_inject_sockopt(rewritten_outbound, sockopt_map))
        config["outbounds"] = rewritten_outbounds
    return config


def rewrite_document(document, sockopt_map):
    if isinstance(document, list):
        return [rewrite_config(item, sockopt_map) for item in document]
    if isinstance(document, dict):
        return rewrite_config(document, sockopt_map)
    return document


class RewriteHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, server_address, handler_cls, upstream_port, timeout, xui_db_path):
        super().__init__(server_address, handler_cls)
        self.upstream_port = upstream_port
        self.timeout = timeout
        self.xui_db_path = xui_db_path
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

    def load_sockopt_map(self):
        if not self.xui_db_path:
            return {}
        try:
            connection = sqlite3.connect(f"file:{self.xui_db_path}?mode=ro", uri=True)
            try:
                cursor = connection.execute("SELECT stream_settings FROM inbounds")
                sockopt_map = {}
                for (stream_settings_raw,) in cursor.fetchall():
                    if not stream_settings_raw:
                        continue
                    try:
                        stream_settings = json.loads(stream_settings_raw)
                    except Exception:
                        continue
                    network = stream_settings.get("network")
                    security = stream_settings.get("security")
                    client_sockopt = build_client_sockopt(stream_settings.get("sockopt"))
                    if network and security and client_sockopt:
                        sockopt_map[(network, security)] = client_sockopt
                return sockopt_map
            finally:
                connection.close()
        except Exception:
            return {}


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
            rewritten = rewrite_document(parsed, self.server.load_sockopt_map())
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
    parser.add_argument("--xui-db-path", default="/etc/x-ui/x-ui.db")
    args = parser.parse_args()

    server = RewriteHTTPServer((args.bind, args.port), Handler, args.upstream_port, args.timeout, args.xui_db_path)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
