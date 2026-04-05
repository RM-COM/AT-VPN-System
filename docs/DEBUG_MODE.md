# DEBUG_MODE

## Назначение

- [2026-04-05 06:17:58] `debug-mode` нужен для проверки текущей установки без полной переустановки сервера после каждой правки.
- [2026-04-05 06:17:58] Основной поддерживаемый сценарий диагностики реализован в `x-ui-pro-updated.sh`.
- [2026-04-05 06:17:58] `x-ui-pro.sh` не содержит отдельной реализации debug-mode и только перенаправляет diagnostic/stage-флаги в `x-ui-pro-updated.sh`.

## Поддерживаемые флаги

- [2026-04-05 06:17:58] `-debug yes` — включает подробную трассировку и запись debug-лога.
- [2026-04-05 06:17:58] `-dry_run yes` — выполняет безопасный предпросмотр без изменения системы.
- [2026-04-05 06:17:58] `-verify yes` — запускает итоговую проверку после изменения системы.
- [2026-04-05 06:17:58] `-stage verify` — проверяет уже установленную систему без переустановки.
- [2026-04-05 06:17:58] `-stage websub` — переустанавливает только web-sub контур из локального репозитория.
- [2026-04-05 07:35:53] `-stage reset` — выполняет полный reset staging-ноды: снимает pre-reset артефакты, удаляет текущую установку и проверяет чистое состояние после очистки.
- [2026-04-05 06:17:58] `-skip_cleanup yes` — пропускает очистку предыдущей установки в полном install-сценарии.
- [2026-04-05 06:17:58] `-keep_artifacts yes` — сохраняет артефакты диагностики даже без полного `-debug yes`.
- [2026-04-05 07:35:53] `-confirm_reset yes` — обязательное подтверждение destructive reset-сценария; без него `-stage reset` завершится отказом.
- [2026-04-05 06:56:44] `-verify yes` больше не переключает сценарий в отдельный diagnostic stage; самостоятельный health-check по-прежнему запускается только через `-stage verify`.

## Базовые команды

- [2026-04-05 06:17:58] Проверка действующей установки: `sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes`
- [2026-04-05 06:17:58] Переустановка только web-sub с пост-проверкой: `sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes`
- [2026-04-05 07:35:53] Безопасный preview reset-потока: `sudo bash ./x-ui-pro-updated.sh -stage reset -dry_run yes -debug yes -keep_artifacts yes`
- [2026-04-05 07:35:53] Реальный destructive reset staging-ноды: `sudo bash ./x-ui-pro-updated.sh -stage reset -confirm_reset yes -debug yes -keep_artifacts yes`
- [2026-04-05 06:17:58] Безопасный предпросмотр полной установки: `sudo bash ./x-ui-pro-updated.sh -dry_run yes -install yes -panel 1 -subdomain <домен> -reality_domain <reality-домен>`
- [2026-04-05 06:56:44] Реальный staging smoke-test уже подтверждён командой: `sudo bash ./x-ui-pro-updated.sh -install yes -panel 1 -auto_domain yes -debug yes -keep_artifacts yes -verify yes`
- [2026-04-05 07:03:16] Отдельный staging re-deploy web-sub уже подтверждён командой: `sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes`

## Что именно проверяет `-stage verify`

- [2026-04-05 06:17:58] Наличие `x-ui.db` по пути `/etc/x-ui/x-ui.db`.
- [2026-04-05 06:17:58] Результат `PRAGMA integrity_check;` для SQLite.
- [2026-04-05 06:17:58] Успешность `nginx -t`.
- [2026-04-05 06:17:58] Активность сервисов `nginx` и `x-ui`.
- [2026-04-05 06:17:58] Наличие `/var/www/subpage/index.html`, `/var/www/subpage/clash.yaml` и локальных `vendor/sb-rule-sets/*.json`.
- [2026-04-05 06:17:58] Локальный HTTPS-ответ web-sub страницы через текущие runtime-пути.

## Артефакты

- [2026-04-05 06:17:58] Все debug-материалы складываются в `/root/x-ui-pro-debug/<timestamp>/`.
- [2026-04-05 06:17:58] В артефакты входят `run.log`, копии `nginx.conf`, `includes.conf`, `stream.conf`, `index.html`, `clash.yaml`, `x-ui.db`.
- [2026-04-05 06:17:58] В артефакты входят результаты `systemctl status nginx`, `systemctl status x-ui`, `nginx -t`, `nginx -T` и ответ локальной web-sub страницы.
- [2026-04-05 07:35:53] Для `stage=reset` дополнительно сохраняются pre-reset снимки `nginx`, `x-ui.db`, web-sub и список активных TCP-listener'ов перед очисткой.

## Что проверяет `-stage reset`

- [2026-04-05 07:35:53] Что `nginx`, `x-ui` и `sub2sing-box` больше не активны после reset.
- [2026-04-05 07:35:53] Что удалены каталоги `/etc/x-ui`, `/usr/local/x-ui`, `/etc/nginx`, `/var/www/subpage`, `/etc/letsencrypt`, `/var/lib/letsencrypt`, `/var/log/letsencrypt`.
- [2026-04-05 07:35:53] Что из `PATH` исчезли бинарники `nginx`, `x-ui`, `sub2sing-box`.
- [2026-04-05 07:35:53] Что порты `80` и `443` больше не заняты после очистки.

## Ограничения

- [2026-04-05 06:17:58] Текущая версия не покрывает отдельные install-stage режимы `packages`, `ssl`, `nginx`, `xui`; это следующая итерация.
- [2026-04-05 06:17:58] `-dry_run yes` для полного install-сценария показывает план и параметры, но не эмулирует пошагово каждую системную команду.
- [2026-04-05 07:03:16] Full install, `stage=verify` и `stage=websub` уже подтверждены на реальном staging VPS, но визуальная клиентская проверка пользовательских URL ещё остаётся отдельным этапом.
- [2026-04-05 07:35:53] `stage=reset` реализован как staging-ориентированный destructive workflow; его нужно использовать только на тестовой ноде и отдельно прогнать в runtime на сервере перед тем, как считать regression-контур завершённым.
