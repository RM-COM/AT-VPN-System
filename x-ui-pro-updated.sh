#!/bin/bash
#################### x-ui-pro v2.4.3 @ github.com/GFW4Fun ##############################################
set -o pipefail
trap 'rc=$?; (( rc )) && printf "[ERROR] Script exited with code %d\n" "$rc" >&2' EXIT

##############################Constants##################################################################
XUIDB="/etc/x-ui/x-ui.db"
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
		PLATFORM_PROFILE_LABEL="Classic"
		TRANSPORT_PROFILE_LABEL="Classic Xray"
		PANEL_PROVIDER_LABEL="3x-ui"
		PLATFORM_RUNTIME_TOKEN_LENGTH=10
		PLATFORM_CREDENTIAL_LENGTH=10
		PLATFORM_DYNAMIC_PORT_BASE=10000
		PLATFORM_DYNAMIC_PORT_SPAN=49152
		PLATFORM_PUBLIC_HTTP_PORT=80
		PLATFORM_PUBLIC_HTTPS_PORT=443
		PLATFORM_SUB2SINGBOX_BIND_PORT=8080
		TRANSPORT_WEB_TLS_PORT=7443
		TRANSPORT_REALITY_SITE_TLS_PORT=9443
		TRANSPORT_REALITY_INBOUND_PORT=8443
		PANEL_PROVIDER_PANEL_TITLE="X-UI Secure Panel"
		PANEL_PROVIDER_SERVICE_NAME="x-ui"
		PANEL_PROVIDER_CONTROL_BIN="x-ui"
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

platform_sub2singbox_bind_port() {
	printf '%s' "${PLATFORM_SUB2SINGBOX_BIND_PORT:-8080}"
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
print_runtime_context() {
	append_debug_log "Runtime context:"
	append_debug_log "  platform_root=${PLATFORM_ROOT:-<empty>}"
	append_debug_log "  platform_selection=$(platform_selection_summary)"
	append_debug_log "  runtime_token_length=$(platform_runtime_token_length)"
	append_debug_log "  credential_length=$(platform_credential_length)"
	append_debug_log "  dynamic_port_base=$(platform_dynamic_port_base)"
	append_debug_log "  dynamic_port_span=$(platform_dynamic_port_span)"
	append_debug_log "  public_http_port=$(platform_public_http_port)"
	append_debug_log "  public_https_port=$(platform_public_https_port)"
	append_debug_log "  sub2singbox_bind_port=$(platform_sub2singbox_bind_port)"
	append_debug_log "  transport_web_tls_port=$(platform_transport_web_tls_port)"
	append_debug_log "  transport_reality_site_tls_port=$(platform_transport_reality_site_tls_port)"
	append_debug_log "  transport_reality_inbound_port=$(platform_transport_reality_inbound_port)"
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
load_existing_runtime_context() {
	local detected_site
	if [[ -f "$XUIDB" ]]; then
		panel_port=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webPort" LIMIT 1;' 2>/dev/null)
		panel_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="webBasePath" LIMIT 1;' 2>/dev/null)")
		sub_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subPath" LIMIT 1;' 2>/dev/null)")
		json_path=$(trim_slashes "$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subJsonPath" LIMIT 1;' 2>/dev/null)")
		sub_uri=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subURI" LIMIT 1;' 2>/dev/null)
		json_uri=$(sqlite3 -list "$XUIDB" 'SELECT "value" FROM settings WHERE "key"="subJsonURI" LIMIT 1;' 2>/dev/null)
	fi
	if [[ -z "$domain" ]]; then
		domain=$(printf '%s\n%s\n' "$sub_uri" "$json_uri" | sed -nE 's#https?://([^/]+)/.*#\1#p' | head -n1)
	fi
	if [[ -z "$web_path" ]]; then
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
	if [[ -z "$json_uri" && -n "$domain" && -n "$web_path" ]]; then
		json_uri="https://${domain}/${web_path}/?name="
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
verify_existing_installation() {
	local failures=0
	local sqlite_result="" curl_output="" unexpected_urls=""
	init_debug_session
	load_existing_runtime_context

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

	if (( failures > 0 )); then
		append_debug_log "Verification finished with failures: ${failures}"
		return 1
	fi

	append_debug_log "Verification finished successfully"
	return 0
}
verify_reset_state() {
	local failures=0
	local path listener_output

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
		"/etc/systemd/system/sub2sing-box.service" \
		"/etc/systemd/system/multi-user.target.wants/sub2sing-box.service"; do
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
		listener_output=$(ss -ltn 2>/dev/null | awk 'NR > 1 && $4 ~ /:(80|443)$/ {print}')
		append_debug_log "Reset listener check: ${listener_output:-<empty>}"
		if [[ -n "$listener_output" ]]; then
			record_verify_result "FAIL" "Ports 80/443 are still busy: ${listener_output//$'\n'/; }"
			failures=$((failures + 1))
		else
			record_verify_result "PASS" "Ports 80/443 are free"
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
	reality_stream=$(sqlite3 -list "$XUIDB" "SELECT stream_settings FROM inbounds WHERE stream_settings LIKE '%\"security\": \"reality\"%' LIMIT 1;" 2>/dev/null)
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
	PLATFORM_PROFILE="${PLATFORM_PROFILE:-classic}"
	TRANSPORT_PROFILE="${TRANSPORT_PROFILE:-classic-xray}"
	PANEL_PROVIDER="${PANEL_PROVIDER:-3x-ui}"
	ENABLE_AWG="${ENABLE_AWG:-n}"

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
			-profile|-platform_profile) PLATFORM_PROFILE="$2"; shift 2;;
			-transport_profile) TRANSPORT_PROFILE="$2"; shift 2;;
			-panel_provider) PANEL_PROVIDER="$2"; shift 2;;
			-enable_awg) ENABLE_AWG="$2"; shift 2;;
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
remove_reset_residuals() {
	local path
	stop_sub2singbox
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable nginx x-ui 2>/dev/null || true
	for path in \
		"/etc/systemd/system/x-ui.service" \
		"/etc/systemd/system/multi-user.target.wants/x-ui.service" \
		"/etc/systemd/system/sub2sing-box.service" \
		"/etc/systemd/system/multi-user.target.wants/sub2sing-box.service" \
		"/usr/local/x-ui" \
		"/etc/x-ui" \
		"/usr/bin/x-ui" \
		"/usr/bin/sub2sing-box" \
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
	systemctl reset-failed nginx x-ui sub2sing-box 2>/dev/null || true
	fuser -k 80/tcp 80/udp 443/tcp 443/udp 2>/dev/null || true
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
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable x-ui sub2sing-box 2>/dev/null || true
	rm -rf /etc/systemd/system/x-ui.service
	rm -rf /etc/systemd/system/multi-user.target.wants/x-ui.service
	rm -rf /etc/systemd/system/sub2sing-box.service
	rm -rf /etc/systemd/system/multi-user.target.wants/sub2sing-box.service
	rm -rf /usr/local/x-ui
	rm -rf /etc/x-ui
	rm -rf /usr/bin/x-ui
	rm -rf /usr/bin/sub2sing-box
	rm -rf /var/www/subpage
	rm -rf /var/www/html
	rm -rf /etc/nginx
	rm -rf /usr/share/nginx
	rm -rf /root/cert
	systemctl daemon-reload 2>/dev/null || true
	systemctl reset-failed nginx x-ui sub2sing-box 2>/dev/null || true
}

##############################Clean Previous Install######################################################
clean_previous_install() {
	if is_yes "$SKIP_CLEANUP"; then
		msg_inf "SKIP_CLEANUP активирован: пропускаю удаление предыдущей установки."
		append_debug_log "Cleanup skipped because SKIP_CLEANUP is enabled"
		return 0
	fi
	stop_sub2singbox
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl disable x-ui sub2sing-box 2>/dev/null || true
	rm -rf /etc/systemd/system/x-ui.service
	rm -rf /etc/systemd/system/multi-user.target.wants/x-ui.service
	rm -rf /etc/systemd/system/sub2sing-box.service
	rm -rf /etc/systemd/system/multi-user.target.wants/sub2sing-box.service
	rm -rf /usr/local/x-ui
	rm -rf /etc/x-ui
	rm -rf /usr/bin/x-ui
	rm -rf /usr/bin/sub2sing-box
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
	systemctl reset-failed nginx x-ui sub2sing-box 2>/dev/null || true
}

##############################Install Packages############################################################
install_packages() {
	if [[ "${INSTALL}" == *"y"* ]]; then
		"$PKG_MGR" -y update
		"$PKG_MGR" -y install curl wget jq bash sudo nginx-full certbot python3-certbot-nginx sqlite3 ufw
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
setup_nginx() {
	mkdir -p "/root/cert/${domain}"
	mkdir -p /etc/nginx/modules-enabled /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/snippets /etc/nginx/stream-enabled
	chmod 700 /root/cert/*

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
	if (\$host !~* ^(.+\.)?$domain\$ ){return 444;}
	if (\$scheme ~* https) {set \$safe 1;}
	if (\$ssl_server_name !~* ^(.+\.)?$domain\$ ) {set \$safe "\${safe}0"; }
	if (\$safe = 10){return 444;}
	if (\$request_uri ~ "(\"|'|\`|~|,|:|--|;|%|\\$|&&|\?\?|0x00|0X00|\||\\|\{|\}|\[|\]|<|>|\.\.\.|\.\.\/|\/\/\/)"){set \$hack 1;}
	error_page 400 401 402 403 500 501 502 503 504 =404 /404;
	proxy_intercept_errors on;
	#X-UI Admin Panel
	location /${panel_path}/ {
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
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${sub_path}/ {
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
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
	location /${json_path}/ {
                if (\$hack = 1) {return 404;}
                proxy_redirect off;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_pass https://127.0.0.1:${sub_port};
                break;
        }
        #XHTTP
        location /${xhttp_path} {
          grpc_pass grpc://unix:/dev/shm/uds2023.sock;
          grpc_buffer_size         16k;
          grpc_socket_keepalive    on;
          grpc_read_timeout        1h;
          grpc_send_timeout        1h;
          grpc_set_header Connection         "";
          grpc_set_header X-Forwarded-For    \$proxy_add_x_forwarded_for;
          grpc_set_header X-Forwarded-Proto  \$scheme;
          grpc_set_header X-Forwarded-Port   \$server_port;
          grpc_set_header Host               \$host;
          grpc_set_header X-Forwarded-Host   \$host;
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
	#X-UI Admin Panel
	location /${panel_path}/ {
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_pass http://127.0.0.1:${panel_port};
		break;
	}
        location /$panel_path {
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
enable_nginx_sites() {
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

       	sqlite3 "$XUIDB" <<EOF
             INSERT INTO "settings" ("key", "value") VALUES ("subPort",  '${sub_port}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subPath",  '/${sub_path}/');
	     INSERT INTO "settings" ("key", "value") VALUES ("subURI",  '${sub_uri}');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonPath",  '${json_path}');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonURI",  '${json_uri}');
             INSERT INTO "settings" ("key", "value") VALUES ("subEnable",  'true');
             INSERT INTO "settings" ("key", "value") VALUES ("webListen",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("webDomain",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("webCertFile",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("webKeyFile",  '');
      	     INSERT INTO "settings" ("key", "value") VALUES ("sessionMaxAge",  '60');
             INSERT INTO "settings" ("key", "value") VALUES ("pageSize",  '50');
             INSERT INTO "settings" ("key", "value") VALUES ("expireDiff",  '0');
             INSERT INTO "settings" ("key", "value") VALUES ("trafficDiff",  '0');
             INSERT INTO "settings" ("key", "value") VALUES ("remarkModel",  '-ieo');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotEnable",  'false');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotToken",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotProxy",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotAPIServer",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotChatId",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("tgRunTime",  '@daily');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgBotBackup",  'false');
             INSERT INTO "settings" ("key", "value") VALUES ("tgBotLoginNotify",  'true');
	     INSERT INTO "settings" ("key", "value") VALUES ("tgCpu",  '80');
             INSERT INTO "settings" ("key", "value") VALUES ("tgLang",  'en-US');
	     INSERT INTO "settings" ("key", "value") VALUES ("timeLocation",  'Europe/Moscow');
             INSERT INTO "settings" ("key", "value") VALUES ("secretEnable",  'false');
	     INSERT INTO "settings" ("key", "value") VALUES ("subDomain",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subCertFile",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("subKeyFile",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subUpdates",  '12');
	     INSERT INTO "settings" ("key", "value") VALUES ("subEncrypt",  'true');
             INSERT INTO "settings" ("key", "value") VALUES ("subShowInfo",  'true');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonFragment",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonNoises",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("subJsonMux",  '');
             INSERT INTO "settings" ("key", "value") VALUES ("subJsonRules",  '');
	     INSERT INTO "settings" ("key", "value") VALUES ("datepicker",  'gregorian');
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
    "scMaxBufferedPosts": 30,
    "scMaxEachPostBytes": "1000000",
    "noSSEHeader": false,
    "xPaddingBytes": "100-1000",
    "mode": "packet-up"
  },
  "sockopt": {
    "acceptProxyProtocol": false,
    "tcpFastOpen": true,
    "mark": 0,
    "tproxy": "off",
    "tcpMptcp": true,
    "tcpNoDelay": true,
    "domainStrategy": "UseIP",
    "tcpMaxSeg": 1440,
    "dialerProxy": "",
    "tcpKeepAliveInterval": 0,
    "tcpKeepAliveIdle": 300,
    "tcpUserTimeout": 10000,
    "tcpcongestion": "bbr",
    "V6Only": false,
    "tcpWindowClamp": 600,
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
/usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${panel_port}" -webBasePath "${panel_path}"
/usr/local/x-ui/x-ui cert -webCert "/root/cert/${domain}/fullchain.pem" -webCertKey "/root/cert/${domain}/privkey.pem"
x-ui start
else
	die "x-ui.db file not exist! Maybe x-ui isn't installed."
fi
}

##############################Config After Install########################################################
config_after_install() {
	/usr/local/x-ui/x-ui setting -username "asdfasdf" -password "asdfasdf" -port "2096" -webBasePath "asdfasdf"
	/usr/local/x-ui/x-ui migrate
}

##############################Install Panel###############################################################
install_panel() {
apt-get update && apt-get install -y -q wget curl tar tzdata
    cd /usr/local/

    local requested_tag="${1:-$XUI_VERSION}"
    local tag_version="" tag_version_numeric="" min_version="2.3.5" url=""
	local xui_archive_name="" xui_archive_path="" xui_release_rel_path=""

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
		printf 'Username:  %s\n\n' "${config_username}"
		printf 'Password:  %s\n\n' "${config_password}"
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
			setup_nginx
			;;
		*)
			die "Unsupported ingress profile: ${PLATFORM_PROFILE}"
			;;
	esac
}

platform_enable_ingress() {
	case "$PLATFORM_PROFILE" in
		classic)
			enable_nginx_sites
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
		classic-xray)
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
	init_debug_session
	append_debug_log "Stage=${STAGE} Debug=${DEBUG_MODE} DryRun=${DRY_RUN} Verify=${VERIFY_MODE} SkipCleanup=${SKIP_CLEANUP} KeepArtifacts=${KEEP_ARTIFACTS} ConfirmReset=${CONFIRM_RESET} Platform=$(platform_selection_summary)"

	case "$STAGE" in
		all|verify|websub|reset) ;;
		*) die "Unsupported stage: ${STAGE}. Supported values: all, verify, websub, reset." ;;
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
	json_uri="https://${domain}/${web_path}/?name="
	print_runtime_context

	if is_yes "$DRY_RUN"; then
		print_execution_plan
		exit 0
	fi

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

	# 16. Install fake site
	install_fake_site

	# 17. Install web sub page
	install_web_sub_page

	# 18. Setup crontab
	setup_crontab

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
