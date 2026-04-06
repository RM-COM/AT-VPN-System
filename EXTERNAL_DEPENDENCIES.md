# Инвентарь внешних зависимостей

## Уже локализовано внутри форка

- `randomfakehtml.sh`
- `sub-3x-ui.html`
- `sub-3x-ui-classical.html`
- `clash/*.yaml`
- `vendor/lib/*`
- `vendor/sb-rule-sets/*`
- `vendor/rules/*`
- `vendor/rule-assets/*`
- `vendor/upstream/marz-sub-page/*`
- `vendor/probes/*`
- `vendor/releases/3x-ui/v2.8.11/x-ui-linux-amd64.tar.gz`
- `vendor/releases/sub2sing-box/v0.0.9/sub2sing-box_0.0.9_linux_amd64.tar.gz`
- `vendor/releases/SHA256SUMS`

Если установщик запускается из локального клона репозитория, эти файлы копируются с диска и обслуживаются из локального bundle-набора.

## Что ещё остаётся внешним

### Базовая установка и рантайм

- `MHSanaei/3x-ui` release tarball для архитектур и версий, которые ещё не зеркалированы в `vendor/releases/`
- `legiz-ru/sub2sing-box` release tarball для архитектур и версий, которые ещё не зеркалированы в `vendor/releases/`
- `ipv4.icanhazip.com`
- `ipv6.icanhazip.com`
- `ipwho.is`
- `Let's Encrypt` через `certbot`

Уточнение:

- [2026-04-06 05:46:14] Установщик больше не тянет `x-ui.sh` с ветки `main` отдельно: CLI берётся из того же tarball-архива `3x-ui`, что и основной runtime.
- [2026-04-06 05:46:14] Для `3x-ui` и `sub2sing-box` введён явный pinning через `XUI_REPO_SLUG`, `XUI_VERSION`, `SUB2SINGBOX_REPO_SLUG`, `SUB2SINGBOX_VERSION`, `SUB2SINGBOX_ARCH`.
- [2026-04-07 01:10:00] Для проверенного сценария `amd64` зеркалированы локальные release-архивы `3x-ui v2.8.11` и `sub2sing-box v0.0.9`; installer теперь использует их из `vendor/releases/` при запуске из локального клона и проверяет `SHA256SUMS`.
- [2026-04-07 01:12:08] Этот зеркалированный `amd64`-контур уже подтверждён clean install-прогоном на staging VPS: installer реально использовал локальные `vendor/releases/*` архивы и после этого прошёл финальный `stage=verify`.

### Legacy-файлы

- `x-ui-pro-old.sh` сохранён как исторический файл и по-прежнему содержит старые внешние ссылки

### Пользовательские ссылки и клиентские шаблоны

- Ссылки на App Store / Google Play / GitHub Releases / справочные статьи
- Публичные DNS-адреса, встроенные в клиентские шаблоны
- `routing.vpn.ru.com` и другие вспомогательные пользовательские ссылки
- Публичные help/doc ссылки внутри `sub2sing-box` UI: GitHub README, инструкции `Secret-Sing-Box`, ссылки на App Store и Google Play
- Проектные ссылки `PROJECT_SUPPORT_URL` и `PROJECT_DONATE_URL`, которые теперь настраиваются через переменные окружения и по умолчанию указывают на `AT-VPN-System`

Уточнение:

- [2026-04-06 05:38:01] Старые upstream-ссылки `gozargah_marzban`, `Gozargah/Marzban#donation`, placeholder `example.com/path/to/template.json` и legacy `BLUEBL0B/Secret-Sing-Box` больше не считаются допустимыми и проверяются как forbidden links в `stage=verify`.
- [2026-04-06 05:38:01] Оставшиеся внешние пользовательские ссылки теперь рассматриваются как allowlist-поверхность: они допустимы только если относятся к реальным client download/help URL и явно проходят verify-проверку.

## Следующая практическая фаза

1. Перевести проверенный install-контур из `codex/operational-regression` в `main`
2. Решить, какие пользовательские ссылки на загрузки и инструкции должны остаться внешними
3. При необходимости дочистить оставшиеся fake-site шаблоны до полностью локального контента без внешних ссылок в HTML
