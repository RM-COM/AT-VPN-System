#!/bin/bash

platform_detect_root() {
	local candidate
	for candidate in "${PLATFORM_ROOT:-}" "${SCRIPT_DIR:-}" "$PWD"; do
		[[ -n "$candidate" && -d "$candidate" ]] || continue
		if [[ -f "$candidate/x-ui-pro-updated.sh" || -f "$candidate/.env.example" ]]; then
			printf '%s' "$candidate"
			return 0
		fi
	done
	return 1
}

platform_set_root() {
	local requested_root="$1"
	if [[ -n "$requested_root" && -d "$requested_root" ]]; then
		PLATFORM_ROOT="$requested_root"
		return 0
	fi
	PLATFORM_ROOT="$(platform_detect_root 2>/dev/null || true)"
	[[ -n "$PLATFORM_ROOT" ]]
}

platform_load_defaults() {
	: "${PLATFORM_PROFILE:=classic}"
	: "${TRANSPORT_PROFILE:=classic-xray}"
	: "${PANEL_PROVIDER:=3x-ui}"
	: "${ENABLE_AWG:=n}"
}

platform_apply_builtin_metadata() {
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
	esac

	ENABLE_AWG_STATE="disabled"
	PLATFORM_METADATA_SOURCE="built-in"
}

platform_source_file() {
	local metadata_file="$1"
	[[ -n "$PLATFORM_ROOT" && -f "$metadata_file" ]] || return 0
	# shellcheck disable=SC1090
	. "$metadata_file"
	PLATFORM_METADATA_SOURCE="repo"
}

platform_load_metadata() {
	platform_apply_builtin_metadata
	[[ -n "$PLATFORM_ROOT" ]] || return 0
	platform_source_file "$PLATFORM_ROOT/modules/profiles/${PLATFORM_PROFILE}/profile.env"
	platform_source_file "$PLATFORM_ROOT/modules/transports/${TRANSPORT_PROFILE}/profile.env"
	platform_source_file "$PLATFORM_ROOT/providers/panels/${PANEL_PROVIDER}/provider.env"
}

platform_validate_selection() {
	case "$PLATFORM_PROFILE" in
		classic|stealth) ;;
		*)
			printf 'Unsupported PLATFORM_PROFILE: %s\n' "$PLATFORM_PROFILE" >&2
			return 1
			;;
	esac

	case "$TRANSPORT_PROFILE" in
		classic-xray|stealth-xray) ;;
		*)
			printf 'Unsupported TRANSPORT_PROFILE: %s\n' "$TRANSPORT_PROFILE" >&2
			return 1
			;;
	esac

	case "$PLATFORM_PROFILE:$TRANSPORT_PROFILE" in
		classic:classic-xray|stealth:stealth-xray) ;;
		*)
			printf 'Unsupported PLATFORM_PROFILE/TRANSPORT_PROFILE combination: %s/%s\n' "$PLATFORM_PROFILE" "$TRANSPORT_PROFILE" >&2
			return 1
			;;
	esac

	case "$PANEL_PROVIDER" in
		3x-ui) ;;
		*)
			printf 'Unsupported PANEL_PROVIDER: %s\n' "$PANEL_PROVIDER" >&2
			return 1
			;;
	esac

	case "${ENABLE_AWG,,}" in
		n|no|0|false|off)
			ENABLE_AWG_STATE="disabled"
			;;
		y|yes|1|true|on)
			printf 'ENABLE_AWG is reserved for a future module and is not implemented yet.\n' >&2
			return 1
			;;
		*)
			printf 'Unsupported ENABLE_AWG value: %s\n' "$ENABLE_AWG" >&2
			return 1
			;;
	esac

	return 0
}

platform_selection_summary() {
	printf 'profile=%s transport=%s panel=%s awg=%s source=%s' \
		"$PLATFORM_PROFILE" \
		"$TRANSPORT_PROFILE" \
		"$PANEL_PROVIDER" \
		"$ENABLE_AWG_STATE" \
		"${PLATFORM_METADATA_SOURCE:-built-in}"
}

platform_init() {
	platform_load_defaults
	platform_set_root "${PLATFORM_ROOT:-${SCRIPT_DIR:-}}"
	platform_validate_selection || return 1
	platform_load_metadata
	return 0
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
