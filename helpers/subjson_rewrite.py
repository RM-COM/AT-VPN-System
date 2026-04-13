#!/usr/bin/env python3
import argparse
import json
import os
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
PASS_HEADERS_LOWER = {header.lower() for header in PASS_HEADERS}

CLIENT_SOCKOPT_KEYS = (
    "tcpNoDelay",
    "domainStrategy",
    "tcpKeepAliveInterval",
    "tcpKeepAliveIdle",
    "tcpUserTimeout",
)

DEFAULT_DNS_SERVERS = (
    "https+local://1.1.1.1/dns-query",
    "https+local://8.8.8.8/dns-query",
)
DEFAULT_DNS_QUERY_STRATEGY = "UseIP"
DEFAULT_DNS_TAG = "dns_out"
DEFAULT_PROXY_OUTBOUND_TAG = "proxy"
PROXY_OUTBOUND_PROTOCOLS = {
    "vless",
    "vmess",
    "trojan",
    "shadowsocks",
    "socks",
    "http",
    "wireguard",
    "hysteria2",
}
FORCED_DNS_PROXY_RULE = {
    "type": "field",
    "network": "tcp,udp",
    "port": "53",
    "outboundTag": DEFAULT_PROXY_OUTBOUND_TAG,
}


def build_vless_vnext(settings):
    if not isinstance(settings, dict):
        return settings
    if "vnext" in settings:
        cleaned = dict(settings)
        for key in ("address", "port", "id", "flow", "encryption", "level", "email"):
            cleaned.pop(key, None)
        return cleaned
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


def build_xhttp_client_contract(stream_settings):
    if not isinstance(stream_settings, dict):
        return None
    xhttp_settings = stream_settings.get("xhttpSettings")
    if not isinstance(xhttp_settings, dict):
        return None
    client_xhttp = {}
    for key in (
        "path",
        "mode",
        "host",
        "noSSEHeader",
        "scMaxBufferedPosts",
        "scMaxEachPostBytes",
        "xPaddingBytes",
    ):
        value = xhttp_settings.get(key)
        if value in (None, ""):
            continue
        client_xhttp[key] = value
    headers = xhttp_settings.get("headers")
    if isinstance(headers, dict) and headers:
        client_xhttp["headers"] = headers
    xmux = xhttp_settings.get("xmux")
    if isinstance(xmux, dict) and xmux:
        client_xhttp["xmux"] = xmux
    if not client_xhttp:
        return None
    return {"xhttpSettings": client_xhttp}


def build_reality_client_contract(stream_settings, inbound_settings):
    if not isinstance(stream_settings, dict):
        return None
    reality_settings = stream_settings.get("realitySettings")
    if not isinstance(reality_settings, dict):
        return None
    server_names = reality_settings.get("serverNames")
    short_ids = reality_settings.get("shortIds")
    settings_block = reality_settings.get("settings")
    if not isinstance(settings_block, dict):
        settings_block = {}

    client_reality = {}
    public_key = (
        settings_block.get("publicKey")
        or reality_settings.get("publicKey")
        or reality_settings.get("password")
    )
    if public_key:
        client_reality["publicKey"] = public_key
    server_name = ""
    if isinstance(server_names, list):
        server_name = next((item for item in server_names if item), "")
    if not server_name:
        server_name = settings_block.get("serverName") or ""
    if server_name:
        client_reality["serverName"] = server_name
    fingerprint = settings_block.get("fingerprint")
    if fingerprint:
        client_reality["fingerprint"] = fingerprint
    short_id = ""
    if isinstance(short_ids, list):
        short_id = next((item for item in short_ids if item), "")
    if short_id:
        client_reality["shortId"] = short_id
    spider_x = settings_block.get("spiderX")
    if spider_x:
        client_reality["spiderX"] = spider_x

    contract = {}
    if client_reality:
        contract["realitySettings"] = client_reality

    if isinstance(inbound_settings, dict):
        clients = inbound_settings.get("clients")
        if isinstance(clients, list) and clients:
            first_client = clients[0]
            if isinstance(first_client, dict):
                user_flow = first_client.get("flow")
                if user_flow:
                    contract["userFlow"] = user_flow

    return contract or None


def split_csv(value):
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def build_dns_servers(dns_servers):
    servers = []
    for address in dns_servers:
        if not address:
            continue
        servers.append(
            {
                "address": address,
                "skipFallback": False,
            }
        )
    return servers


def rewrite_dns(config, dns_servers, dns_query_strategy):
    if not isinstance(config, dict):
        return config
    existing_dns = config.get("dns")
    rewritten_dns = {}
    if isinstance(existing_dns, dict):
        rewritten_dns = {
            key: value
            for key, value in existing_dns.items()
            if key not in ("servers", "queryStrategy", "tag")
        }
    rewritten_dns["queryStrategy"] = dns_query_strategy or DEFAULT_DNS_QUERY_STRATEGY
    rewritten_dns["servers"] = build_dns_servers(dns_servers)
    rewritten_dns["tag"] = DEFAULT_DNS_TAG
    config["dns"] = rewritten_dns
    return config


def preferred_proxy_outbound_tag(config):
    if not isinstance(config, dict):
        return DEFAULT_PROXY_OUTBOUND_TAG
    outbounds = config.get("outbounds")
    if not isinstance(outbounds, list):
        return DEFAULT_PROXY_OUTBOUND_TAG
    for outbound in outbounds:
        if not isinstance(outbound, dict):
            continue
        protocol = outbound.get("protocol")
        tag = outbound.get("tag")
        if protocol in PROXY_OUTBOUND_PROTOCOLS and tag:
            return tag
    return DEFAULT_PROXY_OUTBOUND_TAG


def find_dns_proxy_rule(rules):
    if not isinstance(rules, list):
        return None
    for index, rule in enumerate(rules):
        if not isinstance(rule, dict):
            continue
        if rule.get("type") != FORCED_DNS_PROXY_RULE["type"]:
            continue
        port_value = str(rule.get("port", ""))
        if port_value != FORCED_DNS_PROXY_RULE["port"]:
            continue
        network_value = str(rule.get("network", ""))
        if network_value != FORCED_DNS_PROXY_RULE["network"]:
            continue
        return index
    return None


def rewrite_routing(config):
    if not isinstance(config, dict):
        return config
    routing = config.get("routing")
    if not isinstance(routing, dict):
        routing = {}
        config["routing"] = routing
    rules = routing.get("rules")
    if not isinstance(rules, list):
        rules = []
        routing["rules"] = rules
    outbound_tag = preferred_proxy_outbound_tag(config)
    rule = dict(FORCED_DNS_PROXY_RULE)
    rule["outboundTag"] = outbound_tag
    existing_rule_index = find_dns_proxy_rule(rules)
    if existing_rule_index is None:
        rules.insert(0, rule)
    else:
        rules[existing_rule_index] = rule
    return config


def maybe_inject_transport_contract(outbound, transport_contract_map):
    if not isinstance(outbound, dict):
        return outbound
    if outbound.get("protocol") != "vless":
        return outbound
    stream_settings = outbound.get("streamSettings")
    if not isinstance(stream_settings, dict):
        return outbound
    network = stream_settings.get("network")
    security = stream_settings.get("security")
    if not network:
        return outbound
    contract = transport_contract_map.get((network, security))
    if not contract:
        contract = transport_contract_map.get((network, None))
    if not isinstance(contract, dict):
        return outbound

    xhttp_contract = contract.get("xhttpSettings")
    if isinstance(xhttp_contract, dict):
        stream_xhttp = stream_settings.get("xhttpSettings")
        if not isinstance(stream_xhttp, dict):
            stream_xhttp = {}
            stream_settings["xhttpSettings"] = stream_xhttp
        for key, value in xhttp_contract.items():
            if key not in stream_xhttp or stream_xhttp.get(key) in (None, "", {}, []):
                stream_xhttp[key] = value

    reality_contract = contract.get("realitySettings")
    if isinstance(reality_contract, dict):
        stream_reality = stream_settings.get("realitySettings")
        if not isinstance(stream_reality, dict):
            stream_reality = {}
            stream_settings["realitySettings"] = stream_reality
        for key, value in reality_contract.items():
            if key not in stream_reality or stream_reality.get(key) in (None, ""):
                stream_reality[key] = value

    user_flow = contract.get("userFlow")
    if user_flow:
        settings = outbound.get("settings")
        if isinstance(settings, dict):
            vnext = settings.get("vnext")
            if isinstance(vnext, list) and vnext:
                first_server = vnext[0]
                if isinstance(first_server, dict):
                    users = first_server.get("users")
                    if isinstance(users, list) and users:
                        first_user = users[0]
                        if isinstance(first_user, dict) and not first_user.get("flow"):
                            first_user["flow"] = user_flow

    return outbound


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
    if not network:
        return outbound
    existing_sockopt = stream_settings.get("sockopt")
    if isinstance(existing_sockopt, dict) and existing_sockopt:
        return outbound
    injected_sockopt = sockopt_map.get((network, security))
    if not injected_sockopt:
        injected_sockopt = sockopt_map.get((network, None))
    injected_sockopt = build_client_sockopt(injected_sockopt)
    if injected_sockopt:
        stream_settings["sockopt"] = injected_sockopt
    return outbound


def rewrite_config(config, sockopt_map, transport_contract_map, dns_servers, dns_query_strategy):
    if not isinstance(config, dict):
        return config
    rewrite_dns(config, dns_servers, dns_query_strategy)
    rewrite_routing(config)
    outbounds = config.get("outbounds")
    if isinstance(outbounds, list):
        rewritten_outbounds = []
        for outbound in outbounds:
            rewritten_outbound = rewrite_outbound(outbound)
            rewritten_outbound = maybe_inject_transport_contract(rewritten_outbound, transport_contract_map)
            rewritten_outbounds.append(maybe_inject_sockopt(rewritten_outbound, sockopt_map))
        config["outbounds"] = rewritten_outbounds
    return config


def rewrite_document(document, sockopt_map, transport_contract_map, dns_servers, dns_query_strategy):
    if isinstance(document, list):
        return [rewrite_config(item, sockopt_map, transport_contract_map, dns_servers, dns_query_strategy) for item in document]
    if isinstance(document, dict):
        return rewrite_config(document, sockopt_map, transport_contract_map, dns_servers, dns_query_strategy)
    return document


class RewriteHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, server_address, handler_cls, upstream_port, timeout, xui_db_path, dns_servers, dns_query_strategy):
        super().__init__(server_address, handler_cls)
        self.upstream_port = upstream_port
        self.timeout = timeout
        self.xui_db_path = xui_db_path
        self.dns_servers = dns_servers
        self.dns_query_strategy = dns_query_strategy
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
            headers = {key: value for key, value in response.headers.items() if key.lower() in PASS_HEADERS_LOWER}
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
                    if network and security and client_sockopt and (network, security) not in sockopt_map:
                        sockopt_map[(network, security)] = client_sockopt
                    if network and client_sockopt and (network, None) not in sockopt_map:
                        sockopt_map[(network, None)] = client_sockopt
                return sockopt_map
            finally:
                connection.close()
        except Exception as exc:
            sys.stderr.write(f"sockopt map load failed: {exc}\n")
            return {}

    def load_transport_contract_map(self):
        if not self.xui_db_path:
            return {}
        try:
            connection = sqlite3.connect(f"file:{self.xui_db_path}?mode=ro", uri=True)
            try:
                cursor = connection.execute("SELECT stream_settings, settings FROM inbounds")
                transport_contract_map = {}
                for stream_settings_raw, inbound_settings_raw in cursor.fetchall():
                    if not stream_settings_raw:
                        continue
                    try:
                        stream_settings = json.loads(stream_settings_raw)
                    except Exception:
                        continue
                    try:
                        inbound_settings = json.loads(inbound_settings_raw) if inbound_settings_raw else {}
                    except Exception:
                        inbound_settings = {}
                    network = stream_settings.get("network")
                    security = stream_settings.get("security")
                    if not network:
                        continue

                    contract = None
                    if network == "xhttp":
                        contract = build_xhttp_client_contract(stream_settings)
                    elif security == "reality":
                        contract = build_reality_client_contract(stream_settings, inbound_settings)

                    if not contract:
                        continue
                    if security and (network, security) not in transport_contract_map:
                        transport_contract_map[(network, security)] = contract
                    if (network, None) not in transport_contract_map:
                        transport_contract_map[(network, None)] = contract
                return transport_contract_map
            finally:
                connection.close()
        except Exception as exc:
            sys.stderr.write(f"transport contract map load failed: {exc}\n")
            return {}


class Handler(BaseHTTPRequestHandler):
    server_version = "xui-subjson-rewrite/1.0"

    def do_GET(self):
        host_header = self.headers.get("Host", "")
        try:
            status_code, headers, body = self.server.fetch_upstream(self.path, host_header)
        except urllib.error.HTTPError as exc:
            status_code = exc.code
            headers = {key: value for key, value in exc.headers.items() if key.lower() in PASS_HEADERS_LOWER}
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

        try:
            parsed = json.loads(body.decode("utf-8"))
            rewritten = rewrite_document(
                parsed,
                self.server.load_sockopt_map(),
                self.server.load_transport_contract_map(),
                self.server.dns_servers,
                self.server.dns_query_strategy,
            )
            rewritten_body = json.dumps(rewritten, ensure_ascii=False, indent=2).encode("utf-8")
        except Exception as exc:
            sys.stderr.write(f"json rewrite failed for {self.path}: {exc}\n")
            error_body = json.dumps(
                {"error": "subjson rewrite parse failure", "detail": str(exc)},
                ensure_ascii=False,
            ).encode("utf-8")
            self.send_response(502 if 200 <= status_code < 300 else status_code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(error_body)))
            self.end_headers()
            self.wfile.write(error_body)
            return

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
    parser.add_argument("--dns-server", action="append", default=None)
    parser.add_argument("--dns-query-strategy", default=None)
    args = parser.parse_args()

    dns_servers = args.dns_server or split_csv(os.environ.get("SUBJSON_REWRITE_DNS_SERVERS")) or list(DEFAULT_DNS_SERVERS)
    dns_query_strategy = args.dns_query_strategy or os.environ.get("SUBJSON_REWRITE_DNS_QUERY_STRATEGY") or DEFAULT_DNS_QUERY_STRATEGY

    server = RewriteHTTPServer(
        (args.bind, args.port),
        Handler,
        args.upstream_port,
        args.timeout,
        args.xui_db_path,
        dns_servers,
        dns_query_strategy,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
