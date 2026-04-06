#!/bin/bash
#################### x-ui-pro legacy entrypoint ########################################################
set -o pipefail
trap 'rc=$?; (( rc )) && printf "[ERROR] Script exited with code %d\n" "$rc" >&2' EXIT

msg_ok()  { printf '\e[1;42m %s \e[0m\n' "$1"; }
msg_err() { printf '\e[1;41m %s \e[0m\n' "$1" >&2; }
msg_inf() { printf '\e[1;34m%s\e[0m\n' "$1"; }
die()     { msg_err "$1"; exit "${2:-1}"; }

[[ $EUID -eq 0 ]] || die "Запуск x-ui-pro.sh требует root. Используйте sudo bash ./x-ui-pro.sh ..."

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
case "$SCRIPT_SOURCE" in
    /dev/fd/*|/proc/self/fd/*) SCRIPT_DIR="" ;;
    *) SCRIPT_DIR=$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd -P) ;;
esac

UPDATED_SCRIPT="${SCRIPT_DIR}/x-ui-pro-updated.sh"

if [[ -z "$SCRIPT_DIR" || ! -f "$UPDATED_SCRIPT" ]]; then
    die "Для запуска нужен локальный x-ui-pro-updated.sh рядом с x-ui-pro.sh. Используйте локальный клон репозитория."
fi

msg_inf "x-ui-pro.sh передает выполнение в актуальный installer x-ui-pro-updated.sh"
exec bash "$UPDATED_SCRIPT" "$@"
