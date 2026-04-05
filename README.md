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
- Локальный `sub2sing-box`
- Локальный набор fake-site шаблонов
- Диагностический контур `debug-mode`
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
- `x-ui-pro.sh` — совместимый входной скрипт; debug/stage-флаги перенаправляет в `x-ui-pro-updated.sh`.
- `backup.sh` — резервное копирование и восстановление `nginx`, `x-ui`, `config.json` и web-root файлов.
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

- сохранять `nginx`
- сохранять `x-ui.db`
- сохранять `config.json`
- сохранять web-root файлы
- восстанавливать выбранный backup обратно на сервер

## Текущее подтверждённое состояние

На staging-сервере уже подтверждены:

- полный install-поток
- `stage=verify`
- `stage=websub`
- локальная выдача web-sub через HTTPS
- локальная выдача `clash.yaml`
- работа `nginx`, `x-ui`, `sub2sing-box`

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
