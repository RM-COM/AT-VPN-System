# OPERATIONS

## Назначение

- [2026-04-08 04:30:47] Этот файл является единой канонической сводкой эксплуатационных сценариев проекта.
- [2026-04-08 04:30:47] Он собирает в одном месте install, verify, websub, reset, backup, uninstall, restore и правила staging-regression.
- [2026-04-08 04:30:47] Подробные технические детали при необходимости остаются в `DEBUG_MODE.md`, `STAGING_RESET.md` и `REGRESSION_CHECKLIST.md`.

## Канонические рабочие сценарии

- [2026-04-08 04:30:47] Поддерживаемая установка: `sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no`
- [2026-04-11 14:40:00] Установка с controlled tuning preset: `sudo env PLATFORM_PROFILE=stealth TRANSPORT_PROFILE=stealth-xhttp REALITY_TUNING_PROFILE=mobile-safe XHTTP_TUNING_PROFILE=handoff-safe bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no`
- [2026-04-08 04:30:47] Проверка существующей установки: `sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes`
- [2026-04-08 04:30:47] Переустановка только web-sub контура: `sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes`
- [2026-04-09 00:30:57] Server-side приёмка stealth-профиля: `sudo bash ./x-ui-pro-updated.sh -stage acceptance -debug yes -keep_artifacts yes -acceptance_minutes 5 -acceptance_interval_seconds 30`
- [2026-04-11 14:40:00] Server-side приёмка с явным preset override: `sudo bash ./x-ui-pro-updated.sh -stage acceptance -debug yes -keep_artifacts yes -profile stealth -transport_profile stealth-xray -reality_tuning_profile aggressive-stealth -acceptance_minutes 5 -acceptance_interval_seconds 30`
- [2026-04-11 16:05:00] Comparative acceptance теперь поддерживает matrix-метки: `-acceptance_label`, `-acceptance_matrix_group`, `-acceptance_network`, `-acceptance_operator`, `-acceptance_time_window`, `-acceptance_client`, `-acceptance_notes`
- [2026-04-08 04:30:47] Preview полного reset без изменений: `sudo bash ./x-ui-pro-updated.sh -stage reset -dry_run yes -debug yes -keep_artifacts yes`
- [2026-04-08 04:30:47] Реальный staging reset: `sudo bash ./x-ui-pro-updated.sh -stage reset -confirm_reset yes -debug yes -keep_artifacts yes`
- [2026-04-08 04:30:47] Полное удаление через совместимый entrypoint: `sudo bash ./x-ui-pro.sh -uninstall yes`
- [2026-04-08 04:30:47] Резервное копирование и восстановление: `sudo bash ./backup.sh`

## Канонический regression-маршрут

- [2026-04-08 04:30:47] Основной обязательный маршрут перед выпуском следующего этапа: `reset -> install -> verify -> websub -> backup -> uninstall -> restore -> verify`.
- [2026-04-08 04:30:47] Любая большая правка install-контура или архитектуры должна подтверждаться этим маршрутом на staging.
- [2026-04-08 04:30:47] Полный официальный чек-лист шагов и ожидаемых результатов хранится в `REGRESSION_CHECKLIST.md`.

## Что делает debug-контур

- [2026-04-08 04:30:47] `-stage verify` выполняет быструю диагностику существующей установки без её изменения.
- [2026-04-08 04:30:47] `-stage websub` обновляет только web/UI-контур без полного reinstall.
- [2026-04-09 00:30:57] `-stage acceptance` запускает server-side stealth acceptance: выполняет строгий `verify`, повторяемые HTTPS-пробы и сохраняет чек-лист ручной клиентской проверки.
- [2026-04-11 14:40:00] `-reality_tuning_profile` и `-xhttp_tuning_profile` позволяют прогонять comparative acceptance на разных preset'ах без ручной правки metadata или SQL.
- [2026-04-11 16:05:00] Comparative acceptance теперь дополнительно пишет machine-readable артефакты `acceptance/session-metadata.env`, `acceptance/matrix-row.json` и `acceptance/probe-results.jsonl`, чтобы сравнивать `stealth-xray` и `stealth-xhttp` по единому формату.
- [2026-04-11 17:50:00] `stage=verify` для `stealth-xhttp` больше не ограничивается socket/path-проверками: он поднимает локальный Xray loopback-client и выполняет активный `XHTTP` self-test через публичный ingress, сохраняя `commands/xhttp-selftest.json`, `commands/xhttp-selftest.xray.log` и `commands/xhttp-selftest.curl.log`.
- [2026-04-11 17:50:00] Базовый runtime-контракт `stealth-xhttp` синхронизирован с официальным `nginx + TLS + XHTTP` направлением: server-side default переведён с `packet-up` на `auto`, а `nginx`-location для `XHTTP` усилен под H2 ingress.
- [2026-04-11 19:40:00] Для `stealth-xhttp handoff-safe` installer теперь встраивает handoff/reconnect tuning в inbound, `verify` валидирует этот блок по `x-ui.db`, а JSON-подписка доставляет клиенту валидный `settings.vnext` и `streamSettings.sockopt`.
- [2026-04-11 19:40:00] Практический операторский инвариант: handoff/reconnect тесты `stealth-xhttp handoff-safe` нужно выполнять через `XRAY JSON Subscription` (`v2rayNG install-config` / update subscription), потому что прямой QR/base64 URI формат upstream `3x-ui` не умеет переносить полный JSON transport tuning.
- [2026-04-11 20:05:00] Публичный JSON-sub endpoint больше не отдаётся напрямую из `3x-ui`: nginx проксирует `/${json_path}` в локальный `subjson-rewrite` bridge на `127.0.0.1:8091`, который забирает raw JSON с локального `x-ui` sub-port и переписывает `vless` outbound'ы в валидный `vnext`-формат.
- [2026-04-11 20:05:00] `stage=verify` теперь валидирует не только то, что JSON endpoint отвечает и не возвращает HTML, но и то, что все `vless`-конфиги приходят с `settings.vnext` и без старого плоского `settings.address/id/port`.
- [2026-04-08 04:30:47] `-stage reset` подготавливает staging к новому чистому прогону.
- [2026-04-08 04:30:47] `-dry_run yes` используется как безопасный preview действий.
- [2026-04-08 04:30:47] `-keep_artifacts yes` сохраняет артефакты диагностики даже без полного `-debug yes`.

## Debug-артефакты

- [2026-04-08 04:30:47] Основной каталог артефактов — `/root/x-ui-pro-debug/<timestamp>/`.
- [2026-04-08 04:30:47] Там сохраняются `run.log`, конфиги `nginx`, снимки `x-ui.db`, результаты `nginx -t`, `nginx -T`, статусы сервисов и ответы локальных HTTPS-проверок.
- [2026-04-08 04:30:47] Для `stage=reset` дополнительно сохраняются pre-reset снимки и post-check чистого состояния.
- [2026-04-09 00:30:57] Для `stage=acceptance` дополнительно сохраняются `acceptance/summary.txt`, повторные HTML-ответы probes и `acceptance/manual-client-checklist.md`.
- [2026-04-11 14:40:00] Comparative acceptance теперь дополнительно сохраняет `acceptance/runtime-snapshot.env` с profile/preset/runtime state и `acceptance/xui-inbounds-summary.txt` с redacted сводкой по `REALITY/XHTTP` inbound'ам из `x-ui.db`.
- [2026-04-11 16:05:00] Comparative acceptance теперь также сохраняет `acceptance/session-metadata.env`, `acceptance/matrix-row.json` и `acceptance/probe-results.jsonl`; это канонический артефактный слой для triage блока `C1`.
- [2026-04-11 15:20:00] Постоянный runtime provenance теперь хранится в `/etc/x-ui/runtime-provenance.env`; `backup.sh` копирует его отдельным `runtime-provenance.env` в каталог backup, а `restore` сначала использует этот sidecar-файл и только потом fallback-эвристику по `x-ui.db`.
- [2026-04-09 01:32:44] `acceptance/manual-client-checklist.md` теперь должен рассматриваться как основной handoff-файл для ручного теста: он фиксирует актуальные URL ноды после reinstall и transport-specific подсказку, какой узел выбирать в клиенте.

## Границы использования

- [2026-04-08 04:30:47] `stage=reset` предназначен для staging, а не для production-сопровождения.
- [2026-04-08 04:30:47] Перед risky-изменениями на staging желательно делать `backup.sh`, даже если планируется reset.
- [2026-04-08 04:30:47] `x-ui-pro-old.sh` не должен использоваться ни для install, ни для uninstall, ни для debug.
- [2026-04-08 04:30:47] Основная точка правды по активному installer-контуру — `x-ui-pro-updated.sh`.

## Где смотреть детали

- [2026-04-08 04:30:47] Подробный список поддерживаемых debug-флагов и артефактов — `DEBUG_MODE.md`.
- [2026-04-08 04:30:47] Подробности reset-сценария и его ограничений — `STAGING_RESET.md`.
- [2026-04-08 04:30:47] Формальный чек-лист обязательных staging-проверок — `REGRESSION_CHECKLIST.md`.
