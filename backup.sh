#!/bin/bash

set -o pipefail

if [ "$EUID" -ne 0 ]; then
	echo "Please run this script as root."
	exit 1
fi

PKG_MGR=$(command -v apt >/dev/null 2>&1 && echo "apt" || echo "yum")
DEFAULT_BACKUP_DIR="/backup"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> /var/log/backup_script.log
}

get_web_roots() {
	local roots=()
	local root

	if command -v nginx >/dev/null 2>&1; then
		while IFS= read -r root; do
			[ -n "$root" ] && roots+=("$root")
		done < <(nginx -T 2>/dev/null | awk '/[[:space:]]root[[:space:]]/ {gsub(";", "", $2); print $2}')
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
}

backup_xui_runtime() {
	archive_label "x-ui-runtime" /usr/local/x-ui /usr/bin/x-ui /etc/systemd/system/x-ui.service
}

backup_helper_binaries() {
	archive_label "sub2sing-box" /usr/bin/sub2sing-box
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

fix_restored_permissions() {
	[ -f /usr/bin/x-ui ] && chmod +x /usr/bin/x-ui
	[ -f /usr/bin/sub2sing-box ] && chmod +x /usr/bin/sub2sing-box
	[ -f /usr/local/x-ui/x-ui ] && chmod +x /usr/local/x-ui/x-ui
	[ -f /usr/local/x-ui/x-ui.sh ] && chmod +x /usr/local/x-ui/x-ui.sh
	if [ -d /usr/local/x-ui/bin ]; then
		find /usr/local/x-ui/bin -maxdepth 1 -type f -name 'xray-linux*' -exec chmod +x {} + 2>/dev/null || true
	fi
}

start_restored_services() {
	systemctl daemon-reload 2>/dev/null || true
	if [ -f /etc/systemd/system/x-ui.service ]; then
		systemctl enable x-ui 2>/dev/null || true
	fi
	if command -v nginx >/dev/null 2>&1; then
		systemctl enable nginx 2>/dev/null || true
		systemctl start nginx 2>/dev/null || true
	fi
	if [ -f /etc/systemd/system/x-ui.service ]; then
		systemctl start x-ui 2>/dev/null || true
	fi
	if [ -x /usr/bin/sub2sing-box ] && ! pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		nohup /usr/bin/sub2sing-box server --bind 127.0.0.1 --port 8080 >/dev/null 2>&1 &
	fi
}

verify_restore_result() {
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

	if [ -x /usr/bin/sub2sing-box ] && pgrep -x "sub2sing-box" >/dev/null 2>&1; then
		echo "[PASS] sub2sing-box process is active"
	else
		echo "[FAIL] sub2sing-box process is inactive or binary is missing"
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
