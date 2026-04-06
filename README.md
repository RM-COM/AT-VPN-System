# AT-VPN-System

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

## Основные скрипты

- `x-ui-pro-updated.sh` — основной поддерживаемый installer и debug-runner.
- `x-ui-pro.sh` — совместимый входной wrapper-скрипт; поддерживаемый запуск всегда передаёт выполнение в `x-ui-pro-updated.sh`.
- `backup.sh` — резервное копирование и восстановление `nginx`, SSL, `x-ui`, `sub2sing-box` и web-root файлов.
- `randomfakehtml.sh` — установка локального fake-site из репозитория.
- `x-ui-pro-old.sh` — legacy-файл, не являющийся основным поддерживаемым контуром.

## Установка

Поддерживаемый сценарий установки для этого форка: локальный клон именно нашего репозитория.

```bash
git clone https://github.com/RM-COM/AT-VPN-System.git
cd AT-VPN-System
sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
```

Если нужен тестовый сценарий с автодоменами на staging:

```bash
sudo bash ./x-ui-pro-updated.sh -install yes -panel 1 -auto_domain yes -debug yes -keep_artifacts yes -verify yes
```

Важно:

- режим `wget | bash` для этого форка не считается основным и поддерживаемым способом установки
- основной путь — запуск из локального клона репозитория
- после выпуска сертификатов не следует менять домен без понимания последствий для `certbot`

## Настройка пользовательских ссылок

В `.env.example` зафиксированы проектные ссылки для web-sub страницы:

- `PROJECT_REPO_URL`
- `PROJECT_SUPPORT_URL`
- `PROJECT_DONATE_URL`

По умолчанию они указывают на `AT-VPN-System`, но их можно переопределить через переменные окружения перед запуском installer.

## Диагностика и debug-mode

Проверка уже установленной системы:

```bash
sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes
```

Переустановка только web-sub контура:

```bash
sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes
```

Безопасный предпросмотр install-сценария без изменения системы:

```bash
sudo bash ./x-ui-pro-updated.sh -dry_run yes -install yes -panel 1 -subdomain <домен> -reality_domain <reality-домен>
```

Артефакты debug-режима складываются в:

```bash
/root/x-ui-pro-debug/<timestamp>/
```

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
- локальная выдача web-sub через HTTPS
- локальная выдача `clash.yaml`
- работа `nginx`, `x-ui`, `sub2sing-box`
- внешняя client-side проверка web-sub, `clashmeta/first` и `sub2sing-box` endpoint
- локальная выдача runtime-ассетов `sub2sing-box` UI без `unpkg.com`, `fonts.googleapis.com` и внешних raw JSON `sb-rule-sets`
- отсутствие forbidden upstream-ссылок и неожиданных внешних URL вне allowlist в `stage=verify`

Отдельный обязательный regression-маршрут теперь формализован в:

- `docs/REGRESSION_CHECKLIST.md`

## Документация проекта

Ключевые документы лежат в `docs/`:

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
