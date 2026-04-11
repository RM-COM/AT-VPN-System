# AT-VPN-System

> Ветка: `codex/platform-v2`
> Статус: `ACTIVE IMPLEMENTATION`
> Использование: `dev / staging`
> Официальный стабильный install-source: `main`

`codex/platform-v2` — это основная implementation-ветка большого платформенного обновления. Здесь идёт модульный рефакторинг installer-контура, развитие профилей `classic / stealth`, вынос transport/provider-логики в selection-layer и подготовка к будущему модулю `AmneziaWG`.

Если нужна стабильная установка подтверждённого `classic`-контура, использовать нужно ветку `main`. Если нужна разработка следующего архитектурного этапа, работать нужно именно в этой ветке.

`AT-VPN-System` — это рабочий форк install/debug-контура для развёртывания `3x-ui + nginx + REALITY` с локальной web-sub страницей, локальными `Clash`/`sing-box` шаблонами и staging-ориентированным workflow разработки.

Проект ведётся как самостоятельный форк. Исторически он основан на старых upstream-репозиториях, но поддерживаемый контур, документация и GitHub-репозиторий уже принадлежат этому проекту.

## Что входит в форк

- Установка `3x-ui`, `nginx`, `certbot`, `sqlite3`, `ufw`
- Работа через `443` с SNI-маршрутизацией
- Поддержка `VLESS Reality`, `VLESS WS`, `VLESS XHTTP`, `Trojan gRPC`
- Локальная web-sub страница
- Локальные `Clash`-шаблоны
- Локальные `sing-box` rule-set шаблоны
- Локальный `vendor/` с frontend-ассетами и зеркалированными rule-файлами
- Локальный `sub2sing-box` под `systemd`
- Локальный набор fake-site шаблонов
- Диагностический контур `debug-mode`
- Проверка allowlist внешних пользовательских ссылок в `verify`
- Сценарии удаления, резервного копирования и восстановления

## Канонический репозиторий

- Рабочий GitHub-репозиторий: [RM-COM/AT-VPN-System](https://github.com/RM-COM/AT-VPN-System)
- Upstream-источник для сравнения и заимствования изменений: `mozaroc/x-ui-pro`

## Поддерживаемая среда

- `Ubuntu 24+`
- `Debian 12+`
- запуск от `root`
- основной сценарий: отдельный `staging`-сервер для тестов

## Рабочий цикл проекта

Для этого форка принят жёсткий рабочий порядок:

1. Изменения вносятся локально на Windows.
2. После завершённого логического этапа изменения коммитятся и отправляются в GitHub.
3. Только после этого текущая версия выгружается на Linux `staging`.
4. На `staging` выполняются install/debug/regression-проверки.

## Branch-specific контекст

- Эта ветка предназначена для разработки и `staging`, а не для production-baseline.
- `classic` здесь сохраняется как baseline.
- `stealth-xray` уже является runnable-профилем и подтверждён staging-регрессом.
- `stealth-xhttp` уже является вторым runnable stealth transport и подтверждён staging install/verify.
- `AmneziaWG` в этой ветке пока не реализован и остаётся следующим большим модулем после завершения текущего `Xray/DPI` этапа.
- Branch-specific статус и ограничения этой ветки зафиксированы в `docs/BRANCH_CONTEXT.md`.

## Основные скрипты

- `x-ui-pro-updated.sh` — основной поддерживаемый installer и debug-runner.
- `x-ui-pro.sh` — совместимый входной wrapper-скрипт; поддерживаемый запуск всегда передаёт выполнение в `x-ui-pro-updated.sh`.
- `backup.sh` — резервное копирование и восстановление `nginx`, SSL, `x-ui`, `sub2sing-box` и web-root файлов.
- install/runtime provenance теперь сохраняется в `/etc/x-ui/runtime-provenance.env`, чтобы `verify`, `acceptance` и `backup/restore` не теряли точный `platform/transport/tuning` контекст.
- `randomfakehtml.sh` — установка локального fake-site из репозитория.
- `x-ui-pro-old.sh` — legacy-файл, не являющийся основным поддерживаемым контуром.

## Установка

Для этой ветки поддерживаемый сценарий — локальный клон именно `codex/platform-v2` и прогон на `staging`.

```bash
git clone -b codex/platform-v2 https://github.com/RM-COM/AT-VPN-System.git
cd AT-VPN-System
sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
```

Для явного выбора профиля через переменные окружения:

```bash
PLATFORM_PROFILE=classic TRANSPORT_PROFILE=classic-xray sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
PLATFORM_PROFILE=stealth TRANSPORT_PROFILE=stealth-xray sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
PLATFORM_PROFILE=stealth TRANSPORT_PROFILE=stealth-xhttp sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
```

Для controlled tuning можно сразу передавать preset-профили:

```bash
PLATFORM_PROFILE=stealth TRANSPORT_PROFILE=stealth-xray REALITY_TUNING_PROFILE=aggressive-stealth sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
PLATFORM_PROFILE=stealth TRANSPORT_PROFILE=stealth-xhttp REALITY_TUNING_PROFILE=mobile-safe XHTTP_TUNING_PROFILE=low-latency sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
```

Если нужен тестовый сценарий с автодоменами на staging:

```bash
sudo bash ./x-ui-pro-updated.sh -install yes -panel 1 -auto_domain yes -debug yes -keep_artifacts yes -verify yes
```

Важно:

- режим `wget | bash` для этого форка не считается основным и поддерживаемым способом установки
- для стабильной установки использовать нужно `main`
- основной путь — запуск из локального клона репозитория
- после выпуска сертификатов не следует менять домен без понимания последствий для `certbot`

## Настройка пользовательских ссылок

В `.env.example` зафиксированы проектные ссылки для web-sub страницы:

- `PROJECT_REPO_URL`
- `PROJECT_SUPPORT_URL`
- `PROJECT_DONATE_URL`

По умолчанию они указывают на `AT-VPN-System`, но их можно переопределить через переменные окружения перед запуском installer.

Там же теперь зафиксированы и проверенные pinned-версии внешних бинарников:

- `XUI_REPO_SLUG`
- `XUI_VERSION`
- `SUB2SINGBOX_REPO_SLUG`
- `SUB2SINGBOX_VERSION`
- `SUB2SINGBOX_ARCH`

Поддерживаемый install-путь умеет работать с этими значениями напрямую, поэтому переход на новую версию теперь можно делать осознанно, а не только через неявный `latest`.

Для основного проверенного сценария `amd64` нужные release-архивы `3x-ui v2.8.11` и `sub2sing-box v0.0.9` уже зеркалированы в `vendor/releases/`. Если запуск идёт из локального клона репозитория, installer берёт их локально и проверяет по `SHA256SUMS`, а не скачивает каждый раз извне.

## Диагностика и debug-mode

Проверка уже установленной системы:

```bash
sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes
```

Переустановка только web-sub контура:

```bash
sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes
```

Server-side acceptance для текущего stealth-профиля:

```bash
sudo bash ./x-ui-pro-updated.sh -stage acceptance -debug yes -keep_artifacts yes -acceptance_minutes 5 -acceptance_interval_seconds 30
```

С явным выбором preset и matrix-меток для comparative triage:

```bash
sudo bash ./x-ui-pro-updated.sh -stage acceptance -debug yes -keep_artifacts yes -profile stealth -transport_profile stealth-xray -reality_tuning_profile aggressive-stealth -acceptance_label xray-evening -acceptance_matrix_group c1-longrun -acceptance_network LTE -acceptance_operator "MTS" -acceptance_time_window "evening-no-whitelist" -acceptance_client "Android/v2rayNG" -acceptance_minutes 5 -acceptance_interval_seconds 30
sudo bash ./x-ui-pro-updated.sh -stage acceptance -debug yes -keep_artifacts yes -profile stealth -transport_profile stealth-xhttp -reality_tuning_profile mobile-safe -xhttp_tuning_profile low-latency -acceptance_label xhttp-evening -acceptance_matrix_group c1-longrun -acceptance_network LTE -acceptance_operator "MTS" -acceptance_time_window "evening-no-whitelist" -acceptance_client "Android/v2rayNG" -acceptance_minutes 5 -acceptance_interval_seconds 30
```

Безопасный предпросмотр install-сценария без изменения системы:

```bash
sudo bash ./x-ui-pro-updated.sh -dry_run yes -install yes -panel 1 -subdomain <домен> -reality_domain <reality-домен>
```

Артефакты debug-режима складываются в:

```bash
/root/x-ui-pro-debug/<timestamp>/
```

Для `stage=acceptance` дополнительно сохраняются:

- `acceptance/runtime-snapshot.env` с активным profile/preset/runtime state
- `acceptance/xui-inbounds-summary.txt` с redacted сводкой по `REALITY/XHTTP` inbound'ам из `x-ui.db`
- `acceptance/session-metadata.env` с метками comparative-прогона
- `acceptance/matrix-row.json` как каноническая структурированная строка матрицы для текущего прогона
- `acceptance/probe-results.jsonl` с результатом каждого HTTPS-probe по итерациям

При `backup.sh` этот provenance-файл также сохраняется как отдельный `runtime-provenance.env` рядом с архивами, а после `restore` используется как source of truth до fallback на старую эвристику по `x-ui.db`.

## Reset staging-ноды

Для повторяемой очистки тестового VPS перед новым install-прогоном теперь поддерживается отдельный reset-сценарий.

Безопасный предпросмотр reset без изменения системы:

```bash
sudo bash ./x-ui-pro-updated.sh -stage reset -dry_run yes -debug yes -keep_artifacts yes
```

Реальный reset staging-ноды:

```bash
sudo bash ./x-ui-pro-updated.sh -stage reset -confirm_reset yes -debug yes -keep_artifacts yes
```

Что делает reset:

- останавливает `nginx`, `x-ui`, `sub2sing-box`
- выполняет полный `uninstall` текущего install-контура
- удаляет остаточные каталоги `x-ui`, `nginx`, `web-sub`, `certbot` и бинарники `sub2sing-box`
- сохраняет pre-reset артефакты в debug-директорию, если включён `-debug yes` или `-keep_artifacts yes`
- выполняет post-check, что сервисы остановлены, пути очищены и порты `80/443` освобождены

Важно:

- `stage=reset` предназначен именно для `staging`, а не для production
- destructive reset не выполнится без явного подтверждения `-confirm_reset yes`
- `-uninstall yes` остаётся поддерживаемым режимом полного удаления, но для тестового цикла `Windows -> GitHub -> Linux staging` предпочтителен именно `stage=reset`

## Удаление

Полное удаление текущей установки:

```bash
sudo bash ./x-ui-pro.sh -uninstall yes
```

Этот сценарий считается обязательной частью форка и не должен ломаться при дальнейших изменениях.

## Резервное копирование и восстановление

Запуск меню backup/restore:

```bash
sudo bash ./backup.sh
```

Скрипт умеет:

- сохранять `nginx` и SSL-материалы
- сохранять `x-ui.db` и runtime `x-ui`
- сохранять бинарник и `systemd` unit `sub2sing-box`
- сохранять web-root файлы
- восстанавливать выбранный backup обратно на сервер

## Текущее подтверждённое состояние

На staging-сервере уже подтверждены:

- полный install-поток
- repeated install поверх уже работающей ноды
- `stage=verify`
- `stage=websub`
- `stage=acceptance` для server-side stealth soak и генерации чек-листа ручной клиентской приёмки
- локальная выдача web-sub через HTTPS
- локальная выдача `clash.yaml`
- работа `nginx`, `x-ui`, `sub2sing-box`
- внешняя client-side проверка web-sub, `clashmeta/first` и `sub2sing-box` endpoint
- локальная выдача runtime-ассетов `sub2sing-box` UI без `unpkg.com`, `fonts.googleapis.com` и внешних raw JSON `sb-rule-sets`
- отсутствие forbidden upstream-ссылок и неожиданных внешних URL вне allowlist в `stage=verify`
- короткий server-side acceptance/soak для `stealth-xray` и `stealth-xhttp`
- repeated install с явным пиннингом `XUI_VERSION=v2.8.11` и `SUB2SINGBOX_VERSION=v0.0.9`

Важно:

- `stage=acceptance` пока рассчитан именно на `stealth`-профили
- он не заменяет живую проверку через `v2rayN`, а подготавливает сравнение и сохраняет `manual-client-checklist.md` в debug artifacts

Отдельный обязательный regression-маршрут теперь формализован в:

- `docs/REGRESSION_CHECKLIST.md`

## Документация проекта

Ключевые документы лежат в `docs/`:

- `docs/BRANCH_CONTEXT.md` — статус, допустимые действия и ограничения именно текущей ветки
- `docs/MASTER_PLAN.md` — главный поэтапный план проекта
- `docs/ROADMAP.md` — краткая дорожная карта
- `docs/RESUME_POINT.md` — текущая точка продолжения
- `docs/DEBUG_MODE.md` — режимы диагностики
- `docs/RULES.md` — правила работы с проектом

## Скриншоты

**Как открыть custom web sub page**

![](./media/CustomWebSubHow2Open.png)

**Главная страница custom web sub**

![](./media/CustomWebSub.png)

**Блок sub2sing-box на custom web sub page**

![](./media/CustomWebSubSingBox.png)

**Локальный экземпляр sub2sing-box**

![](./media/sub2sing.png)
