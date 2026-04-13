#!/bin/bash
#################### x-ui-pro v2.4.3 @ github.com/GFW4Fun ##############################################
set -o pipefail
trap 'rc=$?; (( rc )) && printf "[ERROR] Script exited with code %d\n" "$rc" >&2' EXIT

##############################Constants##################################################################
XUIDB="/etc/x-ui/x-ui.db"
XUI_RUNTIME_PROVENANCE_FILE="${XUI_RUNTIME_PROVENANCE_FILE:-/etc/x-ui/runtime-provenance.env}"
IP4_REGEX="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
IP6_REGEX="([a-f0-9:]+:+)+[a-f0-9]+"
PKG_MGR=$(type apt &>/dev/null && echo "apt" || echo "yum")
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
case "$SCRIPT_SOURCE" in
	/dev/fd/*|/proc/self/fd/*) SCRIPT_DIR="" ;;
	*) SCRIPT_DIR=$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd -P) ;;
esac
REPO_SLUG="${REPO_SLUG:-mozaroc/x-ui-pro}"
REPO_REF="${REPO_REF:-master}"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/${REPO_SLUG}/${REPO_REF}}"
SUB2SINGBOX_SERVICE="/etc/systemd/system/sub2sing-box.service"
SUBJSON_REWRITE_SERVICE="/etc/systemd/system/subjson-rewrite.service"
SUBJSON_REWRITE_BIN="/usr/local/bin/subjson-rewrite.py"
SUBJSON_REWRITE_PORT="${SUBJSON_REWRITE_PORT:-8091}"
SUBJSON_REWRITE_XUI_DB="${SUBJSON_REWRITE_XUI_DB:-/etc/x-ui/x-ui.db}"
SUBJSON_REWRITE_DNS_SERVERS="${SUBJSON_REWRITE_DNS_SERVERS:-https+local://1.1.1.1/dns-query,https+local://8.8.8.8/dns-query}"
SUBJSON_REWRITE_DNS_QUERY_STRATEGY="${SUBJSON_REWRITE_DNS_QUERY_STRATEGY:-UseIP}"
XUI_REPO_SLUG="${XUI_REPO_SLUG:-MHSanaei/3x-ui}"
XUI_VERSION="${XUI_VERSION:-v2.8.11}"
SUB2SINGBOX_REPO_SLUG="${SUB2SINGBOX_REPO_SLUG:-legiz-ru/sub2sing-box}"
SUB2SINGBOX_VERSION="${SUB2SINGBOX_VERSION:-v0.0.9}"
SUB2SINGBOX_ARCH="${SUB2SINGBOX_ARCH:-amd64}"
PROJECT_REPO_URL="${PROJECT_REPO_URL:-https://github.com/RM-COM/AT-VPN-System}"
PROJECT_SUPPORT_URL="${PROJECT_SUPPORT_URL:-${PROJECT_REPO_URL}}"
PROJECT_DONATE_URL="${PROJECT_DONATE_URL:-${PROJECT_REPO_URL}}"
PLATFORM_PROFILE="${PLATFORM_PROFILE:-classic}"
TRANSPORT_PROFILE="${TRANSPORT_PROFILE:-classic-xray}"
PANEL_PROVIDER="${PANEL_PROVIDER:-3x-ui}"
ENABLE_AWG="${ENABLE_AWG:-n}"
PLATFORM_ROOT=""
PLATFORM_METADATA_SOURCE="built-in"

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/core/platform-lib.sh" ]]; then
	# shellcheck disable=SC1091
	. "$SCRIPT_DIR/core/platform-lib.sh"
fi

if ! declare -F platform_init >/dev/null 2>&1; then
	platform_init() {
		PLATFORM_ROOT="${SCRIPT_DIR:-$PWD}"
		: "${PLATFORM_PROFILE:=classic}"
		: "${TRANSPORT_PROFILE:=classic-xray}"
		: "${PANEL_PROVIDER:=3x-ui}"
		: "${ENABLE_AWG:=n}"
		case "$PLATFORM_PROFILE" in
			classic)
				PLATFORM_PROFILE_LABEL="Classic"
				PLATFORM_PROFILE_DESCRIPTION="Current stable ingress baseline"
				PLATFORM_IMPLEMENTATION_STATE="ready"
				PLATFORM_INGRESS_OWNER="nginx-stream"
				PLATFORM_RUNTIME_TOKEN_LENGTH=10
				PLATFORM_CREDENTIAL_LENGTH=10
				PLATFORM_DYNAMIC_PORT_BASE=10000
				PLATFORM_DYNAMIC_PORT_SPAN=49152
				PLATFORM_PUBLIC_HTTP_PORT=80
				PLATFORM_PUBLIC_HTTPS_PORT=443
				PLATFORM_SUB2SINGBOX_BIND_PORT=8080
				;;
			stealth)
				PLATFORM_PROFILE_LABEL="Stealth"
				PLATFORM_PROFILE_DESCRIPTION="Anti-DPI profile with Xray on public 443 and local nginx fallback"
				PLATFORM_IMPLEMENTATION_STATE="ready"
				PLATFORM_INGRESS_OWNER="xray"
				PLATFORM_RUNTIME_TOKEN_LENGTH=10
				PLATFORM_CREDENTIAL_LENGTH=10
				PLATFORM_DYNAMIC_PORT_BASE=10000
				PLATFORM_DYNAMIC_PORT_SPAN=49152
				PLATFORM_PUBLIC_HTTP_PORT=80
				PLATFORM_PUBLIC_HTTPS_PORT=443
				PLATFORM_SUB2SINGBOX_BIND_PORT=8080
				;;
			*)
				printf 'Unsupported PLATFORM_PROFILE: %s\n' "$PLATFORM_PROFILE" >&2
				return 1
				;;
		esac

		case "$TRANSPORT_PROFILE" in
			classic-xray)
				TRANSPORT_PROFILE_LABEL="Classic Xray"
				TRANSPORT_PROFILE_DESCRIPTION="Current Xray baseline transport"
				TRANSPORT_IMPLEMENTATION_STATE="ready"
				TRANSPORT_STREAM_MODE="enabled"
				TRANSPORT_WEB_TLS_PORT=7443
				TRANSPORT_REALITY_SITE_TLS_PORT=9443
				TRANSPORT_REALITY_INBOUND_PORT=8443
				TRANSPORT_REALITY_XVER=0
				TRANSPORT_REALITY_ACCEPT_PROXY_PROTOCOL="true"
				TRANSPORT_REALITY_EXTERNAL_PROXY_DEST_MODE="domain"
				TRANSPORT_FALLBACK_TARGET="127.0.0.1:9443"
				TRANSPORT_REALITY_TUNING_PROFILE="default"
				TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
				TRANSPORT_REALITY_FINGERPRINT="random"
				TRANSPORT_REALITY_SPIDER_X="/"
				TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
				TRANSPORT_XHTTP_TUNING_PROFILE="default"
				TRANSPORT_XHTTP_MODE="auto"
				TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=30
				TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="1000000"
				TRANSPORT_XHTTP_NO_SSE_HEADER="false"
				TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
				TRANSPORT_XHTTP_XMUX_ENABLE="false"
				TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
				TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
				TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
				TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
				TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
				TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
				TRANSPORT_XHTTP_TCP_FAST_OPEN="true"
				TRANSPORT_XHTTP_TCP_MPTCP="true"
				TRANSPORT_XHTTP_TCP_NO_DELAY="true"
				TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
				TRANSPORT_XHTTP_TCP_MAX_SEG=1440
				TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=0
				TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=300
				TRANSPORT_XHTTP_TCP_USER_TIMEOUT=10000
				TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
				TRANSPORT_XHTTP_V6_ONLY="false"
				TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=600
				;;
	stealth-xray)
		TRANSPORT_PROFILE_LABEL="Stealth Xray"
		TRANSPORT_PROFILE_DESCRIPTION="Stealth Xray transport with public 443 and local nginx fallback"
				TRANSPORT_IMPLEMENTATION_STATE="ready"
				TRANSPORT_STREAM_MODE="disabled"
				TRANSPORT_WEB_TLS_PORT=7443
				TRANSPORT_REALITY_SITE_TLS_PORT=7443
				TRANSPORT_REALITY_INBOUND_PORT=443
				TRANSPORT_REALITY_XVER=1
				TRANSPORT_REALITY_ACCEPT_PROXY_PROTOCOL="false"
				TRANSPORT_REALITY_EXTERNAL_PROXY_DEST_MODE="reality_domain"
				TRANSPORT_FALLBACK_TARGET="127.0.0.1:7443"
		TRANSPORT_REALITY_TUNING_PROFILE="call-safe"
				TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
				TRANSPORT_REALITY_FINGERPRINT="chrome"
				TRANSPORT_REALITY_SPIDER_X="/"
				TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
				;;
	stealth-xhttp)
		TRANSPORT_PROFILE_LABEL="Stealth XHTTP"
		TRANSPORT_PROFILE_DESCRIPTION="Stealth XHTTP transport routed behind the public REALITY ingress shield"
				TRANSPORT_IMPLEMENTATION_STATE="ready"
				TRANSPORT_STREAM_MODE="disabled"
				TRANSPORT_WEB_TLS_PORT=7443
				TRANSPORT_REALITY_SITE_TLS_PORT=7443
				TRANSPORT_REALITY_INBOUND_PORT=443
				TRANSPORT_REALITY_XVER=1
				TRANSPORT_REALITY_ACCEPT_PROXY_PROTOCOL="false"
				TRANSPORT_REALITY_EXTERNAL_PROXY_DEST_MODE="reality_domain"
				TRANSPORT_FALLBACK_TARGET="127.0.0.1:7443"
		TRANSPORT_REALITY_TUNING_PROFILE="call-safe"
				TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
				TRANSPORT_REALITY_FINGERPRINT="chrome"
				TRANSPORT_REALITY_SPIDER_X="/"
				TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
		TRANSPORT_XHTTP_TUNING_PROFILE="realtime-media-safe"
				TRANSPORT_XHTTP_MODE="auto"
				TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=12
				TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="262144"
				TRANSPORT_XHTTP_NO_SSE_HEADER="false"
				TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
				TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
				TRANSPORT_XHTTP_TCP_MPTCP="false"
				TRANSPORT_XHTTP_TCP_NO_DELAY="true"
				TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
				TRANSPORT_XHTTP_TCP_MAX_SEG=1440
				TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=15
				TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=120
				TRANSPORT_XHTTP_TCP_USER_TIMEOUT=30000
				TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
				TRANSPORT_XHTTP_V6_ONLY="false"
				TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
				;;
	stealth-multi)
		TRANSPORT_PROFILE_LABEL="Stealth Multi"
		TRANSPORT_PROFILE_DESCRIPTION="Unified stealth baseline with REALITY shield and XHTTP in one install contour"
				TRANSPORT_IMPLEMENTATION_STATE="ready"
				TRANSPORT_STREAM_MODE="disabled"
				TRANSPORT_WEB_TLS_PORT=7443
				TRANSPORT_REALITY_SITE_TLS_PORT=7443
				TRANSPORT_REALITY_INBOUND_PORT=443
				TRANSPORT_REALITY_XVER=1
				TRANSPORT_REALITY_ACCEPT_PROXY_PROTOCOL="false"
				TRANSPORT_REALITY_EXTERNAL_PROXY_DEST_MODE="reality_domain"
				TRANSPORT_FALLBACK_TARGET="127.0.0.1:7443"
		TRANSPORT_REALITY_TUNING_PROFILE="call-safe"
				TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
				TRANSPORT_REALITY_FINGERPRINT="chrome"
				TRANSPORT_REALITY_SPIDER_X="/"
				TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
		TRANSPORT_XHTTP_TUNING_PROFILE="realtime-media-safe"
		TRANSPORT_XHTTP_MODE="stream-up"
		TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
		TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
				TRANSPORT_XHTTP_NO_SSE_HEADER="false"
				TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
				TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
				TRANSPORT_XHTTP_TCP_MPTCP="false"
				TRANSPORT_XHTTP_TCP_NO_DELAY="true"
				TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
				TRANSPORT_XHTTP_TCP_MAX_SEG=1440
		TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
		TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=15
		TRANSPORT_XHTTP_TCP_USER_TIMEOUT=9000
				TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
				TRANSPORT_XHTTP_V6_ONLY="false"
				TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
				;;
			*)
				printf 'Unsupported TRANSPORT_PROFILE: %s\n' "$TRANSPORT_PROFILE" >&2
				return 1
				;;
		esac

		case "$PLATFORM_PROFILE:$TRANSPORT_PROFILE" in
			classic:classic-xray|stealth:stealth-xray|stealth:stealth-xhttp|stealth:stealth-multi) ;;
			*)
				printf 'Unsupported PLATFORM_PROFILE/TRANSPORT_PROFILE combination: %s/%s\n' "$PLATFORM_PROFILE" "$TRANSPORT_PROFILE" >&2
				return 1
				;;
		esac

		case "$PANEL_PROVIDER" in
			3x-ui)
				PANEL_PROVIDER_LABEL="3x-ui"
				PANEL_PROVIDER_DESCRIPTION="Current baseline panel provider"
				PANEL_PROVIDER_PANEL_TITLE="X-UI Secure Panel"
				PANEL_PROVIDER_SERVICE_NAME="x-ui"
				PANEL_PROVIDER_CONTROL_BIN="x-ui"
				PANEL_PROVIDER_MIN_VERSION="2.3.5"
				PANEL_PROVIDER_BOOTSTRAP_USERNAME="asdfasdf"
				PANEL_PROVIDER_BOOTSTRAP_PASSWORD="asdfasdf"
				PANEL_PROVIDER_BOOTSTRAP_PORT="2096"
				PANEL_PROVIDER_BOOTSTRAP_BASE_PATH="asdfasdf"
				PANEL_PROVIDER_WEB_LISTEN=""
				PANEL_PROVIDER_WEB_DOMAIN=""
				PANEL_PROVIDER_WEB_CERT_FILE=""
				PANEL_PROVIDER_WEB_KEY_FILE=""
				PANEL_PROVIDER_SESSION_MAX_AGE="60"
				PANEL_PROVIDER_PAGE_SIZE="50"
				PANEL_PROVIDER_EXPIRE_DIFF="0"
				PANEL_PROVIDER_TRAFFIC_DIFF="0"
				PANEL_PROVIDER_REMARK_MODEL="-ieo"
				PANEL_PROVIDER_TG_BOT_ENABLE="false"
				PANEL_PROVIDER_TG_BOT_TOKEN=""
				PANEL_PROVIDER_TG_BOT_PROXY=""
				PANEL_PROVIDER_TG_BOT_API_SERVER=""
				PANEL_PROVIDER_TG_BOT_CHAT_ID=""
				PANEL_PROVIDER_TG_RUN_TIME="@daily"
				PANEL_PROVIDER_TG_BOT_BACKUP="false"
				PANEL_PROVIDER_TG_BOT_LOGIN_NOTIFY="true"
				PANEL_PROVIDER_TG_CPU="80"
				PANEL_PROVIDER_TG_LANG="en-US"
				PANEL_PROVIDER_TIME_LOCATION="Europe/Moscow"
				PANEL_PROVIDER_SECRET_ENABLE="false"
				PANEL_PROVIDER_SUB_ENABLE="true"
				PANEL_PROVIDER_SUB_JSON_ENABLE="true"
				PANEL_PROVIDER_SUB_DOMAIN=""
				PANEL_PROVIDER_SUB_CERT_FILE=""
				PANEL_PROVIDER_SUB_KEY_FILE=""
				PANEL_PROVIDER_SUB_UPDATES="12"
				PANEL_PROVIDER_SUB_ENCRYPT="true"
				PANEL_PROVIDER_SUB_SHOW_INFO="true"
				PANEL_PROVIDER_SUB_JSON_FRAGMENT=""
				PANEL_PROVIDER_SUB_JSON_NOISES=""
				PANEL_PROVIDER_SUB_JSON_MUX=""
				PANEL_PROVIDER_SUB_JSON_RULES=""
				PANEL_PROVIDER_DATEPICKER="gregorian"
				;;
			*)
				printf 'Unsupported PANEL_PROVIDER: %s\n' "$PANEL_PROVIDER" >&2
				return 1
				;;
		esac

		PLATFORM_METADATA_SOURCE="built-in"
		case "${ENABLE_AWG,,}" in
			n|no|0|false|off) ENABLE_AWG_STATE="disabled" ;;
			*) printf 'ENABLE_AWG is reserved for a future module and is not implemented yet.\n' >&2; return 1 ;;
		esac
		return 0
	}
	platform_selection_summary() {
		printf 'profile=%s transport=%s panel=%s awg=%s source=%s' \
			"$PLATFORM_PROFILE" \
			"$TRANSPORT_PROFILE" \
			"$PANEL_PROVIDER" \
			"${ENABLE_AWG_STATE:-disabled}" \
			"${PLATFORM_METADATA_SOURCE:-built-in}"
	}
fi

platform_panel_service_name() {
	printf '%s' "${PANEL_PROVIDER_SERVICE_NAME:-x-ui}"
}

platform_panel_control_bin() {
	printf '%s' "${PANEL_PROVIDER_CONTROL_BIN:-x-ui}"
}

platform_validate_tuning_profile_name() {
	local profile_name="$1"
	case "$profile_name" in
		default|mobile-safe|low-latency|handoff-safe|balanced-speed|realtime-safe|api-latency-safe|stream-one-safe|packet-up-safe|aggressive-stealth) return 0 ;;
		*) return 1 ;;
	esac
}

platform_validate_reality_tuning_profile_name() {
	local profile_name="$1"
	case "$profile_name" in
		default|mobile-safe|low-latency|call-safe|aggressive-stealth) return 0 ;;
		*) return 1 ;;
	esac
}

platform_validate_xhttp_tuning_profile_name() {
	local profile_name="$1"
	case "$profile_name" in
		default|mobile-safe|low-latency|handoff-safe|balanced-speed|realtime-safe|realtime-media-safe|packet-media-safe|api-latency-safe|stream-one-safe|packet-up-safe|aggressive-stealth) return 0 ;;
		*) return 1 ;;
	esac
}

platform_tuning_summary() {
	printf 'reality=%s xhttp=%s' \
		"${TRANSPORT_REALITY_TUNING_PROFILE:-default}" \
		"${TRANSPORT_XHTTP_TUNING_PROFILE:-n/a}"
}

platform_build_xhttp_xmux_block() {
	[[ "${TRANSPORT_XHTTP_XMUX_ENABLE:-false}" == "true" ]] || return 0
	cat <<EOF
,
    "xmux": {
      "maxConcurrency": "${TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY:-16-32}",
      "maxConnections": ${TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS:-0},
      "cMaxReuseTimes": ${TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES:-0},
      "hMaxRequestTimes": "${TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES:-600-900}",
      "hMaxReusableSecs": "${TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS:-1800-3000}",
      "hKeepAlivePeriod": ${TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD:-0}
    }
EOF
}

platform_build_reality_sockopt_block() {
	[[ -n "${TRANSPORT_REALITY_TCP_NO_DELAY:-}" ]] || return 0
	cat <<EOF
,
  "sockopt": {
    "tcpNoDelay": ${TRANSPORT_REALITY_TCP_NO_DELAY:-true},
    "domainStrategy": "${TRANSPORT_REALITY_DOMAIN_STRATEGY:-UseIP}",
    "tcpKeepAliveInterval": ${TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL:-5},
    "tcpKeepAliveIdle": ${TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE:-20},
    "tcpUserTimeout": ${TRANSPORT_REALITY_TCP_USER_TIMEOUT:-15000}
  }
EOF
}

write_platform_runtime_provenance_kv() {
	local target_file="$1"
	local key="$2"
	local value="$3"
	printf '%s=%q\n' "$key" "$value" >> "$target_file"
}

write_platform_runtime_provenance_file() {
	local provenance_file="${1:-$XUI_RUNTIME_PROVENANCE_FILE}"
	mkdir -p "$(dirname "$provenance_file")" || return 1
	: > "$provenance_file" || return 1
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_WRITTEN_AT" "$(timestamp)"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_SELECTION_SUMMARY" "$(platform_selection_summary)"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_PLATFORM_PROFILE" "${PLATFORM_PROFILE:-classic}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_TRANSPORT_PROFILE" "${TRANSPORT_PROFILE:-classic-xray}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_PANEL_PROVIDER" "${PANEL_PROVIDER:-3x-ui}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_REALITY_TUNING_PROFILE" "${TRANSPORT_REALITY_TUNING_PROFILE:-default}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_XHTTP_TUNING_PROFILE" "${TRANSPORT_XHTTP_TUNING_PROFILE:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_DOMAIN" "${domain:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_REALITY_DOMAIN" "${reality_domain:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_PANEL_PATH" "${panel_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_WEB_PATH" "${web_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_SUB_PATH" "${sub_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_JSON_PATH" "${json_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_SUB2SINGBOX_PATH" "${sub2singbox_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_XHTTP_PATH" "${xhttp_path:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_SUBJSON_DNS_SERVERS" "${SUBJSON_REWRITE_DNS_SERVERS:-}"
	write_platform_runtime_provenance_kv "$provenance_file" "RUNTIME_PROVENANCE_SUBJSON_DNS_QUERY_STRATEGY" "${SUBJSON_REWRITE_DNS_QUERY_STRATEGY:-}"
	append_debug_log "Runtime provenance written to ${provenance_file}"
}

load_platform_runtime_provenance_defaults() {
	local provenance_file="${1:-$XUI_RUNTIME_PROVENANCE_FILE}"
	[[ -f "$provenance_file" ]] || return 0
	# shellcheck disable=SC1090
	source "$provenance_file" 2>/dev/null || return 0
	[[ -n "${RUNTIME_PROVENANCE_PLATFORM_PROFILE:-}" ]] && PLATFORM_PROFILE="$RUNTIME_PROVENANCE_PLATFORM_PROFILE"
	[[ -n "${RUNTIME_PROVENANCE_TRANSPORT_PROFILE:-}" ]] && TRANSPORT_PROFILE="$RUNTIME_PROVENANCE_TRANSPORT_PROFILE"
	[[ -n "${RUNTIME_PROVENANCE_PANEL_PROVIDER:-}" ]] && PANEL_PROVIDER="$RUNTIME_PROVENANCE_PANEL_PROVIDER"
	platform_init >/dev/null 2>&1 || true
	if [[ -z "${OVERRIDE_REALITY_TUNING_PROFILE:-}" && -n "${RUNTIME_PROVENANCE_REALITY_TUNING_PROFILE:-}" ]]; then
		TRANSPORT_REALITY_TUNING_PROFILE="$RUNTIME_PROVENANCE_REALITY_TUNING_PROFILE"
	fi
	if [[ ( "$TRANSPORT_PROFILE" == "stealth-xhttp" || "$TRANSPORT_PROFILE" == "stealth-multi" ) && -z "${OVERRIDE_XHTTP_TUNING_PROFILE:-}" && -n "${RUNTIME_PROVENANCE_XHTTP_TUNING_PROFILE:-}" ]]; then
		TRANSPORT_XHTTP_TUNING_PROFILE="$RUNTIME_PROVENANCE_XHTTP_TUNING_PROFILE"
	fi
	[[ -z "$domain" && -n "${RUNTIME_PROVENANCE_DOMAIN:-}" ]] && domain="$RUNTIME_PROVENANCE_DOMAIN"
	[[ -z "$reality_domain" && -n "${RUNTIME_PROVENANCE_REALITY_DOMAIN:-}" ]] && reality_domain="$RUNTIME_PROVENANCE_REALITY_DOMAIN"
	[[ -z "$panel_path" && -n "${RUNTIME_PROVENANCE_PANEL_PATH:-}" ]] && panel_path="$RUNTIME_PROVENANCE_PANEL_PATH"
	[[ -z "$web_path" && -n "${RUNTIME_PROVENANCE_WEB_PATH:-}" ]] && web_path="$RUNTIME_PROVENANCE_WEB_PATH"
	[[ -z "$sub_path" && -n "${RUNTIME_PROVENANCE_SUB_PATH:-}" ]] && sub_path="$RUNTIME_PROVENANCE_SUB_PATH"
	[[ -z "$json_path" && -n "${RUNTIME_PROVENANCE_JSON_PATH:-}" ]] && json_path="$RUNTIME_PROVENANCE_JSON_PATH"
	[[ -z "$sub2singbox_path" && -n "${RUNTIME_PROVENANCE_SUB2SINGBOX_PATH:-}" ]] && sub2singbox_path="$RUNTIME_PROVENANCE_SUB2SINGBOX_PATH"
	[[ -z "$xhttp_path" && -n "${RUNTIME_PROVENANCE_XHTTP_PATH:-}" ]] && xhttp_path="$RUNTIME_PROVENANCE_XHTTP_PATH"
	append_debug_log "Loaded runtime provenance from ${provenance_file}"
}

platform_apply_reality_tuning_profile() {
	local selected_profile="$1"
	case "$selected_profile" in
		default)
			TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
			TRANSPORT_REALITY_FINGERPRINT="random"
			TRANSPORT_REALITY_SPIDER_X="/"
			TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
			TRANSPORT_REALITY_TCP_NO_DELAY=""
			TRANSPORT_REALITY_DOMAIN_STRATEGY=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE=""
			TRANSPORT_REALITY_TCP_USER_TIMEOUT=""
			;;
		mobile-safe)
			TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
			TRANSPORT_REALITY_FINGERPRINT="chrome"
			TRANSPORT_REALITY_SPIDER_X="/"
			TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
			TRANSPORT_REALITY_TCP_NO_DELAY=""
			TRANSPORT_REALITY_DOMAIN_STRATEGY=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE=""
			TRANSPORT_REALITY_TCP_USER_TIMEOUT=""
			;;
		low-latency)
			TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
			TRANSPORT_REALITY_FINGERPRINT="chrome"
			TRANSPORT_REALITY_SPIDER_X="/"
			TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
			TRANSPORT_REALITY_TCP_NO_DELAY=""
			TRANSPORT_REALITY_DOMAIN_STRATEGY=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE=""
			TRANSPORT_REALITY_TCP_USER_TIMEOUT=""
			;;
		call-safe)
			TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
			TRANSPORT_REALITY_FINGERPRINT="chrome"
			TRANSPORT_REALITY_SPIDER_X="/"
			TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
			TRANSPORT_REALITY_TCP_NO_DELAY="true"
			TRANSPORT_REALITY_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL=5
			TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE=20
			TRANSPORT_REALITY_TCP_USER_TIMEOUT=15000
			;;
		aggressive-stealth)
			TRANSPORT_REALITY_CLIENT_FLOW="xtls-rprx-vision"
			TRANSPORT_REALITY_FINGERPRINT="firefox"
			TRANSPORT_REALITY_SPIDER_X="/"
			TRANSPORT_REALITY_TCP_HEADER_TYPE="none"
			TRANSPORT_REALITY_TCP_NO_DELAY=""
			TRANSPORT_REALITY_DOMAIN_STRATEGY=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL=""
			TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE=""
			TRANSPORT_REALITY_TCP_USER_TIMEOUT=""
			;;
		*)
			die "Unsupported REALITY tuning profile: ${selected_profile}"
			;;
	esac
	TRANSPORT_REALITY_TUNING_PROFILE="$selected_profile"
}

platform_apply_xhttp_tuning_profile() {
	local selected_profile="$1"
	case "$selected_profile" in
		default)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=30
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="1000000"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="true"
			TRANSPORT_XHTTP_TCP_MPTCP="true"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=0
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=300
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=10000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=600
			;;
		mobile-safe)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=12
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="262144"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=15
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=120
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=30000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		low-latency)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=8
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="131072"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="true"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY="0"
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES="0"
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS="0"
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=5
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=30
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=10000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		handoff-safe)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=8
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="131072"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=15
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=7000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		balanced-speed)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=12
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="262144"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=20
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=9000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		realtime-safe)
			TRANSPORT_XHTTP_MODE="stream-up"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=8
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="131072"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=12
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=6000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		realtime-media-safe)
			TRANSPORT_XHTTP_MODE="stream-up"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=15
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=9000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		packet-media-safe)
			TRANSPORT_XHTTP_MODE="packet-up"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=3
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=15
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=9000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		api-latency-safe)
			TRANSPORT_XHTTP_MODE="stream-up"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=2
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=10
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=5000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		stream-one-safe)
			TRANSPORT_XHTTP_MODE="stream-one"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=2
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=10
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=5000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		packet-up-safe)
			TRANSPORT_XHTTP_MODE="packet-up"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=4
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="65536"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=2
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=10
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=5000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		aggressive-stealth)
			TRANSPORT_XHTTP_MODE="auto"
			TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS=24
			TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES="131072"
			TRANSPORT_XHTTP_NO_SSE_HEADER="false"
			TRANSPORT_XHTTP_X_PADDING_BYTES="100-1000"
			TRANSPORT_XHTTP_XMUX_ENABLE="false"
			TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY=""
			TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS=0
			TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES=0
			TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES=""
			TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS=""
			TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD=0
			TRANSPORT_XHTTP_TCP_FAST_OPEN="false"
			TRANSPORT_XHTTP_TCP_MPTCP="false"
			TRANSPORT_XHTTP_TCP_NO_DELAY="true"
			TRANSPORT_XHTTP_DOMAIN_STRATEGY="UseIP"
			TRANSPORT_XHTTP_TCP_MAX_SEG=1440
			TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL=20
			TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE=180
			TRANSPORT_XHTTP_TCP_USER_TIMEOUT=45000
			TRANSPORT_XHTTP_TCP_CONGESTION="bbr"
			TRANSPORT_XHTTP_V6_ONLY="false"
			TRANSPORT_XHTTP_TCP_WINDOW_CLAMP=0
			;;
		*)
			die "Unsupported XHTTP tuning profile: ${selected_profile}"
			;;
	esac
	TRANSPORT_XHTTP_TUNING_PROFILE="$selected_profile"
}

platform_apply_requested_tuning_profiles() {
	local requested_reality requested_xhttp
	requested_reality="${OVERRIDE_REALITY_TUNING_PROFILE:-${TRANSPORT_REALITY_TUNING_PROFILE:-default}}"
	requested_xhttp="${OVERRIDE_XHTTP_TUNING_PROFILE:-${TRANSPORT_XHTTP_TUNING_PROFILE:-default}}"

	if ! platform_validate_reality_tuning_profile_name "$requested_reality"; then
		die "Unsupported REALITY tuning profile: ${requested_reality}"
	fi
	platform_apply_reality_tuning_profile "$requested_reality"

	if [[ "$TRANSPORT_PROFILE" == "stealth-xhttp" || "$TRANSPORT_PROFILE" == "stealth-multi" ]]; then
		if ! platform_validate_xhttp_tuning_profile_name "$requested_xhttp"; then
			die "Unsupported XHTTP tuning profile: ${requested_xhttp}"
		fi
		platform_apply_xhttp_tuning_profile "$requested_xhttp"
	elif [[ -n "${OVERRIDE_XHTTP_TUNING_PROFILE:-}" ]]; then
		die "XHTTP tuning profile override is supported only for XHTTP-capable transport profiles. Current transport: ${TRANSPORT_PROFILE}"
	fi
}

platform_profile_state() {
	printf '%s' "${PLATFORM_IMPLEMENTATION_STATE:-ready}"
}

platform_ingress_owner() {
	printf '%s' "${PLATFORM_INGRESS_OWNER:-nginx-stream}"
}

platform_panel_min_version() {
	printf '%s' "${PANEL_PROVIDER_MIN_VERSION:-2.3.5}"
}

platform_panel_bootstrap_username() {
	printf '%s' "${PANEL_PROVIDER_BOOTSTRAP_USERNAME:-asdfasdf}"
}

platform_panel_bootstrap_password() {
	printf '%s' "${PANEL_PROVIDER_BOOTSTRAP_PASSWORD:-asdfasdf}"
}

platform_panel_bootstrap_port() {
	printf '%s' "${PANEL_PROVIDER_BOOTSTRAP_PORT:-2096}"
}

platform_panel_bootstrap_base_path() {
	printf '%s' "${PANEL_PROVIDER_BOOTSTRAP_BASE_PATH:-asdfasdf}"
}

platform_public_http_port() {
	printf '%s' "${PLATFORM_PUBLIC_HTTP_PORT:-80}"
}

platform_public_https_port() {
	printf '%s' "${PLATFORM_PUBLIC_HTTPS_PORT:-443}"
}

platform_runtime_token_length() {
	printf '%s' "${PLATFORM_RUNTIME_TOKEN_LENGTH:-10}"
}

platform_credential_length() {
	printf '%s' "${PLATFORM_CREDENTIAL_LENGTH:-10}"
}

platform_dynamic_port_base() {
	printf '%s' "${PLATFORM_DYNAMIC_PORT_BASE:-10000}"
}

platform_dynamic_port_span() {
	printf '%s' "${PLATFORM_DYNAMIC_PORT_SPAN:-49152}"
}

platform_transport_web_tls_port() {
	printf '%s' "${TRANSPORT_WEB_TLS_PORT:-7443}"
}

platform_transport_reality_site_tls_port() {
	printf '%s' "${TRANSPORT_REALITY_SITE_TLS_PORT:-9443}"
}

platform_transport_reality_inbound_port() {
	printf '%s' "${TRANSPORT_REALITY_INBOUND_PORT:-8443}"
}

platform_transport_reality_inbound_tag() {
	printf 'inbound-%s' "$(platform_transport_reality_inbound_port)"
}

platform_transport_reality_target() {
	printf '127.0.0.1:%s' "$(platform_transport_reality_site_tls_port)"
}

platform_transport_reality_xver() {
	printf '%s' "${TRANSPORT_REALITY_XVER:-0}"
}

platform_transport_reality_accept_proxy_protocol() {
	printf '%s' "${TRANSPORT_REALITY_ACCEPT_PROXY_PROTOCOL:-true}"
}

platform_transport_reality_external_proxy_dest() {
	case "${TRANSPORT_REALITY_EXTERNAL_PROXY_DEST_MODE:-domain}" in
		domain)
			printf '%s' "${domain}"
			;;
		reality_domain)
			printf '%s' "${reality_domain}"
			;;
		*)
			printf '%s' "${domain}"
			;;
	esac
}

platform_transport_state() {
	printf '%s' "${TRANSPORT_IMPLEMENTATION_STATE:-ready}"
}

platform_transport_stream_mode() {
	printf '%s' "${TRANSPORT_STREAM_MODE:-enabled}"
}

platform_transport_fallback_target() {
	printf '%s' "${TRANSPORT_FALLBACK_TARGET:-$(platform_transport_reality_target)}"
}

platform_sub2singbox_bind_port() {
	printf '%s' "${PLATFORM_SUB2SINGBOX_BIND_PORT:-8080}"
}

platform_selection_runtime_state() {
	if [[ "$(platform_profile_state)" == "ready" && "$(platform_transport_state)" == "ready" ]]; then
		printf 'ready'
	else
		printf 'planned'
	fi
}

platform_assert_runtime_selection_ready() {
	[[ "$(platform_selection_runtime_state)" == "ready" ]] && return 0
	if is_yes "$DRY_RUN"; then
		append_debug_log "Selection is staged only; dry-run continues without runtime activation."
		return 0
	fi
	die "Выбранный профиль ${PLATFORM_PROFILE}/${TRANSPORT_PROFILE} уже описан в selection-layer, но runtime-реализация этого профиля ещё не включена. Пока доступен только dry-run."
}

# Color codes used by install_panel()
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

##############################Message Helpers#############################################################
msg_ok()  { printf '\e[1;42m %s \e[0m\n' "$1"; }
msg_err() { printf '\e[1;41m %s \e[0m\n' "$1"; }
msg_inf() { printf '\e[1;34m%s\e[0m\n' "$1"; }
die()     { msg_err "$1"; exit "${2:-1}"; }
warn()    { printf '\e[1;33mWARN: %s\e[0m\n' "$1" >&2; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
is_yes() {
	case "${1,,}" in
		y|yes|1|true|on) return 0 ;;
		*) return 1 ;;
	esac
}
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
trim_slashes() {
	local value="${1#/}"
	value="${value%/}"
	printf '%s' "$value"
}
ensure_version_tag() {
	local value="$1"
	[[ -n "$value" ]] || return 0
	[[ "$value" == v* ]] || value="v${value}"
	printf '%s' "$value"
}
escape_sed_replacement() {
	printf '%s' "$1" | sed 's/[\/&#\\]/\\&/g'
}
extract_https_urls() {
	printf '%s' "$1" | grep -oE 'https://[^"'\''[:space:]<>()]+' | sed 's/[`,;]*$//' | sort -u
}
is_allowed_external_url() {
	local url="$1"
	[[ -n "$domain" && "$url" == "https://${domain}/"* ]] && return 0
	[[ -n "$PROJECT_SUPPORT_URL" && "$url" == "${PROJECT_SUPPORT_URL}"* ]] && return 0
	[[ -n "$PROJECT_DONATE_URL" && "$url" == "${PROJECT_DONATE_URL}"* ]] && return 0
	case "$url" in
		https://apps.apple.com/*|https://play.google.com/*|https://github.com/*|https://habr.com/*|https://v2raya.org/*|https://blancvpn.online/*|https://routing.vpn.ru.com/*|https://t.me/*)
			return 0
			;;
		*)
			return 1
			;;
	esac
}
collect_unexpected_external_urls() {
	local content="$1" url
	while IFS= read -r url; do
		[[ -n "$url" ]] || continue
		if ! is_allowed_external_url "$url"; then
			printf '%s\n' "$url"
		fi
	done < <(extract_https_urls "$content")
}
contains_forbidden_external_reference() {
	grep -Eq 'https://t\.me/gozargah_marzban|https://github\.com/Gozargah/Marzban#donation|https://example\.com/path/to/template\.json|https://github\.com/BLUEBL0B/Secret-Sing-Box/' <<<"$1"
}
DEBUG_MODE="n"
DRY_RUN="n"
VERIFY_MODE="n"
STAGE="all"
SKIP_CLEANUP="n"
KEEP_ARTIFACTS="n"
CONFIRM_RESET="n"
ACCEPTANCE_MINUTES="${ACCEPTANCE_MINUTES:-5}"
ACCEPTANCE_INTERVAL_SECONDS="${ACCEPTANCE_INTERVAL_SECONDS:-30}"
ACCEPTANCE_LABEL="${ACCEPTANCE_LABEL:-}"
ACCEPTANCE_MATRIX_GROUP="${ACCEPTANCE_MATRIX_GROUP:-}"
ACCEPTANCE_NETWORK_LABEL="${ACCEPTANCE_NETWORK_LABEL:-}"
ACCEPTANCE_OPERATOR_LABEL="${ACCEPTANCE_OPERATOR_LABEL:-}"
ACCEPTANCE_TIME_WINDOW="${ACCEPTANCE_TIME_WINDOW:-}"
ACCEPTANCE_CLIENT_DEVICE="${ACCEPTANCE_CLIENT_DEVICE:-}"
ACCEPTANCE_NOTES="${ACCEPTANCE_NOTES:-}"
DEBUG_ROOT="/root/x-ui-pro-debug"
DEBUG_DIR=""
DEBUG_LOG=""
append_debug_log() {
	[[ -n "$DEBUG_LOG" ]] || return 0
	printf '[%s] %s\n' "$(timestamp)" "$*" >> "$DEBUG_LOG"
}
capture_file_if_exists() {
	local source_path="$1" artifact_path="$2"
	[[ -n "$DEBUG_DIR" && -e "$source_path" ]] || return 0
	mkdir -p "$DEBUG_DIR/$(dirname "$artifact_path")"
	cp -a "$source_path" "$DEBUG_DIR/$artifact_path" 2>/dev/null || true
}
capture_command_output() {
	local artifact_path="$1"
	shift
	[[ -n "$DEBUG_DIR" ]] || return 0
	mkdir -p "$DEBUG_DIR/$(dirname "$artifact_path")"
	"$@" > "$DEBUG_DIR/$artifact_path" 2>&1 || true
}
acceptance_metadata_summary() {
	printf 'label=%s group=%s network=%s operator=%s window=%s client=%s' \
		"${ACCEPTANCE_LABEL:-<none>}" \
		"${ACCEPTANCE_MATRIX_GROUP:-<none>}" \
		"${ACCEPTANCE_NETWORK_LABEL:-<none>}" \
		"${ACCEPTANCE_OPERATOR_LABEL:-<none>}" \
		"${ACCEPTANCE_TIME_WINDOW:-<none>}" \
		"${ACCEPTANCE_CLIENT_DEVICE:-<none>}"
}
init_debug_session() {
	if [[ -n "$DEBUG_DIR" ]]; then
		return 0
	fi
	if ! is_yes "$DEBUG_MODE" && ! is_yes "$KEEP_ARTIFACTS"; then
		return 0
	fi
	DEBUG_DIR="${DEBUG_ROOT}/$(date '+%Y%m%d-%H%M%S')"
	mkdir -p "$DEBUG_DIR"
	DEBUG_LOG="${DEBUG_DIR}/run.log"
	touch "$DEBUG_LOG"
	append_debug_log "Debug session initialized"
	append_debug_log "Script path: ${SCRIPT_SOURCE}"
	append_debug_log "Script directory: ${SCRIPT_DIR:-<stream>}"
	if is_yes "$DEBUG_MODE"; then
		exec 9>>"$DEBUG_LOG"
		export BASH_XTRACEFD=9
		export PS4='+ [$(date "+%Y-%m-%d %H:%M:%S")] ${BASH_SOURCE##*/}:${LINENO}: '
		set -x
	fi
	msg_inf "Debug artifacts: ${DEBUG_DIR}"
}

run_sensitive() {
	local had_xtrace=""
	if [[ "$-" == *x* ]]; then
		had_xtrace="yes"
		set +x
	fi
	"$@"
	local rc=$?
	if [[ -n "$had_xtrace" ]]; then
		set -x
	fi
	return "$rc"
}

print_sensitive_printf() {
	local had_xtrace=""
	if [[ "$-" == *x* ]]; then
		had_xtrace="yes"
		set +x
	fi
	printf "$@"
	local rc=$?
	if [[ -n "$had_xtrace" ]]; then
		set -x
	fi
	return "$rc"
}

print_runtime_context() {
	append_debug_log "Runtime context:"
	append_debug_log "  platform_root=${PLATFORM_ROOT:-<empty>}"
	append_debug_log "  platform_selection=$(platform_selection_summary)"
	append_debug_log "  platform_runtime_state=$(platform_selection_runtime_state)"
	append_debug_log "  platform_profile_state=$(platform_profile_state)"
	append_debug_log "  transport_profile_state=$(platform_transport_state)"
	append_debug_log "  ingress_owner=$(platform_ingress_owner)"
	append_debug_log "  transport_stream_mode=$(platform_transport_stream_mode)"
	append_debug_log "  transport_fallback_target=$(platform_transport_fallback_target)"
	append_debug_log "  runtime_token_length=$(platform_runtime_token_length)"
	append_debug_log "  credential_length=$(platform_credential_length)"
	append_debug_log "  dynamic_port_base=$(platform_dynamic_port_base)"
	append_debug_log "  dynamic_port_span=$(platform_dynamic_port_span)"
	append_debug_log "  public_http_port=$(platform_public_http_port)"
	append_debug_log "  public_https_port=$(platform_public_https_port)"
	append_debug_log "  sub2singbox_bind_port=$(platform_sub2singbox_bind_port)"
	append_debug_log "  panel_min_version=$(platform_panel_min_version)"
	append_debug_log "  panel_bootstrap_port=$(platform_panel_bootstrap_port)"
	append_debug_log "  panel_bootstrap_base_path=$(platform_panel_bootstrap_base_path)"
	append_debug_log "  panel_provider_time_location=${PANEL_PROVIDER_TIME_LOCATION:-Europe/Moscow}"
	append_debug_log "  panel_provider_tg_lang=${PANEL_PROVIDER_TG_LANG:-en-US}"
	append_debug_log "  panel_provider_sub_updates=${PANEL_PROVIDER_SUB_UPDATES:-12}"
	append_debug_log "  transport_web_tls_port=$(platform_transport_web_tls_port)"
	append_debug_log "  transport_reality_site_tls_port=$(platform_transport_reality_site_tls_port)"
	append_debug_log "  transport_reality_inbound_port=$(platform_transport_reality_inbound_port)"
	append_debug_log "  transport_reality_xver=$(platform_transport_reality_xver)"
	append_debug_log "  transport_reality_accept_proxy_protocol=$(platform_transport_reality_accept_proxy_protocol)"
	append_debug_log "  transport_reality_tuning_profile=${TRANSPORT_REALITY_TUNING_PROFILE:-default}"
	append_debug_log "  transport_reality_client_flow=${TRANSPORT_REALITY_CLIENT_FLOW:-xtls-rprx-vision}"
	append_debug_log "  transport_reality_fingerprint=${TRANSPORT_REALITY_FINGERPRINT:-random}"
	append_debug_log "  transport_reality_spider_x=${TRANSPORT_REALITY_SPIDER_X:-/}"
	append_debug_log "  transport_reality_tcp_no_delay=${TRANSPORT_REALITY_TCP_NO_DELAY:-<unset>}"
	append_debug_log "  transport_reality_domain_strategy=${TRANSPORT_REALITY_DOMAIN_STRATEGY:-<unset>}"
	append_debug_log "  transport_reality_tcp_keepalive_interval=${TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL:-<unset>}"
	append_debug_log "  transport_reality_tcp_keepalive_idle=${TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE:-<unset>}"
	append_debug_log "  transport_reality_tcp_user_timeout=${TRANSPORT_REALITY_TCP_USER_TIMEOUT:-<unset>}"
	append_debug_log "  override_reality_tuning_profile=${OVERRIDE_REALITY_TUNING_PROFILE:-<none>}"
	if [[ -n "${TRANSPORT_XHTTP_MODE:-}" ]]; then
		append_debug_log "  transport_xhttp_tuning_profile=${TRANSPORT_XHTTP_TUNING_PROFILE:-default}"
	append_debug_log "  transport_xhttp_mode=${TRANSPORT_XHTTP_MODE:-auto}"
		append_debug_log "  transport_xhttp_sc_max_buffered_posts=${TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS:-30}"
		append_debug_log "  transport_xhttp_sc_max_each_post_bytes=${TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES:-1000000}"
		append_debug_log "  transport_xhttp_x_padding_bytes=${TRANSPORT_XHTTP_X_PADDING_BYTES:-100-1000}"
		append_debug_log "  transport_xhttp_tcp_mptcp=${TRANSPORT_XHTTP_TCP_MPTCP:-true}"
		append_debug_log "  transport_xhttp_tcp_user_timeout=${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-10000}"
		append_debug_log "  transport_xhttp_tcp_window_clamp=${TRANSPORT_XHTTP_TCP_WINDOW_CLAMP:-600}"
		append_debug_log "  override_xhttp_tuning_profile=${OVERRIDE_XHTTP_TUNING_PROFILE:-<none>}"
	fi
	append_debug_log "  domain=${domain:-<empty>}"
	append_debug_log "  reality_domain=${reality_domain:-<empty>}"
	append_debug_log "  panel_port=${panel_port:-<empty>}"
	append_debug_log "  panel_path=${panel_path:-<empty>}"
	append_debug_log "  sub_path=${sub_path:-<empty>}"
	append_debug_log "  json_path=${json_path:-<empty>}"
	append_debug_log "  web_path=${web_path:-<empty>}"
	append_debug_log "  sub2singbox_path=${sub2singbox_path:-<empty>}"
	append_debug_log "  sub_uri=${sub_uri:-<empty>}"
	append_debug_log "  json_uri=${json_uri:-<empty>}"
}
platform_generate_runtime_defaults() {
	local token_length credential_length
	token_length="$(platform_runtime_token_length)"
	credential_length="$(platform_credential_length)"

	sub_port=$(make_port)
	panel_port=$(make_port)
	web_path=$(gen_random_string "$token_length")
	sub2singbox_path=$(gen_random_string "$token_length")
	sub_path=$(gen_random_string "$token_length")
	json_path=$(gen_random_string "$token_length")
	panel_path=$(gen_random_string "$token_length")
	ws_port=$(make_port)
	trojan_port=$(make_port)
	ws_path=$(gen_random_string "$token_length")
	trojan_path=$(gen_random_string "$token_length")
	xhttp_path=$(gen_random_string "$token_length")
	config_username=$(gen_random_string "$credential_length")
	config_password=$(gen_random_string "$credential_length")
}
print_execution_plan() {
	msg_inf "Активная сборка: $(platform_selection_summary)"
	msg_inf "Текущий transport tuning: $(platform_tuning_summary)"
	if [[ "$(platform_selection_runtime_state)" != "ready" ]]; then
		msg_inf "Профиль находится в staged-режиме: dry-run уже показывает новую selection-модель, но реальная runtime-установка будет открыта отдельным следующим срезом."
	fi
	msg_inf "DRY-RUN: инсталляция не будет менять систему."
	msg_inf "План действий:"
	msg_inf "1. Подготовка окружения и очистка предыдущей установки."
	msg_inf "2. Генерация путей, портов и конфигурации."
	msg_inf "3. Установка пакетов, SSL и nginx."
	msg_inf "4. Установка 3x-ui, sub2sing-box, fake-site и web-sub."
	msg_inf "5. Проверка сервисов и вывод итоговых данных."
	print_runtime_context
}
print_reset_plan() {
	msg_inf "DRY-RUN reset: staging node will not be modified."
	msg_inf "Reset plan:"
	msg_inf "1. Capture debug artifacts from the current installation state."
	msg_inf "2. Stop nginx, x-ui and sub2sing-box."
	msg_inf "3. Run full uninstall for x-ui/nginx/certbot."
	msg_inf "4. Remove residual web-sub, nginx, certbot and binary paths."
	msg_inf "5. Verify that ports 80/443 are free and install artifacts are gone."
	print_runtime_context
}
print_acceptance_plan() {
	msg_inf "DRY-RUN acceptance: будет выполнен только план сравнительной приёмки stealth-профиля."
	msg_inf "Acceptance plan:"
	msg_inf "1. Восстановить runtime-контекст текущего stealth-профиля."
	msg_inf "2. Выполнить строгий verify как базовую server-side приёмку."
	msg_inf "3. Прогнать циклические HTTPS-пробы panel/web-sub/sub2sing-box/fallback через public 443."
	msg_inf "4. Сохранить отчёт и чек-лист ручной клиентской проверки в debug artifacts."
	msg_inf "5. Использовать отчёт для сравнения stealth-xray и stealth-xhttp."
	msg_inf "Acceptance duration (minutes): ${ACCEPTANCE_MINUTES}"
	msg_inf "Acceptance interval (seconds): ${ACCEPTANCE_INTERVAL_SECONDS}"
	msg_inf "Текущий transport tuning: $(platform_tuning_summary)"
	msg_inf "Acceptance metadata: $(acceptance_metadata_summary)"
	print_runtime_context
}
load_existing_runtime_context() {
	local detected_site detected_reality_port detected_xhttp_inbound
	if [[ "$PLATFORM_PROFILE" == "classic" && "$TRANSPORT_PROFILE" == "classic-xray" && -f "$XUIDB" ]]; then
		detected_reality_port=$(sqlite3 -list "$XUIDB" "SELECT port FROM inbounds WHERE port=$(platform_public_https_port) AND instr(stream_settings, 'reality') > 0 LIMIT 1;" 2>/dev/null | tr -d '[:space:]')
		if [[ "$detected_reality_port" == "$(platform_public_https_port)" ]]; then
			PLATFORM_PROFILE="stealth"
			detected_xhttp_inbound=$(sqlite3 -list "$XUIDB" "SELECT COUNT(*) FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp';" 2>/dev/null | tr -d '[:space:]')
			if [[ "$detected_xhttp_inbound" =~ ^[1-9][0-9]*$ ]]; then
				TRANSPORT_PROFILE="stealth-xhttp"
			else
				TRANSPORT_PROFILE="stealth-xray"
			fi
			platform_init >/dev/null 2>&1 || true
			append_debug_log "Autodetected installed selection: ${PLATFORM_PROFILE}/${TRANSPORT_PROFILE}"
		fi
	fi
	load_platform_runtime_provenance_defaults
	platform_apply_requested_tuning_profiles >/dev/null 2>&1 || true
	if [[ -f "$XUIDB" ]]; then
		panel_port=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>/dev/null)
		sub_port=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subPort" LIMIT 1;' 2>/dev/null)
		panel_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webBasePath" LIMIT 1;' 2>/dev/null)")
		sub_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subPath" LIMIT 1;' 2>/dev/null)")
		json_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subJsonPath" LIMIT 1;' 2>/dev/null)")
		sub_uri=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subURI" LIMIT 1;' 2>/dev/null)
		json_uri=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subJsonURI" LIMIT 1;' 2>/dev/null)
		if [[ -z "$xhttp_path" ]]; then
			xhttp_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" "SELECT json_extract(stream_settings, '$.xhttpSettings.path') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null)")
		fi
		if [[ -z "$reality_domain" ]]; then
			reality_domain=$(sqlite3 -list "$XUIDB" "SELECT json_extract(stream_settings, '$.realitySettings.serverNames[0]') FROM inbounds WHERE json_extract(stream_settings, '$.security')='reality' LIMIT 1;" 2>/dev/null | head -n1)
		fi
	fi
	if [[ -z "$domain" ]]; then
		domain=$(printf '%s\n%s\n' "$sub_uri" "$json_uri" | sed -nE 's#https?://([^/]+)/.*#\1#p' | head -n1)
	fi
	if [[ -z "$reality_domain" ]]; then
		detected_site=$(ls -1 /etc/nginx/sites-enabled 2>/dev/null \
			| grep -vx '80.conf' \
			| grep -vx "${domain}" \
			| head -n1)
		[[ -n "$detected_site" ]] && reality_domain="$detected_site"
	fi
	if [[ -z "$web_path" && "$json_uri" == *"?name="* ]]; then
		web_path=$(printf '%s' "$json_uri" | sed -nE 's#https?://[^/]+/([^/?]+)/?.*#\1#p' | head -n1)
	fi
	if [[ -f /etc/nginx/snippets/includes.conf ]]; then
		if [[ -z "$sub2singbox_path" ]]; then
			sub2singbox_path=$(sed -nE 's#^[[:space:]]*location /([^/]+)/ \{#\1#p' /etc/nginx/snippets/includes.conf | head -n1)
		fi
		if [[ -z "$web_path" ]]; then
			web_path=$(sed -nE 's#^[[:space:]]*location = /([^[:space:]]+) \{#\1#p' /etc/nginx/snippets/includes.conf | head -n1)
		fi
	fi
	if [[ -z "$domain" ]]; then
		detected_site=$(grep -Rsl "listen $(platform_transport_web_tls_port) ssl http2 proxy_protocol;" /etc/nginx/sites-enabled 2>/dev/null | head -n1)
		[[ -n "$detected_site" ]] && domain=$(basename "$detected_site")
	fi
	if [[ -z "$sub_uri" && -n "$domain" && -n "$sub_path" ]]; then
		sub_uri="https://${domain}/${sub_path}/"
	fi
	if [[ -z "$json_uri" && -n "$domain" && -n "$json_path" ]]; then
		json_uri="https://${domain}/${json_path}/"
	fi
	print_runtime_context
}
record_verify_result() {
	local status="$1" message="$2"
	append_debug_log "VERIFY ${status}: ${message}"
	if [[ "$status" == "PASS" ]]; then
		printf '[PASS] %s\n' "$message"
	else
		printf '[FAIL] %s\n' "$message"
	fi
}
record_acceptance_result() {
	local status="$1" message="$2"
	append_debug_log "ACCEPT ${status}: ${message}"
	if [[ "$status" == "PASS" ]]; then
		printf '[PASS] %s\n' "$message"
	else
		printf '[FAIL] %s\n' "$message"
	fi
}
acceptance_artifact_path() {
	local name="$1"
	[[ -n "$DEBUG_DIR" ]] || return 1
	printf '%s/acceptance/%s' "$DEBUG_DIR" "$name"
}
capture_acceptance_snapshot() {
	[[ -n "$DEBUG_DIR" ]] || return 0
	capture_command_output "acceptance/ss-lntp.txt" ss -lntp
	capture_command_output "acceptance/ss-tinp.txt" ss -tinp
	capture_command_output "acceptance/ss-summary.txt" ss -s
	capture_command_output "acceptance/systemctl-nginx.txt" systemctl status nginx --no-pager
	capture_command_output "acceptance/systemctl-x-ui.txt" systemctl status x-ui --no-pager
	capture_command_output "acceptance/journal-nginx.txt" journalctl -u nginx -n 200 --no-pager
	capture_command_output "acceptance/journal-x-ui.txt" journalctl -u x-ui -n 200 --no-pager
	if [[ -f "$SUB2SINGBOX_SERVICE" ]]; then
		capture_command_output "acceptance/systemctl-sub2sing-box.txt" systemctl status sub2sing-box --no-pager
		capture_command_output "acceptance/journal-sub2sing-box.txt" journalctl -u sub2sing-box -n 200 --no-pager
	fi
	if [[ -f "$SUBJSON_REWRITE_SERVICE" ]]; then
		capture_command_output "acceptance/systemctl-subjson-rewrite.txt" systemctl status subjson-rewrite --no-pager
		capture_command_output "acceptance/journal-subjson-rewrite.txt" journalctl -u subjson-rewrite -n 200 --no-pager
	fi
}
write_acceptance_runtime_snapshot() {
	local snapshot_file sqlite_file
	[[ -n "$DEBUG_DIR" ]] || return 0
	snapshot_file="$(acceptance_artifact_path "runtime-snapshot.env")"
	mkdir -p "$(dirname "$snapshot_file")"
	cat > "$snapshot_file" <<EOF
timestamp=$(timestamp)
selection_summary=$(platform_selection_summary)
tuning_summary=$(platform_tuning_summary)
platform_profile=${PLATFORM_PROFILE}
transport_profile=${TRANSPORT_PROFILE}
panel_provider=${PANEL_PROVIDER}
transport_reality_tuning_profile=${TRANSPORT_REALITY_TUNING_PROFILE:-default}
transport_reality_client_flow=${TRANSPORT_REALITY_CLIENT_FLOW:-xtls-rprx-vision}
transport_reality_fingerprint=${TRANSPORT_REALITY_FINGERPRINT:-random}
transport_reality_spider_x=${TRANSPORT_REALITY_SPIDER_X:-/}
transport_reality_tcp_no_delay=${TRANSPORT_REALITY_TCP_NO_DELAY:-}
transport_reality_domain_strategy=${TRANSPORT_REALITY_DOMAIN_STRATEGY:-}
transport_reality_tcp_keepalive_interval=${TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL:-}
transport_reality_tcp_keepalive_idle=${TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE:-}
transport_reality_tcp_user_timeout=${TRANSPORT_REALITY_TCP_USER_TIMEOUT:-}
override_reality_tuning_profile=${OVERRIDE_REALITY_TUNING_PROFILE:-}
transport_xhttp_tuning_profile=${TRANSPORT_XHTTP_TUNING_PROFILE:-}
transport_xhttp_mode=${TRANSPORT_XHTTP_MODE:-}
transport_xhttp_sc_max_buffered_posts=${TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS:-}
transport_xhttp_sc_max_each_post_bytes=${TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES:-}
transport_xhttp_x_padding_bytes=${TRANSPORT_XHTTP_X_PADDING_BYTES:-}
transport_xhttp_tcp_fast_open=${TRANSPORT_XHTTP_TCP_FAST_OPEN:-}
transport_xhttp_tcp_mptcp=${TRANSPORT_XHTTP_TCP_MPTCP:-}
transport_xhttp_tcp_keepalive_interval=${TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL:-}
transport_xhttp_tcp_keepalive_idle=${TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE:-}
transport_xhttp_tcp_user_timeout=${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-}
transport_xhttp_tcp_window_clamp=${TRANSPORT_XHTTP_TCP_WINDOW_CLAMP:-}
override_xhttp_tuning_profile=${OVERRIDE_XHTTP_TUNING_PROFILE:-}
acceptance_label=${ACCEPTANCE_LABEL:-}
acceptance_matrix_group=${ACCEPTANCE_MATRIX_GROUP:-}
acceptance_network_label=${ACCEPTANCE_NETWORK_LABEL:-}
acceptance_operator_label=${ACCEPTANCE_OPERATOR_LABEL:-}
acceptance_time_window=${ACCEPTANCE_TIME_WINDOW:-}
acceptance_client_device=${ACCEPTANCE_CLIENT_DEVICE:-}
acceptance_notes=${ACCEPTANCE_NOTES:-}
domain=${domain:-}
reality_domain=${reality_domain:-}
panel_path=${panel_path:-}
web_path=${web_path:-}
sub_path=${sub_path:-}
json_path=${json_path:-}
sub2singbox_path=${sub2singbox_path:-}
xhttp_path=${xhttp_path:-}
subjson_rewrite_dns_servers=${SUBJSON_REWRITE_DNS_SERVERS:-}
subjson_rewrite_dns_query_strategy=${SUBJSON_REWRITE_DNS_QUERY_STRATEGY:-}
EOF
	append_debug_log "Acceptance runtime snapshot written to ${snapshot_file}"
	if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$XUIDB" ]]; then
		sqlite_file="$(acceptance_artifact_path "xui-inbounds-summary.txt")"
		sqlite3 -line "$XUIDB" "
SELECT
  remark,
  port,
  protocol,
  json_extract(stream_settings, '$.network') AS network,
  json_extract(stream_settings, '$.security') AS security,
  json_extract(stream_settings, '$.realitySettings.settings.fingerprint') AS fingerprint,
  json_extract(stream_settings, '$.xhttpSettings.mode') AS xhttp_mode,
  json_extract(stream_settings, '$.xhttpSettings.scMaxBufferedPosts') AS xhttp_sc_max_buffered_posts,
  json_type(stream_settings, '$.xhttpSettings.xmux') AS xhttp_xmux_type,
  json_extract(stream_settings, '$.xhttpSettings.xmux.maxConcurrency') AS xhttp_xmux_max_concurrency,
  json_extract(stream_settings, '$.xhttpSettings.xmux.maxConnections') AS xhttp_xmux_max_connections,
  json_extract(stream_settings, '$.xhttpSettings.xmux.cMaxReuseTimes') AS xhttp_xmux_c_max_reuse_times,
  json_extract(stream_settings, '$.xhttpSettings.xmux.hMaxRequestTimes') AS xhttp_xmux_h_max_request_times,
  json_extract(stream_settings, '$.xhttpSettings.xmux.hMaxReusableSecs') AS xhttp_xmux_h_max_reusable_secs,
  json_extract(stream_settings, '$.xhttpSettings.xmux.hKeepAlivePeriod') AS xhttp_xmux_h_keepalive_period,
  json_extract(stream_settings, '$.sockopt.tcpFastOpen') AS tcp_fast_open,
  json_extract(stream_settings, '$.sockopt.tcpMptcp') AS tcp_mptcp,
  json_extract(stream_settings, '$.sockopt.tcpUserTimeout') AS tcp_user_timeout
FROM inbounds
WHERE json_extract(stream_settings, '$.security')='reality'
   OR json_extract(stream_settings, '$.network')='xhttp';
" > "$sqlite_file" 2>&1 || true
		append_debug_log "Acceptance inbound summary written to ${sqlite_file}"
	fi
}
write_acceptance_session_metadata() {
	local metadata_file
	[[ -n "$DEBUG_DIR" ]] || return 0
	metadata_file="$(acceptance_artifact_path "session-metadata.env")"
	mkdir -p "$(dirname "$metadata_file")"
	cat > "$metadata_file" <<EOF
timestamp=$(timestamp)
acceptance_label=${ACCEPTANCE_LABEL:-}
acceptance_matrix_group=${ACCEPTANCE_MATRIX_GROUP:-}
acceptance_network_label=${ACCEPTANCE_NETWORK_LABEL:-}
acceptance_operator_label=${ACCEPTANCE_OPERATOR_LABEL:-}
acceptance_time_window=${ACCEPTANCE_TIME_WINDOW:-}
acceptance_client_device=${ACCEPTANCE_CLIENT_DEVICE:-}
acceptance_notes=${ACCEPTANCE_NOTES:-}
selection_summary=$(platform_selection_summary)
tuning_summary=$(platform_tuning_summary)
EOF
	append_debug_log "Acceptance session metadata written to ${metadata_file}"
}
acceptance_metric_value() {
	local metrics="$1" key="$2"
	printf '%s\n' "$metrics" | tr ' ' '\n' | awk -F= -v target="$key" '$1 == target { print $2; exit }'
}
response_has_header() {
	local headers="$1" header_name="$2" expected_fragment="${3:-}"
	local header_line=""
	header_line="$(printf '%s\n' "$headers" | grep -iE "^${header_name}:" | head -n1 || true)"
	[[ -n "$header_line" ]] || return 1
	if [[ -n "$expected_fragment" ]]; then
		grep -qi -- "$expected_fragment" <<<"$header_line"
		return $?
	fi
	return 0
}
append_acceptance_probe_result_jsonl() {
	local iteration="$1" label="$2" host="$3" path="$4" status="$5" curl_metrics="$6"
	local jsonl_file http_code remote_ip time_namelookup time_connect time_appconnect time_starttransfer time_total
	[[ -n "$DEBUG_DIR" ]] || return 0
	command -v jq >/dev/null 2>&1 || return 0
	jsonl_file="$(acceptance_artifact_path "probe-results.jsonl")"
	mkdir -p "$(dirname "$jsonl_file")"
	http_code="$(acceptance_metric_value "$curl_metrics" "http_code")"
	remote_ip="$(acceptance_metric_value "$curl_metrics" "remote_ip")"
	time_namelookup="$(acceptance_metric_value "$curl_metrics" "time_namelookup")"
	time_connect="$(acceptance_metric_value "$curl_metrics" "time_connect")"
	time_appconnect="$(acceptance_metric_value "$curl_metrics" "time_appconnect")"
	time_starttransfer="$(acceptance_metric_value "$curl_metrics" "time_starttransfer")"
	time_total="$(acceptance_metric_value "$curl_metrics" "time_total")"
	jq -cn \
		--arg timestamp "$(timestamp)" \
		--arg selection_summary "$(platform_selection_summary)" \
		--arg tuning_summary "$(platform_tuning_summary)" \
		--arg platform_profile "${PLATFORM_PROFILE}" \
		--arg transport_profile "${TRANSPORT_PROFILE}" \
		--arg panel_provider "${PANEL_PROVIDER}" \
		--arg reality_tuning_profile "${TRANSPORT_REALITY_TUNING_PROFILE:-default}" \
		--arg xhttp_tuning_profile "${TRANSPORT_XHTTP_TUNING_PROFILE:-}" \
		--arg label "${label}" \
		--arg host "${host}" \
		--arg path "${path}" \
		--arg status "${status}" \
		--arg metrics_raw "${curl_metrics}" \
		--arg http_code "${http_code:-}" \
		--arg remote_ip "${remote_ip:-}" \
		--arg time_namelookup "${time_namelookup:-}" \
		--arg time_connect "${time_connect:-}" \
		--arg time_appconnect "${time_appconnect:-}" \
		--arg time_starttransfer "${time_starttransfer:-}" \
		--arg time_total "${time_total:-}" \
		--arg acceptance_label "${ACCEPTANCE_LABEL:-}" \
		--arg acceptance_matrix_group "${ACCEPTANCE_MATRIX_GROUP:-}" \
		--arg acceptance_network_label "${ACCEPTANCE_NETWORK_LABEL:-}" \
		--arg acceptance_operator_label "${ACCEPTANCE_OPERATOR_LABEL:-}" \
		--arg acceptance_time_window "${ACCEPTANCE_TIME_WINDOW:-}" \
		--arg acceptance_client_device "${ACCEPTANCE_CLIENT_DEVICE:-}" \
		--arg acceptance_notes "${ACCEPTANCE_NOTES:-}" \
		--argjson iteration "${iteration:-0}" \
		'{
			timestamp: $timestamp,
			iteration: $iteration,
			status: $status,
			probe: {
				label: $label,
				host: $host,
				path: $path,
				url: ("https://" + $host + $path)
			},
			selection: {
				summary: $selection_summary,
				tuning: $tuning_summary,
				platform_profile: $platform_profile,
				transport_profile: $transport_profile,
				panel_provider: $panel_provider,
				reality_tuning_profile: $reality_tuning_profile,
				xhttp_tuning_profile: $xhttp_tuning_profile
			},
			matrix: {
				label: $acceptance_label,
				group: $acceptance_matrix_group,
				network: $acceptance_network_label,
				operator: $acceptance_operator_label,
				time_window: $acceptance_time_window,
				client_device: $acceptance_client_device,
				notes: $acceptance_notes
			},
			metrics: {
				http_code: $http_code,
				remote_ip: $remote_ip,
				time_namelookup: $time_namelookup,
				time_connect: $time_connect,
				time_appconnect: $time_appconnect,
				time_starttransfer: $time_starttransfer,
				time_total: $time_total,
				raw: $metrics_raw
			}
		}' >> "$jsonl_file"
	append_debug_log "Acceptance probe JSONL appended to ${jsonl_file}: ${label}/${status}/iteration=${iteration}"
}
write_acceptance_matrix_row_json() {
	local failures="${1:-0}" panel_passes="${2:-0}" panel_fails="${3:-0}" websub_passes="${4:-0}" websub_fails="${5:-0}"
	local sub2singbox_passes="${6:-0}" sub2singbox_fails="${7:-0}" fallback_passes="${8:-0}" fallback_fails="${9:-0}"
	local json_passes="${10:-0}" json_fails="${11:-0}" transport_reality_passes="${12:-0}" transport_reality_fails="${13:-0}"
	local transport_xhttp_passes="${14:-0}" transport_xhttp_fails="${15:-0}"
	local matrix_file
	[[ -n "$DEBUG_DIR" ]] || return 0
	command -v jq >/dev/null 2>&1 || return 0
	matrix_file="$(acceptance_artifact_path "matrix-row.json")"
	mkdir -p "$(dirname "$matrix_file")"
	jq -n \
		--arg generated_at "$(timestamp)" \
		--arg selection_summary "$(platform_selection_summary)" \
		--arg tuning_summary "$(platform_tuning_summary)" \
		--arg platform_profile "${PLATFORM_PROFILE}" \
		--arg transport_profile "${TRANSPORT_PROFILE}" \
		--arg panel_provider "${PANEL_PROVIDER}" \
		--arg reality_tuning_profile "${TRANSPORT_REALITY_TUNING_PROFILE:-default}" \
		--arg xhttp_tuning_profile "${TRANSPORT_XHTTP_TUNING_PROFILE:-}" \
		--arg subjson_rewrite_dns_servers "${SUBJSON_REWRITE_DNS_SERVERS:-}" \
		--arg subjson_rewrite_dns_query_strategy "${SUBJSON_REWRITE_DNS_QUERY_STRATEGY:-}" \
		--arg acceptance_label "${ACCEPTANCE_LABEL:-}" \
		--arg acceptance_matrix_group "${ACCEPTANCE_MATRIX_GROUP:-}" \
		--arg acceptance_network_label "${ACCEPTANCE_NETWORK_LABEL:-}" \
		--arg acceptance_operator_label "${ACCEPTANCE_OPERATOR_LABEL:-}" \
		--arg acceptance_time_window "${ACCEPTANCE_TIME_WINDOW:-}" \
		--arg acceptance_client_device "${ACCEPTANCE_CLIENT_DEVICE:-}" \
		--arg acceptance_notes "${ACCEPTANCE_NOTES:-}" \
		--arg domain "${domain:-}" \
		--arg reality_domain "${reality_domain:-}" \
		--arg panel_path "${panel_path:-}" \
		--arg web_path "${web_path:-}" \
		--arg sub_path "${sub_path:-}" \
		--arg json_path "${json_path:-}" \
		--arg sub2singbox_path "${sub2singbox_path:-}" \
		--arg xhttp_path "${xhttp_path:-}" \
		--arg checklist_path "acceptance/manual-client-checklist.md" \
		--arg probe_results_path "acceptance/probe-results.jsonl" \
		--arg runtime_snapshot_path "acceptance/runtime-snapshot.env" \
		--arg session_metadata_path "acceptance/session-metadata.env" \
		--arg probe_summary_path "acceptance/summary.txt" \
		--argjson public_https_port "$(platform_public_https_port)" \
		--argjson acceptance_minutes "${ACCEPTANCE_MINUTES:-0}" \
		--argjson acceptance_interval_seconds "${ACCEPTANCE_INTERVAL_SECONDS:-0}" \
		--argjson total_failures "${failures}" \
		--argjson panel_passes "${panel_passes}" \
		--argjson panel_fails "${panel_fails}" \
		--argjson websub_passes "${websub_passes}" \
		--argjson websub_fails "${websub_fails}" \
		--argjson sub2singbox_passes "${sub2singbox_passes}" \
		--argjson sub2singbox_fails "${sub2singbox_fails}" \
		--argjson fallback_passes "${fallback_passes}" \
		--argjson fallback_fails "${fallback_fails}" \
		--argjson json_passes "${json_passes}" \
		--argjson json_fails "${json_fails}" \
		--argjson transport_reality_passes "${transport_reality_passes}" \
		--argjson transport_reality_fails "${transport_reality_fails}" \
		--argjson transport_xhttp_passes "${transport_xhttp_passes}" \
		--argjson transport_xhttp_fails "${transport_xhttp_fails}" \
		'{
			generated_at: $generated_at,
			selection: {
				summary: $selection_summary,
				tuning: $tuning_summary,
				platform_profile: $platform_profile,
				transport_profile: $transport_profile,
				panel_provider: $panel_provider,
				reality_tuning_profile: $reality_tuning_profile,
				xhttp_tuning_profile: $xhttp_tuning_profile,
				subjson_rewrite_dns_servers: $subjson_rewrite_dns_servers,
				subjson_rewrite_dns_query_strategy: $subjson_rewrite_dns_query_strategy
			},
			matrix: {
				label: $acceptance_label,
				group: $acceptance_matrix_group,
				network: $acceptance_network_label,
				operator: $acceptance_operator_label,
				time_window: $acceptance_time_window,
				client_device: $acceptance_client_device,
				notes: $acceptance_notes
			},
			targets: {
				public_https_port: $public_https_port,
				domain: $domain,
				reality_domain: $reality_domain,
				panel_path: $panel_path,
				web_path: $web_path,
				sub_path: $sub_path,
				json_path: $json_path,
				sub2singbox_path: $sub2singbox_path,
				xhttp_path: $xhttp_path
			},
			run: {
				acceptance_minutes: $acceptance_minutes,
				acceptance_interval_seconds: $acceptance_interval_seconds
			},
			server_probe_summary: {
				total_failures: $total_failures,
				panel: { pass: $panel_passes, fail: $panel_fails },
				web_sub: { pass: $websub_passes, fail: $websub_fails },
				sub2sing_box: { pass: $sub2singbox_passes, fail: $sub2singbox_fails },
				fallback_root: { pass: $fallback_passes, fail: $fallback_fails },
				subscription_json: { pass: $json_passes, fail: $json_fails },
				transport_reality: { pass: $transport_reality_passes, fail: $transport_reality_fails },
				transport_xhttp: { pass: $transport_xhttp_passes, fail: $transport_xhttp_fails }
			},
			manual_fields: {
				result: "",
				start_msk: "",
				failure_msk: "",
				symptom: "",
				reconnect_helped: "",
				handoff_issue: "",
				client_error: "",
				client_log_excerpt: ""
			},
			artifacts: {
				checklist_path: $checklist_path,
				probe_results_path: $probe_results_path,
				runtime_snapshot_path: $runtime_snapshot_path,
				session_metadata_path: $session_metadata_path,
				probe_summary_path: $probe_summary_path
			}
		}' > "$matrix_file"
	append_debug_log "Acceptance matrix row written to ${matrix_file}"
}
platform_normalize_expected_sqlite_value() {
	local raw_value="$1"
	case "$raw_value" in
		true) printf '1' ;;
		false) printf '0' ;;
		*) printf '%s' "$raw_value" ;;
	esac
}

verify_transport_tuning_contract() {
	local actual_reality actual_xhttp
	local actual_fingerprint actual_spider actual_header
	local actual_reality_no_delay actual_reality_domain_strategy actual_reality_keepalive_interval actual_reality_keepalive_idle actual_reality_user_timeout
	local actual_mode actual_buffered actual_each_bytes actual_padding
	local actual_fast_open actual_mptcp actual_keepalive_interval actual_keepalive_idle actual_user_timeout actual_window_clamp
	local mismatch_count=0

	if ! command -v sqlite3 >/dev/null 2>&1 || [[ ! -f "$XUIDB" ]]; then
		return 0
	fi

	actual_reality=$(sqlite3 -separator '|' -list "$XUIDB" "
SELECT
  COALESCE(json_extract(stream_settings, '$.realitySettings.settings.fingerprint'), ''),
  COALESCE(json_extract(stream_settings, '$.realitySettings.settings.spiderX'), ''),
  COALESCE(json_extract(stream_settings, '$.tcpSettings.header.type'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpNoDelay'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.domainStrategy'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpKeepAliveInterval'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpKeepAliveIdle'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpUserTimeout'), '')
FROM inbounds
WHERE json_extract(stream_settings, '$.security')='reality'
LIMIT 1;
" 2>/dev/null)
	IFS='|' read -r actual_fingerprint actual_spider actual_header actual_reality_no_delay actual_reality_domain_strategy actual_reality_keepalive_interval actual_reality_keepalive_idle actual_reality_user_timeout <<<"$actual_reality"
	append_debug_log "verify reality tuning fingerprint=${actual_fingerprint:-<empty>} spiderX=${actual_spider:-<empty>} header=${actual_header:-<empty>} tcpNoDelay=${actual_reality_no_delay:-<empty>} domainStrategy=${actual_reality_domain_strategy:-<empty>} keepalive_interval=${actual_reality_keepalive_interval:-<empty>} keepalive_idle=${actual_reality_keepalive_idle:-<empty>} user_timeout=${actual_reality_user_timeout:-<empty>}"
	if [[ "${actual_reality_no_delay:-}" == "$(platform_normalize_expected_sqlite_value "${TRANSPORT_REALITY_TCP_NO_DELAY:-}")" ]]; then
		record_verify_result "PASS" "REALITY tcpNoDelay matches preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY tcpNoDelay does not match preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_reality_domain_strategy:-}" == "${TRANSPORT_REALITY_DOMAIN_STRATEGY:-}" ]]; then
		record_verify_result "PASS" "REALITY domainStrategy matches preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY domainStrategy does not match preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_reality_keepalive_interval:-}" == "${TRANSPORT_REALITY_TCP_KEEPALIVE_INTERVAL:-}" ]]; then
		record_verify_result "PASS" "REALITY tcpKeepAliveInterval matches preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY tcpKeepAliveInterval does not match preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_reality_keepalive_idle:-}" == "${TRANSPORT_REALITY_TCP_KEEPALIVE_IDLE:-}" ]]; then
		record_verify_result "PASS" "REALITY tcpKeepAliveIdle matches preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY tcpKeepAliveIdle does not match preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_reality_user_timeout:-}" == "${TRANSPORT_REALITY_TCP_USER_TIMEOUT:-}" ]]; then
		record_verify_result "PASS" "REALITY tcpUserTimeout matches preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY tcpUserTimeout does not match preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi

	if [[ "${actual_fingerprint:-}" == "${TRANSPORT_REALITY_FINGERPRINT:-}" ]]; then
		record_verify_result "PASS" "REALITY fingerprint соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY fingerprint не соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_spider:-}" == "${TRANSPORT_REALITY_SPIDER_X:-}" ]]; then
		record_verify_result "PASS" "REALITY spiderX соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY spiderX не соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi
	if [[ "${actual_header:-}" == "${TRANSPORT_REALITY_TCP_HEADER_TYPE:-}" ]]; then
		record_verify_result "PASS" "REALITY tcp header соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
	else
		record_verify_result "FAIL" "REALITY tcp header не соответствует preset '${TRANSPORT_REALITY_TUNING_PROFILE:-default}'"
		mismatch_count=$((mismatch_count + 1))
	fi

	if [[ "$TRANSPORT_PROFILE" == "stealth-xhttp" || "$TRANSPORT_PROFILE" == "stealth-multi" ]]; then
		actual_xhttp=$(sqlite3 -separator '|' -list "$XUIDB" "
SELECT
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.mode'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.scMaxBufferedPosts'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.scMaxEachPostBytes'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xPaddingBytes'), ''),
  COALESCE(json_type(stream_settings, '$.xhttpSettings.xmux'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.maxConcurrency'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.maxConnections'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.cMaxReuseTimes'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.hMaxRequestTimes'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.hMaxReusableSecs'), ''),
  COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux.hKeepAlivePeriod'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpFastOpen'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpMptcp'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpKeepAliveInterval'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpKeepAliveIdle'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpUserTimeout'), ''),
  COALESCE(json_extract(stream_settings, '$.sockopt.tcpWindowClamp'), '')
FROM inbounds
WHERE json_extract(stream_settings, '$.network')='xhttp'
LIMIT 1;
" 2>/dev/null)
		IFS='|' read -r actual_mode actual_buffered actual_each_bytes actual_padding actual_xmux_type actual_xmux_max_concurrency actual_xmux_max_connections actual_xmux_c_max_reuse_times actual_xmux_h_max_request_times actual_xmux_h_max_reusable_secs actual_xmux_h_keepalive_period actual_fast_open actual_mptcp actual_keepalive_interval actual_keepalive_idle actual_user_timeout actual_window_clamp <<<"$actual_xhttp"
		append_debug_log "verify xhttp tuning mode=${actual_mode:-<empty>} buffered=${actual_buffered:-<empty>} bytes=${actual_each_bytes:-<empty>} padding=${actual_padding:-<empty>} xmux_type=${actual_xmux_type:-<empty>} xmux_max_concurrency=${actual_xmux_max_concurrency:-<empty>} xmux_max_connections=${actual_xmux_max_connections:-<empty>} xmux_c_max_reuse_times=${actual_xmux_c_max_reuse_times:-<empty>} xmux_h_max_request_times=${actual_xmux_h_max_request_times:-<empty>} xmux_h_max_reusable_secs=${actual_xmux_h_max_reusable_secs:-<empty>} xmux_h_keepalive_period=${actual_xmux_h_keepalive_period:-<empty>} fastopen=${actual_fast_open:-<empty>} mptcp=${actual_mptcp:-<empty>} keepalive_interval=${actual_keepalive_interval:-<empty>} keepalive_idle=${actual_keepalive_idle:-<empty>} timeout=${actual_user_timeout:-<empty>} clamp=${actual_window_clamp:-<empty>}"

		if [[ "${actual_mode:-}" == "${TRANSPORT_XHTTP_MODE:-}" ]]; then
			record_verify_result "PASS" "XHTTP mode соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP mode не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_buffered:-}" == "${TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS:-}" ]]; then
			record_verify_result "PASS" "XHTTP scMaxBufferedPosts соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP scMaxBufferedPosts не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_each_bytes:-}" == "${TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES:-}" ]]; then
			record_verify_result "PASS" "XHTTP scMaxEachPostBytes соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP scMaxEachPostBytes не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_padding:-}" == "${TRANSPORT_XHTTP_X_PADDING_BYTES:-}" ]]; then
			record_verify_result "PASS" "XHTTP xPaddingBytes соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP xPaddingBytes не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${TRANSPORT_XHTTP_XMUX_ENABLE:-false}" == "true" ]]; then
			if [[ "${actual_xmux_type:-}" == "object" ]]; then
				record_verify_result "PASS" "XHTTP xmux present for preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux missing for preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_max_concurrency:-}" == "${TRANSPORT_XHTTP_XMUX_MAX_CONCURRENCY:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.maxConcurrency matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.maxConcurrency does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_max_connections:-}" == "${TRANSPORT_XHTTP_XMUX_MAX_CONNECTIONS:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.maxConnections matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.maxConnections does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_c_max_reuse_times:-}" == "${TRANSPORT_XHTTP_XMUX_C_MAX_REUSE_TIMES:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.cMaxReuseTimes matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.cMaxReuseTimes does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_h_max_request_times:-}" == "${TRANSPORT_XHTTP_XMUX_H_MAX_REQUEST_TIMES:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.hMaxRequestTimes matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.hMaxRequestTimes does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_h_max_reusable_secs:-}" == "${TRANSPORT_XHTTP_XMUX_H_MAX_REUSABLE_SECS:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.hMaxReusableSecs matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.hMaxReusableSecs does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
			if [[ "${actual_xmux_h_keepalive_period:-}" == "${TRANSPORT_XHTTP_XMUX_H_KEEPALIVE_PERIOD:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux.hKeepAlivePeriod matches preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux.hKeepAlivePeriod does not match preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
		else
			if [[ -z "${actual_xmux_type:-}" ]]; then
				record_verify_result "PASS" "XHTTP xmux disabled for preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			else
				record_verify_result "FAIL" "XHTTP xmux should be disabled for preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
				mismatch_count=$((mismatch_count + 1))
			fi
		fi
		if [[ "${actual_fast_open:-}" == "$(platform_normalize_expected_sqlite_value "${TRANSPORT_XHTTP_TCP_FAST_OPEN:-}")" ]]; then
			record_verify_result "PASS" "XHTTP tcpFastOpen соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpFastOpen не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_mptcp:-}" == "$(platform_normalize_expected_sqlite_value "${TRANSPORT_XHTTP_TCP_MPTCP:-}")" ]]; then
			record_verify_result "PASS" "XHTTP tcpMptcp соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpMptcp не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_keepalive_interval:-}" == "${TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL:-}" ]]; then
			record_verify_result "PASS" "XHTTP tcpKeepAliveInterval соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpKeepAliveInterval не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_keepalive_idle:-}" == "${TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE:-}" ]]; then
			record_verify_result "PASS" "XHTTP tcpKeepAliveIdle соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpKeepAliveIdle не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_user_timeout:-}" == "${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-}" ]]; then
			record_verify_result "PASS" "XHTTP tcpUserTimeout соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpUserTimeout не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
		if [[ "${actual_window_clamp:-}" == "${TRANSPORT_XHTTP_TCP_WINDOW_CLAMP:-}" ]]; then
			record_verify_result "PASS" "XHTTP tcpWindowClamp соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
		else
			record_verify_result "FAIL" "XHTTP tcpWindowClamp не соответствует preset '${TRANSPORT_XHTTP_TUNING_PROFILE:-default}'"
			mismatch_count=$((mismatch_count + 1))
		fi
	fi

	return "$mismatch_count"
}
transport_profile_has_xhttp() {
	case "$TRANSPORT_PROFILE" in
		stealth-xhttp|stealth-multi) return 0 ;;
		*) return 1 ;;
	esac
}
transport_profile_has_reality() {
	case "$TRANSPORT_PROFILE" in
		stealth-xray|stealth-multi) return 0 ;;
		*) return 1 ;;
	esac
}
transport_probe_reset_state() {
	TRANSPORT_PROBE_LAST_METRICS=""
	TRANSPORT_PROBE_LAST_FAILURE_HINT=""
	TRANSPORT_PROBE_LAST_TARGET_URL=""
	TRANSPORT_PROBE_LAST_TARGET_HOST=""
	TRANSPORT_PROBE_LAST_TARGET_PATH=""
}
transport_probe_target_url() {
	if [[ -n "$domain" && -n "$web_path" ]]; then
		printf 'https://%s/%s/' "$domain" "$web_path"
		return 0
	fi
	if [[ -n "$domain" ]]; then
		printf 'https://%s/' "$domain"
		return 0
	fi
	return 1
}
run_local_transport_probe() {
	local transport_kind="$1" artifact_prefix="$2"
	local xray_bin="" test_dir="" config_file="" xray_log="" curl_log="" body_file="" headers_file=""
	local curl_metrics="" curl_output="" curl_rc=0 xray_pid="" failure_hint=""
	local target_url="" target_host="" target_path="" public_https_port=""
	local probe_client_id="" probe_flow="" probe_address="" probe_server_name="" probe_public_key=""
	local probe_short_id="" probe_fingerprint="" probe_spider_x="" probe_mode="" probe_host=""
	local probe_path_db="" probe_xmux_json=""

	transport_probe_reset_state

	if ! command -v sqlite3 >/dev/null 2>&1 || [[ ! -f "$XUIDB" ]]; then
		append_debug_log "${transport_kind} transport probe cannot start without sqlite3 and ${XUIDB}"
		return 1
	fi
	if ! command -v jq >/dev/null 2>&1; then
		append_debug_log "${transport_kind} transport probe cannot start without jq"
		return 1
	fi

	if [[ -x /usr/local/x-ui/bin/xray-linux-amd64 ]]; then
		xray_bin="/usr/local/x-ui/bin/xray-linux-amd64"
	else
		xray_bin="$(command -v xray 2>/dev/null || true)"
	fi
	if [[ -z "$xray_bin" || ! -x "$xray_bin" ]]; then
		append_debug_log "${transport_kind} transport probe cannot find an executable Xray binary"
		return 1
	fi

	if ! target_url="$(transport_probe_target_url)"; then
		append_debug_log "${transport_kind} transport probe cannot resolve target URL"
		return 1
	fi
	target_host="${target_url#https://}"
	target_host="${target_host%%/*}"
	if [[ "$target_url" == "https://${target_host}" || "$target_url" == "https://${target_host}/" ]]; then
		target_path="/"
	else
		target_path="/${target_url#https://${target_host}/}"
	fi
	public_https_port="$(platform_public_https_port)"

	case "$transport_kind" in
		xhttp)
			probe_client_id=$(sqlite3 -list "$XUIDB" "SELECT json_extract(settings, '$.clients[0].id') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			probe_path_db=$(sqlite3 -list "$XUIDB" "SELECT json_extract(stream_settings, '$.xhttpSettings.path') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			probe_host=$(sqlite3 -list "$XUIDB" "SELECT COALESCE(json_extract(stream_settings, '$.xhttpSettings.host'), '') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			probe_mode=$(sqlite3 -list "$XUIDB" "SELECT COALESCE(json_extract(stream_settings, '$.xhttpSettings.mode'), '') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			probe_xmux_json=$(sqlite3 -list "$XUIDB" "SELECT COALESCE(json_extract(stream_settings, '$.xhttpSettings.xmux'), 'null') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			probe_path_db="$(trim_slashes "$probe_path_db")"
			[[ -z "$probe_mode" ]] && probe_mode="${TRANSPORT_XHTTP_MODE:-auto}"
			[[ -z "$probe_xmux_json" ]] && probe_xmux_json='null'
			if [[ -z "$domain" || -z "$probe_path_db" || -z "$probe_client_id" ]]; then
				append_debug_log "xhttp transport probe cannot resolve domain/path/client id from the current installation"
				return 1
			fi
			;;
		reality)
			local reality_row=""
			reality_row=$(sqlite3 -separator '|' -list "$XUIDB" "
SELECT
  COALESCE(json_extract(settings, '$.clients[0].id'), ''),
  COALESCE(json_extract(settings, '$.clients[0].flow'), ''),
  COALESCE(json_extract(stream_settings, '$.realitySettings.settings.publicKey'), json_extract(stream_settings, '$.realitySettings.publicKey'), json_extract(stream_settings, '$.realitySettings.password'), ''),
  COALESCE(json_extract(stream_settings, '$.realitySettings.serverNames[0]'), ''),
  COALESCE(json_extract(stream_settings, '$.realitySettings.shortIds[0]'), ''),
  COALESCE(json_extract(stream_settings, '$.realitySettings.settings.fingerprint'), 'chrome'),
  COALESCE(json_extract(stream_settings, '$.realitySettings.settings.spiderX'), '/')
FROM inbounds
WHERE json_extract(stream_settings, '$.security')='reality'
LIMIT 1;
" 2>/dev/null)
			IFS='|' read -r probe_client_id probe_flow probe_public_key probe_server_name probe_short_id probe_fingerprint probe_spider_x <<<"$reality_row"
			[[ -z "$probe_server_name" ]] && probe_server_name="${reality_domain:-$domain}"
			probe_address="$probe_server_name"
			if [[ -z "$probe_client_id" || -z "$probe_public_key" || -z "$probe_server_name" || -z "$probe_short_id" ]]; then
				append_debug_log "reality transport probe cannot resolve public key/serverName/shortId/client id from the current installation"
				return 1
			fi
			;;
		*)
			append_debug_log "unsupported transport probe kind: ${transport_kind}"
			return 1
			;;
	esac

	test_dir="$(mktemp -d)"
	config_file="${test_dir}/${transport_kind}-selftest.json"
	xray_log="${test_dir}/${transport_kind}-selftest.xray.log"
	curl_log="${test_dir}/${transport_kind}-selftest.curl.log"
	body_file="${test_dir}/${transport_kind}-selftest.body"
	headers_file="${test_dir}/${transport_kind}-selftest.headers"

	case "$transport_kind" in
		xhttp)
			jq -n \
				--arg uuid "$probe_client_id" \
				--arg domain "$domain" \
				--arg path "/${probe_path_db}" \
				--arg mode "$probe_mode" \
				--arg host "$probe_host" \
				--argjson xmux "$probe_xmux_json" \
				'{
					log: { loglevel: "info" },
					inbounds: [
						{
							tag: "socks-in",
							port: 10881,
							listen: "127.0.0.1",
							protocol: "socks",
							settings: { udp: false }
						}
					],
					outbounds: [
						{
							tag: "xhttp-selftest",
							protocol: "vless",
							settings: {
								vnext: [
									{
										address: $domain,
										port: 443,
										users: [
											{
												id: $uuid,
												encryption: "none"
											}
										]
									}
								]
							},
							streamSettings: {
								network: "xhttp",
								security: "tls",
								tlsSettings: {
									serverName: $domain,
									fingerprint: "chrome",
									alpn: ["h2"]
								},
								xhttpSettings: (
									{ path: $path, mode: $mode } +
									(if $host != "" then { host: $host } else {} end) +
									(if $xmux != null then { xmux: $xmux } else {} end)
								)
							}
						}
					]
				}' > "$config_file"
			;;
		reality)
			jq -n \
				--arg uuid "$probe_client_id" \
				--arg flow "$probe_flow" \
				--arg address "$probe_address" \
				--argjson port "$public_https_port" \
				--arg serverName "$probe_server_name" \
				--arg publicKey "$probe_public_key" \
				--arg shortId "$probe_short_id" \
				--arg fingerprint "$probe_fingerprint" \
				--arg spiderX "$probe_spider_x" \
				'{
					log: { loglevel: "info" },
					inbounds: [
						{
							tag: "socks-in",
							port: 10881,
							listen: "127.0.0.1",
							protocol: "socks",
							settings: { udp: false }
						}
					],
					outbounds: [
						{
							tag: "reality-selftest",
							protocol: "vless",
							settings: {
								vnext: [
									{
										address: $address,
										port: $port,
										users: [
											(
												{ id: $uuid, encryption: "none" } +
												(if $flow != "" then { flow: $flow } else {} end)
											)
										]
									}
								]
							},
							streamSettings: {
								network: "tcp",
								security: "reality",
								realitySettings: {
									serverName: $serverName,
									publicKey: $publicKey,
									shortId: $shortId,
									fingerprint: $fingerprint,
									spiderX: $spiderX
								}
							}
						}
					]
				}' > "$config_file"
			;;
	esac

	append_debug_log "${transport_kind} transport probe target_url=${target_url} target_host=${target_host} target_path=${target_path} config=${config_file}"
	"$xray_bin" run -c "$config_file" > "$xray_log" 2>&1 &
	xray_pid=$!
	sleep 2
	curl_metrics=$(curl --max-time 20 --socks5 127.0.0.1:10881 -kfsS -D "$headers_file" -o "$body_file" -w 'http_code=%{http_code} remote_ip=%{remote_ip} time_namelookup=%{time_namelookup} time_connect=%{time_connect} time_appconnect=%{time_appconnect} time_starttransfer=%{time_starttransfer} time_total=%{time_total}\n' "$target_url" 2>"$curl_log")
	curl_rc=$?
	curl_output="$(cat "$curl_log" 2>/dev/null)"
	kill "$xray_pid" >/dev/null 2>&1 || true
	wait "$xray_pid" 2>/dev/null || true

	TRANSPORT_PROBE_LAST_METRICS="$curl_metrics"
	TRANSPORT_PROBE_LAST_TARGET_URL="$target_url"
	TRANSPORT_PROBE_LAST_TARGET_HOST="$target_host"
	TRANSPORT_PROBE_LAST_TARGET_PATH="$target_path"

	capture_file_if_exists "$config_file" "${artifact_prefix}.json"
	capture_file_if_exists "$xray_log" "${artifact_prefix}.xray.log"
	capture_file_if_exists "$curl_log" "${artifact_prefix}.curl.log"
	capture_file_if_exists "$headers_file" "${artifact_prefix}.headers.txt"
	capture_file_if_exists "$body_file" "${artifact_prefix}.body"

	if [[ "$curl_rc" -eq 0 ]]; then
		rm -rf "$test_dir"
		return 0
	fi

	failure_hint=$(grep -E 'unexpected status|failed to send upload|XHTTP is dialing|REALITY|handshake|proxy/vless/outbound|failed to dial|EOF' "$xray_log" 2>/dev/null | tail -n 4 | tr '\n' '; ')
	TRANSPORT_PROBE_LAST_FAILURE_HINT="${failure_hint:-curl=${curl_rc}}"
	append_debug_log "${transport_kind} transport probe curl output: ${curl_output}"
	append_debug_log "${transport_kind} transport probe failure hint: ${TRANSPORT_PROBE_LAST_FAILURE_HINT}"
	rm -rf "$test_dir"
	return 1
}
xhttp_transport_self_test() {
	transport_profile_has_xhttp || return 0
	if run_local_transport_probe "xhttp" "commands/xhttp-selftest"; then
		record_verify_result "PASS" "Stealth XHTTP transport self-test passed through local loopback client"
		return 0
	fi
	record_verify_result "FAIL" "Stealth XHTTP transport self-test failed (${TRANSPORT_PROBE_LAST_FAILURE_HINT:-probe failed})"
	return 1
}
reality_transport_self_test() {
	transport_profile_has_reality || return 0
	if run_local_transport_probe "reality" "commands/reality-selftest"; then
		record_verify_result "PASS" "Stealth REALITY transport self-test passed through local loopback client"
		return 0
	fi
	record_verify_result "FAIL" "Stealth REALITY transport self-test failed (${TRANSPORT_PROBE_LAST_FAILURE_HINT:-probe failed})"
	return 1
}
write_acceptance_manual_checklist() {
	local checklist_file public_https_port client_target_hint client_log_hint transport_extra_url secondary_target_hint
	[[ -n "$DEBUG_DIR" ]] || return 0
	public_https_port="$(platform_public_https_port)"
	checklist_file="$(acceptance_artifact_path "manual-client-checklist.md")"
	mkdir -p "$(dirname "$checklist_file")"
	case "$TRANSPORT_PROFILE" in
		stealth-xhttp)
			client_target_hint="Для client-load проверки выбирайте узел remark \`🇷🇺 xhttp\`, а не \`🇷🇺 reality-shield\`."
			client_log_hint="Если в логе \`v2rayN\` видны строки \`REALITY ... DialTLSContext\`, значит выбран shield-профиль, а не \`xhttp\`."
			transport_extra_url="- XHTTP path: https://${domain:-<domain>}/${xhttp_path:-<xhttp_path>}"
			secondary_target_hint="- Дополнительный контроль: отдельно прогоните \`🇷🇺 reality-shield\` как reality-only узел в той же мобильной сети."
			;;
		stealth-multi)
			client_target_hint="Для client-load проверки сравнивайте оба узла из одной установки: \`🇷🇺 reality-shield\` как low-latency профиль и \`🇷🇺 xhttp\` как stealth-профиль."
			client_log_hint="Для \`reality-shield\` строки \`REALITY ... DialTLSContext\` ожидаемы; для \`xhttp\` ориентируйтесь на импортированный JSON/XHTTP-профиль."
			transport_extra_url="- XHTTP path: https://${domain:-<domain>}/${xhttp_path:-<xhttp_path>}"
			secondary_target_hint="- Основная цель: сравнить роли \`primary low-latency\` и \`primary stealth\` внутри одного baseline, а не искать один универсальный transport."
			;;
		stealth-xray)
			client_target_hint="Для client-load проверки выбирайте узел remark \`🇷🇺 reality-shield\` / обычный \`VLESS REALITY TCP\`."
			client_log_hint="Для этого профиля строки \`REALITY ... DialTLSContext\` в логе \`v2rayN\` ожидаемы."
			transport_extra_url=""
			secondary_target_hint="- Дополнительный контроль: сравните этот reality-only профиль с последним результатом \`stealth-xhttp\` в той же сети."
			;;
		*)
			client_target_hint="Выбирайте узел, соответствующий текущему transport profile."
			client_log_hint="Если лог клиента не соответствует выбранному transport profile, проверьте, какой именно узел импортирован."
			transport_extra_url=""
			secondary_target_hint=""
			;;
	esac
	if [[ "$TRANSPORT_PROFILE" == "stealth-multi" ]]; then
		client_target_hint="Для client-load проверки сравнивайте оба узла из одной установки: \`${emoji_flag} reality-call\` как low-latency/calls профиль и \`${emoji_flag} xhttp-stealth\` как stealth/browsing профиль."
		client_log_hint="Для \`reality-call\` строки \`REALITY ... DialTLSContext\` ожидаемы; для \`xhttp-stealth\` ориентируйтесь на импортированный JSON/XHTTP-профиль."
		secondary_target_hint="- Основная цель: сравнить роли \`primary low-latency\` и \`primary stealth\` внутри одного baseline, а не искать один универсальный transport."
	fi
	cat > "$checklist_file" <<EOF
# Чек-лист ручной клиентской приёмки

- Дата генерации: $(timestamp)
- Профиль: $(platform_selection_summary)
- Транспортный preset: $(platform_tuning_summary)
- Метка сравнения: ${ACCEPTANCE_LABEL:-<не задана>}
- Группа сравнения: ${ACCEPTANCE_MATRIX_GROUP:-<не задана>}
- Сеть: ${ACCEPTANCE_NETWORK_LABEL:-<не задана>}
- Оператор/провайдер: ${ACCEPTANCE_OPERATOR_LABEL:-<не задан>}
- Временное окно: ${ACCEPTANCE_TIME_WINDOW:-<не задано>}
- Клиент/устройство: ${ACCEPTANCE_CLIENT_DEVICE:-<не задано>}
- Заметки к сеансу: ${ACCEPTANCE_NOTES:-<нет>}
- Домен панели: ${domain:-<не определён>}
- REALITY-домен: ${reality_domain:-<не определён>}
- Публичный HTTPS-порт: ${public_https_port}

## Обязательные шаги

1. Импортировать текущий профиль в \`v2rayN\`.
2. Подтвердить успешное подключение без ошибки \`PublicKey property is invalid\`.
3. Проверить открытие обычных сайтов через прокси.
4. Проверить видео/стриминг и фоновые запросы браузера.
5. Выполнить ручное переподключение клиента и убедиться, что профиль восстанавливается.
6. Если возможно, повторить проверку с другой сети или на другом типе устройства.
7. Зафиксировать, какой профиль тестировался: \`$(platform_selection_summary)\`.
8. При деградации записать точное время по Москве, тип сети (\`Wi-Fi/LTE\`), помог ли reconnect и какие сайты перестали открываться.

## Что заполнить после теста

- Итог: \`PASS\` / \`DEGRADED\` / \`FAIL\`
- Время начала по Москве:
- Время сбоя по Москве:
- Симптом:
- Помог ли reconnect:
- Наблюдалась ли проблема после смены сети:
- Что открывалось / что перестало открываться:
- Фрагмент клиентского лога рядом со сбоем:

## Полезные URL текущей ноды

- Panel: https://${domain:-<domain>}/${panel_path:-<panel_path>}/
- Web-sub: https://${domain:-<domain>}/${web_path:-<web_path>}/
- sub2sing-box UI: https://${domain:-<domain>}/${sub2singbox_path:-<sub2singbox_path>}/
- Fallback root: https://${reality_domain:-<reality_domain>}/
- Subscription path: https://${domain:-<domain>}/${sub_path:-<sub_path>}
- Subscription JSON path: https://${domain:-<domain>}/${json_path:-<json_path>}
${transport_extra_url}
${secondary_target_hint}

- Client target hint: ${client_target_hint}
- Client log hint: ${client_log_hint}
EOF
	append_debug_log "Acceptance manual checklist written to ${checklist_file}"
}
acceptance_probe_url() {
	local iteration="$1" label="$2" host="$3" path="$4" artifact_name="$5" public_https_port curl_output curl_metrics artifact_base
	public_https_port="$(platform_public_https_port)"
	if [[ -z "$host" || -z "$path" ]]; then
		record_acceptance_result "FAIL" "${label}: не удалось определить host/path"
		append_acceptance_probe_result_jsonl "$iteration" "$label" "${host:-}" "${path:-}" "FAIL" "http_code= remote_ip= time_namelookup= time_connect= time_appconnect= time_starttransfer= time_total="
		return 1
	fi
	artifact_base="${artifact_name%.*}"
	curl_metrics=$(curl -kfsS -o /dev/null -w 'http_code=%{http_code} remote_ip=%{remote_ip} time_namelookup=%{time_namelookup} time_connect=%{time_connect} time_appconnect=%{time_appconnect} time_starttransfer=%{time_starttransfer} time_total=%{time_total}\n' --resolve "${host}:${public_https_port}:127.0.0.1" "https://${host}${path}" 2>&1)
	if curl_output=$(curl -kfsS --resolve "${host}:${public_https_port}:127.0.0.1" "https://${host}${path}" 2>&1); then
		record_acceptance_result "PASS" "${label}: HTTPS probe passed"
		append_acceptance_probe_result_jsonl "$iteration" "$label" "$host" "$path" "PASS" "$curl_metrics"
		if [[ -n "$DEBUG_DIR" ]]; then
			printf '%s' "$curl_output" > "$(acceptance_artifact_path "${artifact_name}")"
			printf '%s' "$curl_metrics" > "$(acceptance_artifact_path "${artifact_base}.metrics.txt")"
		fi
		return 0
	fi
	record_acceptance_result "FAIL" "${label}: HTTPS probe failed"
	append_acceptance_probe_result_jsonl "$iteration" "$label" "$host" "$path" "FAIL" "$curl_metrics"
	append_debug_log "${label} curl output: ${curl_output}"
	append_debug_log "${label} curl metrics: ${curl_metrics}"
	if [[ -n "$DEBUG_DIR" ]]; then
		printf '%s' "$curl_metrics" > "$(acceptance_artifact_path "${artifact_base}.metrics.txt")"
		capture_acceptance_snapshot
	fi
	return 1
}
acceptance_transport_probe() {
	local iteration="$1" transport_kind="$2"
	local label="" artifact_base="" host="" path="" status="FAIL"
	case "$transport_kind" in
		reality)
			label="Data-plane REALITY"
			artifact_base="acceptance/reality-dataplane-${iteration}"
			;;
		xhttp)
			label="Data-plane XHTTP"
			artifact_base="acceptance/xhttp-dataplane-${iteration}"
			;;
		*)
			record_acceptance_result "FAIL" "Unsupported transport probe kind: ${transport_kind}"
			return 1
			;;
	esac
	if run_local_transport_probe "$transport_kind" "$artifact_base"; then
		status="PASS"
	fi
	host="${TRANSPORT_PROBE_LAST_TARGET_HOST:-}"
	path="${TRANSPORT_PROBE_LAST_TARGET_PATH:-/}"
	if [[ "$status" == "PASS" ]]; then
		record_acceptance_result "PASS" "${label}: local loopback transport probe passed"
	else
		record_acceptance_result "FAIL" "${label}: local loopback transport probe failed"
		append_debug_log "${label} failure hint: ${TRANSPORT_PROBE_LAST_FAILURE_HINT:-<none>}"
		capture_acceptance_snapshot
	fi
	append_acceptance_probe_result_jsonl "$iteration" "$label" "$host" "$path" "$status" "${TRANSPORT_PROBE_LAST_METRICS:-http_code= remote_ip= time_namelookup= time_connect= time_appconnect= time_starttransfer= time_total=}"
	[[ "$status" == "PASS" ]]
}
run_stealth_acceptance_stage() {
	local failures=0 iteration=1 total_iterations=0 summary_file public_https_port
	local panel_passes=0 panel_fails=0 websub_passes=0 websub_fails=0
	local sub2singbox_passes=0 sub2singbox_fails=0 fallback_passes=0 fallback_fails=0
	local json_passes=0 json_fails=0 transport_reality_passes=0 transport_reality_fails=0
	local transport_xhttp_passes=0 transport_xhttp_fails=0

	KEEP_ARTIFACTS="y"
	init_debug_session
	load_existing_runtime_context

	if [[ "$PLATFORM_PROFILE" != "stealth" ]]; then
		die "Stage=acceptance пока поддерживается только для stealth-профилей. Текущий профиль: $(platform_selection_summary)"
	fi

	if ! [[ "$ACCEPTANCE_MINUTES" =~ ^[0-9]+$ ]] || ! [[ "$ACCEPTANCE_INTERVAL_SECONDS" =~ ^[0-9]+$ ]]; then
		die "Параметры acceptance должны быть целыми числами: minutes=${ACCEPTANCE_MINUTES}, interval=${ACCEPTANCE_INTERVAL_SECONDS}"
	fi
	if (( ACCEPTANCE_MINUTES < 1 )); then
		die "ACCEPTANCE_MINUTES должен быть >= 1"
	fi
	if (( ACCEPTANCE_INTERVAL_SECONDS < 1 )); then
		die "ACCEPTANCE_INTERVAL_SECONDS должен быть >= 1"
	fi

	public_https_port="$(platform_public_https_port)"
	total_iterations=$(( (ACCEPTANCE_MINUTES * 60 + ACCEPTANCE_INTERVAL_SECONDS - 1) / ACCEPTANCE_INTERVAL_SECONDS ))
	(( total_iterations < 1 )) && total_iterations=1

	msg_inf "Запускаю acceptance для $(platform_selection_summary)"
	msg_inf "Интервал: ${ACCEPTANCE_INTERVAL_SECONDS}s, длительность: ${ACCEPTANCE_MINUTES}m, циклов: ${total_iterations}"
	print_runtime_context

	verify_existing_installation || die "Acceptance остановлен: verify не прошёл."
	capture_acceptance_snapshot
	write_acceptance_runtime_snapshot
	write_acceptance_session_metadata
	write_acceptance_manual_checklist
	write_acceptance_matrix_row_json "$failures" "$panel_passes" "$panel_fails" "$websub_passes" "$websub_fails" "$sub2singbox_passes" "$sub2singbox_fails" "$fallback_passes" "$fallback_fails" "$json_passes" "$json_fails" "$transport_reality_passes" "$transport_reality_fails" "$transport_xhttp_passes" "$transport_xhttp_fails"

	while (( iteration <= total_iterations )); do
		msg_inf "Acceptance iteration ${iteration}/${total_iterations}"

		if acceptance_probe_url "$iteration" "Panel" "${domain}" "/${panel_path}/" "panel-body-${iteration}.html"; then
			panel_passes=$((panel_passes + 1))
		else
			panel_fails=$((panel_fails + 1))
			failures=$((failures + 1))
		fi

		if acceptance_probe_url "$iteration" "Web-sub" "${domain}" "/${web_path}/" "websub-body-${iteration}.html"; then
			websub_passes=$((websub_passes + 1))
		else
			websub_fails=$((websub_fails + 1))
			failures=$((failures + 1))
		fi

		if acceptance_probe_url "$iteration" "Subscription JSON" "${domain}" "/${json_path}/first" "subscription-json-${iteration}.json"; then
			json_passes=$((json_passes + 1))
		else
			json_fails=$((json_fails + 1))
			failures=$((failures + 1))
		fi

		if acceptance_probe_url "$iteration" "sub2sing-box" "${domain}" "/${sub2singbox_path}/" "sub2singbox-body-${iteration}.html"; then
			sub2singbox_passes=$((sub2singbox_passes + 1))
		else
			sub2singbox_fails=$((sub2singbox_fails + 1))
			failures=$((failures + 1))
		fi

		if acceptance_probe_url "$iteration" "Fallback root" "${reality_domain}" "/" "fallback-root-${iteration}.html"; then
			fallback_passes=$((fallback_passes + 1))
		else
			fallback_fails=$((fallback_fails + 1))
			failures=$((failures + 1))
		fi

		if transport_profile_has_reality; then
			if acceptance_transport_probe "$iteration" "reality"; then
				transport_reality_passes=$((transport_reality_passes + 1))
			else
				transport_reality_fails=$((transport_reality_fails + 1))
				failures=$((failures + 1))
			fi
		fi
		if transport_profile_has_xhttp; then
			if acceptance_transport_probe "$iteration" "xhttp"; then
				transport_xhttp_passes=$((transport_xhttp_passes + 1))
			else
				transport_xhttp_fails=$((transport_xhttp_fails + 1))
				failures=$((failures + 1))
			fi
		fi

		if (( iteration < total_iterations )); then
			sleep "${ACCEPTANCE_INTERVAL_SECONDS}"
		fi
		iteration=$((iteration + 1))
	done

	summary_file="$(acceptance_artifact_path "summary.txt")"
	mkdir -p "$(dirname "$summary_file")"
	cat > "$summary_file" <<EOF
Acceptance summary
Timestamp: $(timestamp)
Selection: $(platform_selection_summary)
Transport tuning: $(platform_tuning_summary)
Acceptance label: ${ACCEPTANCE_LABEL:-}
Acceptance matrix group: ${ACCEPTANCE_MATRIX_GROUP:-}
Acceptance network: ${ACCEPTANCE_NETWORK_LABEL:-}
Acceptance operator: ${ACCEPTANCE_OPERATOR_LABEL:-}
Acceptance time window: ${ACCEPTANCE_TIME_WINDOW:-}
Acceptance client device: ${ACCEPTANCE_CLIENT_DEVICE:-}
Acceptance notes: ${ACCEPTANCE_NOTES:-}
Public HTTPS port: ${public_https_port}
Iterations: ${total_iterations}
Interval seconds: ${ACCEPTANCE_INTERVAL_SECONDS}
Minutes: ${ACCEPTANCE_MINUTES}
Panel: pass=${panel_passes} fail=${panel_fails}
Web-sub: pass=${websub_passes} fail=${websub_fails}
Subscription JSON: pass=${json_passes} fail=${json_fails}
sub2sing-box: pass=${sub2singbox_passes} fail=${sub2singbox_fails}
Fallback root: pass=${fallback_passes} fail=${fallback_fails}
Data-plane REALITY: pass=${transport_reality_passes} fail=${transport_reality_fails}
Data-plane XHTTP: pass=${transport_xhttp_passes} fail=${transport_xhttp_fails}
EOF
	append_debug_log "Acceptance summary written to ${summary_file}"
	capture_acceptance_snapshot
	write_acceptance_runtime_snapshot
	write_acceptance_session_metadata
	write_acceptance_matrix_row_json "$failures" "$panel_passes" "$panel_fails" "$websub_passes" "$websub_fails" "$sub2singbox_passes" "$sub2singbox_fails" "$fallback_passes" "$fallback_fails" "$json_passes" "$json_fails" "$transport_reality_passes" "$transport_reality_fails" "$transport_xhttp_passes" "$transport_xhttp_fails"

	if (( failures > 0 )); then
		die "Acceptance завершён с ошибками. Подробности: ${summary_file}"
	fi

	msg_ok "Acceptance завершён успешно. Отчёт: ${summary_file}"
}
verify_existing_installation() {
	local failures=0
	local sqlite_result="" curl_output="" curl_headers="" unexpected_urls="" listener_output="" stealth_reality_port=""
	local stealth_xhttp_inbound_count="" stealth_xhttp_path=""
	local stream_mode="" selection_runtime_state="" https_proxy_checks_enabled="" stealth_runtime_checks_enabled=""
	local public_https_port="" web_tls_port=""
	init_debug_session
	load_existing_runtime_context
	stream_mode="$(platform_transport_stream_mode)"
	selection_runtime_state="$(platform_selection_runtime_state)"
	public_https_port="$(platform_public_https_port)"
	web_tls_port="$(platform_transport_web_tls_port)"
	if [[ "$selection_runtime_state" == "ready" && ( "$PLATFORM_PROFILE" == "classic" || "$PLATFORM_PROFILE" == "stealth" ) ]]; then
		https_proxy_checks_enabled="enabled"
	else
		https_proxy_checks_enabled="disabled"
	fi
	if [[ "$selection_runtime_state" == "ready" && "$PLATFORM_PROFILE" == "stealth" ]]; then
		stealth_runtime_checks_enabled="enabled"
	else
		stealth_runtime_checks_enabled="disabled"
	fi
	append_debug_log "verify stream_mode=${stream_mode}"
	append_debug_log "verify https_proxy_checks_enabled=${https_proxy_checks_enabled}"
	append_debug_log "verify stealth_runtime_checks_enabled=${stealth_runtime_checks_enabled}"

	capture_file_if_exists "/etc/nginx/nginx.conf" "files/nginx.conf"
	capture_file_if_exists "/etc/nginx/snippets/includes.conf" "files/includes.conf"
	capture_file_if_exists "/etc/nginx/stream-enabled/stream.conf" "files/stream.conf"
	capture_file_if_exists "/var/www/subpage/index.html" "files/subpage/index.html"
	capture_file_if_exists "/var/www/subpage/clash.yaml" "files/subpage/clash.yaml"
	capture_file_if_exists "$XUIDB" "files/x-ui.db"
	capture_command_output "commands/systemctl-nginx.txt" systemctl status nginx --no-pager
	capture_command_output "commands/systemctl-x-ui.txt" systemctl status x-ui --no-pager
	if [[ -f "$SUB2SINGBOX_SERVICE" ]]; then
		capture_command_output "commands/systemctl-sub2sing-box.txt" systemctl status sub2sing-box --no-pager
	fi
	if [[ -f "$SUBJSON_REWRITE_SERVICE" ]]; then
		capture_command_output "commands/systemctl-subjson-rewrite.txt" systemctl status subjson-rewrite --no-pager
	fi
	capture_command_output "commands/nginx-test.txt" nginx -t
	capture_command_output "commands/nginx-dump.txt" nginx -T

	if [[ -f "$XUIDB" ]]; then
		record_verify_result "PASS" "Файл базы x-ui найден: ${XUIDB}"
	else
		record_verify_result "FAIL" "Файл базы x-ui не найден: ${XUIDB}"
		failures=$((failures + 1))
	fi

	if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$XUIDB" ]]; then
		sqlite_result=$(sqlite3 "$XUIDB" 'PRAGMA integrity_check;' 2>&1)
		append_debug_log "sqlite integrity_check: ${sqlite_result}"
		if [[ "$sqlite_result" == "ok" ]]; then
			record_verify_result "PASS" "SQLite integrity_check вернул ok"
		else
			record_verify_result "FAIL" "SQLite integrity_check вернул: ${sqlite_result}"
			failures=$((failures + 1))
		fi
	fi

	if verify_reality_inbound_keys; then
		record_verify_result "PASS" "REALITY inbound contains valid private/public key pair"
	else
		record_verify_result "FAIL" "REALITY inbound is missing or contains invalid private/public key pair"
		failures=$((failures + 1))
	fi

	if nginx -t >/dev/null 2>&1; then
		record_verify_result "PASS" "Конфигурация nginx проходит nginx -t"
	else
		record_verify_result "FAIL" "Конфигурация nginx не проходит nginx -t"
		failures=$((failures + 1))
	fi

	if systemctl is-active --quiet nginx; then
		record_verify_result "PASS" "Сервис nginx активен"
	else
		record_verify_result "FAIL" "Сервис nginx неактивен"
		failures=$((failures + 1))
	fi

	if systemctl is-active --quiet x-ui; then
		record_verify_result "PASS" "Сервис x-ui активен"
	else
		record_verify_result "FAIL" "Сервис x-ui неактивен"
		failures=$((failures + 1))
	fi

	if [[ -f "$SUB2SINGBOX_SERVICE" ]]; then
		if systemctl is-active --quiet sub2sing-box; then
			record_verify_result "PASS" "sub2sing-box service is active"
		else
			record_verify_result "FAIL" "sub2sing-box service is inactive"
			failures=$((failures + 1))
		fi
	elif pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		record_verify_result "PASS" "sub2sing-box process is active"
	else
		record_verify_result "FAIL" "sub2sing-box process is inactive"
		failures=$((failures + 1))
	fi

	if [[ -f "$SUBJSON_REWRITE_SERVICE" ]]; then
		if systemctl is-active --quiet subjson-rewrite; then
			record_verify_result "PASS" "subjson-rewrite service is active"
		else
			record_verify_result "FAIL" "subjson-rewrite service is inactive"
			failures=$((failures + 1))
		fi
	fi

	if [[ -f /var/www/subpage/index.html ]]; then
		record_verify_result "PASS" "Локальная web-sub страница найдена"
	else
		record_verify_result "FAIL" "Локальная web-sub страница не найдена"
		failures=$((failures + 1))
	fi

	if [[ -f /var/www/subpage/clash.yaml ]]; then
		record_verify_result "PASS" "Локальный clash.yaml найден"
	else
		record_verify_result "FAIL" "Локальный clash.yaml не найден"
		failures=$((failures + 1))
	fi

	if [[ -d /var/www/subpage/vendor/sb-rule-sets ]] && find /var/www/subpage/vendor/sb-rule-sets -type f -name '*.json' | grep -q .; then
		record_verify_result "PASS" "Локальные sb-rule-sets присутствуют"
	else
		record_verify_result "FAIL" "Локальные sb-rule-sets отсутствуют"
		failures=$((failures + 1))
	fi

	if [[ "$stealth_runtime_checks_enabled" == "enabled" ]]; then
		if [[ ! -f /etc/nginx/stream-enabled/stream.conf ]]; then
			record_verify_result "PASS" "Stealth ingress does not use nginx stream.conf"
		else
			record_verify_result "FAIL" "Stealth ingress unexpectedly still has nginx stream.conf"
			failures=$((failures + 1))
		fi

		listener_output=$(ss -lntp 2>/dev/null || true)
		append_debug_log "stealth listener snapshot: ${listener_output//$'\n'/ | }"
		if grep -Eq "[:.]${public_https_port}[[:space:]].*xray" <<<"$listener_output"; then
			record_verify_result "PASS" "Stealth ingress has Xray listening on public ${public_https_port}"
		else
			record_verify_result "FAIL" "Stealth ingress does not show Xray listening on public ${public_https_port}"
			failures=$((failures + 1))
		fi

		if grep -Eq "[:.]${web_tls_port}[[:space:]].*nginx" <<<"$listener_output"; then
			record_verify_result "PASS" "Stealth ingress has nginx listening on local TLS boundary ${web_tls_port}"
		else
			record_verify_result "FAIL" "Stealth ingress does not show nginx listening on local TLS boundary ${web_tls_port}"
			failures=$((failures + 1))
		fi

		if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$XUIDB" ]]; then
			stealth_reality_port=$(sqlite3 -list "$XUIDB" "SELECT port FROM inbounds WHERE json_extract(stream_settings, '$.security')='reality' LIMIT 1;" 2>/dev/null)
			append_debug_log "stealth reality inbound port: ${stealth_reality_port}"
			stealth_reality_port=$(printf '%s' "$stealth_reality_port" | tr -d '[:space:]')
			if [[ "$stealth_reality_port" == "${public_https_port}" ]]; then
				record_verify_result "PASS" "Stealth REALITY inbound is bound to public ${public_https_port}"
			else
				record_verify_result "FAIL" "Stealth REALITY inbound is not bound to public ${public_https_port}"
				failures=$((failures + 1))
			fi
		fi

		if [[ ( "$TRANSPORT_PROFILE" == "stealth-xhttp" || "$TRANSPORT_PROFILE" == "stealth-multi" ) ]] && command -v sqlite3 >/dev/null 2>&1 && [[ -f "$XUIDB" ]]; then
			stealth_xhttp_inbound_count=$(sqlite3 -list "$XUIDB" "SELECT COUNT(*) FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp';" 2>/dev/null | tr -d '[:space:]')
			append_debug_log "stealth xhttp inbound count: ${stealth_xhttp_inbound_count}"
			if [[ "$stealth_xhttp_inbound_count" =~ ^[1-9][0-9]*$ ]]; then
				record_verify_result "PASS" "Stealth XHTTP inbound is present in x-ui.db"
			else
				record_verify_result "FAIL" "Stealth XHTTP inbound is missing in x-ui.db"
				failures=$((failures + 1))
			fi

			stealth_xhttp_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" "SELECT json_extract(stream_settings, '$.xhttpSettings.path') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null)")
			append_debug_log "stealth xhttp path: ${stealth_xhttp_path:-<empty>}"
			if [[ -n "$stealth_xhttp_path" ]] && grep -Rqs "location /${stealth_xhttp_path} {" /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/nginx/snippets 2>/dev/null; then
				record_verify_result "PASS" "Stealth XHTTP path is published by nginx fallback"
			else
				record_verify_result "FAIL" "Stealth XHTTP path is not published by nginx fallback"
				failures=$((failures + 1))
			fi

			if [[ -S /dev/shm/uds2023.sock ]]; then
				record_verify_result "PASS" "Stealth XHTTP unix socket exists"
			else
				record_verify_result "FAIL" "Stealth XHTTP unix socket is missing"
				failures=$((failures + 1))
			fi

			if ! xhttp_transport_self_test; then
				failures=$((failures + 1))
			fi
		fi
	fi

	if transport_profile_has_reality; then
		if ! reality_transport_self_test; then
			failures=$((failures + 1))
		fi
	fi

	if ! verify_transport_tuning_contract; then
		failures=$((failures + 1))
	fi

	if [[ "$https_proxy_checks_enabled" == "enabled" ]]; then
		if [[ -n "$domain" && -n "$web_path" ]]; then
			if curl_output=$(curl -kfsS --resolve "${domain}:443:127.0.0.1" "https://${domain}/${web_path}/" 2>&1); then
				record_verify_result "PASS" "Web-sub страница отвечает через локальный HTTPS"
				[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_output" > "$DEBUG_DIR/commands/websub-index-body.html"
				if contains_forbidden_external_reference "$curl_output"; then
					record_verify_result "FAIL" "Web-sub страница содержит устаревшие upstream-ссылки или placeholder URL"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "Web-sub страница очищена от устаревших upstream-ссылок и placeholder URL"
				fi
				unexpected_urls=$(collect_unexpected_external_urls "$curl_output")
				if [[ -n "$unexpected_urls" ]]; then
					record_verify_result "FAIL" "Web-sub страница содержит неожиданные внешние ссылки вне allowlist"
					append_debug_log "Unexpected web-sub external URLs: ${unexpected_urls//$'\n'/, }"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "Web-sub страница использует только локальные и allowlist-внешние ссылки"
				fi
			else
				record_verify_result "FAIL" "Web-sub страница не отвечает через локальный HTTPS"
				append_debug_log "curl output: ${curl_output}"
				failures=$((failures + 1))
			fi
		else
			record_verify_result "FAIL" "Не удалось определить domain/web_path для локальной HTTP-проверки"
			failures=$((failures + 1))
		fi
	else
		record_verify_result "PASS" "Локальная HTTPS-проверка web-sub пропущена для staged-профиля ${PLATFORM_PROFILE}/${TRANSPORT_PROFILE}"
	fi

	if [[ "$https_proxy_checks_enabled" == "enabled" ]]; then
		if [[ -n "$domain" && -n "$json_path" ]]; then
			if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$XUIDB" ]]; then
				local_subjson_settings=$(sqlite3 -separator '|' -list "$XUIDB" "
SELECT
  COALESCE((SELECT value FROM settings WHERE key='subJsonEnable' LIMIT 1), ''),
  COALESCE((SELECT value FROM settings WHERE key='subJsonPath' LIMIT 1), ''),
  COALESCE((SELECT value FROM settings WHERE key='subJsonURI' LIMIT 1), '');
" 2>/dev/null)
				IFS='|' read -r actual_subjson_enable actual_subjson_path actual_subjson_uri <<<"$local_subjson_settings"
				expected_subjson_uri="https://${domain}/${json_path}/"
				if [[ "${actual_subjson_enable:-}" == "true" && "$(trim_slashes "${actual_subjson_path:-}")" == "${json_path}" && "${actual_subjson_uri:-}" == "$expected_subjson_uri" ]]; then
					record_verify_result "PASS" "Subscription JSON settings match runtime context"
				else
					record_verify_result "FAIL" "Subscription JSON settings do not match runtime context"
					append_debug_log "subJson settings actual enable=${actual_subjson_enable:-<empty>} path=${actual_subjson_path:-<empty>} uri=${actual_subjson_uri:-<empty>} expected_path=${json_path} expected_uri=${expected_subjson_uri}"
					failures=$((failures + 1))
				fi
			fi
			if curl_output=$(curl -kfsS --resolve "${domain}:443:127.0.0.1" "https://${domain}/${json_path}/first" 2>&1); then
				record_verify_result "PASS" "Subscription JSON endpoint responds through local HTTPS"
				[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_output" > "$DEBUG_DIR/commands/subscription-json-body.txt"
				if curl_headers=$(curl -kfsS -D - -o /dev/null --resolve "${domain}:443:127.0.0.1" "https://${domain}/${json_path}/first" 2>&1); then
					[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_headers" > "$DEBUG_DIR/commands/subscription-json-headers.txt"
					if response_has_header "$curl_headers" "Cache-Control" "no-store"; then
						record_verify_result "PASS" "Subscription JSON endpoint sends no-store cache headers"
					else
						record_verify_result "FAIL" "Subscription JSON endpoint is missing no-store cache headers"
						failures=$((failures + 1))
					fi
					if response_has_header "$curl_headers" "X-Robots-Tag" "noindex"; then
						record_verify_result "PASS" "Subscription JSON endpoint sends anti-index headers"
					else
						record_verify_result "FAIL" "Subscription JSON endpoint is missing anti-index headers"
						failures=$((failures + 1))
					fi
					if response_has_header "$curl_headers" "X-Content-Type-Options" "nosniff"; then
						record_verify_result "PASS" "Subscription JSON endpoint sends nosniff header"
					else
						record_verify_result "FAIL" "Subscription JSON endpoint is missing nosniff header"
						failures=$((failures + 1))
					fi
				else
					record_verify_result "FAIL" "Subscription JSON endpoint headers do not respond through local HTTPS"
					failures=$((failures + 1))
				fi
				if grep -Eqi '<!doctype html|<html' <<<"$curl_output"; then
					record_verify_result "FAIL" "Subscription JSON endpoint returns HTML instead of client config"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "Subscription JSON endpoint returns non-HTML client config"
					if printf '%s' "$curl_output" | jq -e \
						--arg expectedTcpNoDelay "${TRANSPORT_XHTTP_TCP_NO_DELAY:-}" \
						--arg expectedKeepAliveInterval "${TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL:-}" \
						--arg expectedKeepAliveIdle "${TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE:-}" \
						--arg expectedTcpUserTimeout "${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-}" \
						--arg expectedTransportProfile "${TRANSPORT_PROFILE:-}" \
						--arg expectedDnsServersCsv "${SUBJSON_REWRITE_DNS_SERVERS:-}" \
						--arg expectedDnsQueryStrategy "${SUBJSON_REWRITE_DNS_QUERY_STRATEGY:-}" \
						'
						def configs: if type == "array" then . else [.] end;
						def outbounds: [configs[] | (.outbounds // [])[]];
						def expected_dns_servers:
							($expectedDnsServersCsv | split(",") | map(gsub("^\\s+|\\s+$"; "") | select(length > 0)));
						def valid_vless:
							(.protocol == "vless")
							and ((.settings.vnext | type) == "array")
							and ((.settings | has("address")) | not)
							and ((.settings.vnext[0].users | type) == "array");
						def valid_xhttp_sockopt:
							(.streamSettings.network == "xhttp")
							and ((.streamSettings.sockopt | type) == "object")
							and ((.streamSettings.sockopt.tcpNoDelay | tostring) == $expectedTcpNoDelay)
							and ((.streamSettings.sockopt.tcpKeepAliveInterval | tostring) == $expectedKeepAliveInterval)
							and ((.streamSettings.sockopt.tcpKeepAliveIdle | tostring) == $expectedKeepAliveIdle)
							and ((.streamSettings.sockopt.tcpUserTimeout | tostring) == $expectedTcpUserTimeout);
						def valid_xhttp_contract:
							(.streamSettings.network == "xhttp")
							and ((.streamSettings.security // "") == "tls")
							and ((.streamSettings.xhttpSettings | type) == "object")
							and (((.streamSettings.xhttpSettings.path // "") | tostring | length) > 0)
							and (((.streamSettings.xhttpSettings.mode // "") | tostring | length) > 0)
							and valid_xhttp_sockopt;
						def valid_reality_contract:
							(.streamSettings.security == "reality")
							and ((.streamSettings.realitySettings | type) == "object")
							and (((.streamSettings.realitySettings.publicKey // "") | tostring | length) > 0)
							and (((.streamSettings.realitySettings.serverName // "") | tostring | length) > 0)
							and (((.streamSettings.realitySettings.fingerprint // "") | tostring | length) > 0)
							and (((.streamSettings.realitySettings.shortId // "") | tostring | length) > 0)
							and (((.streamSettings.realitySettings.spiderX // "") | tostring | length) > 0);
						def valid_dns:
							. as $cfg
							| (($cfg.outbounds // []) | map(select(.protocol == "vless" and ((.tag // "") | length > 0)) | .tag)) as $vless_tags
							| (($cfg.dns | type) == "object")
							and (($cfg.dns.queryStrategy // "") == $expectedDnsQueryStrategy)
							and (($cfg.dns.tag // "") == "dns_out")
							and (($cfg.dns.servers | type) == "array")
							and (expected_dns_servers | length > 0)
							and (expected_dns_servers | all(. as $dns_server | ([$cfg.dns.servers[]?.address] | index($dns_server)) != null))
							and ((($cfg.routing.rules // []) | any(
								(.type == "field")
								and ((.port | tostring) == "53")
								and ((.network // "") == "tcp,udp")
								and ((.outboundTag // "") as $tag | ($vless_tags | index($tag)) != null)
							)));
						(outbounds | any(.protocol == "vless"))
						and (configs | all(valid_dns))
						and (outbounds | all(if .protocol == "vless" then valid_vless else true end))
						and (
							if ($expectedTransportProfile == "stealth-xhttp" or $expectedTransportProfile == "stealth-multi") then
								(outbounds | any(.protocol == "vless" and valid_xhttp_contract))
							else
								true
							end
						)
						and (
							if ($expectedTransportProfile == "stealth-xray" or $expectedTransportProfile == "stealth-multi") then
								(outbounds | any(.protocol == "vless" and valid_reality_contract))
							else
								true
							end
						)
					' >/dev/null 2>&1; then
						record_verify_result "PASS" "Subscription JSON endpoint returns VLESS configs with vnext"
					else
						record_verify_result "FAIL" "Subscription JSON endpoint returns invalid VLESS JSON format"
						failures=$((failures + 1))
					fi
				fi
			else
				record_verify_result "FAIL" "Subscription JSON endpoint does not respond through local HTTPS"
				append_debug_log "subscription json curl output: ${curl_output}"
				failures=$((failures + 1))
			fi
		else
			record_verify_result "FAIL" "Не удалось определить domain/json_path для локальной JSON subscription проверки"
			failures=$((failures + 1))
		fi
	else
		record_verify_result "PASS" "Локальная HTTPS-проверка JSON subscription пропущена для staged-профиля ${PLATFORM_PROFILE}/${TRANSPORT_PROFILE}"
	fi

	if [[ "$https_proxy_checks_enabled" == "enabled" ]]; then
		if [[ -n "$domain" && -n "$sub2singbox_path" ]]; then
			if curl_output=$(curl -kfsS --resolve "${domain}:443:127.0.0.1" "https://${domain}/${sub2singbox_path}/" 2>&1); then
				record_verify_result "PASS" "sub2sing-box UI responds through local HTTPS"
				[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_output" > "$DEBUG_DIR/commands/sub2sing-box-ui.html"
				if grep -Eq 'https://unpkg\.com/|https://fonts\.googleapis\.com/|https://github\.com/legiz-ru/sb-rule-sets/raw/main/\.github/sub2sing-box/' <<<"$curl_output"; then
					record_verify_result "FAIL" "sub2sing-box UI still contains external runtime asset/template URLs"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "sub2sing-box UI uses local runtime assets and local template URLs"
				fi
				if contains_forbidden_external_reference "$curl_output"; then
					record_verify_result "FAIL" "sub2sing-box UI contains forbidden legacy external links"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "sub2sing-box UI does not contain forbidden legacy external links"
				fi
				unexpected_urls=$(collect_unexpected_external_urls "$curl_output")
				if [[ -n "$unexpected_urls" ]]; then
					record_verify_result "FAIL" "sub2sing-box UI contains unexpected external links outside allowlist"
					append_debug_log "Unexpected sub2sing-box external URLs: ${unexpected_urls//$'\n'/, }"
					failures=$((failures + 1))
				else
					record_verify_result "PASS" "sub2sing-box UI uses only allowlist external links"
				fi
			else
				record_verify_result "FAIL" "sub2sing-box UI does not respond through local HTTPS"
				append_debug_log "sub2sing-box curl output: ${curl_output}"
				failures=$((failures + 1))
			fi
		else
			record_verify_result "FAIL" "Не удалось определить domain/sub2singbox_path для проверки sub2sing-box UI"
			failures=$((failures + 1))
		fi
	else
		record_verify_result "PASS" "Локальная HTTPS-проверка sub2sing-box пропущена для staged-профиля ${PLATFORM_PROFILE}/${TRANSPORT_PROFILE}"
	fi

	if [[ "$stealth_runtime_checks_enabled" == "enabled" ]]; then
		if [[ -n "$domain" && -n "$panel_path" ]]; then
			if curl_output=$(curl -kfsS --resolve "${domain}:${public_https_port}:127.0.0.1" "https://${domain}/${panel_path}/" 2>&1); then
				record_verify_result "PASS" "Stealth panel responds through public ${public_https_port}"
				[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_output" > "$DEBUG_DIR/commands/stealth-panel-body.html"
				if curl_headers=$(curl -kfsS -D - -o /dev/null --resolve "${domain}:${public_https_port}:127.0.0.1" "https://${domain}/${panel_path}/" 2>&1); then
					[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_headers" > "$DEBUG_DIR/commands/stealth-panel-headers.txt"
					if response_has_header "$curl_headers" "Cache-Control" "no-store"; then
						record_verify_result "PASS" "Stealth panel sends no-store cache headers"
					else
						record_verify_result "FAIL" "Stealth panel is missing no-store cache headers"
						failures=$((failures + 1))
					fi
					if response_has_header "$curl_headers" "X-Robots-Tag" "noindex"; then
						record_verify_result "PASS" "Stealth panel sends anti-index headers"
					else
						record_verify_result "FAIL" "Stealth panel is missing anti-index headers"
						failures=$((failures + 1))
					fi
					if response_has_header "$curl_headers" "X-Content-Type-Options" "nosniff"; then
						record_verify_result "PASS" "Stealth panel sends nosniff header"
					else
						record_verify_result "FAIL" "Stealth panel is missing nosniff header"
						failures=$((failures + 1))
					fi
					if response_has_header "$curl_headers" "X-Frame-Options" "SAMEORIGIN"; then
						record_verify_result "PASS" "Stealth panel sends SAMEORIGIN frame policy"
					else
						record_verify_result "FAIL" "Stealth panel is missing SAMEORIGIN frame policy"
						failures=$((failures + 1))
					fi
				else
					record_verify_result "FAIL" "Stealth panel headers do not respond through public ${public_https_port}"
					failures=$((failures + 1))
				fi
			else
				record_verify_result "FAIL" "Stealth panel does not respond through public ${public_https_port}"
				append_debug_log "stealth panel curl output: ${curl_output}"
				failures=$((failures + 1))
			fi
		else
			record_verify_result "FAIL" "Не удалось определить domain/panel_path для stealth panel проверки"
			failures=$((failures + 1))
		fi

		if [[ -z "$reality_domain" ]]; then
			reality_domain=$(ls -1 /etc/nginx/sites-enabled 2>/dev/null | grep -vx '80.conf' | grep -vx "${domain}" | head -n1)
			append_debug_log "stealth fallback reality_domain recovery: ${reality_domain:-<empty>}"
		fi

		if [[ -n "$reality_domain" ]]; then
			if curl_output=$(curl -kfsS --resolve "${reality_domain}:${public_https_port}:127.0.0.1" "https://${reality_domain}/" 2>&1); then
				record_verify_result "PASS" "Stealth fallback root responds through public ${public_https_port}"
				[[ -n "$DEBUG_DIR" ]] && printf '%s' "$curl_output" > "$DEBUG_DIR/commands/stealth-fallback-root.html"
			else
				record_verify_result "FAIL" "Stealth fallback root does not respond through public ${public_https_port}"
				append_debug_log "stealth fallback curl output: ${curl_output}"
				failures=$((failures + 1))
			fi
		else
			record_verify_result "FAIL" "Не удалось определить reality_domain для stealth fallback проверки"
			failures=$((failures + 1))
		fi
	fi

	if (( failures > 0 )); then
		append_debug_log "Verification finished with failures: ${failures}"
		return 1
	fi

	append_debug_log "Verification finished successfully"
	return 0
}
verify_reset_state() {
	local failures=0
	local path listener_output port_regex=""
	local check_ports=() port_value

	if systemctl is-active --quiet nginx; then
		record_verify_result "FAIL" "nginx service is still active after reset"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "nginx service is stopped or removed"
	fi

	if systemctl is-active --quiet x-ui; then
		record_verify_result "FAIL" "x-ui service is still active after reset"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "x-ui service is stopped or removed"
	fi

	if systemctl is-active --quiet sub2sing-box; then
		record_verify_result "FAIL" "sub2sing-box service is still active after reset"
		failures=$((failures + 1))
	elif pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		record_verify_result "FAIL" "sub2sing-box process is still running"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "sub2sing-box service/process is stopped"
	fi

	if systemctl is-active --quiet subjson-rewrite; then
		record_verify_result "FAIL" "subjson-rewrite service is still active after reset"
		failures=$((failures + 1))
	elif pgrep -f "subjson-rewrite.py" >/dev/null 2>&1; then
		record_verify_result "FAIL" "subjson-rewrite process is still running"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "subjson-rewrite service/process is stopped"
	fi

	for path in \
		"/etc/x-ui" \
		"/usr/local/x-ui" \
		"/etc/nginx" \
		"/var/www/subpage" \
		"/etc/letsencrypt" \
		"/var/lib/letsencrypt" \
		"/var/log/letsencrypt" \
		"/usr/bin/x-ui" \
		"/usr/bin/sub2sing-box" \
		"$SUBJSON_REWRITE_BIN" \
		"/etc/systemd/system/sub2sing-box.service" \
		"/etc/systemd/system/multi-user.target.wants/sub2sing-box.service" \
		"$SUBJSON_REWRITE_SERVICE" \
		"/etc/systemd/system/multi-user.target.wants/subjson-rewrite.service"; do
		if [[ -e "$path" ]]; then
			record_verify_result "FAIL" "Residual path still exists: $path"
			failures=$((failures + 1))
		else
			record_verify_result "PASS" "Path is clean: $path"
		fi
	done

	if command -v nginx >/dev/null 2>&1; then
		record_verify_result "FAIL" "nginx binary is still available in PATH"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "nginx binary is gone from PATH"
	fi

	if command -v x-ui >/dev/null 2>&1; then
		record_verify_result "FAIL" "x-ui binary is still available in PATH"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "x-ui binary is gone from PATH"
	fi

	if command -v sub2sing-box >/dev/null 2>&1; then
		record_verify_result "FAIL" "sub2sing-box binary is still available in PATH"
		failures=$((failures + 1))
	else
		record_verify_result "PASS" "sub2sing-box binary is gone from PATH"
	fi

	if command -v ss >/dev/null 2>&1; then
		check_ports=("80" "443")
		if [[ "$SUBJSON_REWRITE_PORT" =~ ^[0-9]+$ ]]; then
			check_ports+=("$SUBJSON_REWRITE_PORT")
		fi
		for port_value in "$(platform_transport_web_tls_port)" "$(platform_transport_reality_site_tls_port)"; do
			[[ "$port_value" =~ ^[0-9]+$ ]] || continue
			[[ "$port_value" == "80" || "$port_value" == "443" ]] && continue
			if [[ ! " ${check_ports[*]} " =~ [[:space:]]${port_value}[[:space:]] ]]; then
				check_ports+=("$port_value")
			fi
		done
		port_regex=$(printf '%s|' "${check_ports[@]}")
		port_regex="${port_regex%|}"
		listener_output=$(ss -ltn 2>/dev/null | awk -v regex=":(${port_regex})$" 'NR > 1 && $4 ~ regex {print}')
		append_debug_log "Reset listener check: ${listener_output:-<empty>}"
		if [[ -n "$listener_output" ]]; then
			record_verify_result "FAIL" "Managed stack ports are still busy: ${listener_output//$'\n'/; }"
			failures=$((failures + 1))
		else
			record_verify_result "PASS" "Managed stack ports are free"
		fi
	fi

	if (( failures > 0 )); then
		append_debug_log "Reset verification finished with failures: ${failures}"
		return 1
	fi

	append_debug_log "Reset verification finished successfully"
	return 0
}
reset_staging_node() {
	init_debug_session
	load_existing_runtime_context

	capture_file_if_exists "/etc/nginx/nginx.conf" "pre-reset/nginx.conf"
	capture_file_if_exists "/etc/nginx/snippets/includes.conf" "pre-reset/includes.conf"
	capture_file_if_exists "/etc/nginx/stream-enabled/stream.conf" "pre-reset/stream.conf"
	capture_file_if_exists "/var/www/subpage/index.html" "pre-reset/subpage/index.html"
	capture_file_if_exists "/var/www/subpage/clash.yaml" "pre-reset/subpage/clash.yaml"
	capture_file_if_exists "$XUIDB" "pre-reset/x-ui.db"
	capture_command_output "pre-reset/systemctl-nginx.txt" systemctl status nginx --no-pager
	capture_command_output "pre-reset/systemctl-x-ui.txt" systemctl status x-ui --no-pager
	capture_command_output "pre-reset/ss-ltn.txt" ss -ltn

	if is_yes "$DRY_RUN"; then
		print_reset_plan
		return 0
	fi

	if ! is_yes "$CONFIRM_RESET"; then
		die "stage=reset is destructive. Re-run with -confirm_reset yes."
	fi

	msg_inf "Starting staging reset: the current installation will be fully removed."
	append_debug_log "Starting staging reset"
	uninstall_xui
	verify_reset_state || die "Staging reset finished with failures. Check debug artifacts."
	msg_ok "Staging reset completed successfully."
}
repo_asset_exists() { [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$1" ]]; }
copy_or_fetch_repo_file() {
	local rel_path="$1" dest="$2"
	mkdir -p "$(dirname "$dest")"
	if repo_asset_exists "$rel_path"; then
		cp "$SCRIPT_DIR/$rel_path" "$dest"
	else
		curl -fsSL "${REPO_RAW_BASE}/${rel_path}" -o "$dest"
	fi
}
copy_repo_dir_or_fail() {
	local rel_path="$1" dest="$2"
	[[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/$rel_path" ]] || die "Required local repo directory not found: $rel_path. Run installer from a local clone of this repo."
	rm -rf "$dest"
	mkdir -p "$(dirname "$dest")"
	cp -a "$SCRIPT_DIR/$rel_path" "$dest"
}
release_manifest_rel_path() {
	printf '%s\n' 'vendor/releases/SHA256SUMS'
}
lookup_release_archive_sha256() {
	local rel_path="$1" manifest="" expected=""
	[[ -n "$SCRIPT_DIR" ]] || return 1
	manifest="$SCRIPT_DIR/$(release_manifest_rel_path)"
	[[ -f "$manifest" ]] || return 1
	expected=$(awk -v p="$rel_path" '$2 == p { print $1; exit }' "$manifest")
	[[ -n "$expected" ]] || return 1
	printf '%s\n' "$expected"
}
verify_release_archive_checksum() {
	local rel_path="$1" local_file="$2" expected="" actual=""
	expected=$(lookup_release_archive_sha256 "$rel_path" 2>/dev/null || true)
	[[ -n "$expected" ]] || return 0
	actual=$(sha256sum "$local_file" | awk '{print $1}')
	if [[ "${actual,,}" != "${expected,,}" ]]; then
		die "Checksum mismatch for mirrored release archive: ${rel_path}"
	fi
	append_debug_log "Checksum verified for mirrored release archive: ${rel_path}"
}
copy_or_fetch_release_archive() {
	local rel_path="$1" url="$2" dest="$3"
	mkdir -p "$(dirname "$dest")"
	if repo_asset_exists "$rel_path"; then
		msg_inf "Using local mirrored release archive: ${rel_path}"
		cp "$SCRIPT_DIR/$rel_path" "$dest"
	else
		warn "Local mirrored release archive not found: ${rel_path}. Falling back to upstream download."
		wget -N -O "$dest" "$url"
		if [[ $? -ne 0 ]]; then
			die "Failed to download release archive: ${url}"
		fi
	fi
	verify_release_archive_checksum "$rel_path" "$dest"
}
sub2singbox_ui_asset_base() {
	printf '/%s/vendor/lib/sub2sing-box-ui' "$web_path"
}
sub2singbox_rule_set_base() {
	printf '/%s/vendor/sb-rule-sets' "$web_path"
}
ensure_sub2singbox_local_ui_proxy() {
	local includes="/etc/nginx/snippets/includes.conf"
	local tmp asset_base rules_base sub2singbox_bind_port

	[[ -f "$includes" ]] || return 0

	asset_base=$(sub2singbox_ui_asset_base)
	rules_base=$(sub2singbox_rule_set_base)
	sub2singbox_bind_port=$(platform_sub2singbox_bind_port)

	tmp=$(mktemp)
	awk -v asset_base="$asset_base" -v rules_base="$rules_base" -v bind_port="$sub2singbox_bind_port" '
		BEGIN { inblock = 0; normalize = 0 }
		/^[[:space:]]*#sub2sing-box/ { inblock = 1 }
		{
			if (inblock && normalize) {
				if ($0 ~ ("proxy_pass http://127\\.0\\.0\\.1:" bind_port "/")) {
					print
					normalize = 0
					next
				}
				if ($0 ~ /proxy_set_header Accept-Encoding "";/ || $0 ~ /sub_filter_once off;/ || $0 ~ /sub_filter_types text\/html;/ || $0 ~ /^[[:space:]]*sub_filter /) {
					next
				}
			}

			print
			if (inblock && $0 ~ /proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;/) {
				print "\t\tproxy_set_header Accept-Encoding \"\";"
				print "\t\tsub_filter_once off;"
				print "\t\tsub_filter '\''https://unpkg.com/mdui@2/mdui.css'\'' '\''" asset_base "/mdui.css'\'';"
				print "\t\tsub_filter '\''https://unpkg.com/mdui@2/mdui.global.js'\'' '\''" asset_base "/mdui.global.js'\'';"
				print "\t\tsub_filter '\''https://fonts.googleapis.com/css?family=Roboto|Noto+Sans+SC&display=swap'\'' '\''" asset_base "/sub2sing-box-fonts.css'\'';"
				print "\t\tsub_filter '\''https://fonts.googleapis.com/icon?family=Material+Icons+Outlined'\'' '\''" asset_base "/material-icons-outlined.css'\'';"
				print "\t\tsub_filter '\''https://fonts.googleapis.com/icon?family=Material+Icons'\'' '\''" asset_base "/material-icons.css'\'';"
				print "\t\tsub_filter '\''https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle.json'\'' '\''" rules_base "/ru-bundle.json'\'';"
				print "\t\tsub_filter '\''https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle-refilter.json'\'' '\''" rules_base "/ru-bundle-refilter.json'\'';"
				print "\t\tsub_filter '\''https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/re-filter.json'\'' '\''" rules_base "/re-filter.json'\'';"
				print "\t\tsub_filter '\''https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/secret-sing-box.json'\'' '\''" rules_base "/secret-sing-box.json'\'';"
				normalize = 1
			}
			if (inblock && $0 ~ /^[[:space:]]*}[[:space:]]*$/) {
				inblock = 0
			}
		}
	' "$includes" > "$tmp"
	mv "$tmp" "$includes"
	append_debug_log "Normalized sub2sing-box proxy block for local UI assets"
}
replace_web_placeholders() {
	local target="$1"
	local project_support_url_escaped project_donate_url_escaped
	project_support_url_escaped=$(escape_sed_replacement "$PROJECT_SUPPORT_URL")
	project_donate_url_escaped=$(escape_sed_replacement "$PROJECT_DONATE_URL")
	sed -i \
		-e "s/\${DOMAIN}/$domain/g" \
		-e "s#\${SUB_JSON_PATH}#$json_path#g" \
		-e "s#\${SUB_PATH}#$sub_path#g" \
		-e "s#\${WEB_PATH}#$web_path#g" \
		-e "s#\${SUB2SINGBOX_PATH}#$sub2singbox_path#g" \
		-e "s#\${PROJECT_SUPPORT_URL}#${project_support_url_escaped}#g" \
		-e "s#\${PROJECT_DONATE_URL}#${project_donate_url_escaped}#g" \
		"$target"
}
install_builtin_fake_site() {
	mkdir -p /var/www/html
	cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Service Portal</title>
  <style>
    :root { color-scheme: light dark; }
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background: linear-gradient(135deg, #0f172a, #1e293b);
      color: #e2e8f0;
      min-height: 100vh;
      display: grid;
      place-items: center;
    }
    .card {
      width: min(92vw, 720px);
      padding: 32px;
      border-radius: 24px;
      background: rgba(15, 23, 42, 0.88);
      box-shadow: 0 24px 80px rgba(15, 23, 42, 0.45);
    }
    h1 { margin: 0 0 12px; font-size: 2rem; }
    p { line-height: 1.6; color: #cbd5e1; }
    .pill {
      display: inline-block;
      margin-top: 16px;
      padding: 8px 14px;
      border-radius: 999px;
      background: #0f766e;
      color: #f0fdfa;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      font-size: 0.78rem;
    }
  </style>
</head>
<body>
  <main class="card">
    <div class="pill">Operational</div>
    <h1>Service Portal</h1>
    <p>This host is online and serving encrypted traffic through the edge gateway.</p>
    <p>Administrative endpoints are published on non-public routes. If you reached this page directly, no further action is required.</p>
  </main>
</body>
</html>
EOF
}

##############################Root Check##################################################################
ensure_root() {
	if [[ $EUID -ne 0 ]]; then
		msg_inf "Not root, re-executing with sudo..."
		exec sudo -E bash "$0" "$@"
	fi
}
ensure_root "$@"

##############################Banner######################################################################
show_banner() {
	echo
	msg_inf '           ___    _   _   _  '
	msg_inf ' \/ __ | |  | __ |_) |_) / \ '
	msg_inf ' /\    |_| _|_   |   | \ \_/ '
	echo
}
show_banner

##############################OS & CPU Preflight Check####################################################
check_os() {
	if [[ ! -f /etc/os-release ]]; then
		msg_err "Cannot detect OS: /etc/os-release not found."
		return 1
	fi
	. /etc/os-release
	OS_ID="${ID,,}"
	local os_ver="${VERSION_ID%%.*}"
	case "$OS_ID" in
		ubuntu)
			if [[ -n "$os_ver" ]] && (( os_ver < 24 )); then
				msg_err "Unsupported OS: Ubuntu $VERSION_ID detected. Ubuntu 24+ is required. Please upgrade your OS."
				return 1
			fi
			;;
		debian)
			if [[ -n "$os_ver" ]] && (( os_ver < 12 )); then
				msg_err "Unsupported OS: Debian $VERSION_ID detected. Debian 12 or 13 is required. Please upgrade your OS."
				return 1
			fi
			;;
		*)
			msg_err "Unsupported OS: $PRETTY_NAME. Only Ubuntu 24+ and Debian 12/13 are supported."
			return 1
			;;
	esac
	return 0
}

check_cpu() {
	local cpu_model
	cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
	if [[ "$cpu_model" == *"QEMU"* ]]; then
		warn "QEMU virtual CPU detected ($cpu_model). Installation will continue, but network or performance issues are still possible. For production prefer a host CPU model."
		return 0
	fi
	return 0
}

preflight_checks() {
	local fail=0
	check_os  || fail=1
	check_cpu || fail=1
	if (( fail )); then
		die "Preflight checks failed. Exiting."
	fi
	# Initialize release for install_panel() Alpine checks
	release="$OS_ID"
}
preflight_checks

##############################IP Detection################################################################
detect_ips() {
	IP4=$(ip route get 8.8.8.8 2>&1 | grep -Po -- 'src \K\S*')
	[[ "$IP4" =~ $IP4_REGEX ]] || IP4=$(curl -s ipv4.icanhazip.com | tr -d '[:space:]')
	IP6=$(ip route get 2620:fe::fe 2>&1 | grep -Po -- 'src \K\S*')
	[[ "$IP6" =~ $IP6_REGEX ]] || IP6=$(curl -s ipv6.icanhazip.com | tr -d '[:space:]')
}

resolve_to_ip() {
	local host="$1"
	getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | grep -Fxq "$IP4"
}

##############################Port & String Generators####################################################
get_random_port() {
	local port_base port_span
	port_base="$(platform_dynamic_port_base)"
	port_span="$(platform_dynamic_port_span)"
	echo $(( ((RANDOM<<15)|RANDOM) % port_span + port_base ))
}

gen_random_string() {
	local length="$1"
	head -c 4096 /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
	echo
}

port_in_use() {
	local port="$1"
	nc -z 127.0.0.1 "$port" &>/dev/null
}

make_port() {
	local p
	while true; do
		p=$(get_random_port)
		if ! port_in_use "$p"; then
			echo "$p"
			break
		fi
	done
}

##############################Architecture Detection######################################################
arch() {
	case "$(uname -m)" in
		x86_64 | x64 | amd64) echo 'amd64' ;;
		i*86 | x86) echo '386' ;;
		armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
		armv7* | armv7 | arm) echo 'armv7' ;;
		armv6* | armv6) echo 'armv6' ;;
		armv5* | armv5) echo 'armv5' ;;
		s390x) echo 's390x' ;;
		*) printf '%bUnsupported CPU architecture!%b\n' "${green}" "${plain}" && exit 1 ;;
	esac
}
xray_binary_path() {
	local arch_name
	arch_name=$(arch)
	case "$arch_name" in
		armv5|armv6|armv7)
			if [[ -x /usr/local/x-ui/bin/xray-linux-arm ]]; then
				printf '%s\n' "/usr/local/x-ui/bin/xray-linux-arm"
			else
				printf '%s\n' "/usr/local/x-ui/bin/xray-linux-${arch_name}"
			fi
			;;
		*)
			printf '%s\n' "/usr/local/x-ui/bin/xray-linux-${arch_name}"
			;;
	esac
}
is_valid_reality_x25519_key() {
	[[ "$1" =~ ^[A-Za-z0-9_-]{40,60}$ ]]
}
extract_x25519_private_key() {
	printf '%s\n' "$1" | awk -F': ' '/^Private[[:space:]]*[Kk]ey:/{print $2; exit}'
}
extract_x25519_public_key() {
	printf '%s\n' "$1" | awk -F': ' '/^Public[[:space:]]*[Kk]ey:/{print $2; exit} /^Password:/{print $2; exit}'
}
generate_reality_x25519_pair() {
	local xray_bin="$1" output=""
	output=$("$xray_bin" x25519)
	append_debug_log "xray x25519 output: ${output//$'\n'/; }"
	private_key=$(extract_x25519_private_key "$output")
	public_key=$(extract_x25519_public_key "$output")
	if ! is_valid_reality_x25519_key "$private_key"; then
		die "Failed to parse REALITY private key from xray x25519 output."
	fi
	if ! is_valid_reality_x25519_key "$public_key"; then
		die "Failed to parse REALITY public key from xray x25519 output."
	fi
}
verify_reality_inbound_keys() {
	local reality_stream="" reality_private_key="" reality_public_key=""
	[[ -f "$XUIDB" ]] || return 1
	command -v sqlite3 >/dev/null 2>&1 || return 1
	command -v jq >/dev/null 2>&1 || return 1
	reality_stream=$(sqlite3 -list "$XUIDB" "SELECT stream_settings FROM inbounds WHERE json_extract(stream_settings, '$.security')='reality' LIMIT 1;" 2>/dev/null)
	[[ -n "$reality_stream" ]] || return 1
	reality_private_key=$(printf '%s' "$reality_stream" | jq -r '.realitySettings.privateKey // empty' 2>/dev/null)
	reality_public_key=$(printf '%s' "$reality_stream" | jq -r '.realitySettings.settings.publicKey // .realitySettings.publicKey // .realitySettings.password // empty' 2>/dev/null)
	append_debug_log "Reality inbound private key length: ${#reality_private_key}"
	append_debug_log "Reality inbound public key length: ${#reality_public_key}"
	is_valid_reality_x25519_key "$reality_private_key" && is_valid_reality_x25519_key "$reality_public_key"
}
detect_ssh_ports() {
	local ports=()
	local current_port
	local port

	current_port=$(printf '%s\n' "${SSH_CONNECTION:-}" | awk 'NF >= 4 {print $4}')
	if [[ "$current_port" =~ ^[0-9]+$ ]]; then
		ports+=("$current_port")
	fi

	if command -v sshd >/dev/null 2>&1; then
		while IFS= read -r port; do
			[[ "$port" =~ ^[0-9]+$ ]] && ports+=("$port")
		done < <(sshd -T 2>/dev/null | awk '$1 == "port" {print $2}')
	fi

	if [[ ${#ports[@]} -eq 0 ]]; then
		ports+=(22)
	fi

	printf '%s\n' "${ports[@]}" | awk 'NF && !seen[$0]++'
}

##############################Sysctl Idempotent Writer#####################################################
sysctl_ensure() {
	local key="$1" value="$2"
	local entry="$key=$value"
	if grep -q "^${key}[[:space:]]*=" /etc/sysctl.conf 2>/dev/null; then
		sed -i "s|^${key}[[:space:]]*=.*|${entry}|" /etc/sysctl.conf
	else
		echo "$entry" >> /etc/sysctl.conf
	fi
}

##############################Argument Parsing############################################################
parse_args() {
	domain=""
	UNINSTALL="x"
	INSTALL="n"
	PNLNUM=1
	CFALLOW="n"
	CLASH=0
	CUSTOMWEBSUB=0
	AUTODOMAIN="n"
	DEBUG_MODE="n"
	DRY_RUN="n"
	VERIFY_MODE="n"
	STAGE="all"
	SKIP_CLEANUP="n"
	KEEP_ARTIFACTS="n"
	CONFIRM_RESET="n"
	ACCEPTANCE_MINUTES="${ACCEPTANCE_MINUTES:-5}"
	ACCEPTANCE_INTERVAL_SECONDS="${ACCEPTANCE_INTERVAL_SECONDS:-30}"
	ACCEPTANCE_LABEL="${ACCEPTANCE_LABEL:-}"
	ACCEPTANCE_MATRIX_GROUP="${ACCEPTANCE_MATRIX_GROUP:-}"
	ACCEPTANCE_NETWORK_LABEL="${ACCEPTANCE_NETWORK_LABEL:-}"
	ACCEPTANCE_OPERATOR_LABEL="${ACCEPTANCE_OPERATOR_LABEL:-}"
	ACCEPTANCE_TIME_WINDOW="${ACCEPTANCE_TIME_WINDOW:-}"
	ACCEPTANCE_CLIENT_DEVICE="${ACCEPTANCE_CLIENT_DEVICE:-}"
	ACCEPTANCE_NOTES="${ACCEPTANCE_NOTES:-}"
	PLATFORM_PROFILE="${PLATFORM_PROFILE:-classic}"
	TRANSPORT_PROFILE="${TRANSPORT_PROFILE:-classic-xray}"
	PANEL_PROVIDER="${PANEL_PROVIDER:-3x-ui}"
	ENABLE_AWG="${ENABLE_AWG:-n}"
	OVERRIDE_REALITY_TUNING_PROFILE="${OVERRIDE_REALITY_TUNING_PROFILE:-${REALITY_TUNING_PROFILE:-}}"
	OVERRIDE_XHTTP_TUNING_PROFILE="${OVERRIDE_XHTTP_TUNING_PROFILE:-${XHTTP_TUNING_PROFILE:-}}"

	while [[ "$#" -gt 0 ]]; do
		case "$1" in
			-auto_domain) AUTODOMAIN="$2"; shift 2;;
			-install) INSTALL="$2"; shift 2;;
			-panel) PNLNUM="$2"; shift 2;;
			-subdomain) domain="$2"; shift 2;;
			-reality_domain) reality_domain="$2"; shift 2;;
			-ONLY_CF_IP_ALLOW) CFALLOW="$2"; shift 2;;
			-websub) CUSTOMWEBSUB="$2"; shift 2;;
			-clash) CLASH="$2"; shift 2;;
			-uninstall) UNINSTALL="$2"; shift 2;;
			-debug) DEBUG_MODE="$2"; shift 2;;
			-dry_run) DRY_RUN="$2"; shift 2;;
			-verify) VERIFY_MODE="$2"; shift 2;;
			-stage) STAGE="$2"; shift 2;;
			-skip_cleanup) SKIP_CLEANUP="$2"; shift 2;;
			-keep_artifacts) KEEP_ARTIFACTS="$2"; shift 2;;
			-confirm_reset) CONFIRM_RESET="$2"; shift 2;;
			-acceptance_minutes) ACCEPTANCE_MINUTES="$2"; shift 2;;
			-acceptance_interval_seconds) ACCEPTANCE_INTERVAL_SECONDS="$2"; shift 2;;
			-acceptance_label) ACCEPTANCE_LABEL="$2"; shift 2;;
			-acceptance_matrix_group) ACCEPTANCE_MATRIX_GROUP="$2"; shift 2;;
			-acceptance_network) ACCEPTANCE_NETWORK_LABEL="$2"; shift 2;;
			-acceptance_operator) ACCEPTANCE_OPERATOR_LABEL="$2"; shift 2;;
			-acceptance_time_window) ACCEPTANCE_TIME_WINDOW="$2"; shift 2;;
			-acceptance_client) ACCEPTANCE_CLIENT_DEVICE="$2"; shift 2;;
			-acceptance_notes) ACCEPTANCE_NOTES="$2"; shift 2;;
			-profile|-platform_profile) PLATFORM_PROFILE="$2"; shift 2;;
			-transport_profile) TRANSPORT_PROFILE="$2"; shift 2;;
			-panel_provider) PANEL_PROVIDER="$2"; shift 2;;
			-enable_awg) ENABLE_AWG="$2"; shift 2;;
			-reality_tuning_profile) OVERRIDE_REALITY_TUNING_PROFILE="$2"; shift 2;;
			-xhttp_tuning_profile) OVERRIDE_XHTTP_TUNING_PROFILE="$2"; shift 2;;
			*) shift 1;;
		esac
	done
}

##############################Uninstall###################################################################
stop_sub2singbox() {
	systemctl stop sub2sing-box 2>/dev/null || true
	systemctl disable sub2sing-box 2>/dev/null || true
	if pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		pkill -x "sub2sing-box" 2>/dev/null || true
	fi
}
stop_subjson_rewrite() {
	systemctl stop subjson-rewrite 2>/dev/null || true
	systemctl disable subjson-rewrite 2>/dev/null || true
}
remove_reset_residuals() {
	local path
	local extra_ports=()
	local web_tls_port reality_site_tls_port
	stop_sub2singbox
	stop_subjson_rewrite
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable nginx x-ui 2>/dev/null || true
	web_tls_port="$(platform_transport_web_tls_port)"
	reality_site_tls_port="$(platform_transport_reality_site_tls_port)"
	for path in \
		"/etc/systemd/system/x-ui.service" \
		"/etc/systemd/system/multi-user.target.wants/x-ui.service" \
		"/etc/systemd/system/sub2sing-box.service" \
		"/etc/systemd/system/multi-user.target.wants/sub2sing-box.service" \
		"$SUBJSON_REWRITE_SERVICE" \
		"/etc/systemd/system/multi-user.target.wants/subjson-rewrite.service" \
		"/usr/local/x-ui" \
		"/etc/x-ui" \
		"/usr/bin/x-ui" \
		"/usr/bin/sub2sing-box" \
		"$SUBJSON_REWRITE_BIN" \
		"/var/www/subpage" \
		"/var/www/html" \
		"/etc/nginx" \
		"/usr/share/nginx" \
		"/etc/letsencrypt" \
		"/var/lib/letsencrypt" \
		"/var/log/letsencrypt"; do
		rm -rf "$path"
	done
	systemctl daemon-reload 2>/dev/null || true
	systemctl reset-failed nginx x-ui sub2sing-box subjson-rewrite 2>/dev/null || true
	fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null || true
	[[ "$web_tls_port" =~ ^[0-9]+$ && "$web_tls_port" != "80" && "$web_tls_port" != "443" ]] && extra_ports+=("$web_tls_port")
	[[ "$reality_site_tls_port" =~ ^[0-9]+$ && "$reality_site_tls_port" != "80" && "$reality_site_tls_port" != "443" && "$reality_site_tls_port" != "$web_tls_port" ]] && extra_ports+=("$reality_site_tls_port")
	for path in "${extra_ports[@]}"; do
		fuser -k "${path}/tcp" "${path}/udp" 2>/dev/null || true
	done
}
uninstall_xui() {
	if command -v x-ui >/dev/null 2>&1; then
		printf 'y\n' | x-ui uninstall || true
	fi
	remove_reset_residuals
	"$PKG_MGR" -y remove certbot python3-certbot-nginx nginx nginx-common nginx-core nginx-full || true
	"$PKG_MGR" -y purge certbot python3-certbot-nginx nginx nginx-common nginx-core nginx-full || true
	"$PKG_MGR" -y autoremove || true
	"$PKG_MGR" -y autoclean || true
	stop_sub2singbox
	stop_subjson_rewrite
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable x-ui sub2sing-box subjson-rewrite 2>/dev/null || true
	rm -rf /etc/systemd/system/x-ui.service
	rm -rf /etc/systemd/system/multi-user.target.wants/x-ui.service
	rm -rf /etc/systemd/system/sub2sing-box.service
	rm -rf /etc/systemd/system/multi-user.target.wants/sub2sing-box.service
	rm -rf "$SUBJSON_REWRITE_SERVICE"
	rm -rf /etc/systemd/system/multi-user.target.wants/subjson-rewrite.service
	rm -rf /usr/local/x-ui
	rm -rf /etc/x-ui
	rm -rf /usr/bin/x-ui
	rm -rf /usr/bin/sub2sing-box
	rm -rf "$SUBJSON_REWRITE_BIN"
	rm -rf /var/www/subpage
	rm -rf /var/www/html
	rm -rf /etc/nginx
	rm -rf /usr/share/nginx
	rm -rf /root/cert
	systemctl daemon-reload 2>/dev/null || true
	systemctl reset-failed nginx x-ui sub2sing-box subjson-rewrite 2>/dev/null || true
}

##############################Clean Previous Install######################################################
clean_previous_install() {
	if is_yes "$SKIP_CLEANUP"; then
		msg_inf "SKIP_CLEANUP активирован: пропускаю удаление предыдущей установки."
		append_debug_log "Cleanup skipped because SKIP_CLEANUP is enabled"
		return 0
	fi
	stop_sub2singbox
	stop_subjson_rewrite
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable x-ui sub2sing-box subjson-rewrite 2>/dev/null || true
	rm -rf /etc/systemd/system/x-ui.service
	rm -rf /etc/systemd/system/multi-user.target.wants/x-ui.service
	rm -rf /etc/systemd/system/sub2sing-box.service
	rm -rf /etc/systemd/system/multi-user.target.wants/sub2sing-box.service
	rm -rf "$SUBJSON_REWRITE_SERVICE"
	rm -rf /etc/systemd/system/multi-user.target.wants/subjson-rewrite.service
	rm -rf /usr/local/x-ui
	rm -rf /etc/x-ui
	rm -rf /usr/bin/x-ui
	rm -rf /usr/bin/sub2sing-box
	rm -rf "$SUBJSON_REWRITE_BIN"
	rm -rf /var/www/subpage
	rm -rf /var/www/html
	rm -rf /root/cert
	rm -f /etc/nginx/snippets/includes.conf
	rm -f /etc/nginx/modules-enabled/50-mod-stream.conf
	rm -f /etc/nginx/modules-enabled/70-mod-stream-geoip2.conf
	rm -rf /etc/nginx/sites-enabled/*
	rm -rf /etc/nginx/sites-available/*
	rm -rf /etc/nginx/stream-enabled/*
	systemctl daemon-reload 2>/dev/null || true
	systemctl reset-failed nginx x-ui sub2sing-box subjson-rewrite 2>/dev/null || true
}

##############################Install Packages############################################################
install_packages() {
	if [[ "${INSTALL}" == *"y"* ]]; then
		"$PKG_MGR" -y update
		"$PKG_MGR" -y install curl wget jq bash sudo nginx-full certbot python3 python3-certbot-nginx sqlite3 ufw
		systemctl daemon-reload && systemctl enable --now nginx
	fi
	systemctl stop nginx
	fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null
}

##############################SSL Helper##################################################################
obtain_ssl() {
	local cert_domain="$1"
	local cert_dir="/etc/letsencrypt/live/${cert_domain}"
	if [[ -f "${cert_dir}/fullchain.pem" && -f "${cert_dir}/privkey.pem" ]] && \
		openssl x509 -checkend 86400 -noout -in "${cert_dir}/fullchain.pem" >/dev/null 2>&1; then
		msg_inf "Reusing existing certificate for ${cert_domain}"
		append_debug_log "Reusing existing certificate for ${cert_domain}"
		return 0
	fi
	certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email -d "$cert_domain"
	if [[ ! -d "/etc/letsencrypt/live/${cert_domain}/" ]]; then
		systemctl start nginx >/dev/null 2>&1
		die "$cert_domain SSL could not be generated! Check Domain/IP Or Enter new domain!"
	fi
}

##############################Nginx Config################################################################
write_nginx_edge_hardening_snippets() {
	cat > "/etc/nginx/snippets/edge-security-headers.conf" <<'EOF'
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-Frame-Options "SAMEORIGIN" always;
EOF

	cat > "/etc/nginx/snippets/sensitive-edge-headers.conf" <<'EOF'
proxy_hide_header X-Powered-By;
proxy_hide_header Server;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
add_header Pragma "no-cache" always;
add_header Expires "0" always;
add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
EOF
}

setup_nginx_classic() {
	mkdir -p "/root/cert/${domain}"
	mkdir -p /etc/nginx/modules-enabled /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets /etc/nginx/stream-enabled
	chmod 700 /root/cert/*
	write_nginx_edge_hardening_snippets

	local public_http_port public_https_port web_tls_port reality_inbound_port reality_site_tls_port sub2singbox_bind_port
	public_http_port="$(platform_public_http_port)"
	public_https_port="$(platform_public_https_port)"
	web_tls_port="$(platform_transport_web_tls_port)"
	reality_inbound_port="$(platform_transport_reality_inbound_port)"
	reality_site_tls_port="$(platform_transport_reality_site_tls_port)"
	sub2singbox_bind_port="$(platform_sub2singbox_bind_port)"

	ln -sf "/etc/letsencrypt/live/${domain}/fullchain.pem" "/root/cert/${domain}/fullchain.pem"
	ln -sf "/etc/letsencrypt/live/${domain}/privkey.pem" "/root/cert/${domain}/privkey.pem"

	mkdir -p /etc/nginx/stream-enabled
	cat > "/etc/nginx/stream-enabled/stream.conf" << EOF
map \$ssl_preread_server_name \$sni_name {
    hostnames;
    ${reality_domain}      xray;
    ${domain}           www;
    default              xray;
}

upstream xray {
    server 127.0.0.1:${reality_inbound_port};
}

upstream www {
    server 127.0.0.1:${web_tls_port};
}

server {
    proxy_protocol on;
    set_real_ip_from unix:;
    listen          ${public_https_port};
    proxy_pass      \$sni_name;
    ssl_preread     on;
}

EOF

	grep -qF "stream { include /etc/nginx/stream-enabled/*.conf; }" /etc/nginx/nginx.conf || echo "stream { include /etc/nginx/stream-enabled/*.conf; }" >> /etc/nginx/nginx.conf

	local nginx_v stream_ready="n"
	nginx_v=$(nginx -V 2>&1)
	sed -i '/ngx_stream_module\.so/d;/ngx_stream_geoip2_module\.so/d' /etc/nginx/nginx.conf
	rm -f /etc/nginx/modules-enabled/50-mod-stream.conf /etc/nginx/modules-enabled/70-mod-stream-geoip2.conf

	if printf '%s' "$nginx_v" | grep -q -- '--with-stream=dynamic'; then
		if [[ -f /usr/lib/nginx/modules/ngx_stream_module.so ]]; then
			cat > /etc/nginx/modules-enabled/50-mod-stream.conf <<'EOF'
load_module /usr/lib/nginx/modules/ngx_stream_module.so;
EOF
			msg_inf "stream module enabled via modules-enabled/50-mod-stream.conf"
			stream_ready="y"
		else
			warn "nginx reports --with-stream=dynamic but ngx_stream_module.so is missing"
		fi
	elif printf '%s' "$nginx_v" | grep -qE -- '(^|[[:space:]])--with-stream([[:space:]]|$)'; then
		msg_inf "stream module is compiled statically, skipping load_module"
		stream_ready="y"
	elif ls /etc/nginx/modules-enabled/*stream* &>/dev/null; then
		msg_inf "stream module already enabled via modules-enabled, keeping existing configuration"
		stream_ready="y"
	elif [[ -f /usr/lib/nginx/modules/ngx_stream_module.so ]]; then
		cat > /etc/nginx/modules-enabled/50-mod-stream.conf <<'EOF'
load_module /usr/lib/nginx/modules/ngx_stream_module.so;
EOF
		msg_inf "stream module enabled via modules-enabled/50-mod-stream.conf"
		stream_ready="y"
	else
		warn "ngx_stream_module.so not found and stream not built-in; install libnginx-mod-stream"
	fi

	if [[ "$stream_ready" == "y" && -f /usr/lib/nginx/modules/ngx_stream_geoip2_module.so ]]; then
		cat > /etc/nginx/modules-enabled/70-mod-stream-geoip2.conf <<'EOF'
load_module /usr/lib/nginx/modules/ngx_stream_geoip2_module.so;
EOF
		msg_inf "stream geoip2 module enabled via modules-enabled/70-mod-stream-geoip2.conf"
	elif [[ "$stream_ready" == "y" ]]; then
		warn "ngx_stream_geoip2_module.so not found; geoip2 filtering will not work"
	fi

	grep -qF "worker_rlimit_nofile 16384;" /etc/nginx/nginx.conf || echo "worker_rlimit_nofile 16384;" >> /etc/nginx/nginx.conf
	sed -i "/worker_connections/c\worker_connections 4096;" /etc/nginx/nginx.conf

	cat > "/etc/nginx/sites-available/80.conf" << EOF
server {
    listen ${public_http_port};
    server_name ${domain} ${reality_domain};
    return 301 https://\$host\$request_uri;
}
EOF

	cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
	server_tokens off;
	server_name ${domain};
	listen ${web_tls_port} ssl http2 proxy_protocol;
	listen [::]:${web_tls_port} ssl http2 proxy_protocol;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
	client_header_buffer_size 4k;
	large_client_header_buffers 8 16k;
	client_body_buffer_size 512k;
	keepalive_requests 1000;
	keepalive_timeout 52s;
	if (\$host !~* ^(.+\.)?$domain\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?$domain\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	include /etc/nginx/snippets/edge-security-headers.conf;
	#X-UI Admin Panel
	location /${panel_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
        location /${panel_path} {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
	include /etc/nginx/snippets/includes.conf;

}
EOF

	cat > "/etc/nginx/snippets/includes.conf" << EOF
	#sub2sing-box
	location /${sub2singbox_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header Accept-Encoding "";
		sub_filter_once off;
		sub_filter 'https://unpkg.com/mdui@2/mdui.css' '$(sub2singbox_ui_asset_base)/mdui.css';
		sub_filter 'https://unpkg.com/mdui@2/mdui.global.js' '$(sub2singbox_ui_asset_base)/mdui.global.js';
		sub_filter 'https://fonts.googleapis.com/css?family=Roboto|Noto+Sans+SC&display=swap' '$(sub2singbox_ui_asset_base)/sub2sing-box-fonts.css';
		sub_filter 'https://fonts.googleapis.com/icon?family=Material+Icons+Outlined' '$(sub2singbox_ui_asset_base)/material-icons-outlined.css';
		sub_filter 'https://fonts.googleapis.com/icon?family=Material+Icons' '$(sub2singbox_ui_asset_base)/material-icons.css';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle.json' '$(sub2singbox_rule_set_base)/ru-bundle.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle-refilter.json' '$(sub2singbox_rule_set_base)/ru-bundle-refilter.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/re-filter.json' '$(sub2singbox_rule_set_base)/re-filter.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/secret-sing-box.json' '$(sub2singbox_rule_set_base)/secret-sing-box.json';
		proxy_pass http://127.0.0.1:${sub2singbox_bind_port}/;
		}
    location = /${web_path} {
        return 302 /${web_path}/\$is_args\$args;
    }
    # Path to open clash.yaml and generate YAML
    location ~ ^/${web_path}/clashmeta/(.+)$ {
        default_type text/plain;
        ssi on;
        ssi_types text/plain;
        set \$subid \$1;
        root /var/www/subpage;
        try_files /clash.yaml =404;
    }
    # web
    location /${web_path}/ {
        alias /var/www/subpage/;
        index index.html;
    }
	#Subscription Path (simple/encode)
        location /${sub_path} {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${sub_path}/ {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	#Subscription Path (json/fragment)
        location /${json_path} {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:${SUBJSON_REWRITE_PORT};
                break;
        }
	location /${json_path}/ {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:${SUBJSON_REWRITE_PORT};
                break;
        }
        #XHTTP
        location /${xhttp_path} {
          client_max_body_size       0;
          client_body_timeout        1h;
          grpc_pass                  unix:/dev/shm/uds2023.sock;
          grpc_buffer_size         16k;
          grpc_socket_keepalive    on;
          grpc_read_timeout        1h;
          grpc_send_timeout        1h;
          grpc_set_header Connection         "";
          grpc_set_header X-Real-IP          \$remote_addr;
          grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
          grpc_set_header X-Forwarded-Proto  \$scheme;
          grpc_set_header X-Forwarded-Port   \$server_port;
          grpc_set_header Host               \$host;
          grpc_set_header X-Forwarded-Host   \$host;
          grpc_set_header Forwarded          "for=\$proxy_add_x_forwarded_for;proto=\$scheme";
          }
	#Xray Config Path
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
		if (\$hack = 1) {return 404;}
		client_max_body_size 0;
		client_body_timeout 1d;
		grpc_read_timeout 1d;
		grpc_socket_keepalive on;
		proxy_read_timeout 1d;
		proxy_http_version 1.1;
		proxy_buffering off;
		proxy_request_buffering off;
		proxy_socket_keepalive on;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		#proxy_set_header CF-IPCountry \$http_cf_ipcountry;
		#proxy_set_header CF-IP \$realip_remote_addr;
		if (\$content_type ~* "GRPC") {
			grpc_pass grpc://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
		if (\$http_upgrade ~* "(WEBSOCKET|WS)") {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
	        }
		if (\$request_method ~* ^(PUT|POST|GET)\$) {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
	}
	location / { try_files \$uri \$uri/ =404; }
EOF

	cat > "/etc/nginx/sites-available/${reality_domain}" << EOF
server {
	server_tokens off;
	server_name ${reality_domain};
	listen ${reality_site_tls_port} ssl http2;
	listen [::]:${reality_site_tls_port} ssl http2;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$reality_domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$reality_domain/privkey.pem;
	if (\$host !~* ^(.+\.)?${reality_domain}\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?${reality_domain}\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	include /etc/nginx/snippets/edge-security-headers.conf;
	#X-UI Admin Panel
	location /${panel_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:${panel_port};
		break;
	}
        location /$panel_path {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:${panel_port};
		break;
	}
include /etc/nginx/snippets/includes.conf;
}
EOF
}

setup_nginx_stealth() {
	mkdir -p "/root/cert/${domain}"
	mkdir -p /etc/nginx/modules-enabled /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets /etc/nginx/stream-enabled
	chmod 700 /root/cert/*
	write_nginx_edge_hardening_snippets

	local public_http_port web_tls_port reality_site_tls_port sub2singbox_bind_port
	public_http_port="$(platform_public_http_port)"
	web_tls_port="$(platform_transport_web_tls_port)"
	reality_site_tls_port="$(platform_transport_reality_site_tls_port)"
	sub2singbox_bind_port="$(platform_sub2singbox_bind_port)"

	ln -sf "/etc/letsencrypt/live/${domain}/fullchain.pem" "/root/cert/${domain}/fullchain.pem"
	ln -sf "/etc/letsencrypt/live/${domain}/privkey.pem" "/root/cert/${domain}/privkey.pem"

	rm -f /etc/nginx/stream-enabled/stream.conf /etc/nginx/modules-enabled/50-mod-stream.conf /etc/nginx/modules-enabled/70-mod-stream-geoip2.conf
	sed -i '/stream { include \/etc\/nginx\/stream-enabled\/\*\.conf; }/d;/ngx_stream_module\.so/d;/ngx_stream_geoip2_module\.so/d' /etc/nginx/nginx.conf
	grep -qF "worker_rlimit_nofile 16384;" /etc/nginx/nginx.conf || echo "worker_rlimit_nofile 16384;" >> /etc/nginx/nginx.conf
	sed -i "/worker_connections/c\worker_connections 4096;" /etc/nginx/nginx.conf

	cat > "/etc/nginx/sites-available/80.conf" << EOF
server {
    listen ${public_http_port};
    server_name ${domain} ${reality_domain};
    return 301 https://\$host\$request_uri;
}
EOF

	cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
	server_tokens off;
	server_name ${domain};
	listen ${web_tls_port} ssl http2 proxy_protocol;
	listen [::]:${web_tls_port} ssl http2 proxy_protocol;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
	client_header_buffer_size 4k;
	large_client_header_buffers 8 16k;
	client_body_buffer_size 512k;
	keepalive_requests 1000;
	keepalive_timeout 52s;
	if (\$host !~* ^(.+\.)?$domain\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?$domain\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	include /etc/nginx/snippets/edge-security-headers.conf;
	#X-UI Admin Panel
	location /${panel_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
        location /${panel_path} {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;

        proxy_pass https://127.0.0.1:${panel_port};
		break;
	}
	include /etc/nginx/snippets/includes.conf;

}
EOF

	cat > "/etc/nginx/snippets/includes.conf" << EOF
  	#sub2sing-box
	location /${sub2singbox_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header Accept-Encoding "";
		sub_filter_once off;
		sub_filter 'https://unpkg.com/mdui@2/mdui.css' '$(sub2singbox_ui_asset_base)/mdui.css';
		sub_filter 'https://unpkg.com/mdui@2/mdui.global.js' '$(sub2singbox_ui_asset_base)/mdui.global.js';
		sub_filter 'https://fonts.googleapis.com/css?family=Roboto|Noto+Sans+SC&display=swap' '$(sub2singbox_ui_asset_base)/sub2sing-box-fonts.css';
		sub_filter 'https://fonts.googleapis.com/icon?family=Material+Icons+Outlined' '$(sub2singbox_ui_asset_base)/material-icons-outlined.css';
		sub_filter 'https://fonts.googleapis.com/icon?family=Material+Icons' '$(sub2singbox_ui_asset_base)/material-icons.css';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle.json' '$(sub2singbox_rule_set_base)/ru-bundle.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/ru-bundle-refilter.json' '$(sub2singbox_rule_set_base)/ru-bundle-refilter.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/re-filter.json' '$(sub2singbox_rule_set_base)/re-filter.json';
		sub_filter 'https://github.com/legiz-ru/sb-rule-sets/raw/main/.github/sub2sing-box/secret-sing-box.json' '$(sub2singbox_rule_set_base)/secret-sing-box.json';
		proxy_pass http://127.0.0.1:${sub2singbox_bind_port}/;
		}
    location = /${web_path} {
        return 302 /${web_path}/\$is_args\$args;
    }
    # Path to open clash.yaml and generate YAML
    location ~ ^/${web_path}/clashmeta/(.+)$ {
        default_type text/plain;
        ssi on;
        ssi_types text/plain;
        set \$subid \$1;
        root /var/www/subpage;
        try_files /clash.yaml =404;
    }
    # web
    location /${web_path}/ {
        alias /var/www/subpage/;
        index index.html;
    }
 	#Subscription Path (simple/encode)
        location /${sub_path} {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${sub_path}/ {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	#Subscription Path (json/fragment)
        location /${json_path} {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:${SUBJSON_REWRITE_PORT};
                break;
        }
	location /${json_path}/ {
                include /etc/nginx/snippets/sensitive-edge-headers.conf;
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:${SUBJSON_REWRITE_PORT};
                break;
        }
        #XHTTP
        location /${xhttp_path} {
          client_max_body_size       0;
          client_body_timeout        1h;
          grpc_pass                  unix:/dev/shm/uds2023.sock;
          grpc_buffer_size         16k;
          grpc_socket_keepalive    on;
          grpc_read_timeout        1h;
          grpc_send_timeout        1h;
          grpc_set_header Connection         "";
          grpc_set_header X-Real-IP          \$remote_addr;
          grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
          grpc_set_header X-Forwarded-Proto  \$scheme;
          grpc_set_header X-Forwarded-Port   \$server_port;
          grpc_set_header Host               \$host;
          grpc_set_header X-Forwarded-Host   \$host;
          grpc_set_header Forwarded          "for=\$proxy_add_x_forwarded_for;proto=\$scheme";
          }
 	#Xray Config Path
	location ~ ^/(?<fwdport>\d+)/(?<fwdpath>.*)\$ {
		if (\$hack = 1) {return 404;}
		client_max_body_size 0;
		client_body_timeout 1d;
		grpc_read_timeout 1d;
		grpc_socket_keepalive on;
		proxy_read_timeout 1d;
		proxy_http_version 1.1;
		proxy_buffering off;
		proxy_request_buffering off;
		proxy_socket_keepalive on;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		#proxy_set_header CF-IPCountry \$http_cf_ipcountry;
		#proxy_set_header CF-IP \$realip_remote_addr;
		if (\$content_type ~* "GRPC") {
			grpc_pass grpc://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
		if (\$http_upgrade ~* "(WEBSOCKET|WS)") {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
	        }
		if (\$request_method ~* ^(PUT|POST|GET)\$) {
			proxy_pass http://127.0.0.1:\$fwdport\$is_args\$args;
			break;
		}
	}
	location / { try_files \$uri \$uri/ =404; }
EOF

	cat > "/etc/nginx/sites-available/${reality_domain}" << EOF
server {
	server_tokens off;
	server_name ${reality_domain};
	listen ${reality_site_tls_port} ssl http2 proxy_protocol;
	listen [::]:${reality_site_tls_port} ssl http2 proxy_protocol;
	index index.html index.htm index.php index.nginx-debian.html;
	root /var/www/html/;
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers HIGH:!aNULL:!eNULL:!MD5:!DES:!RC4:!ADH:!SSLv3:!EXP:!PSK:!DSS;
	ssl_certificate /etc/letsencrypt/live/$reality_domain/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$reality_domain/privkey.pem;
	if (\$host !~* ^(.+\.)?${reality_domain}\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?${reality_domain}\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	include /etc/nginx/snippets/edge-security-headers.conf;
	#X-UI Admin Panel
	location /${panel_path}/ {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:${panel_port};
		break;
	}
        location /$panel_path {
		include /etc/nginx/snippets/sensitive-edge-headers.conf;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:${panel_port};
		break;
	}
include /etc/nginx/snippets/includes.conf;
}
EOF
}

##############################Enable Nginx Sites##########################################################
enable_nginx_sites_classic() {
	if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
		unlink "/etc/nginx/sites-enabled/default" >/dev/null 2>&1
		rm -f "/etc/nginx/sites-enabled/default" "/etc/nginx/sites-available/default"
		ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/"
		ln -sf "/etc/nginx/sites-available/${reality_domain}" "/etc/nginx/sites-enabled/"
		ln -sf "/etc/nginx/sites-available/80.conf" "/etc/nginx/sites-enabled/"
	else
		die "${domain} nginx config not exist!"
	fi

	if [[ $(nginx -t 2>&1 | grep -o 'successful') != "successful" ]]; then
		die "nginx config is not ok!"
	else
		systemctl start nginx
	fi
}

enable_nginx_sites_stealth() {
	if [[ -f "/etc/nginx/sites-available/${domain}" ]]; then
		unlink "/etc/nginx/sites-enabled/default" >/dev/null 2>&1
		rm -f "/etc/nginx/sites-enabled/default" "/etc/nginx/sites-available/default"
		rm -f "/etc/nginx/sites-enabled/stream.conf"
		rm -f "/etc/nginx/stream-enabled/stream.conf"
		rm -f "/etc/nginx/modules-enabled/50-mod-stream.conf" "/etc/nginx/modules-enabled/70-mod-stream-geoip2.conf"
		ln -sf "/etc/nginx/sites-available/${domain}" "/etc/nginx/sites-enabled/"
		ln -sf "/etc/nginx/sites-available/${reality_domain}" "/etc/nginx/sites-enabled/"
		ln -sf "/etc/nginx/sites-available/80.conf" "/etc/nginx/sites-enabled/"
	else
		die "${domain} nginx config not exist!"
	fi

	if [[ $(nginx -t 2>&1 | grep -o 'successful') != "successful" ]]; then
		die "nginx config is not ok!"
	else
		systemctl start nginx
	fi
}

##############################Read Existing XUI DB########################################################
read_existing_xui_db() {
	if [[ -f "$XUIDB" ]]; then
		XUIPORT=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>&1)
		XUIPATH=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webBasePath" LIMIT 1;' 2>&1)
		if [[ "$XUIPORT" -gt 0 && "$XUIPORT" != "54321" && "$XUIPORT" != "2053" ]] && [[ ${#XUIPORT} -gt 4 ]]; then
			RNDSTR=$(echo "$XUIPATH" 2>&1 | tr -d '/')
			PORT=$XUIPORT
			sqlite3 "$XUIDB" <<EOF
	DELETE FROM "settings" WHERE ( "key"="webCertFile" ) OR ( "key"="webKeyFile" );
	INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  "");
	INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile", "");
EOF
		fi
	fi
}

##############################Update XUI DB###############################################################
write_panel_provider_settings_3xui() {
	sqlite3 "$XUIDB" <<EOF
             INSERT INTO "settings" ("key", "value") VALUES ("subPort",  '${sub_port}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subPath",  '/${sub_path}/');
	     INSERT INTO "settings" ("key", "value") VALUES ("subURI",  '${sub_uri}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",  '${json_path}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",  '${json_uri}');
             INSERT INTO "settings" ("key", "value") VALUES ("subEnable",  '${PANEL_PROVIDER_SUB_ENABLE:-true}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonEnable",  '${PANEL_PROVIDER_SUB_JSON_ENABLE:-true}');
             INSERT INTO "settings" ("key", "value") VALUES ("webListen",  '${PANEL_PROVIDER_WEB_LISTEN:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("webDomain",  '${PANEL_PROVIDER_WEB_DOMAIN:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  '${PANEL_PROVIDER_WEB_CERT_FILE:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",  '${PANEL_PROVIDER_WEB_KEY_FILE:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",  '${PANEL_PROVIDER_SESSION_MAX_AGE:-60}');
             INSERT INTO "settings" ("key", "value") VALUES ("pageSize",  '${PANEL_PROVIDER_PAGE_SIZE:-50}');
             INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",  '${PANEL_PROVIDER_EXPIRE_DIFF:-0}');
             INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",  '${PANEL_PROVIDER_TRAFFIC_DIFF:-0}');
             INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",  '${PANEL_PROVIDER_REMARK_MODEL:--ieo}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",  '${PANEL_PROVIDER_TG_BOT_ENABLE:-false}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",  '${PANEL_PROVIDER_TG_BOT_TOKEN:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",  '${PANEL_PROVIDER_TG_BOT_PROXY:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",  '${PANEL_PROVIDER_TG_BOT_API_SERVER:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",  '${PANEL_PROVIDER_TG_BOT_CHAT_ID:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",  '${PANEL_PROVIDER_TG_RUN_TIME:-@daily}');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",  '${PANEL_PROVIDER_TG_BOT_BACKUP:-false}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify",  '${PANEL_PROVIDER_TG_BOT_LOGIN_NOTIFY:-true}');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",  '${PANEL_PROVIDER_TG_CPU:-80}');
             INSERT INTO "settings" ("key", "value") VALUES ("tgLang",  '${PANEL_PROVIDER_TG_LANG:-en-US}');
	     INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",  '${PANEL_PROVIDER_TIME_LOCATION:-Europe/Moscow}');
             INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",  '${PANEL_PROVIDER_SECRET_ENABLE:-false}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subDomain",  '${PANEL_PROVIDER_SUB_DOMAIN:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",  '${PANEL_PROVIDER_SUB_CERT_FILE:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",  '${PANEL_PROVIDER_SUB_KEY_FILE:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",  '${PANEL_PROVIDER_SUB_UPDATES:-12}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",  '${PANEL_PROVIDER_SUB_ENCRYPT:-true}');
             INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",  '${PANEL_PROVIDER_SUB_SHOW_INFO:-true}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",  '${PANEL_PROVIDER_SUB_JSON_FRAGMENT:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",  '${PANEL_PROVIDER_SUB_JSON_NOISES:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",  '${PANEL_PROVIDER_SUB_JSON_MUX:-}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",  '${PANEL_PROVIDER_SUB_JSON_RULES:-}');
	     INSERT INTO "settings" ("key", "value") VALUES ("datepicker",  '${PANEL_PROVIDER_DATEPICKER:-gregorian}');
EOF
}

write_transport_inbounds_classic_xray() {
	sqlite3 "$XUIDB" <<EOF
             INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('1','1','first','0','0','0','0','0');
	     INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('2','1','first_1','0','0','0','0','0');
		   INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('3','1','firstX','0','0','0','0','0');
	     INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('4','1','firstT','0','0','0','0','0');
             INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${emoji_flag} reality',
	     '1',
	     '0',
	     '',
             '${reality_inbound_port}',
	     'vless',
             '{
	     "clients": [
    {
      "id": "${client_id}",
      "flow": "xtls-rprx-vision",
      "email": "first",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
      "created_at": 1756726925000,
      "updated_at": 1756726925000

    }
  ],
  "decryption": "none",
  "fallbacks": []
}',
	     '{
  "network": "tcp",
  "security": "reality",
  "externalProxy": [
    {
      "forceTls": "same",
      "dest": "${domain}",
      "port": ${public_https_port},
      "remark": ""
    }
  ],
  "realitySettings": {
    "show": false,
    "xver": 0,
    "target": "${reality_target}",
    "serverNames": [
      "$reality_domain"
    ],
    "privateKey": "${private_key}",
    "minClient": "",
    "maxClient": "",
    "maxTimediff": 0,
    "shortIds": [
      "${shor[0]}",
      "${shor[1]}",
      "${shor[2]}",
      "${shor[3]}",
      "${shor[4]}",
      "${shor[5]}",
      "${shor[6]}",
      "${shor[7]}"
    ],
    "settings": {
      "publicKey": "${public_key}",
      "fingerprint": "random",
      "serverName": "",
      "spiderX": "/"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": true,
    "header": {
      "type": "none"
    }
  }
}',
             '${reality_inbound_tag}',
	     '{
  "enabled": false,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
      INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${emoji_flag} ws',
	     '1',
             '0',
	     '',
             '${ws_port}',
	     'vless',
             '{
  "clients": [
    {
      "id": "${client_id2}",
      "flow": "",
      "email": "first_1",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
      "created_at": 1756726925000,
      "updated_at": 1756726925000

    }
  ],
  "decryption": "none",
  "fallbacks": []
}','{
  "network": "ws",
  "security": "none",
  "externalProxy": [
    {
      "forceTls": "tls",
      "dest": "${domain}",
      "port": 443,
      "remark": ""
    }
  ],
  "wsSettings": {
    "acceptProxyProtocol": false,
    "path": "/${ws_port}/${ws_path}",
    "host": "${domain}",
    "headers": {}
  }
}',
             'inbound-${ws_port}',
	     '{
  "enabled": false,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
      INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${emoji_flag} xhttp',
	     '1',
             '0',
	     '/dev/shm/uds2023.sock,0666',
             '0',
	     'vless',
             '{
  "clients": [
    {
      "id": "${client_id3}",
      "flow": "",
      "email": "firstX",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
	  "created_at": 1756726925000,
      "updated_at": 1756726925000
    }
  ],
  "decryption": "none",
  "fallbacks": []
}','{
  "network": "xhttp",
  "security": "none",
  "externalProxy": [
    {
      "forceTls": "tls",
      "dest": "${domain}",
      "port": 443,
      "remark": ""
    }
  ],
  "xhttpSettings": {
    "path": "/${xhttp_path}",
    "host": "",
    "headers": {},
    "scMaxBufferedPosts": ${TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS:-30},
    "scMaxEachPostBytes": "${TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES:-1000000}",
    "noSSEHeader": ${TRANSPORT_XHTTP_NO_SSE_HEADER:-false},
    "xPaddingBytes": "${TRANSPORT_XHTTP_X_PADDING_BYTES:-100-1000}",
    "mode": "${TRANSPORT_XHTTP_MODE:-auto}"$(platform_build_xhttp_xmux_block)
  },
  "sockopt": {
    "acceptProxyProtocol": false,
    "tcpFastOpen": ${TRANSPORT_XHTTP_TCP_FAST_OPEN:-true},
    "mark": 0,
    "tproxy": "off",
    "tcpMptcp": ${TRANSPORT_XHTTP_TCP_MPTCP:-true},
    "tcpNoDelay": ${TRANSPORT_XHTTP_TCP_NO_DELAY:-true},
    "domainStrategy": "${TRANSPORT_XHTTP_DOMAIN_STRATEGY:-UseIP}",
    "tcpMaxSeg": ${TRANSPORT_XHTTP_TCP_MAX_SEG:-1440},
    "dialerProxy": "",
    "tcpKeepAliveInterval": ${TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL:-0},
    "tcpKeepAliveIdle": ${TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE:-300},
    "tcpUserTimeout": ${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-10000},
    "tcpcongestion": "${TRANSPORT_XHTTP_TCP_CONGESTION:-bbr}",
    "V6Only": ${TRANSPORT_XHTTP_V6_ONLY:-false},
    "tcpWindowClamp": ${TRANSPORT_XHTTP_TCP_WINDOW_CLAMP:-600},
    "interface": ""
  }
}',
             'inbound-/dev/shm/uds2023.sock,0666:0|',
	     '{
  "enabled": true,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
	INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
	     '1',
	     '0',
         '0',
	     '0',
         '${emoji_flag} trojan-grpc',
	     '1',
         '0',
		 '',
		 '${trojan_port}',
		 'trojan',
		 '{
  "clients": [
    {
      "comment": "",
      "created_at": 1756726925000,
      "email": "firstT",
      "enable": true,
      "expiryTime": 0,
      "limitIp": 0,
      "password": "${trojan_pass}",
      "reset": 0,
      "subId": "first",
      "tgId": 0,
      "totalGB": 0,
      "updated_at": 1756726925000
    }
  ],
  "fallbacks": []
}',
'{
  "network": "grpc",
  "security": "none",
  "externalProxy": [
    {
      "forceTls": "tls",
      "dest": "${domain}",
      "port": 443,
      "remark": ""
    }
  ],
  "grpcSettings": {
    "serviceName": "/${trojan_port}/${trojan_path}",
    "authority": "${domain}",
    "multiMode": false
  }
}',
'inbound-${trojan_port}',
'{
  "enabled": false,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	);
EOF
}

write_transport_inbounds_stealth_xray() {
	local reality_external_proxy_dest reality_accept_proxy_protocol reality_xver
	reality_external_proxy_dest="$(platform_transport_reality_external_proxy_dest)"
	reality_accept_proxy_protocol="$(platform_transport_reality_accept_proxy_protocol)"
	reality_xver="$(platform_transport_reality_xver)"

	sqlite3 "$XUIDB" <<EOF
             INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('1','1','first','0','0','0','0','0');
             INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${emoji_flag} reality',
	     '1',
	     '0',
	     '',
             '${reality_inbound_port}',
	     'vless',
             '{
	     "clients": [
    {
      "id": "${client_id}",
      "flow": "${TRANSPORT_REALITY_CLIENT_FLOW:-xtls-rprx-vision}",
      "email": "first",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
      "created_at": 1756726925000,
      "updated_at": 1756726925000

    }
  ],
  "decryption": "none",
  "fallbacks": []
}',
	     '{
  "network": "tcp",
  "security": "reality",
  "externalProxy": [
    {
      "forceTls": "same",
      "dest": "${reality_external_proxy_dest}",
      "port": ${public_https_port},
      "remark": ""
    }
  ],
  "realitySettings": {
    "show": false,
    "xver": ${reality_xver},
    "target": "${reality_target}",
    "serverNames": [
      "${reality_domain}"
    ],
    "privateKey": "${private_key}",
    "minClient": "",
    "maxClient": "",
    "maxTimediff": 0,
    "shortIds": [
      "${shor[0]}",
      "${shor[1]}",
      "${shor[2]}",
      "${shor[3]}",
      "${shor[4]}",
      "${shor[5]}",
      "${shor[6]}",
      "${shor[7]}"
    ],
    "settings": {
      "publicKey": "${public_key}",
      "fingerprint": "${TRANSPORT_REALITY_FINGERPRINT:-random}",
      "serverName": "",
      "spiderX": "${TRANSPORT_REALITY_SPIDER_X:-/}"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": ${reality_accept_proxy_protocol},
    "header": {
      "type": "${TRANSPORT_REALITY_TCP_HEADER_TYPE:-none}"
    }
  }$(platform_build_reality_sockopt_block)
}',
             '${reality_inbound_tag}',
	     '{
  "enabled": false,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
EOF
}

write_transport_inbounds_stealth_xhttp() {
	local reality_external_proxy_dest reality_accept_proxy_protocol reality_xver
	local reality_node_remark xhttp_node_remark
	reality_external_proxy_dest="$(platform_transport_reality_external_proxy_dest)"
	reality_accept_proxy_protocol="$(platform_transport_reality_accept_proxy_protocol)"
	reality_xver="$(platform_transport_reality_xver)"
	reality_node_remark="${emoji_flag} reality-shield"
	xhttp_node_remark="${emoji_flag} xhttp"
	if [[ "$TRANSPORT_PROFILE" == "stealth-multi" ]]; then
		reality_node_remark="${emoji_flag} reality-call"
		xhttp_node_remark="${emoji_flag} xhttp-stealth"
	fi

	sqlite3 "$XUIDB" <<EOF
             INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('1','1','first','0','0','0','0','0');
             INSERT INTO "client_traffics" ("inbound_id","enable","email","up","down","expiry_time","total","reset") VALUES ('2','1','firstX','0','0','0','0','0');
             INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${reality_node_remark}',
	     '1',
	     '0',
	     '',
             '${reality_inbound_port}',
	     'vless',
             '{
	     "clients": [
    {
      "id": "${client_id}",
      "flow": "${TRANSPORT_REALITY_CLIENT_FLOW:-xtls-rprx-vision}",
      "email": "first",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
      "created_at": 1756726925000,
      "updated_at": 1756726925000

    }
  ],
  "decryption": "none",
  "fallbacks": []
}',
	     '{
  "network": "tcp",
  "security": "reality",
  "externalProxy": [
    {
      "forceTls": "same",
      "dest": "${reality_external_proxy_dest}",
      "port": ${public_https_port},
      "remark": ""
    }
  ],
  "realitySettings": {
    "show": false,
    "xver": ${reality_xver},
    "target": "${reality_target}",
    "serverNames": [
      "${reality_domain}"
    ],
    "privateKey": "${private_key}",
    "minClient": "",
    "maxClient": "",
    "maxTimediff": 0,
    "shortIds": [
      "${shor[0]}",
      "${shor[1]}",
      "${shor[2]}",
      "${shor[3]}",
      "${shor[4]}",
      "${shor[5]}",
      "${shor[6]}",
      "${shor[7]}"
    ],
    "settings": {
      "publicKey": "${public_key}",
      "fingerprint": "${TRANSPORT_REALITY_FINGERPRINT:-random}",
      "serverName": "",
      "spiderX": "${TRANSPORT_REALITY_SPIDER_X:-/}"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": ${reality_accept_proxy_protocol},
    "header": {
      "type": "${TRANSPORT_REALITY_TCP_HEADER_TYPE:-none}"
    }
  }$(platform_build_reality_sockopt_block)
}',
             '${reality_inbound_tag}',
	     '{
  "enabled": false,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
      INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES (
             '1',
	     '0',
             '0',
	     '0',
             '${xhttp_node_remark}',
	     '1',
             '0',
	     '/dev/shm/uds2023.sock,0666',
             '0',
	     'vless',
             '{
  "clients": [
    {
      "id": "${client_id3}",
      "flow": "",
      "email": "firstX",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": "first",
      "reset": 0,
      "created_at": 1756726925000,
      "updated_at": 1756726925000
    }
  ],
  "decryption": "none",
  "fallbacks": []
}','{
  "network": "xhttp",
  "security": "none",
  "externalProxy": [
    {
      "forceTls": "tls",
      "dest": "${domain}",
      "port": ${public_https_port},
      "remark": ""
    }
  ],
  "xhttpSettings": {
    "path": "/${xhttp_path}",
    "host": "",
    "headers": {},
    "scMaxBufferedPosts": ${TRANSPORT_XHTTP_SC_MAX_BUFFERED_POSTS:-30},
    "scMaxEachPostBytes": "${TRANSPORT_XHTTP_SC_MAX_EACH_POST_BYTES:-1000000}",
    "noSSEHeader": ${TRANSPORT_XHTTP_NO_SSE_HEADER:-false},
    "xPaddingBytes": "${TRANSPORT_XHTTP_X_PADDING_BYTES:-100-1000}",
    "mode": "${TRANSPORT_XHTTP_MODE:-auto}"$(platform_build_xhttp_xmux_block)
  },
  "sockopt": {
    "acceptProxyProtocol": false,
    "tcpFastOpen": ${TRANSPORT_XHTTP_TCP_FAST_OPEN:-true},
    "mark": 0,
    "tproxy": "off",
    "tcpMptcp": ${TRANSPORT_XHTTP_TCP_MPTCP:-true},
    "tcpNoDelay": ${TRANSPORT_XHTTP_TCP_NO_DELAY:-true},
    "domainStrategy": "${TRANSPORT_XHTTP_DOMAIN_STRATEGY:-UseIP}",
    "tcpMaxSeg": ${TRANSPORT_XHTTP_TCP_MAX_SEG:-1440},
    "dialerProxy": "",
    "tcpKeepAliveInterval": ${TRANSPORT_XHTTP_TCP_KEEPALIVE_INTERVAL:-0},
    "tcpKeepAliveIdle": ${TRANSPORT_XHTTP_TCP_KEEPALIVE_IDLE:-300},
    "tcpUserTimeout": ${TRANSPORT_XHTTP_TCP_USER_TIMEOUT:-10000},
    "tcpcongestion": "${TRANSPORT_XHTTP_TCP_CONGESTION:-bbr}",
    "V6Only": ${TRANSPORT_XHTTP_V6_ONLY:-false},
    "tcpWindowClamp": ${TRANSPORT_XHTTP_TCP_WINDOW_CLAMP:-600},
    "interface": ""
  }
}',
             'inbound-/dev/shm/uds2023.sock,0666:0|',
	     '{
  "enabled": true,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ],
  "metadataOnly": false,
  "routeOnly": false
}'
	     );
EOF
}

update_xui_db() {
if [[ -f "$XUIDB" ]]; then
		local xray_bin public_https_port reality_inbound_port reality_target reality_inbound_tag credential_length
		public_https_port="$(platform_public_https_port)"
		reality_inbound_port="$(platform_transport_reality_inbound_port)"
		reality_target="$(platform_transport_reality_target)"
		reality_inbound_tag="$(platform_transport_reality_inbound_tag)"
		credential_length="$(platform_credential_length)"
        x-ui stop
		xray_bin=$(xray_binary_path)
		[[ -x "$xray_bin" ]] || die "xray helper binary not found or not executable: ${xray_bin}"
		generate_reality_x25519_pair "$xray_bin"

        client_id=$("$xray_bin" uuid)
        client_id2=$("$xray_bin" uuid)
        client_id3=$("$xray_bin" uuid)
	trojan_pass=$(gen_random_string "$credential_length")
        emoji_flag=$(LC_ALL=en_US.UTF-8 curl -s https://ipwho.is/ | jq -r '.flag.emoji')
		[[ -n "$emoji_flag" && "$emoji_flag" != "null" ]] || emoji_flag="VPN"

	# Generate shortIds via loop
	local shor=()
	local i
	for i in {1..8}; do
		shor+=("$(openssl rand -hex 8)")
	done

		write_panel_provider_settings_3xui
		case "$TRANSPORT_PROFILE" in
			classic-xray)
				write_transport_inbounds_classic_xray
				;;
			stealth-xray)
				write_transport_inbounds_stealth_xray
				;;
			stealth-xhttp|stealth-multi)
				write_transport_inbounds_stealth_xhttp
				;;
			*)
				die "Unsupported transport profile in update_xui_db: ${TRANSPORT_PROFILE}"
				;;
		esac
run_sensitive /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${panel_port}" -webBasePath "${panel_path}"
/usr/local/x-ui/x-ui cert -webCert "/root/cert/${domain}/fullchain.pem" -webCertKey "/root/cert/${domain}/privkey.pem"
x-ui start
else
	die "x-ui.db file not exist! Maybe x-ui isn't installed."
fi
}

##############################Config After Install########################################################
config_after_install() {
	run_sensitive /usr/local/x-ui/x-ui setting \
		-username "$(platform_panel_bootstrap_username)" \
		-password "$(platform_panel_bootstrap_password)" \
		-port "$(platform_panel_bootstrap_port)" \
		-webBasePath "$(platform_panel_bootstrap_base_path)"
	/usr/local/x-ui/x-ui migrate
}

##############################Install Panel###############################################################
install_panel() {
apt-get update && apt-get install -y -q wget curl tar tzdata
    cd /usr/local/

    local requested_tag="${1:-$XUI_VERSION}"
    local tag_version="" tag_version_numeric="" min_version="" url=""
	local xui_archive_name="" xui_archive_path="" xui_release_rel_path=""
	min_version="$(platform_panel_min_version)"

    if [[ -n "$requested_tag" ]]; then
        tag_version=$(ensure_version_tag "$requested_tag")
        tag_version_numeric=${tag_version#v}
        if [[ "$(printf '%s\n' "$min_version" "$tag_version_numeric" | sort -V | head -n1)" != "$min_version" ]]; then
            printf '%bPlease use a newer version (at least v%s). Exiting installation.%b\n' "${red}" "$min_version" "${plain}"
            exit 1
        fi
        echo -e "Using pinned x-ui version: ${tag_version}"
    else
        tag_version=$(curl -Ls "https://api.github.com/repos/${XUI_REPO_SLUG}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$tag_version" ]]; then
            printf '%bTrying to fetch version with IPv4...%b\n' "${yellow}" "${plain}"
            tag_version=$(curl -4 -Ls "https://api.github.com/repos/${XUI_REPO_SLUG}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ -z "$tag_version" ]]; then
                printf '%bFailed to fetch x-ui version, it may be due to GitHub API restrictions, please try it later%b\n' "${red}" "${plain}"
                exit 1
            fi
        fi
        echo -e "Got x-ui latest version: ${tag_version}, beginning the installation..."
    fi

	xui_archive_name="x-ui-linux-$(arch).tar.gz"
	xui_archive_path="/usr/local/${xui_archive_name}"
	xui_release_rel_path="vendor/releases/3x-ui/${tag_version}/${xui_archive_name}"
    url="https://github.com/${XUI_REPO_SLUG}/releases/download/${tag_version}/${xui_archive_name}"
	copy_or_fetch_release_archive "$xui_release_rel_path" "$url" "$xui_archive_path"

    # Stop x-ui service and remove old resources
    if [[ -e /usr/local/x-ui/ ]]; then
        if [[ "$release" == "alpine" ]]; then
            rc-service x-ui stop
        else
            systemctl stop x-ui
        fi
        rm /usr/local/x-ui/ -rf
    fi

    # Extract resources and set permissions
    tar zxvf "$xui_archive_name"
    rm "$xui_archive_name" -f

    cd x-ui
    chmod +x x-ui
    chmod +x x-ui.sh

    # Check the system's architecture and rename the file accordingly
	local xray_target="bin/xray-linux-$(arch)"
    if [[ $(arch) == "armv5" || $(arch) == "armv6" || $(arch) == "armv7" ]]; then
        mv bin/xray-linux-$(arch) bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
		xray_target="bin/xray-linux-arm"
    fi
    chmod +x x-ui "$xray_target"

    # Use the CLI script bundled with the exact tarball version.
    cp -f x-ui.sh /usr/bin/x-ui
    chmod +x /usr/bin/x-ui
	config_after_install

    if [[ "$release" == "alpine" ]]; then
        wget --inet4-only -O /etc/init.d/x-ui "https://raw.githubusercontent.com/${XUI_REPO_SLUG}/${tag_version}/x-ui.rc"
        if [[ $? -ne 0 ]]; then
            printf '%bFailed to download x-ui.rc%b\n' "${red}" "${plain}"
            exit 1
        fi
        chmod +x /etc/init.d/x-ui
        rc-update add x-ui
        rc-service x-ui start
    else
        cp -f x-ui.service.debian /etc/systemd/system/x-ui.service
        systemctl daemon-reload
        systemctl enable x-ui
        systemctl start x-ui
    fi

    printf '%bx-ui %s%b installation finished, it is running now...\n' "${green}" "${tag_version}" "${plain}"
    echo -e ""
    printf '┌───────────────────────────────────────────────────────┐
│  %bx-ui control menu usages (subcommands):%b              │
│                                                       │
│  %bx-ui%b              - Admin Management Script          │
│  %bx-ui start%b        - Start                            │
│  %bx-ui stop%b         - Stop                             │
│  %bx-ui restart%b      - Restart                          │
│  %bx-ui status%b       - Current Status                   │
│  %bx-ui settings%b     - Current Settings                 │
│  %bx-ui enable%b       - Enable Autostart on OS Startup   │
│  %bx-ui disable%b      - Disable Autostart on OS Startup  │
│  %bx-ui log%b          - Check logs                       │
│  %bx-ui banlog%b       - Check Fail2ban ban logs          │
│  %bx-ui update%b       - Update                           │
│  %bx-ui legacy%b       - Legacy version                   │
│  %bx-ui install%b      - Install                          │
│  %bx-ui uninstall%b    - Uninstall                        │
└───────────────────────────────────────────────────────┘\n' \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}" \
    "${blue}" "${plain}"

}

##############################Tune System#################################################################
tune_system() {
	apt-get install -yqq --no-install-recommends ca-certificates
	sysctl_ensure "net.core.default_qdisc" "fq"
	sysctl_ensure "net.ipv4.tcp_congestion_control" "bbr"
	sysctl_ensure "fs.file-max" "2097152"
	sysctl_ensure "net.ipv4.tcp_timestamps" "1"
	sysctl_ensure "net.ipv4.tcp_sack" "1"
	sysctl_ensure "net.ipv4.tcp_window_scaling" "1"
	sysctl_ensure "net.core.rmem_max" "16777216"
	sysctl_ensure "net.core.wmem_max" "16777216"
	sysctl_ensure "net.ipv4.tcp_rmem" "4096 87380 16777216"
	sysctl_ensure "net.ipv4.tcp_wmem" "4096 65536 16777216"
	sysctl_ensure "net.core.somaxconn" "65535"
	sysctl_ensure "net.ipv4.tcp_max_syn_backlog" "65535"
	sysctl_ensure "net.ipv4.tcp_slow_start_after_idle" "0"
	sysctl_ensure "net.ipv4.tcp_mtu_probing" "1"
	sysctl -p
}

##############################Install sub2sing-box########################################################
write_sub2singbox_service() {
	local sub2singbox_bind_port
	sub2singbox_bind_port="$(platform_sub2singbox_bind_port)"
	cat > "$SUB2SINGBOX_SERVICE" <<EOF
[Unit]
Description=Local sub2sing-box bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/sub2sing-box server --bind 127.0.0.1 --port ${sub2singbox_bind_port}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

write_subjson_rewrite_service() {
	local subjson_upstream_port
	subjson_upstream_port="${sub_port:-}"
	if [[ -z "$subjson_upstream_port" && -f "$XUIDB" ]]; then
		subjson_upstream_port=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subPort" LIMIT 1;' 2>/dev/null)
	fi
	[[ -n "$subjson_upstream_port" ]] || die "Unable to determine subjson upstream port."
	cat > "$SUBJSON_REWRITE_SERVICE" <<EOF
[Unit]
Description=Local JSON subscription rewrite bridge
After=network-online.target x-ui.service
Wants=network-online.target

[Service]
Type=simple
Environment="SUBJSON_REWRITE_DNS_SERVERS=${SUBJSON_REWRITE_DNS_SERVERS}"
Environment="SUBJSON_REWRITE_DNS_QUERY_STRATEGY=${SUBJSON_REWRITE_DNS_QUERY_STRATEGY}"
ExecStart=/usr/bin/python3 ${SUBJSON_REWRITE_BIN} --bind 127.0.0.1 --port ${SUBJSON_REWRITE_PORT} --upstream-port ${subjson_upstream_port} --xui-db-path ${SUBJSON_REWRITE_XUI_DB}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

install_subjson_rewrite() {
	stop_subjson_rewrite
	rm -f "$SUBJSON_REWRITE_BIN" "$SUBJSON_REWRITE_SERVICE" /etc/systemd/system/multi-user.target.wants/subjson-rewrite.service
	copy_or_fetch_repo_file "helpers/subjson_rewrite.py" "$SUBJSON_REWRITE_BIN"
	chmod +x "$SUBJSON_REWRITE_BIN"
	write_subjson_rewrite_service
	systemctl daemon-reload || die "Failed to reload systemd before starting subjson-rewrite."
	systemctl enable --now subjson-rewrite.service || die "Failed to enable/start subjson-rewrite.service."
	systemctl is-active --quiet subjson-rewrite.service || die "subjson-rewrite.service is not active after install."
}

install_sub2singbox() {
	stop_sub2singbox
	if [ -f "/usr/bin/sub2sing-box" ]; then
		echo "delete sub2sing-box..."
		rm -f /usr/bin/sub2sing-box
	fi
	rm -f "$SUB2SINGBOX_SERVICE" /etc/systemd/system/multi-user.target.wants/sub2sing-box.service
	systemctl daemon-reload 2>/dev/null || true
	local sub2singbox_version_tag sub2singbox_version_num sub2singbox_archive sub2singbox_url
	local sub2singbox_release_rel_path sub2singbox_archive_path
	sub2singbox_version_tag=$(ensure_version_tag "$SUB2SINGBOX_VERSION")
	sub2singbox_version_num=${sub2singbox_version_tag#v}
	sub2singbox_archive="sub2sing-box_${sub2singbox_version_num}_linux_${SUB2SINGBOX_ARCH}.tar.gz"
	sub2singbox_url="https://github.com/${SUB2SINGBOX_REPO_SLUG}/releases/download/${sub2singbox_version_tag}/${sub2singbox_archive}"
	sub2singbox_release_rel_path="vendor/releases/sub2sing-box/${sub2singbox_version_tag}/${sub2singbox_archive}"
	sub2singbox_archive_path="/root/${sub2singbox_archive}"
	printf 'Using pinned sub2sing-box version: %s (%s)\n' "${sub2singbox_version_tag}" "${SUB2SINGBOX_ARCH}"
	copy_or_fetch_release_archive "$sub2singbox_release_rel_path" "$sub2singbox_url" "$sub2singbox_archive_path"
	tar -xvzf "$sub2singbox_archive_path" -C /root/ --strip-components=1 "sub2sing-box_${sub2singbox_version_num}_linux_${SUB2SINGBOX_ARCH}/sub2sing-box"
	mv /root/sub2sing-box /usr/bin/
	chmod +x /usr/bin/sub2sing-box
	rm "$sub2singbox_archive_path"
	write_sub2singbox_service
	systemctl daemon-reload
	systemctl enable --now sub2sing-box.service
}

##############################Install Fake Site###########################################################
install_fake_site() {
	if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/randomfakehtml.sh" ]]; then
		bash "$SCRIPT_DIR/randomfakehtml.sh"
	else
		warn "randomfakehtml.sh is not available locally; installing bundled fallback page"
		install_builtin_fake_site
	fi
}

##############################Install Web Sub Page########################################################
install_web_sub_page() {
	local REPO_SUB_PAGE=(
		"sub-3x-ui.html"
		"sub-3x-ui-classical.html"
	)
	local REPO_CLASH_SUB=(
		"clash/clash.yaml"
		"clash/clash_skrepysh.yaml"
		"clash/clash_fullproxy_without_ru.yaml"
		"clash/clash_refilter_ech.yaml"
	)
	local DEST_DIR_SUB_PAGE="/var/www/subpage"
	local DEST_FILE_SUB_PAGE="$DEST_DIR_SUB_PAGE/index.html"
	local DEST_FILE_CLASH_SUB="$DEST_DIR_SUB_PAGE/clash.yaml"

	mkdir -p "$DEST_DIR_SUB_PAGE"

	copy_or_fetch_repo_file "${REPO_CLASH_SUB[$CLASH]}" "$DEST_FILE_CLASH_SUB"
	copy_or_fetch_repo_file "${REPO_SUB_PAGE[$CUSTOMWEBSUB]}" "$DEST_FILE_SUB_PAGE"
	rm -rf "$DEST_DIR_SUB_PAGE/assets" "$DEST_DIR_SUB_PAGE/vendor"
	copy_repo_dir_or_fail "vendor" "$DEST_DIR_SUB_PAGE/vendor"

	replace_web_placeholders "$DEST_FILE_SUB_PAGE"
	replace_web_placeholders "$DEST_FILE_CLASH_SUB"
	while IFS= read -r -d '' file; do
		replace_web_placeholders "$file"
	done < <(find "$DEST_DIR_SUB_PAGE/vendor/sb-rule-sets" -type f -name '*.json' -print0 2>/dev/null)
	append_debug_log "Web-sub assets deployed to ${DEST_DIR_SUB_PAGE}"
}

##############################Setup Crontab###############################################################
setup_crontab() {
	crontab -l | grep -v "certbot\|x-ui\|cloudflareips\|sub2sing-box" | crontab -
	(crontab -l 2>/dev/null; echo '@daily x-ui restart > /dev/null 2>&1 && nginx -s reload;') | crontab -
	(crontab -l 2>/dev/null; echo '@monthly certbot renew --nginx --non-interactive --post-hook "nginx -s reload" > /dev/null 2>&1;') | crontab -
}

##############################Setup UFW###################################################################
setup_ufw() {
	local ssh_port

	ufw disable
	while IFS= read -r ssh_port; do
		[[ "$ssh_port" =~ ^[0-9]+$ ]] || continue
		ufw allow "${ssh_port}/tcp"
	done < <(detect_ssh_ports)
	ufw allow 80/tcp
	ufw allow 443/tcp
	ufw --force enable
}

##############################Show Details#################################################################
show_details() {
	if systemctl is-active --quiet "$(platform_panel_service_name)"; then
		clear
		printf '0\n' | "$(platform_panel_control_bin)" | grep --color=never -i ':'
		msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		nginx -T | grep -i 'ssl_certificate\|ssl_certificate_key'
		msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		certbot certificates | grep -i 'Path:\|Domains:\|Expiry Date:'
		msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		msg_inf "${PANEL_PROVIDER_PANEL_TITLE:-X-UI Secure Panel}: https://${domain}/${panel_path}/"
		printf '\n'
		print_sensitive_printf 'Username:  %s\n\n' "${config_username}"
		print_sensitive_printf 'Password:  %s\n\n' "${config_password}"
		msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		msg_inf "Web Sub Page your first client: https://${domain}/${web_path}/?name=first"
		printf '\n'
		msg_inf "Your local sub2sing-box instance: https://${domain}/$sub2singbox_path/"
		printf '\n'
		msg_inf "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
		msg_inf "Please Save this Screen!!"
	else
		nginx -t && printf '0\n' | "$(platform_panel_control_bin)" | grep --color=never -i ':'
		msg_err "sqlite and x-ui to be checked, try on a new clean linux! "
	fi
}

platform_setup_ingress() {
	case "$PLATFORM_PROFILE" in
		classic)
			setup_nginx_classic
			;;
		stealth)
			setup_nginx_stealth
			;;
		*)
			die "Unsupported ingress profile: ${PLATFORM_PROFILE}"
			;;
	esac
}

platform_enable_ingress() {
	case "$PLATFORM_PROFILE" in
		classic)
			enable_nginx_sites_classic
			;;
		stealth)
			enable_nginx_sites_stealth
			;;
		*)
			die "Unsupported ingress profile: ${PLATFORM_PROFILE}"
			;;
	esac
}

platform_install_panel_provider() {
	case "$PANEL_PROVIDER" in
		3x-ui)
			install_panel
			;;
		*)
			die "Unsupported panel provider: ${PANEL_PROVIDER}"
			;;
	esac
}

platform_apply_transport_profile() {
	case "$TRANSPORT_PROFILE" in
		classic-xray|stealth-xray|stealth-xhttp|stealth-multi)
			update_xui_db
			;;
		*)
			die "Unsupported transport profile: ${TRANSPORT_PROFILE}"
			;;
	esac
}

platform_restart_panel() {
	"$(platform_panel_control_bin)" restart
}

platform_enable_panel_service() {
	local service_name
	service_name="$(platform_panel_service_name)"
	if ! systemctl is-enabled --quiet "${service_name}"; then
		systemctl daemon-reload && systemctl enable "${service_name}.service"
	fi
}

##############################Main########################################################################
main() {
	# 1. Parse arguments BEFORE any destructive action
	parse_args "$@"
	platform_init || die "Unsupported platform selection. Current values: $(platform_selection_summary)"
	platform_apply_requested_tuning_profiles
	init_debug_session
	append_debug_log "Stage=${STAGE} Debug=${DEBUG_MODE} DryRun=${DRY_RUN} Verify=${VERIFY_MODE} SkipCleanup=${SKIP_CLEANUP} KeepArtifacts=${KEEP_ARTIFACTS} ConfirmReset=${CONFIRM_RESET} Platform=$(platform_selection_summary)"

	case "$STAGE" in
		all|verify|websub|reset|acceptance) ;;
		*) die "Unsupported stage: ${STAGE}. Supported values: all, verify, websub, reset, acceptance." ;;
	esac

	if [[ "$STAGE" == "verify" ]]; then
		if is_yes "$DRY_RUN"; then
			msg_inf "DRY-RUN verify: будет выполнена только диагностика текущей установки."
			load_existing_runtime_context
			exit 0
		fi
		verify_existing_installation || die "Проверка текущей установки завершилась с ошибками."
		msg_ok "Проверка текущей установки завершена успешно."
		exit 0
	fi

	if [[ "$STAGE" == "acceptance" ]]; then
		if is_yes "$DRY_RUN"; then
			load_existing_runtime_context
			print_acceptance_plan
			exit 0
		fi
		run_stealth_acceptance_stage
		exit 0
	fi

	if [[ "$STAGE" == "websub" ]]; then
		load_existing_runtime_context
		if [[ -z "$domain" || -z "$web_path" || -z "$sub_path" || -z "$json_path" || -z "$sub2singbox_path" ]]; then
			die "Не удалось восстановить runtime-контекст для stage=websub. Сначала установите систему или передайте параметры вручную."
		fi
		if is_yes "$DRY_RUN"; then
			msg_inf "DRY-RUN websub: локальная web-sub страница будет переустановлена без полной переустановки стека."
			print_runtime_context
			exit 0
		fi
		install_web_sub_page
		ensure_sub2singbox_local_ui_proxy
		install_subjson_rewrite
		platform_setup_ingress
		platform_enable_ingress
		nginx -t >/dev/null 2>&1 || die "nginx validation failed after updating web/sub2sing-box UI."
		systemctl reload nginx >/dev/null 2>&1 || die "Failed to reload nginx after updating web/sub2sing-box UI."
		if is_yes "$VERIFY_MODE"; then
			verify_existing_installation || die "Переустановка web-sub завершилась, но проверки не прошли."
		fi
		msg_ok "Web-sub страница переустановлена из локального репозитория."
		exit 0
	fi

	if [[ "$STAGE" == "reset" ]]; then
		reset_staging_node
		exit 0
	fi

	# 2. Handle uninstall early (no wipe needed)
	if [[ "${UNINSTALL}" == *"y"* ]]; then
		if is_yes "$DRY_RUN"; then
			msg_inf "DRY-RUN uninstall: удаление не будет выполнено."
			exit 0
		fi
		uninstall_xui
		clear && msg_ok "Completely Uninstalled!"
		exit 0
	fi

	# 3. Detect IPs (needed for auto-domain)
	detect_ips

	# 4. Auto-domain setup
	if [[ "${AUTODOMAIN}" == *"y"* ]]; then
		domain="${IP4}.cdn-one.org"
		reality_domain="${IP4//./-}.cdn-one.org"
	fi

	# 5. Domain prompts
	while true; do
		if [[ -n "$domain" ]]; then
			break
		fi
		printf "Enter available subdomain (sub.domain.tld): " && read domain
	done

	domain=$(echo "$domain" 2>&1 | tr -d '[:space:]')
	SubDomain=$(echo "$domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
	MainDomain=$(echo "$domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')

	if [[ "${SubDomain}.${MainDomain}" != "${domain}" ]]; then
		MainDomain=${domain}
	fi

	while true; do
		if [[ -n "$reality_domain" ]]; then
			break
		fi
		printf "Enter available subdomain for REALITY (sub.domain.tld): " && read reality_domain
	done

	reality_domain=$(echo "$reality_domain" 2>&1 | tr -d '[:space:]')
	RealitySubDomain=$(echo "$reality_domain" 2>&1 | sed 's/^[^ ]* \|\..*//g')
	RealityMainDomain=$(echo "$reality_domain" 2>&1 | sed 's/.*\.\([^.]*\..*\)$/\1/')

	if [[ "${RealitySubDomain}.${RealityMainDomain}" != "${reality_domain}" ]]; then
		RealityMainDomain=${reality_domain}
	fi

	# 6. Read existing XUI DB before cleanup so upgrade diagnostics keep access to the old database.
	read_existing_xui_db

	# 7. Generate random ports and paths
	platform_generate_runtime_defaults
	sub_uri="https://${domain}/${sub_path}/"
	json_uri="https://${domain}/${json_path}/"
	print_runtime_context

	if is_yes "$DRY_RUN"; then
		print_execution_plan
		exit 0
	fi

	platform_assert_runtime_selection_ready

	# 8. NOW do destructive cleanup (after args parsed, uninstall handled)
	clean_previous_install

	# 9. Install packages & disable UFW initially
	ufw disable 2>/dev/null
	install_packages

	# 10. Auto-domain DNS verification
	if [[ "${AUTODOMAIN}" == *"y"* ]]; then
		if ! resolve_to_ip "$domain"; then
			die "Auto-domain $domain does not resolve to this server IP ($IP4). Fix DNS/service and retry."
		fi
		if ! resolve_to_ip "$reality_domain"; then
			die "Auto-domain $reality_domain does not resolve to this server IP ($IP4). Fix DNS/service and retry."
		fi
	fi

	# 11. Obtain SSL certificates
	obtain_ssl "$domain"
	obtain_ssl "$reality_domain"

	# 12. Setup nginx configs
	platform_setup_ingress
	platform_enable_ingress

	# 13. Install or restart X-UI panel
	if systemctl is-active --quiet "$(platform_panel_service_name)"; then
		platform_restart_panel
	else
		platform_install_panel_provider
		platform_apply_transport_profile
		platform_enable_panel_service
		platform_restart_panel
	fi

	# 14. Tune system (idempotent sysctl)
	tune_system

	# 15. Install sub2sing-box
	install_sub2singbox

	# 15.5. Install JSON subscription rewrite bridge
	install_subjson_rewrite

	# 16. Install fake site
	install_fake_site

	# 17. Install web sub page
	install_web_sub_page

	# 18. Setup crontab
	setup_crontab

	# 18.5. Persist runtime provenance for verify/restore/acceptance flows
	write_platform_runtime_provenance_file || die "Failed to write runtime provenance file."

	# 19. Setup UFW
	setup_ufw

	if is_yes "$VERIFY_MODE"; then
		verify_existing_installation || die "Установка завершилась, но итоговые проверки не прошли."
	fi

	# 20. Show details
	show_details
}

main "$@"
#################################################N-joy##################################################
