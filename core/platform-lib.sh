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
			PLATFORM_PROFILE_DESCRIPTION="Текущий стабильный ingress-контур форка"
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
			TRANSPORT_PROFILE_DESCRIPTION="Текущий профиль Xray с baseline-логикой"
			TRANSPORT_WEB_TLS_PORT=7443
			TRANSPORT_REALITY_SITE_TLS_PORT=9443
			TRANSPORT_REALITY_INBOUND_PORT=8443
			;;
	esac

	case "$PANEL_PROVIDER" in
		3x-ui)
			PANEL_PROVIDER_LABEL="3x-ui"
			PANEL_PROVIDER_DESCRIPTION="Текущий baseline-провайдер панели"
			PANEL_PROVIDER_PANEL_TITLE="X-UI Secure Panel"
			PANEL_PROVIDER_SERVICE_NAME="x-ui"
			PANEL_PROVIDER_CONTROL_BIN="x-ui"
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
		classic) ;;
		*)
			printf 'Unsupported PLATFORM_PROFILE: %s\n' "$PLATFORM_PROFILE" >&2
			return 1
			;;
	esac

	case "$TRANSPORT_PROFILE" in
		classic-xray) ;;
		*)
			printf 'Unsupported TRANSPORT_PROFILE: %s\n' "$TRANSPORT_PROFILE" >&2
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
