# PROJECT_STATE

## Назначение

- [2026-04-08 04:30:47] Этот файл является единой сводкой текущего технического состояния проекта.
- [2026-04-08 04:30:47] Он не заменяет подробные документы `IMPLEMENTED.md`, `AI_CONTEXT.md` и `SERVICES_PLAN.md`, а собирает из них канонический срез без дублирования.

## Текущее состояние baseline

- [2026-04-12 19:45:00] Первый прямой живой сравнительный прогон `stealth-xray mobile-safe` против лучшего текущего `stealth-xhttp packet-up-safe` уже дал полезное разделение ролей: `stealth-xray` подключается примерно за `1` секунду и в целом ощущается быстрее по `cold-start`, но `Telegram` calls на нём пока нестабильны, тогда как `Discord` держится заметно лучше.
- [2026-04-12 19:45:00] Это усиливает продуктовую гипотезу о complementary baseline, а не о победе одного transport над другим: `stealth-xray` выглядит сильнее как кандидат на `primary low-latency`, а `stealth-xhttp packet-up-safe` остаётся сильным кандидатом на `primary stealth/realtime-browsing` для более тяжёлых сетей.
- [2026-04-12 19:45:00] Архитектурный вывод тоже зафиксирован явно: эти профили не нужно «склеивать» в один hybrid transport. Правильная интеграция — один installer, один baseline, одна подписка и несколько отдельных узлов/ролей внутри продукта, чтобы каждый профиль можно было тюнить, проверять и переключать независимо.
- [2026-04-12 19:25:00] Переход к прямому сравнению transport-ролей уже подготовлен инфраструктурно: staging переведён на `stealth-xray` с `REALITY mobile-safe`, а полный server-side контур `install -> strict verify -> acceptance (1m/20s)` завершился полным `PASS`.
- [2026-04-12 19:25:00] Это значит, что текущий активный шаг внутри `Block C1` больше не про внутренний подбор XHTTP-presets. Теперь задача продуктовая: сравнить лучший `stealth-xhttp packet-up-safe` против `stealth-xray mobile-safe` и решить, какой профиль становится `primary stealth`, а какой `primary low-latency`.
- [2026-04-12 19:35:00] Дополнительный полевой тест `stealth-xhttp packet-up-safe` подтвердил, что профиль держит `Discord` voice в хорошем качестве, а значит улучшение по `packet-up` не куплено ценой деградации realtime-path.
- [2026-04-12 19:35:00] При этом `cold-start` класс проблемы остаётся: первый успешный ping всё ещё занимает около `6` секунд. Практический вывод теперь жёсткий: `packet-up-safe` — лучший текущий XHTTP-кандидат по совокупности `UI latency + browsing + calls`, но дальнейший выигрыш уже не гарантирован простым локальным тюнингом `XHTTP`.
- [2026-04-12 19:35:00] Следующий правильный шаг по Block C1 теперь смещается с внутренней гонки XHTTP-presets на сравнительный выбор ролей: зафиксировать `packet-up-safe` как ведущий `stealth-xhttp` preset и перейти к прямому сравнению лучшего `XHTTP`-профиля с `stealth-xray` для финальной схемы `primary low-latency` и `primary stealth`.
- [2026-04-12 19:20:00] Новый живой результат по `stealth-xhttp packet-up-safe` уже лучше предыдущих mode-slice'ов по user-facing UI-path: главная `YouTube` стала загружаться заметно приятнее, а `Instagram` работает стабильнее, чем на `stream-one-safe`.
- [2026-04-12 19:20:00] Это означает, что гипотеза про `XHTTP mode=packet-up` оказалась продуктивной: текущий выигрыш виден не только на server-side `PASS`, но и в живом browsing-поведении. Следующий шаг теперь не искать новый mode вслепую, а подтвердить, удерживается ли этот выигрыш вместе с `first ping` и realtime-calls.
- [2026-04-12 18:54:00] Новый preset `packet-up-safe` уже подтверждён на staging по полному server-side контуру: install, strict `verify` и `acceptance (1m/20s)` завершились полным `PASS` с transport tuning `reality=mobile-safe xhttp=packet-up-safe`.
- [2026-04-12 18:54:00] Значит, следующий шаг для `packet-up-safe` уже не инфраструктурный, а чисто полевой: сравнить его с `stream-one-safe` по `first ping`, `Instagram/YouTube` лентам, обычному browsing и `Telegram/Discord` calls, чтобы понять, даёт ли `packet-up` реальный выигрыш по `cold-start`.
- [2026-04-12 16:05:00] Новый живой результат по `stealth-xhttp stream-one-safe` подтвердил устойчивость текущего направления, но не снял сам класс `cold-start`: первый успешный ping по-прежнему может занимать около `6` секунд, хотя voice/video связь уже ощущается стабильной, а обычный browsing остаётся нормальным.
- [2026-04-12 16:05:00] Практический вывод из этого результата: очередное уменьшение batching/таймаутов больше не выглядит главным рычагом. Следующий controlled slice нужно вести не по keepalive, а по максимально совместимому `XHTTP mode`, сохраняя уже подтверждённую realtime-стабильность.
- [2026-04-12 16:12:00] Для этого в код добавлен новый opt-in preset `packet-up-safe`: он сохраняет консервативный batching, выключенный `XMUX` и безопасный `sockopt` как у `stream-one-safe`, но меняет только `XHTTP mode` на `packet-up`, чтобы проверить гипотезу о лучшем `cold-start` и более лёгком прохождении мелких запросов без потери текущей устойчивости.
- [2026-04-12 04:20:00] Новый полевой тест `stealth-xhttp realtime-safe` подтвердил рабочий компромисс: звонки, browsing и media-path в целом работают хорошо, но остаётся отдельный `cold-start / small-request latency` симптом. Первое установление соединения и первый успешный ping могут занимать около `5` секунд, после чего канал стабилизируется.
- [2026-04-12 04:20:00] Этот симптом проявляется не как слабый throughput, а как замедление мелких API/ленточных запросов: media-content (`Instagram` картинки/видео, `YouTube` видео) грузится хорошо, но сама лента/дозагрузка списков и часть мелких запросов ощущаются тяжелее именно на `XHTTP`.
- [2026-04-12 04:20:00] Практический вывод по `realtime-safe`: preset не провалился и подтверждает жизнеспособность `stealth-xhttp` как stealth/browsing/realtime-компромисса, но следующий controlled tuning уже должен быть направлен не на handoff и не на raw throughput, а на уменьшение `cold-start` и ускорение мелких HTTP/API запросов.
- [2026-04-12 04:28:00] Для этого следующего safe-slice в код добавлен отдельный opt-in preset `api-latency-safe`: он сохраняет `stream-up`, не включает `XMUX`, но сильнее снижает batching (`scMaxBufferedPosts=4`, `scMaxEachPostBytes=65536`) и ещё сокращает keepalive/user-timeout, чтобы проверить именно `first-request` и feed/API latency без смены общей stealth-модели.
- [2026-04-12 15:05:00] Новый preset `api-latency-safe` уже подтверждён на staging по server-side контуру: install, strict `verify` и `acceptance (1m/20s)` завершились полным `PASS`, поэтому следующий шаг для него уже не инфраструктурный, а чисто полевой сравнительный тест против `realtime-safe`.
- [2026-04-12 15:15:00] Так как `api-latency-safe` дал только небольшой полевой сдвиг, следующий controlled slice переведён на уровень transport mode: в код добавлен отдельный opt-in preset `stream-one-safe`, который сохраняет консервативный batching и выключенный `XMUX`, но меняет `XHTTP mode` с `stream-up` на `stream-one` для проверки гипотезы о более лёгком `cold-start` и лучшем поведении мелких запросов.
- [2026-04-12 15:17:00] Новый mode-slice `stream-one-safe` уже подтверждён на staging по server-side контуру: install, strict `verify` и `acceptance (1m/20s)` завершились полным `PASS`, поэтому следующий шаг для него — только живое сравнение с `api-latency-safe` и `realtime-safe`.
- [2026-04-12 01:25:00] В живом использовании выявлен новый отдельный сценарий нагрузки: `stealth-xhttp` хорошо держит browsing/video и быстрый `Wi-Fi <-> LTE` handoff, но видеозвонки `Discord` и `Telegram` через него пока ощущаются тяжёлыми по latency/uplink-поведению.
- [2026-04-12 01:25:00] Это не отменяет текущий успешный baseline `handoff-safe`, но уточняет роль следующего safe-slice: для `XHTTP` нужен отдельный controlled preset под realtime-трафик, а не попытка бесконечно ускорять browsing-профиль вслепую.
- [2026-04-12 01:25:00] Для этого в код добавлен opt-in preset `realtime-safe`: он фиксирует `XHTTP mode=stream-up`, оставляет `XMUX` выключенным и использует более короткий TCP keepalive/timeout-контур, чтобы проверить, можно ли улучшить `Discord/Telegram calls` без потери текущей скрытности и handoff-качества.
- [2026-04-12 01:25:00] Если `realtime-safe` не улучшит видеозвонки заметно, это будет считаться уже не tuning-gap, а ограничением самого `XHTTP/H2` профиля для realtime-сценариев; в таком случае `XHTTP` остаётся stealth/browsing-кандидатом, а основной low-latency/call-friendly профиль будет окончательно смещаться в сторону `stealth-xray` и будущего compatibility-класса.
- [2026-04-12 00:20:00] `stealth-xhttp handoff-safe` получил положительное полевое подтверждение: handoff между `Wi-Fi` и мобильной сетью восстановился до комфортного уровня `0-5` секунд, профиль работает на Android, ПК и Shadowrocket/iPhone.
- [2026-04-12 00:20:00] Текущий успешный baseline сохраняется без изменений; для следующей итерации скорости введён отдельный XHTTP preset `balanced-speed`. Он увеличивает XHTTP buffering/post-size умеренно, оставляет `XMUX` выключенным и сохраняет короткий keepalive-контур, чтобы не возвращать прежние длинные зависания при смене сети.
- [2026-04-12 00:20:00] Дополнительно расширен server-side TCP/sysctl слой: сохраняются `fq + bbr`, а также добавлены безопасные сетевые параметры очередей/backlog, `tcp_slow_start_after_idle=0` и `tcp_mtu_probing=1` для более стабильного восстановления и throughput без изменения клиентской сигнатуры XHTTP.
- [2026-04-11 21:05:00] По живому отчёту пользователя handoff оказался асимметричным: `Wi‑Fi -> LTE` восстанавливается нормально, а `LTE -> Wi‑Fi` может держать старую `XHTTP/H2` сессию 30-60 секунд. Для этого добавлен отдельный `handoff-safe` preset, а не очередная правка общего `low-latency`.
- [2026-04-11 21:05:00] `handoff-safe` сознательно отключает `XMUX` и использует короткие TCP keepalive/timeout значения, чтобы проверить гипотезу о слишком долгом удержании старого соединения при переходе с мобильной сети на Wi‑Fi.
- [2026-04-11 20:45:00] Для `stealth-xhttp` подтверждён ещё один product-gap в delivery-слое: даже после фикса `vnext` upstream `3x-ui` по-прежнему не отдавал в JSON-подписке client-side `streamSettings.sockopt`, из-за чего часть low-latency tuning фактически оставалась только на сервере.
- [2026-04-11 20:45:00] В актуальном rewrite-слое это закрыто: `subjson-rewrite` читает `x-ui.db`, извлекает transport-aware `sockopt` для `XHTTP` и добавляет его в клиентский JSON-контур, так что `v2rayNG/v2rayN` получает уже не урезанный, а синхронизированный outbound-профиль.
- [2026-04-11 20:45:00] Сам preset `stealth-xhttp low-latency` тоже смягчён под handoff: жёсткие `XMUX` overrides заменены на нулевые штатные значения, чтобы не удерживать одну H2-сессию слишком долго при смене сети `Wi‑Fi <-> LTE`.
- [2026-04-11 20:05:00] Для user-facing JSON-подписок подтверждён отдельный upstream-дефект `3x-ui`: `XRAY JSON Subscription` для `vless` отдавал невалидный outbound-контракт `settings.address/id/port` вместо `settings.vnext`, из-за чего клиенты вроде `v2rayNG` импортировали такие профили как сломанные `null:null`.
- [2026-04-11 20:05:00] В актуальном installer-контуре этот дефект закрыт без форка upstream-бинарника: рядом с `x-ui` теперь поднимается локальный `subjson-rewrite` bridge, а публичный JSON endpoint проксируется через него и отдаёт уже нормальные `vnext`-конфиги для `REALITY` и `XHTTP`.
- [2026-04-11 20:05:00] Staging-проверка на новой переустановке подтвердила новый контракт: strict `verify` видит активный `subjson-rewrite`, а `https://<domain>/<subJsonPath>/first` возвращает валидные `vless` JSON-конфиги, пригодные для повторного импорта в `v2rayNG/v2rayN`.
- [2026-04-11 19:40:00] Для `stealth-xhttp low-latency` теперь подтверждён ещё один transport-контракт: server-side inbound получает `xhttpSettings.xmux`, strict `verify` валидирует этот блок в `x-ui.db`, а loopback self-test использует тот же `xmux`, который уходит в клиентскую JSON-подписку.
- [2026-04-11 19:40:00] На staging это уже подтверждено повторной установкой: `xhttpSettings.xmux` присутствует и в `x-ui.db`, и в `https://<domain>/<subJsonPath>/first`, поэтому следующий handoff-тест можно проводить не вслепую, а на реально доставленном low-latency tuning-слое.
- [2026-04-11 19:40:00] Зафиксировано и эксплуатационное ограничение: direct URI/QR формат upstream `3x-ui` не переносит `xhttpSettings.xmux`, поэтому для сравнения `Wi‑Fi <-> LTE` в `stealth-xhttp low-latency` нужно использовать `XRAY JSON Subscription` или client route, который импортирует именно JSON-конфиг.
- [2026-04-11 19:35:00] Для subscription delivery подтверждён отдельный installer-регресс: JSON subscription route в `3x-ui` не включался, потому что форк записывал `subJsonPath`, но не записывал `subJsonEnable=true`; это исправлено в актуальном installer-контуре.
- [2026-04-11 19:35:00] Дополнительно нормализован контракт `subJsonURI`: он снова указывает на реальный JSON endpoint, а `verify` теперь валидирует этот путь отдельной локальной HTTPS-пробой и не пропускает silent `404/HTML` деградацию.
- [2026-04-11 18:25:00] Для `stealth-xhttp` подтверждён отдельный runtime-риск server-side compatibility: server-side `xPaddingBytes` не может быть уже фактического client-side default padding, иначе inbound начинает отвергать запросы ещё до полноценного proxy traffic.
- [2026-04-11 18:25:00] На staging это уже локализовано через controlled self-test: минимальный официальный `XHTTP + nginx + grpc_pass` работает, а `x-ui`-generated inbound ломался именно на узком диапазоне `xPaddingBytes`; после возврата к `100-1000` контракт снова становится совместимым.

- [2026-04-08 04:30:47] Текущий стабильный baseline проекта — это `classic` install-контур в ветке `main`.
- [2026-04-08 04:30:47] Официальный install-source репозитория на текущий момент — `main`.
- [2026-04-08 04:30:47] Основной поддерживаемый installer-контур сосредоточен в `x-ui-pro-updated.sh`.
- [2026-04-08 04:30:47] `x-ui-pro.sh` является совместимым wrapper-entrypoint и не содержит отдельного поддерживаемого installer-тела.
- [2026-04-08 04:30:47] `x-ui-pro-old.sh` не входит в поддерживаемый контур и заблокирован как архивный legacy-файл.

## Подтверждённая архитектура текущего контура

- [2026-04-08 04:30:47] Проект обслуживает два домена: основной домен для панели, web-sub и связанных web-сервисов, а также отдельный домен для `REALITY`.
- [2026-04-08 04:30:47] Базовый входной слой — `nginx`, который маршрутизирует трафик между web-частью и `xray`-контуром.
- [2026-04-08 04:30:47] Панель и транспортный слой работают на `3x-ui` / `xray`.
- [2026-04-08 04:30:47] Основная база панели — SQLite по пути `/etc/x-ui/x-ui.db`.
- [2026-04-08 04:30:47] `sub2sing-box` работает как локальный `systemd`-сервис и обслуживает конвертацию подписок.
- [2026-04-08 04:30:47] Web-sub bundle обслуживается локально из `/var/www/subpage`.
- [2026-04-08 04:30:47] Основные статические зависимости форка уже локализованы в `vendor/`.
- [2026-04-08 04:30:47] Для основного `amd64`-сценария release-архивы `3x-ui` и `sub2sing-box` уже локально зеркалированы в `vendor/releases/` и проверяются по `SHA256SUMS`.

## Что уже подтверждено тестами

- [2026-04-08 04:30:47] На staging подтверждён полный маршрут `reset -> install -> verify -> websub`.
- [2026-04-08 04:30:47] На staging подтверждён полный operational regression `backup -> uninstall -> restore -> verify`.
- [2026-04-08 04:30:47] На staging подтверждён clean install success-path через `x-ui-pro.sh`.
- [2026-04-08 04:30:47] На staging подтверждён repeated install success-path поверх уже работающей ноды.
- [2026-04-08 04:30:47] На полностью отформатированном сервере повторно подтверждён рабочий `REALITY`-контур с валидным `publicKey` в `x-ui.db`.
- [2026-04-08 04:30:47] На clean staging-install подтверждено использование локальных mirrored release-архивов из `vendor/releases/`.

## Что уже нормализовано в проекте

- [2026-04-08 04:30:47] Документация и рабочий процесс переведены на русский язык с сохранением английских технических терминов там, где это необходимо.
- [2026-04-10 22:10:47] Для документации введён единый операционный порядок `DOCS_WORKFLOW.md`: ежедневный минимальный набор, порядок фиксации контекста и требования к синхронизации branch-html.
- [2026-04-10 22:48:10] Технологический план усиления протоколов формализован в `PROTOCOL_HARDENING_PLAN.md`: зафиксированы `REALITY/XHTTP/AWG`, auth hardening, ограничения `RST`-защиты и phased rollout.
- [2026-04-10 23:09:41] Итоговая идея доработанного форка формализована в `PLATFORM_VISION_PLAN.md`: multi-transport платформа, staged rollout, threat model, mobile whitelist backlog и критерии успеха.
- [2026-04-10 23:30:48] Visual docs-слой `docs/branch-html/` пересобран в подробный русскоязычный формат и теперь обновляется через `render-branch-html.ps1`.
- [2026-04-11 00:05:00] По текущему полевому тесту появился первый позитивный результат по смене сети: тестовый контур `platform-v2` продолжает работать при ручном переключении `Wi‑Fi <-> mobile`, а базовый browsing/video трафик остаётся доступным вне окна `mobile whitelist`.
- [2026-04-11 10:28:01] Для платформы формально зафиксирован стабильный клиентский контракт: улучшения transport/fallback слоя должны по возможности укладываться в обычный `subscription refresh`, а не в постоянные полные re-import/ручную перенастройку устройств.
- [2026-04-11 10:28:01] Транспортные решения текущего этапа тоже формализованы: активное anti-DPI ядро проекта ограничено `stealth-xray` и `stealth-xhttp`, compatibility-layer отделён от главной stealth-стратегии, а `ICMP` исключён из roadmap как нецелевой transport для `VLESS + REALITY`.
- [2026-04-12 00:55:00] Следующий слой transport-портфеля зафиксирован как отдельный compatibility/fallback-класс, а не как немедленное расширение anti-DPI ядра: после стабилизации `stealth-xray` и `stealth-xhttp` в работу возвращаются `Trojan gRPC`, `WS TLS` и другие legacy-пути только как отдельные профили совместимости.
- [2026-04-12 00:55:00] Будущий unified baseline проекта должен собираться не как «зоопарк протоколов», а как curated-набор подтверждённых профилей: `primary low-latency`, `primary stealth`, `compatibility fallback`. Каждый новый transport обязан пройти тот же стандарт `install -> verify -> acceptance -> backup/restore -> subscription/import -> field test`.
- [2026-04-11 14:40:00] Controlled tuning перестал быть только design-слоем: `x-ui-pro-updated.sh` уже поддерживает preset overrides для `REALITY` и `XHTTP`, а comparative acceptance фиксирует runtime snapshot и redacted inbound summary для последующего triage.
- [2026-04-11 15:20:00] Runtime provenance теперь закреплён как persistent sidecar в `/etc/x-ui/runtime-provenance.env`: install/verify/acceptance/backup/restore больше не обязаны угадывать `platform/transport/tuning` только по косвенным признакам `x-ui.db` и nginx.
- [2026-04-11 16:05:00] Comparative acceptance усилен до структурированной acceptance-матрицы: `stage=acceptance` принимает полевые метки `label/group/network/operator/time_window/client/notes`, пишет `matrix-row.json` и `probe-results.jsonl`, а значит следующий live-triage `stealth-xray` vs `stealth-xhttp` можно вести по одному каноническому формату.
- [2026-04-08 04:30:47] Рабочий цикл стандартизован как `Windows -> GitHub -> Linux staging`.
- [2026-04-08 04:30:47] После каждого завершённого этапа требуется отдельный `commit + push`.
- [2026-04-08 04:30:47] Для проекта уже существует формальный staging regression-checklist.
- [2026-04-08 04:30:47] Основная масса repo-owned web-ассетов и frontend-зависимостей локализована внутри форка.
- [2026-04-10 20:07:20] Продуктовый контекст «устойчивая связь и рабочие ресурсы под DPI» формализован в отдельном каноническом документе `PROJECT_CONNECTIVITY_REQUIREMENTS.md`.

## Что остаётся внешним на текущем этапе

- [2026-04-08 04:30:47] `Let's Encrypt` для выпуска сертификатов.
- [2026-04-08 04:30:47] `ipwho.is`, `ipv4.icanhazip.com`, `ipv6.icanhazip.com` для определения сетевого окружения.
- [2026-04-08 04:30:47] Upstream fallback для неотзеркалированных комбинаций версии и архитектуры `3x-ui` / `sub2sing-box`.
- [2026-04-08 04:30:47] Часть user-facing ссылок уровня GitHub / App Store / Google Play, которые пока сознательно не зеркалируются.

## Что уже решено архитектурно, но ещё не реализовано кодом

- [2026-04-08 04:30:47] Следующий крупный этап развивается как платформенное расширение, а не как хаотичный набор патчей к одному installer-скрипту.
- [2026-04-08 04:30:47] Новый `stealth`-профиль будет развиваться отдельно от текущего `classic` baseline.
- [2026-04-08 04:30:47] `AmneziaWG` рассматривается как отдельный `optional` модуль, а не как принудительная часть baseline.
- [2026-04-08 04:30:47] Каноническим design-doc следующего этапа является `PLATFORM_BLUEPRINT.md`.
- [2026-04-08 22:29:01] Переход к `AWG` отложен до формального завершения текущего `Xray/DPI` hardening-этапа.
- [2026-04-08 22:29:01] Идеи по ускорениям и performance-оптимизации зафиксированы как отдельный будущий backlog-блок и не должны смешиваться с текущим transport/security-этапом.

## Что уже подготовлено для platform-v2

- [2026-04-08 05:09:48] В `codex/platform-v2` уже введён минимальный модульный каркас `core / modules / providers` без изменения поведения текущего `classic`.
- [2026-04-08 05:09:48] `x-ui-pro-updated.sh` уже знает о platform-v2 selection-переменных `PLATFORM_PROFILE`, `TRANSPORT_PROFILE`, `PANEL_PROVIDER`, `ENABLE_AWG`, но пока принимает только baseline-комбинацию.
- [2026-04-08 05:09:48] Новый слой не делает проект зависимым от локальной структуры репозитория: при отсутствии metadata-файлов installer использует встроенные дефолты и остаётся совместим с одиночным запуском.
- [2026-04-08 05:09:48] Реального переключения логики `classic -> stealth` или `classic -> AWG` ещё нет; текущий срез является именно безопасной подготовкой к дальнейшей модульной реализации.
- [2026-04-08 05:34:52] Внутренние orchestration-решения installer уже частично переведены на selection-layer: ingress, panel provider и transport profile вызываются через dispatcher-обёртки, а не напрямую из `main()`.
- [2026-04-08 05:34:52] Provider metadata теперь уже влияет на runtime-output и service/control слой `classic`, но при этом сама функциональная логика `classic` не изменена.
- [2026-04-08 05:58:05] Runtime-defaults и boundary-значения `classic` теперь тоже частично подняты в selection-layer: длины токенов и учётных данных, политика генерации динамических портов, публичные порты `80/443`, внутренние порты `7443/8443/9443` и локальный порт `sub2sing-box`.
- [2026-04-08 05:58:05] При этом install-result baseline по-прежнему не менялся: те же значения используются механически через helper-функции, а не через новые transport/provider-ветви выполнения.
- [2026-04-08 06:09:36] Provider metadata `3x-ui` теперь покрывает не только service/control-идентичность, но и panel-defaults из блока `settings`: baseline-дефолты панели больше не размазаны между provider-файлом и SQL-литералами.
- [2026-04-08 06:09:36] При этом transport/runtime часть baseline по-прежнему не менялась: в `codex/platform-v2` пока выносились только orchestration, runtime-defaults, boundary-константы и panel-provider defaults.
- [2026-04-08 06:21:05] Bootstrap-дефолты панели теперь тоже подняты в provider metadata: минимальная версия `3x-ui` и временные bootstrap-значения для первичной инициализации панели больше не зашиты в install-flow как голые литералы.
- [2026-04-08 06:21:05] Это означает, что baseline `classic` уже почти полностью подготовлен к открытию первого нового runtime-профиля: transport/runtime и panel/provider слои разделены заметно чище, чем в исходном монолитном installer'е.
- [2026-04-08 06:32:49] Первый `stealth-xray`-срез уже открыт в коде как staged-profile: metadata, валидация selection-комбинаций, runtime-state и dry-run diagnostics уже существуют, но реальный install-path ещё не активирован.
- [2026-04-08 06:32:49] Текущее состояние `platform-v2` теперь такое: `classic` остаётся `ready`, а `stealth` уже не гипотеза в docs, а реальный профиль в selection-layer со статусом `planned`.
- [2026-04-08 06:44:51] Следующий безопасный срез тоже уже выполнен: `nginx` ingress разделён на `classic` и `stealth` seam через отдельные функции `setup_nginx_classic/setup_nginx_stealth` и `enable_nginx_sites_classic/enable_nginx_sites_stealth`.
- [2026-04-08 06:44:51] При этом граница изменений удержана жёстко: `update_xui_db()`, `verify_existing_installation()` и runtime-контракт `stealth-xray` не менялись; transport для `stealth` всё ещё блокируется как `not enabled`.
- [2026-04-08 06:44:51] Это означает, что `platform-v2` теперь уже умеет маршрутизировать ingress по profile-layer, но реальный runnable-режим `stealth` пока ещё не открыт и остаётся следующим отдельным срезом.
- [2026-04-08 07:04:32] Следующий transport/runtime seam тоже уже реализован: `update_xui_db()` разделён на provider settings helper и два transport helper'а, а `stealth-xray` получил собственный `REALITY`-контракт вместо необходимости параметризовать giant SQL прямо в orchestrator.
- [2026-04-08 07:04:32] Для transport metadata теперь явно различаются `REALITY`-инварианты `classic` и `stealth`: `8443/0/acceptProxyProtocol=true/domain` против `443/1/acceptProxyProtocol=false/reality_domain`.
- [2026-04-08 07:04:32] При этом `stealth` всё ещё сознательно не переведён в `ready`: install-runtime остаётся staged до отдельного шага, в котором `verify_existing_installation()` и `load_existing_runtime_context()` станут profile-aware.
- [2026-04-08 07:11:12] Этот следующий шаг уже тоже закрыт: `load_existing_runtime_context()` теперь обогащает baseline-контекст значением `reality_domain`, а `verify_existing_installation()` различает строгий runnable `classic` и staged-профили, для которых public-HTTPS пробы пока пропускаются без ложного `FAIL`.
- [2026-04-08 21:18:12] Следующий safe-slice тоже уже закрыт: `stealth` и `stealth-xray` переведены в `ready`, поэтому selection-layer больше не считает этот профиль purely staged и допускает реальный install-path.
- [2026-04-08 21:18:12] При этом runtime-граница удержана осознанно: public-HTTPS verify по-прежнему считается strict только для `classic`, а `stealth` остаётся runnable без преждевременного ложного `FAIL` до отдельного Linux staging-regression.
- [2026-04-08 21:34:41] Следующий Linux runtime-этап тоже уже закрыт: после нормализации `LF` для metadata `.env` на staging подтверждён реальный clean install профиля `stealth/stealth-xray`, отдельный `-stage verify` и ручные HTTPS-пробы через публичный `443`.
- [2026-04-08 21:34:41] Практически подтверждённый stealth-контур сейчас выглядит так: `xray` слушает публичный `443`, `nginx` слушает `7443`, `sub2sing-box` остаётся на `127.0.0.1:8080`, а panel/web-sub/sub2sing-box и fallback root реально отвечают через `443` на домене `185.207.64.40.sslip.io`.
- [2026-04-08 21:58:42] Следующий шаг зрелости для `stealth` тоже уже закрыт: профиль больше не требует ручных допроверок как обязательной части regression-маршрута, потому что strict verify теперь знает его реальные runtime-инварианты.
- [2026-04-08 21:58:42] Текущий stealth-baseline считается подтверждённым уже в двух слоях: install/runtime smoke-test и повторный `-stage verify` после установки.
- [2026-04-08 22:29:01] Это означает, что `platform-v2` уже имеет подтверждённый stealth-baseline, но текущий продуктовый этап считается закрытым не автоматически, а только после формального завершения всего `Xray/DPI` слоя.
- [2026-04-08 22:29:01] Для этого введён отдельный фазовый документ `XRAY_DPI_PLAN.md`, который становится каноническим планом текущего подэтапа поверх общего `PLATFORM_BLUEPRINT.md`.
- [2026-04-08 22:29:01] Идеи по ускорению системы не потеряны: они сознательно вынесены за пределы текущего `Xray/DPI` этапа и должны быть рассмотрены отдельным блоком после его закрытия.
- [2026-04-08 23:00:27] На staging `185.207.64.40` `stealth/stealth-xray` теперь подтверждён не только как runnable install-path, но и как полноценный эксплуатационный baseline: пройдены `install`, `verify`, `websub`, `backup`, `uninstall`, `restore`, `reset`, повторный `install` и финальный `verify`.
- [2026-04-08 23:00:27] Для этого были внесены минимальные точечные правки в profile-aware cleanup/reset/restore: managed stack ports, корректная очистка `stream-enabled/stream.conf` и stealth-aware restore diagnostics.
- [2026-04-08 23:00:27] Следующий активный продуктовый шаг внутри `Xray/DPI` этапа теперь смещается с доведения baseline на открытие второго stealth transport.
- [2026-04-08 23:24:11] Этот шаг уже частично закрыт: в `codex/platform-v2` открыт второй runnable stealth transport `stealth-xhttp` с тем же ingress-контуром `xray:443 -> nginx:7443`, но с отдельным `xhttp` inbound на `unix:/dev/shm/uds2023.sock,0666`.
- [2026-04-08 23:24:11] На staging `185.207.64.40` новый профиль подтверждён реальной установкой и строгим `-stage verify`, включая transport-specific проверки `xhttp` inbound, публикации `xhttp` path в nginx fallback и наличия unix socket.
- [2026-04-08 23:24:11] Autodetect runtime-контекста тоже уже работает для этого профиля: повторный `-stage verify` без явной передачи `PLATFORM_PROFILE/TRANSPORT_PROFILE` сам восстанавливает `stealth-xhttp` из `x-ui.db`.
- [2026-04-08 23:24:11] Это означает, что у `platform-v2` теперь уже есть два runnable stealth transport-пути: `stealth-xray` и `stealth-xhttp`; следующий шаг смещается с открытия transport-а на сбор anti-DPI матрицы приёмки и user-facing проверок.
- [2026-04-09 00:15:49] Этот следующий шаг уже тоже формализован: создан отдельный канонический документ `ANTI_DPI_MATRIX.md`, который фиксирует подтверждённые transport-профили, практические сценарии выбора и обязательные проверки блока C.
- [2026-04-09 00:15:49] На текущий момент server-side часть блока C уже описана и частично закрыта, но user-facing и long-running сравнение `stealth-xray` против `stealth-xhttp` ещё остаётся следующим прикладным шагом.
- [2026-04-09 00:30:57] Для следующего шага уже появился реальный operational helper: `-stage acceptance` в `x-ui-pro-updated.sh`.
- [2026-04-09 00:30:57] На staging `185.207.64.40` этот helper уже прогнан для `stealth-xhttp` и `stealth-xray` в коротком server-side soak режиме `1 minute / 10 seconds`, и оба профиля прошли все 6 циклов probes без ошибок.
- [2026-04-09 00:30:57] Это означает, что server-side сравнительный слой блока C уже воспроизводим кодом; незакрытой остаётся именно живая клиентская приёмка и длинные сессии, а не отсутствие инструмента сравнения.
- [2026-04-09 01:10:14] Первый клиентский результат по блоку C уже получен: `stealth-xray` выдержал около 10 минут реальной нагрузки `4K`-видео и параллельного браузерного трафика через `v2rayN` без замеченных проблем.
- [2026-04-09 01:32:44] Симметричный клиентский шаг тоже уже закрыт: `stealth-xhttp` выдержал около 10 минут реальной нагрузки `4K`-видео и параллельного браузерного трафика через `v2rayN` без замеченных проблем.
- [2026-04-09 01:32:44] Следующий практический шаг смещается с коротких client-load тестов на длинные сессии `30-60` минут и reconnect-проверки для обоих stealth-профилей.
- [2026-04-09 20:50:25] Новый полевой отчёт показал, что коротких client-load тестов недостаточно: старые reality-схемы на mobile internet не подтверждены как рабочие, а `stealth-xhttp` хотя и проходит короткую нагрузку, но деградирует в длительном дневном использовании.
- [2026-04-09 20:50:25] Это означает, что текущий продуктовый фокус по-прежнему остаётся на блоке C `Xray/DPI` этапа: расследование mobile-data нестабильности, long-running приёмка и финальный выбор основного stealth-профиля.
- [2026-04-10 00:34:06] Первый кодовый шаг этого расследования уже выполнен безопасно: `xhttp`-tuning и ключевые `sockopt` для `classic-xray` и `stealth-xhttp` вынесены в metadata/selection-layer без изменения текущих значений по умолчанию.
- [2026-04-10 00:34:06] Благодаря этому следующий tuning-этап можно вести как controlled preset work, а не как ручную правку giant SQL-блоков в installer.
- [2026-04-10 08:06:43] Следующий безопасный шаг тоже уже выполнен: metadata-driven слой подготовлен и для `REALITY` в `stealth-xray`/`reality-shield`, а acceptance-контур теперь собирает более полезные diagnostics для mobile-data triage.
- [2026-04-10 08:06:43] Это означает, что текущий блок C уже имеет не только profile-selection и server-side soak, но и управляемый слой transport tuning/observability для обоих stealth-путей.
- [2026-04-10 08:10:51] Первый реальный tuning-шаг тоже уже сделан: `stealth-xhttp` переведён на `mobile-safe` preset, который уменьшает burstiness и убирает наиболее агрессивные socket-настройки, сохраняя тот же ingress/runtime-контур.
- [2026-04-10 08:14:46] Этот preset уже не только в коде, но и на staging runtime: repeated install подтверждён, strict `verify` проходит, а `x-ui.db` содержит обновлённые `xhttpSettings/sockopt` значения.
- [2026-04-10 19:41:17] После провайдерного инцидента старый staging заменён на новый сервер `217.199.253.102`; на нём заново подтверждён runnable-контур `stealth/stealth-xhttp` через install, strict `verify` и `acceptance` (`5m/30s`) с полным `PASS`.
- [2026-04-10 19:41:17] В `codex/platform-v2` включён controlled `mobile-safe` preset для `REALITY` слоя stealth-контуров: `stealth-xray` и `stealth-xhttp` теперь используют `TRANSPORT_REALITY_TUNING_PROFILE=mobile-safe` и стабильный fingerprint `chrome`.

## Текущие риски блока C

- [2026-04-09 20:50:25] `REALITY`-контуры пока не подтверждены как устойчивые на мобильной сети пользователя; старый сервер и старый скриптовый контур на mobile internet фактически считаются нестабильными.
- [2026-04-09 20:50:25] `stealth-xhttp` нельзя считать безусловно принятым по короткому тесту: он даёт лучший результат, чем старые reality-схемы, но пока показывает деградацию при длительном дневном использовании.
- [2026-04-09 20:50:25] До завершения long-running/mobile-data triage финальная рекомендация выбора между `stealth-xray` и `stealth-xhttp` отсутствует, а значит этап `Xray/DPI` ещё не закрыт.
- [2026-04-10 22:10:47] Добавлен обязательный подэтап `Block C1`: short-test больше не считается достаточным, если не подтверждены одновременно невидимость для DPI, long-running устойчивость и reconnect-поведение на мобильной сети.
- [2026-04-10 22:48:10] Для `Block C1` теперь есть отдельный технологический контракт: `PROTOCOL_HARDENING_PLAN.md` фиксирует, что `RST` считается симптомом детекта/drop-воздействия, а не отдельной магической firewall-задачей.
- [2026-04-10 22:53:58] В риск-модель `Block C1` добавлен `single-IP co-tenancy`: смешивание дефолтного `AWG` и `Xray` на одном IP может ухудшать общий fingerprint сервера и вызывать деградацию всего IP.
- [2026-04-10 23:05:05] В риск-модель добавлен `mobile whitelist / IP-level drop`: если мобильная сеть не пропускает прямой VPS IP, transport tuning не является достаточным решением и требуется отдельный fallback-класс.

## Ближайшая точка продолжения

- [2026-04-12 04:20:00] Следующая ближайшая задача: не трогая успешный `realtime-safe`, подготовить отдельный speed/latency safe-slice именно под `cold-start` и мелкие API-запросы `XHTTP`, затем сравнить его с текущим preset по сценариям `first ping`, `Instagram feed`, `YouTube thumbnails/feed`, обычный web и звонки.
- [2026-04-12 04:28:00] Следующая ближайшая задача уточнена: выложить `stealth-xhttp + XHTTP_TUNING_PROFILE=api-latency-safe` на staging, прогнать `verify/acceptance` и затем отдельно сравнить его с `realtime-safe` по `first ping`, `Instagram feed`, `YouTube UI/feed`, обычному browsing и `Telegram calls`.
- [2026-04-12 15:15:00] Следующая ближайшая задача уточнена ещё раз: выложить `stealth-xhttp + XHTTP_TUNING_PROFILE=stream-one-safe` на staging, прогнать `verify/acceptance` и затем сравнить его с `api-latency-safe` и `realtime-safe` по `first ping`, `Instagram feed`, `YouTube UI/feed`, обычному browsing и `Telegram calls`.
- [2026-04-12 01:25:00] Следующая ближайшая задача: выложить `stealth-xhttp + XHTTP_TUNING_PROFILE=realtime-safe` на staging, прогнать `verify/acceptance`, затем отдельно сравнить `Discord/Telegram calls`, обычный browsing, `Wi-Fi <-> LTE` handoff и повторяемость результата против `handoff-safe`.
- [2026-04-10 23:05:05] Текущая ближайшая задача: идти по `PROTOCOL_HARDENING_PLAN.md`, закрыть `Block C1`, различать ordinary DPI / co-tenancy / mobile whitelist и затем зафиксировать production-рекомендацию в формате «основной stealth-профиль + DPI fallback + mobile whitelist fallback».

## Где смотреть детали

- [2026-04-08 04:30:47] Подробная история отличий от upstream и уже выполненных багфиксов — `FORK_PASSPORT.md`.
- [2026-04-08 04:30:47] Подробная архитектура текущего baseline и технические ограничения — `AI_CONTEXT.md`.
- [2026-04-08 04:30:47] Подробная детализация того, что уже работает и как это проверялось — `IMPLEMENTED.md`.
- [2026-04-08 04:30:47] Подробная инфраструктурная и сервисная схема — `SERVICES_PLAN.md`.
- [2026-04-11 17:50:00] Новое расследование `stealth-xhttp` на зарубежной ноде показало системный дефект в старом acceptance-мысленном контракте: `verify` подтверждал наличие `xhttp` inbound/socket/path, но не выполнял реальную transport-пробу, поэтому прежние `PASS` не гарантировали работоспособный `XHTTP`.
- [2026-04-11 17:50:00] В коде уже зафиксирован следующий безопасный corrective step: `stealth-xhttp` переведён на `mode=auto`, `nginx`-location усилен под официальный `H2/grpc_pass` контракт, а `verify` теперь запускает активный loopback self-test.
