# PROFILE_PROVIDER_SLICE

## Назначение

- [2026-04-08 05:00:30] Этот документ фиксирует первый минимальный и безопасный срез абстракции `profile/provider` для ветки `codex/platform-v2`.
- [2026-04-08 05:00:30] Цель этапа — подготовить площадку для будущих профилей `classic/stealth` и будущих провайдеров панелей без изменения текущего runtime-поведения `classic`.
- [2026-04-08 05:00:30] На этом этапе запрещено менять топологию install-контура, SQL-схему текущего `3x-ui`, `nginx stream`-маршрутизацию и operational lifecycle уже подтверждённого baseline.

## Главный практический вывод

- [2026-04-08 05:00:30] Самая безопасная точка входа — не переписывание `setup_nginx()`, `update_xui_db()` или `install_panel()`, а маленький слой совместимости над уже существующими глобальными переменными и `main()`.
- [2026-04-08 05:00:30] Первый слой должен только выбирать профиль и провайдер, валидировать их, загружать их metadata-файлы и раскладывать derived-значения в новые переменные без изменения уже существующих веток исполнения.
- [2026-04-08 05:00:30] `classic` и `3x-ui` должны оставаться значениями по умолчанию и давать абсолютно тот же runtime, что и до начала платформенного этапа.

## Какие файлы безопасно создать на первом шаге

### Новый helper-слой

- [2026-04-08 05:00:30] Создать каталог `installer/lib/`.
- [2026-04-08 05:00:30] Создать файл `installer/lib/profile-provider.sh`.
- [2026-04-08 05:00:30] Этот файл должен содержать только:
  - валидацию значений `profile/provider`;
  - загрузку профильного и provider-файла;
  - сбор derived metadata;
  - совместимый shim, который не ломает текущие глобальные переменные.

### Каталог профилей

- [2026-04-08 05:00:30] Создать каталог `installer/profiles/`.
- [2026-04-08 05:00:30] Создать файл `installer/profiles/classic.sh`.
- [2026-04-08 05:00:30] На первом этапе в `classic.sh` должны лежать только metadata и ожидаемые baseline-инварианты, а не новая install-логика.

### Каталог провайдеров

- [2026-04-08 05:00:30] Создать каталог `installer/providers/`.
- [2026-04-08 05:00:30] Создать файл `installer/providers/3x-ui.sh`.
- [2026-04-08 05:00:30] На первом этапе в `3x-ui.sh` должны лежать только metadata и значения baseline-провайдера, а не отдельный install-path.

## Где source-ить helper

- [2026-04-08 05:00:30] `x-ui-pro.sh` не трогать. Это wrapper-entrypoint, и он должен оставаться максимально тонким.
- [2026-04-08 05:00:30] `x-ui-pro-updated.sh` — единственная точка, где безопасно вводить первый abstraction-layer.
- [2026-04-08 05:00:30] Helper надо source-ить в верхней части `x-ui-pro-updated.sh` после определения `SCRIPT_DIR` и базовых путей репозитория, но до большинства install-функций.
- [2026-04-08 05:00:30] Практически безопасное место: сразу после блока констант верхнего уровня и до `append_debug_log()` / `print_runtime_context()`, чтобы эти функции уже видели активные `profile/provider` metadata.
- [2026-04-08 05:00:30] Для этого в `x-ui-pro-updated.sh` нужно ввести только path-константы:
  - `INSTALLER_DIR="${SCRIPT_DIR}/installer"`
  - `INSTALLER_LIB_DIR="${INSTALLER_DIR}/lib"`
  - `INSTALLER_PROFILES_DIR="${INSTALLER_DIR}/profiles"`
  - `INSTALLER_PROVIDERS_DIR="${INSTALLER_DIR}/providers"`
- [2026-04-08 05:00:30] После этих констант допустим один guarded `source`:
  - `source "$INSTALLER_LIB_DIR/profile-provider.sh" || die "..."`

## Какие переменные ввести на первом шаге

### Пользовательские входные переменные

- [2026-04-08 05:00:30] Добавить в `parse_args()` только два новых флага:
  - `-profile`
  - `-provider`
- [2026-04-08 05:00:30] Значения по умолчанию:
  - `PROFILE_ID="classic"`
  - `PROVIDER_ID="3x-ui"`

### Новые platform-переменные runtime

- [2026-04-08 05:00:30] Ввести новые переменные уровня platform metadata:
  - `PROFILE_ID`
  - `PROVIDER_ID`
  - `PROFILE_TITLE`
  - `PROVIDER_TITLE`
  - `PROFILE_KIND`
  - `PROVIDER_KIND`
  - `PROFILE_STATE_KEY`
  - `PROVIDER_STATE_KEY`

### Derived baseline-инварианты профиля

- [2026-04-08 05:00:30] Ввести только те derived-переменные, которые уже и так жёстко зашиты в baseline и нужны для будущего безопасного разделения режимов:
  - `PROFILE_EXPECT_STREAM_CONF="y"`
  - `PROFILE_EXPECT_REALITY_PORT="8443"`
  - `PROFILE_EXPECT_WEB_TLS_PORT="7443"`
  - `PROFILE_EXPECT_REALITY_PROXY_PROTOCOL="y"`
  - `PROFILE_DOMAIN_MODE="dual-domain"`
  - `PROFILE_INGRESS_MODE="nginx-stream"`

### Derived baseline-инварианты провайдера

- [2026-04-08 05:00:30] Ввести metadata текущего провайдера панели:
  - `PROVIDER_PANEL_SERVICE="x-ui"`
  - `PROVIDER_PANEL_DB_PATH="/etc/x-ui/x-ui.db"`
  - `PROVIDER_PANEL_BIN="/usr/local/x-ui/x-ui"`
  - `PROVIDER_PANEL_CLI="/usr/bin/x-ui"`

## Какой shim нужен на первом шаге

- [2026-04-08 05:00:30] Нужна одна функция bootstrap, например `platform_bootstrap_runtime`.
- [2026-04-08 05:00:30] Её безопасный порядок:
  - проверить, что `PROFILE_ID` и `PROVIDER_ID` допустимы;
  - source-ить `installer/profiles/${PROFILE_ID}.sh`;
  - source-ить `installer/providers/${PROVIDER_ID}.sh`;
  - проверить обязательные metadata-переменные;
  - выставить derived runtime metadata;
  - ничего не менять в текущих глобальных install-переменных вроде `XUIDB`, `domain`, `reality_domain`, `panel_port`, `web_path`.
- [2026-04-08 05:00:30] На этом этапе shim не должен вызывать install-функции, не должен выбирать другой код-path и не должен менять sequencing `main()`.

## Где helper можно использовать уже на первом шаге

- [2026-04-08 05:00:30] Безопасно использовать новый слой в read-only и presentation-участках:
  - `print_runtime_context()`
  - `print_execution_plan()`
  - `show_details()`
- [2026-04-08 05:00:30] Условно безопасно использовать metadata в `verify_existing_installation()`, но только для чтения baseline-инвариантов, без переписывания самой логики verify на первом проходе.
- [2026-04-08 05:00:30] Безопасно логировать `PROFILE_ID` и `PROVIDER_ID` в `main()` сразу после `parse_args()`.

## Какие участки installer пока не трогать

- [2026-04-08 05:00:30] Не трогать `setup_nginx()`. Это сердце текущей `classic`-топологии.
- [2026-04-08 05:00:30] Не трогать `update_xui_db()`. Там текущая baseline-модель inbound'ов, портов и `REALITY`.
- [2026-04-08 05:00:30] Не трогать `install_panel()`. Вынос провайдера панели в отдельный code-path должен идти только после стабилизации metadata-слоя.
- [2026-04-08 05:00:30] Не трогать `clean_previous_install()`, `uninstall_xui()`, `remove_reset_residuals()`. Это destructive-участки, и profile/provider abstraction не должна менять их до явной operational-модели.
- [2026-04-08 05:00:30] Не трогать `setup_ufw()`. Для будущего `AWG` и `stealth` там появятся profile-зависимые правила, но не на первом минимальном шаге.
- [2026-04-08 05:00:30] Не трогать `load_existing_runtime_context()`. Сейчас он эвристический; переводить его на profile/provider metadata имеет смысл только после записи явного state.
- [2026-04-08 05:00:30] Не трогать `backup.sh`. Provider/module-aware backup — это следующий отдельный этап.

## Минимальный безопасный порядок внедрения

- [2026-04-08 05:00:30] Шаг 1: добавить `installer/lib/profile-provider.sh`.
- [2026-04-08 05:00:30] Шаг 2: добавить `installer/profiles/classic.sh` и `installer/providers/3x-ui.sh`.
- [2026-04-08 05:00:30] Шаг 3: в `x-ui-pro-updated.sh` добавить новые path-константы и guarded `source`.
- [2026-04-08 05:00:30] Шаг 4: в `parse_args()` добавить `-profile` и `-provider` с дефолтами `classic`/`3x-ui`.
- [2026-04-08 05:00:30] Шаг 5: в `main()` сразу после `parse_args()` вызвать `platform_bootstrap_runtime`.
- [2026-04-08 05:00:30] Шаг 6: отобразить `PROFILE_ID/PROVIDER_ID` в debug/context-выводе.
- [2026-04-08 05:00:30] Шаг 7: прогнать только `bash -n`, `-stage verify -dry_run yes`, `-stage websub -dry_run yes`, `-install yes -dry_run yes`.

## Что даст этот этап на практике

- [2026-04-08 05:00:30] Появится реальная точка расширения для `classic/stealth/AWG optional`, но без изменения текущего `classic` runtime.
- [2026-04-08 05:00:30] Появится реальная точка расширения для `3x-ui` как первого provider, не заставляя сразу выносить install-контур панели в отдельный модуль.
- [2026-04-08 05:00:30] Следующий этап уже можно будет делать поверх формальной модели `profile/provider`, а не поверх случайных глобальных переменных.

## Практический запрет этого этапа

- [2026-04-08 05:00:30] Если на первом шаге появляется новая ветка исполнения install/runtime, новый `nginx`-шаблон, новый SQL-вставщик inbound'ов или новый uninstall/reset path — значит этап уже вышел за пределы безопасного минимального среза.
