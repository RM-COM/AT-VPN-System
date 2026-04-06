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

Если установщик запускается из локального клона репозитория, эти файлы копируются с диска и обслуживаются из локального bundle-набора.

## Что ещё остаётся внешним

### Базовая установка и рантайм

- `MHSanaei/3x-ui` release tarball и служебные скрипты
- `legiz-ru/sub2sing-box` release tarball
- `ipv4.icanhazip.com`
- `ipv6.icanhazip.com`
- `ipwho.is`
- `Let's Encrypt` через `certbot`

### Legacy-файлы

- `x-ui-pro-old.sh` сохранён как исторический файл и по-прежнему содержит старые внешние ссылки

### Пользовательские ссылки и клиентские шаблоны

- Ссылки на App Store / Google Play / GitHub Releases / справочные статьи
- Публичные DNS-адреса, встроенные в клиентские шаблоны
- `routing.vpn.ru.com` и другие вспомогательные пользовательские ссылки
- Публичные help/doc ссылки внутри `sub2sing-box` UI: GitHub README, инструкции `Secret-Sing-Box`, ссылки на App Store и Google Play

## Следующая практическая фаза

1. Решить, зеркалировать ли `3x-ui` и `sub2sing-box` в активы самого форка
2. Решить, какие пользовательские ссылки на загрузки и инструкции должны остаться внешними
3. При необходимости дочистить оставшиеся fake-site шаблоны до полностью локального контента без внешних ссылок в HTML
