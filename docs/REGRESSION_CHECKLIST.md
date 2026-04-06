# Regression Checklist

## Назначение

- [2026-04-06 04:44:23] Этот документ фиксирует минимальный обязательный regression-маршрут форка перед переходом к новым багфиксам, рефакторингу или публикации очередного этапа.
- [2026-04-06 04:44:23] Чек-лист построен на уже реально подтверждённых runtime-сценариях staging VPS и должен использоваться как канонический порядок тестирования.
- [2026-04-06 04:44:23] Рабочий цикл остаётся неизменным: `Windows -> GitHub -> Linux staging`.

## Обязательный маршрут

1. [2026-04-06 04:44:23] `stage=reset` или подтверждённое исходное рабочее состояние staging-ноды.
2. [2026-04-06 04:44:23] `install` через поддерживаемый entrypoint.
3. [2026-04-06 04:44:23] `stage=verify`.
4. [2026-04-06 04:44:23] `stage=websub`.
5. [2026-04-06 04:44:23] `backup`.
6. [2026-04-06 04:44:23] `uninstall`.
7. [2026-04-06 04:44:23] `restore`.
8. [2026-04-06 04:44:23] Финальный `stage=verify`.

## Подготовка staging

- [2026-04-06 04:44:23] Загрузить на сервер актуальные файлы из текущего commit форка.
- [2026-04-06 04:44:23] Убедиться, что на staging есть локальный каталог проекта и именно из него запускается installer.
- [2026-04-06 04:44:23] Перед destructive-сценариями сохранить или обновить backup, если на ноде есть состояние, которое требуется удержать.

## Команды проверки

### 1. Предварительная диагностика

```bash
sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] `x-ui.db` найдена и `sqlite integrity_check` возвращает `ok`.
- [2026-04-06 04:44:23] `nginx -t` проходит успешно.
- [2026-04-06 05:28:47] `nginx -t` не должен выводить warning `duplicate MIME type`.
- [2026-04-06 04:44:23] `nginx`, `x-ui`, `sub2sing-box` активны.
- [2026-04-06 04:44:23] web-sub по локальному `HTTPS` отвечает, локальный `clash.yaml` и `sb-rule-sets` существуют.
- [2026-04-06 05:13:22] `sub2sing-box` UI отвечает по локальному `HTTPS` и не содержит runtime-ссылок на `unpkg.com`, `fonts.googleapis.com` и внешние raw JSON `sb-rule-sets`.
- [2026-04-06 05:38:01] Web-sub и `sub2sing-box` UI не должны содержать forbidden upstream-ссылки (`gozargah_marzban`, `Gozargah/Marzban#donation`, `example.com/path/to/template.json`, `BLUEBL0B/Secret-Sing-Box`) и неожиданные внешние URL вне allowlist.

### 2. Reset staging

Предпросмотр:

```bash
sudo bash ./x-ui-pro-updated.sh -stage reset -dry_run yes -debug yes -keep_artifacts yes
```

Реальный reset:

```bash
sudo bash ./x-ui-pro-updated.sh -stage reset -confirm_reset yes -debug yes -keep_artifacts yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] install-контур форка очищен.
- [2026-04-06 04:44:23] debug-артефакты reset сохранены при включённом debug.
- [2026-04-06 04:44:23] порты `80/443` освобождены или готовы к новому install-потоку.

### 3. Install

Канонический install через совместимый entrypoint:

```bash
sudo bash ./x-ui-pro.sh -install yes -panel 1 -subdomain <домен> -reality_domain <reality-домен> -debug yes -keep_artifacts yes -verify yes
```

Пример staging-доменов, уже подтверждённых runtime:

```bash
sudo bash ./x-ui-pro.sh -install yes -panel 1 -subdomain 185.207.64.40.sslip.io -reality_domain 185-207-64-40.sslip.io -debug yes -keep_artifacts yes -verify yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] installer завершается с кодом `0`.
- [2026-04-06 04:44:23] финальный экран печатается полностью.
- [2026-04-06 04:44:23] `SSH`-сеанс возвращается без ложного «подвисания».
- [2026-04-06 04:44:23] при повторной установке на те же домены вывод содержит `Reusing existing certificate ...`.
- [2026-04-06 05:28:47] install-лог не должен содержать warning `duplicate MIME type`.

### 4. Повторная verify-проверка

```bash
sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] полный набор `PASS`.

### 5. Переустановка web-sub

```bash
sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] web-sub пересобирается без полного reinstall.
- [2026-04-06 04:44:23] post-check остаётся зелёным.

### 6. Backup

```bash
sudo bash ./backup.sh
```

Ожидаемый результат:

- [2026-04-06 04:44:23] создан новый каталог backup в `/backup/<дата>/<время>`.
- [2026-04-06 04:44:23] в архивы попали `nginx`, `Let's Encrypt`, `x-ui.db`, runtime `x-ui`, `sub2sing-box`, web-root и `root crontab`.

### 7. Uninstall

```bash
sudo bash ./x-ui-pro.sh -uninstall yes
```

Ожидаемый результат:

- [2026-04-06 04:44:23] install-контур удалён через актуальный uninstall-механизм `x-ui-pro-updated.sh`.
- [2026-04-06 04:44:23] `x-ui`, `nginx`, `sub2sing-box` остановлены или удалены согласно сценарию.

### 8. Restore

```bash
sudo bash ./backup.sh
```

Ожидаемый результат:

- [2026-04-06 04:44:23] выбранный backup восстанавливается без ручных правок.
- [2026-04-06 04:44:23] после restore сервисы снова поднимаются.
- [2026-04-06 04:44:23] финальный `stage=verify` возвращает полный `PASS`.

## Критичные сигналы отказа

- [2026-04-06 04:44:23] `nginx -t` падает после reset/install.
- [2026-04-06 04:44:23] `x-ui.db` не создаётся или `sqlite integrity_check` не возвращает `ok`.
- [2026-04-06 04:44:23] `sub2sing-box.service` не активируется после install или restore.
- [2026-04-06 04:44:23] installer не возвращает `SSH`-сеанс после печати финального экрана.
- [2026-04-06 04:44:23] repeated install повторно вызывает `certbot` при наличии валидных сертификатов и начинает расходовать лимит без необходимости.
- [2026-04-06 04:44:23] cleanup repeated install удаляет базовый layout `nginx` и ломает следующий install.

## Уже подтверждено на практике

- [2026-04-06 04:44:23] `stage=verify` подтверждён на актуальной ревизии.
- [2026-04-06 04:44:23] clean install success-path подтверждён на staging с доменами `sslip.io`.
- [2026-04-06 04:44:23] repeated install success-path подтверждён на тех же доменах с reuse сертификатов.
- [2026-04-06 04:44:23] `stage=websub` подтверждён.
- [2026-04-06 04:44:23] `backup -> uninstall -> restore -> verify` подтверждён.
- [2026-04-06 05:13:22] client-side локализация `sub2sing-box` UI подтверждена: локальные CSS/JS/JSON по путям `${WEB_PATH}/vendor/lib/sub2sing-box-ui/*` и `${WEB_PATH}/vendor/sb-rule-sets/*` отвечают `200 OK`.
- [2026-04-06 05:28:47] warning `duplicate MIME type` после `stage=websub` и repeated install устранён и больше не воспроизводится на staging.
