#!/bin/bash

set -o pipefail

if [ "$EUID" -ne 0 ]; then
	echo "Please run this script as root."
	exit 1
fi

PKG_MGR=$(command -v apt >/dev/null 2>&1 && echo "apt" || echo "yum")
DEFAULT_BACKUP_DIR="/backup"
RUNTIME_PROVENANCE_FILE="/etc/x-ui/runtime-provenance.env"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/backup_script.log
}

get_web_roots() {
	local roots=()
	local root

	if command -v nginx >/dev/null 2>&1; then
		while IFS= read -r root; do
			[ -n "$root" ] && roots+=("${root%/}")
		done < <(nginx -T 2>/dev/null | awk '/^[[:space:]]*root[[:space:]]+/ {gsub(";", "", $2); print $2}')
	fi

	for root in /var/www/html /var/www/subpage; do
		[ -d "$root" ] && roots+=("$root")
	done

	printf '%s\n' "${roots[@]}" | awk 'NF && !seen[$0]++'
}

ask_backup_dir_for_backup() {
	while true; do
		read -p "Enter the backup directory path (default $DEFAULT_BACKUP_DIR): " BACKUP_DIR
		BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
		if mkdir -p "$BACKUP_DIR" 2>/dev/null; then
			return 0
		fi
		echo "Failed to create backup directory. Please enter a valid path."
	done
}

ask_backup_dir_for_restore() {
	while true; do
		read -p "Enter the backup directory path (default $DEFAULT_BACKUP_DIR): " BACKUP_DIR
		BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
		if [ -d "$BACKUP_DIR" ]; then
			return 0
		fi
		echo "Backup directory does not exist. Please enter a valid path."
	done
}

init_backup_target() {
	BACKUP_DATE=$(date +%F)
	BACKUP_TIMESTAMP=$(date +%H-%M-%S)
	BACKUP_DIR_DATE="$BACKUP_DIR/$BACKUP_DATE"
	BACKUP_DIR_TIMESTAMP="$BACKUP_DIR_DATE/$BACKUP_TIMESTAMP"
	mkdir -p "$BACKUP_DIR_TIMESTAMP"
}

archive_label() {
	local label="$1"
	shift
	local archive_path="${BACKUP_DIR_TIMESTAMP}/${label}-${BACKUP_TIMESTAMP}.tar.gz"
	local existing=()
	local item

	for item in "$@"; do
		[ -e "$item" ] && existing+=("$item")
	done

	if [ ${#existing[@]} -eq 0 ]; then
		echo "Nothing to back up for ${label}. Skipping."
		log "Skipped ${label}: no source paths found"
		return 0
	fi

	echo "Creating backup of ${label}..."
	tar -czf "$archive_path" "${existing[@]}"
	echo "Backup completed: $archive_path"
	log "${label} backed up to $archive_path"
}

backup_root_crontab() {
	local cron_file="${BACKUP_DIR_TIMESTAMP}/root-crontab.txt"

	if crontab -l > "$cron_file" 2>/dev/null; then
		echo "Root crontab backed up to $cron_file"
		log "Root crontab backed up to $cron_file"
	else
		rm -f "$cron_file"
		echo "Root crontab is empty. Skipping."
		log "Skipped root crontab backup: no entries"
	fi
}

backup_nginx_stack() {
	archive_label "nginx" /etc/nginx /etc/letsencrypt /var/lib/letsencrypt
}

backup_xui_database() {
	archive_label "x-ui-sql" /etc/x-ui
	if [ -f "$RUNTIME_PROVENANCE_FILE" ]; then
		cp -f "$RUNTIME_PROVENANCE_FILE" "${BACKUP_DIR_TIMESTAMP}/runtime-provenance.env"
		echo "Runtime provenance copied to ${BACKUP_DIR_TIMESTAMP}/runtime-provenance.env"
		log "Runtime provenance copied to ${BACKUP_DIR_TIMESTAMP}/runtime-provenance.env"
	fi
}

backup_xui_runtime() {
	archive_label "x-ui-runtime" /usr/local/x-ui /usr/bin/x-ui /etc/systemd/system/x-ui.service
}

backup_helper_binaries() {
	archive_label "sub2sing-box" /usr/bin/sub2sing-box /etc/systemd/system/sub2sing-box.service
	backup_root_crontab
}

backup_websites() {
	local web_roots
	local web_root

	web_roots=$(get_web_roots)
	if [ -z "$web_roots" ]; then
		echo "No website roots found. Skipping website backup."
		log "Skipped website backup: no web roots found"
		return 0
	fi

	echo "Creating backup of website files..."
	while IFS= read -r web_root; do
		[ -n "$web_root" ] || continue
		if [ -d "$web_root" ]; then
			tar -czf "${BACKUP_DIR_TIMESTAMP}/website-${web_root//\//_}-${BACKUP_TIMESTAMP}.tar.gz" -P "$web_root"
			echo "Backed up $web_root"
			log "Website files for $web_root backed up"
		else
			echo "Web root $web_root does not exist. Skipping."
			log "Skipped website root $web_root: path missing"
		fi
	done <<< "$web_roots"
	echo "Website backup completed."
}

backup_all() {
	echo "Creating full backup..."
	backup_nginx_stack
	backup_xui_database
	backup_xui_runtime
	backup_helper_binaries
	backup_websites
	echo "Full backup completed."
}

backup() {
	ask_backup_dir_for_backup
	init_backup_target

	while true; do
		echo "Select components to back up:"
		echo "1. Nginx configuration and SSL"
		echo "2. 3x-ui database"
		echo "3. 3x-ui runtime, helper binaries and crontab"
		echo "4. Website files"
		echo "5. All of the above"
		echo "0. Exit"
		read -p "Enter your choice (0-5): " OPTION

		case "$OPTION" in
			1)
				backup_nginx_stack
				;;
			2)
				backup_xui_database
				;;
			3)
				backup_xui_runtime
				backup_helper_binaries
				;;
			4)
				backup_websites
				;;
			5)
				backup_all
				;;
			0)
				echo "Exiting backup selection."
				break
				;;
			*)
				echo "Invalid choice. Please select a valid option."
				;;
		esac

		read -p "Press Enter to continue..."
	done
}

ensure_restore_packages() {
	echo "Ensuring restore prerequisites are installed..."
	if [ "$PKG_MGR" = "apt" ]; then
		DEBIAN_FRONTEND=noninteractive apt -y update
		DEBIAN_FRONTEND=noninteractive apt -y install nginx-full certbot python3-certbot-nginx sqlite3
	else
		yum -y install nginx certbot python3-certbot-nginx sqlite
	fi
	log "Restore prerequisites ensured via $PKG_MGR"
}

stop_restore_services() {
	systemctl stop nginx x-ui 2>/dev/null || true
	systemctl stop sub2sing-box 2>/dev/null || true
	pkill -x "sub2sing-box" 2>/dev/null || true
}

restore_root_crontab() {
	local cron_file="${BACKUP_DIR_TIMESTAMP}/root-crontab.txt"
	if [ -f "$cron_file" ]; then
		crontab "$cron_file"
		echo "Root crontab restored."
		log "Root crontab restored from $cron_file"
	fi
}

remove_legacy_sub2singbox_cron() {
	local tmp_file

	tmp_file=$(mktemp)
	if crontab -l 2>/dev/null | grep -v 'sub2sing-box server --bind 127.0.0.1 --port 8080' > "$tmp_file"; then
		if [ -s "$tmp_file" ]; then
			crontab "$tmp_file"
		else
			crontab -r 2>/dev/null || true
		fi
	else
		: > "$tmp_file"
		crontab -r 2>/dev/null || true
	fi
	rm -f "$tmp_file"
}

fix_restored_permissions() {
	[ -f /usr/bin/x-ui ] && chmod +x /usr/bin/x-ui
	[ -f /usr/bin/sub2sing-box ] && chmod +x /usr/bin/sub2sing-box
	[ -f /usr/local/x-ui/x-ui ] && chmod +x /usr/local/x-ui/x-ui
	[ -f /usr/local/x-ui/x-ui.sh ] && chmod +x /usr/local/x-ui/x-ui.sh
	if [ -d /usr/local/x-ui/bin ]; then
		find /usr/local/x-ui/bin -maxdepth 1 -type f -name 'xray-linux*' -exec chmod +x {} + 2>/dev/null || true
	fi
}

trim_slashes() {
	local value="${1#/}"
	value="${value%/}"
	printf '%s' "$value"
}

load_restore_runtime_context() {
	RESTORE_DOMAIN=""
	RESTORE_REALITY_DOMAIN=""
	RESTORE_WEB_PATH=""
	RESTORE_PANEL_PATH=""
	RESTORE_SUB_PATH=""
	RESTORE_JSON_PATH=""
	RESTORE_SUB2SINGBOX_PATH=""
	RESTORE_XHTTP_PATH=""
	RESTORE_SUB_URI=""
	RESTORE_JSON_URI=""
	RESTORE_PLATFORM_PROFILE="classic"
	RESTORE_TRANSPORT_PROFILE="classic-xray"
	RESTORE_PANEL_PROVIDER="3x-ui"
	RESTORE_REALITY_TUNING_PROFILE="default"
	RESTORE_XHTTP_TUNING_PROFILE=""
	RESTORE_PUBLIC_HTTPS_PORT="443"
	RESTORE_WEB_TLS_PORT="7443"
	local detected_reality_port="" detected_xhttp_inbound=""

	if [ -f "$RUNTIME_PROVENANCE_FILE" ]; then
		# shellcheck disable=SC1090
		. "$RUNTIME_PROVENANCE_FILE" 2>/dev/null || true
		[ -n "${RUNTIME_PROVENANCE_DOMAIN:-}" ] && RESTORE_DOMAIN="$RUNTIME_PROVENANCE_DOMAIN"
		[ -n "${RUNTIME_PROVENANCE_REALITY_DOMAIN:-}" ] && RESTORE_REALITY_DOMAIN="$RUNTIME_PROVENANCE_REALITY_DOMAIN"
		[ -n "${RUNTIME_PROVENANCE_WEB_PATH:-}" ] && RESTORE_WEB_PATH="$RUNTIME_PROVENANCE_WEB_PATH"
		[ -n "${RUNTIME_PROVENANCE_PANEL_PATH:-}" ] && RESTORE_PANEL_PATH="$RUNTIME_PROVENANCE_PANEL_PATH"
		[ -n "${RUNTIME_PROVENANCE_SUB_PATH:-}" ] && RESTORE_SUB_PATH="$RUNTIME_PROVENANCE_SUB_PATH"
		[ -n "${RUNTIME_PROVENANCE_JSON_PATH:-}" ] && RESTORE_JSON_PATH="$RUNTIME_PROVENANCE_JSON_PATH"
		[ -n "${RUNTIME_PROVENANCE_SUB2SINGBOX_PATH:-}" ] && RESTORE_SUB2SINGBOX_PATH="$RUNTIME_PROVENANCE_SUB2SINGBOX_PATH"
		[ -n "${RUNTIME_PROVENANCE_XHTTP_PATH:-}" ] && RESTORE_XHTTP_PATH="$RUNTIME_PROVENANCE_XHTTP_PATH"
		[ -n "${RUNTIME_PROVENANCE_PLATFORM_PROFILE:-}" ] && RESTORE_PLATFORM_PROFILE="$RUNTIME_PROVENANCE_PLATFORM_PROFILE"
		[ -n "${RUNTIME_PROVENANCE_TRANSPORT_PROFILE:-}" ] && RESTORE_TRANSPORT_PROFILE="$RUNTIME_PROVENANCE_TRANSPORT_PROFILE"
		[ -n "${RUNTIME_PROVENANCE_PANEL_PROVIDER:-}" ] && RESTORE_PANEL_PROVIDER="$RUNTIME_PROVENANCE_PANEL_PROVIDER"
		[ -n "${RUNTIME_PROVENANCE_REALITY_TUNING_PROFILE:-}" ] && RESTORE_REALITY_TUNING_PROFILE="$RUNTIME_PROVENANCE_REALITY_TUNING_PROFILE"
		[ -n "${RUNTIME_PROVENANCE_XHTTP_TUNING_PROFILE:-}" ] && RESTORE_XHTTP_TUNING_PROFILE="$RUNTIME_PROVENANCE_XHTTP_TUNING_PROFILE"
	fi

	if [ -f /etc/x-ui/x-ui.db ] && command -v sqlite3 >/dev/null 2>&1; then
		RESTORE_SUB_URI=$(sqlite3 -list /etc/x-ui/x-ui.db 'SELECT value FROM settings WHERE key="subURI" LIMIT 1;' 2>/dev/null)
		RESTORE_JSON_URI=$(sqlite3 -list /etc/x-ui/x-ui.db 'SELECT value FROM settings WHERE key="subJsonURI" LIMIT 1;' 2>/dev/null)
		[ -z "$RESTORE_REALITY_DOMAIN" ] && RESTORE_REALITY_DOMAIN=$(sqlite3 -list /etc/x-ui/x-ui.db "SELECT json_extract(stream_settings, '$.realitySettings.serverNames[0]') FROM inbounds WHERE json_extract(stream_settings, '$.security')='reality' LIMIT 1;" 2>/dev/null | head -n1)
		detected_reality_port=$(sqlite3 -list /etc/x-ui/x-ui.db "SELECT port FROM inbounds WHERE json_extract(stream_settings, '$.security')='reality' LIMIT 1;" 2>/dev/null | tr -d '[:space:]')
		detected_xhttp_inbound=$(sqlite3 -list /etc/x-ui/x-ui.db "SELECT COUNT(*) FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp';" 2>/dev/null | tr -d '[:space:]')
		if [ "$detected_reality_port" = "$RESTORE_PUBLIC_HTTPS_PORT" ]; then
			RESTORE_PLATFORM_PROFILE="stealth"
			if [[ "$detected_xhttp_inbound" =~ ^[1-9][0-9]*$ ]]; then
				RESTORE_TRANSPORT_PROFILE="stealth-xhttp"
			else
				RESTORE_TRANSPORT_PROFILE="stealth-xray"
			fi
		fi
		if [ -z "$RESTORE_XHTTP_PATH" ]; then
			RESTORE_XHTTP_PATH=$(sqlite3 -list /etc/x-ui/x-ui.db "SELECT json_extract(stream_settings, '$.xhttpSettings.path') FROM inbounds WHERE json_extract(stream_settings, '$.network')='xhttp' LIMIT 1;" 2>/dev/null | tr -d '\r')
			RESTORE_XHTTP_PATH=$(trim_slashes "$RESTORE_XHTTP_PATH")
		fi
	fi

	if [ -z "$RESTORE_DOMAIN" ]; then
		RESTORE_DOMAIN=$(printf '%s\n%s\n' "$RESTORE_SUB_URI" "$RESTORE_JSON_URI" | sed -nE 's#https?://([^/]+)/.*#\1#p' | head -n1)
	fi

	if [ -z "$RESTORE_WEB_PATH" ]; then
		RESTORE_WEB_PATH=$(printf '%s' "$RESTORE_JSON_URI" | sed -nE 's#https?://[^/]+/([^/?]+)/?.*#\1#p' | head -n1)
	fi

	if [ -f /etc/nginx/snippets/includes.conf ] && [ -z "$RESTORE_WEB_PATH" ]; then
		RESTORE_WEB_PATH=$(sed -nE 's#^[[:space:]]*location = /([^[:space:]]+) \{#\1#p' /etc/nginx/snippets/includes.conf | head -n1)
		RESTORE_WEB_PATH=$(trim_slashes "$RESTORE_WEB_PATH")
	fi
}

start_restored_services() {
	systemctl daemon-reload 2>/dev/null || true
	if [ -f /etc/systemd/system/x-ui.service ]; then
		systemctl enable x-ui 2>/dev/null || true
	fi
	if command -v nginx >/dev/null 2>&1; then
		systemctl enable nginx 2>/dev/null || true
		systemctl restart nginx 2>/dev/null || true
	fi
	if [ -f /etc/systemd/system/x-ui.service ]; then
		systemctl restart x-ui 2>/dev/null || true
	fi
	if [ -f /etc/systemd/system/sub2sing-box.service ]; then
		remove_legacy_sub2singbox_cron
		systemctl enable sub2sing-box 2>/dev/null || true
		systemctl restart sub2sing-box 2>/dev/null || true
	elif [ -x /usr/bin/sub2sing-box ] && ! pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		nohup /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 >/dev/null 2>&1 &
	fi
}

verify_restore_result() {
	local listener_output="" probe_port="" probe_url="" resolve_host="" stealth_failures=0

	echo "Post-restore checks:"
	if command -v nginx >/dev/null 2>&1; then
		if nginx -t >/dev/null 2>&1; then
			echo "[PASS] nginx configuration is valid"
		else
			echo "[FAIL] nginx configuration test failed"
		fi
	else
		echo "[FAIL] nginx binary is missing after restore"
	fi

	if systemctl is-active --quiet nginx; then
		echo "[PASS] nginx service is active"
	else
		echo "[FAIL] nginx service is inactive"
	fi

	if [ -f /etc/systemd/system/x-ui.service ] && systemctl is-active --quiet x-ui; then
		echo "[PASS] x-ui service is active"
	else
		echo "[FAIL] x-ui service is inactive or service file is missing"
	fi

	if [ -f /etc/systemd/system/sub2sing-box.service ] && systemctl is-active --quiet sub2sing-box; then
		echo "[PASS] sub2sing-box service is active"
	elif [ -x /usr/bin/sub2sing-box ] && pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		echo "[PASS] sub2sing-box process is active"
	else
		echo "[FAIL] sub2sing-box service/process is inactive or binary is missing"
	fi

	load_restore_runtime_context
	if [ -f "$RUNTIME_PROVENANCE_FILE" ]; then
		echo "[PASS] runtime provenance file restored"
	else
		echo "[INFO] runtime provenance file is missing; restore context falls back to heuristics"
	fi
	echo "[INFO] restored selection: ${RESTORE_PLATFORM_PROFILE}/${RESTORE_TRANSPORT_PROFILE} | reality_tuning=${RESTORE_REALITY_TUNING_PROFILE:-default} | xhttp_tuning=${RESTORE_XHTTP_TUNING_PROFILE:-n/a}"
	if [ "$RESTORE_PLATFORM_PROFILE" = "stealth" ] && command -v ss >/dev/null 2>&1; then
		listener_output=$(ss -lntp 2>/dev/null || true)
		if grep -Eq "[:.]${RESTORE_PUBLIC_HTTPS_PORT}[[:space:]].*xray" <<<"$listener_output"; then
			echo "[PASS] stealth restore keeps xray on public ${RESTORE_PUBLIC_HTTPS_PORT}"
		else
			echo "[FAIL] stealth restore does not show xray on public ${RESTORE_PUBLIC_HTTPS_PORT}"
			stealth_failures=$((stealth_failures + 1))
		fi
		if grep -Eq "[:.]${RESTORE_WEB_TLS_PORT}[[:space:]].*nginx" <<<"$listener_output"; then
			echo "[PASS] stealth restore keeps nginx on local ${RESTORE_WEB_TLS_PORT}"
		else
			echo "[FAIL] stealth restore does not show nginx on local ${RESTORE_WEB_TLS_PORT}"
			stealth_failures=$((stealth_failures + 1))
		fi
		if [ ! -f /etc/nginx/stream-enabled/stream.conf ]; then
			echo "[PASS] stealth restore does not leave nginx stream.conf behind"
		else
			echo "[FAIL] stealth restore unexpectedly still has nginx stream.conf"
			stealth_failures=$((stealth_failures + 1))
		fi
		if [ "$RESTORE_TRANSPORT_PROFILE" = "stealth-xhttp" ]; then
			if [ -S /dev/shm/uds2023.sock ]; then
				echo "[PASS] stealth-xhttp restore keeps unix socket"
			else
				echo "[FAIL] stealth-xhttp restore is missing unix socket"
				stealth_failures=$((stealth_failures + 1))
			fi
			if [ -n "$RESTORE_XHTTP_PATH" ] && grep -Rqs "location /${RESTORE_XHTTP_PATH} {" /etc/nginx/sites-enabled /etc/nginx/sites-available /etc/nginx/snippets 2>/dev/null; then
				echo "[PASS] stealth-xhttp restore keeps nginx fallback route"
			else
				echo "[FAIL] stealth-xhttp restore is missing nginx fallback route"
				stealth_failures=$((stealth_failures + 1))
			fi
		fi
	fi
	if command -v curl >/dev/null 2>&1 && [ -n "$RESTORE_DOMAIN" ] && [ -n "$RESTORE_WEB_PATH" ]; then
		probe_port="$RESTORE_PUBLIC_HTTPS_PORT"
		probe_url="https://${RESTORE_DOMAIN}/${RESTORE_WEB_PATH}/"
		resolve_host="${RESTORE_DOMAIN}:${RESTORE_PUBLIC_HTTPS_PORT}:127.0.0.1"
		if curl -kfsS --resolve "$resolve_host" "$probe_url" >/dev/null 2>&1; then
			echo "[PASS] local HTTPS web-sub responds after restore"
		else
			echo "[FAIL] local HTTPS web-sub does not respond after restore"
		fi
	else
		echo "[FAIL] restore runtime context is incomplete for HTTPS web-sub check"
	fi

	if [ "$stealth_failures" -gt 0 ]; then
		echo "[FAIL] stealth-specific restore checks reported ${stealth_failures} issue(s)"
	fi
}

restore() {
	local file

	ask_backup_dir_for_restore

	BACKUP_DATES=($(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort))
	if [ ${#BACKUP_DATES[@]} -eq 0 ]; then
		echo "No backup dates found."
		return
	fi

	echo "Available backup dates:"
	select BACKUP_DATE in "${BACKUP_DATES[@]}" "Exit"; do
		if [ "$BACKUP_DATE" = "Exit" ]; then
			echo "Exiting restore selection."
			return
		elif [ -n "$BACKUP_DATE" ]; then
			BACKUP_DIR_DATE="$BACKUP_DIR/$BACKUP_DATE"
			break
		else
			echo "Please select a valid option."
		fi
	done

	BACKUP_TIMESTAMPS=($(find "$BACKUP_DIR_DATE" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort))
	if [ ${#BACKUP_TIMESTAMPS[@]} -eq 0 ]; then
		echo "No backup timestamps found in $BACKUP_DIR_DATE."
		return
	fi

	echo "Available backup timestamps in $BACKUP_DIR_DATE:"
	select BACKUP_TIMESTAMP in "${BACKUP_TIMESTAMPS[@]}" "Exit"; do
		if [ "$BACKUP_TIMESTAMP" = "Exit" ]; then
			echo "Exiting restore selection."
			return
		elif [ -n "$BACKUP_TIMESTAMP" ]; then
			BACKUP_DIR_TIMESTAMP="$BACKUP_DIR_DATE/$BACKUP_TIMESTAMP"
			break
		else
			echo "Please select a valid option."
		fi
	done

	echo "Restoring from $BACKUP_DIR_TIMESTAMP..."
	stop_restore_services
	ensure_restore_packages
	for file in "$BACKUP_DIR_TIMESTAMP"/*.tar.gz; do
		[ -f "$file" ] || continue
		echo "Restoring $file..."
		tar -xzf "$file" -C /
		log "Restored $file from $BACKUP_DIR_TIMESTAMP"
	done
	restore_root_crontab
	fix_restored_permissions
	start_restored_services
	verify_restore_result
	echo "Restore completed."
	read -p "Press Enter to continue..."
}

while true; do
	echo "------------------------"
	echo "  Backup/Restore Menu  "
	echo "------------------------"
	echo "1. Perform Backup"
	echo "2. Perform Restore"
	echo "0. Exit"
	read -p "Select an option: " OPTION

	case "$OPTION" in
		1)
			backup
			;;
		2)
			restore
			;;
		0)
			echo "Exiting script."
			log "Script exited by user."
			break
			;;
		*)
			echo "Invalid option. Please choose again."
			;;
	esac
done
