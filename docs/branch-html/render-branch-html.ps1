$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$Utf8Bom = [System.Text.UTF8Encoding]::new($true)

function Write-Report {
  param([string]$Name, [string]$Html)
  $Normalized = (($Html -split "`r?`n") | ForEach-Object { $_.TrimEnd() }) -join "`n"
  [System.IO.File]::WriteAllText((Join-Path $Root $Name), "$Normalized`n", $Utf8Bom)
}

function Bullets {
  param([string[]]$Items)
  if (-not $Items -or $Items.Count -eq 0) {
    return '<p class="muted">Отдельных пунктов пока нет.</p>'
  }

  $Lines = $Items | ForEach-Object { "          <li>$_</li>" }
  return "<ul>`n$($Lines -join "`n")`n        </ul>"
}

function Steps {
  param([string[]]$Items)
  if (-not $Items -or $Items.Count -eq 0) {
    return '<p class="muted">Отдельных пунктов пока нет.</p>'
  }

  $Lines = $Items | ForEach-Object { "        <div class=""step"">$_</div>" }
  return $Lines -join "`n"
}

$Branches = @(
  @{
    Slug='main'; Branch='main'; Status='АКТИВНАЯ / STABLE'; Tag='active';
    Summary='Стабильная ветка и основной install-source для подтверждённого classic-контура.';
    Install='Да. Это основной источник для стабильной установки после regression-проверок.';
    Role='Поддержка production-ready baseline: установка, панель, web-sub, backup, restore и безопасные обновления.';
    Profile='Classic Xray-профиль текущего форка: проверенные подключения, TLS/REALITY-контур, панель и служебная маршрутизация.';
    Done=@('Адаптирован install-flow под наш репозиторий.', 'Проверены install, verify, web-sub, backup, uninstall и restore.', 'README и операционные документы очищены от чужого fork-контекста.', 'Ветка закреплена как стабильная точка без сырых экспериментов.');
    Now=@('Только сопровождение и точечные исправления после regression.', 'Приём изменений из platform-v2 только после тестов и отдельного решения.');
    Next=@('Переносить только проверенные функции из platform-v2.', 'Сохранять ветку понятным install-source.', 'Перед merge требовать regression и rollback-проверку.');
    Risks=@('Нельзя превращать stable в полигон anti-DPI гипотез.', 'Сырой перенос новых профилей может сломать рабочую установку.');
    Tests=@('Чистая установка на свежем сервере.', 'Проверка панели, подписок, сертификатов, web-sub и служб.', 'Backup/uninstall/restore без ручного восстановления.', 'Smoke-тест клиентских подключений.');
    Stop=@('Не внедрять экспериментальный stealth/AWG-код напрямую.', 'Не публиковать приватные данные, учётки, тестовые домены и личный контекст.');
  },
  @{
    Slug='codex-platform-v2'; Branch='codex/platform-v2'; Status='АКТИВНАЯ IMPLEMENTATION-ВЕТКА'; Tag='active';
    Summary='Главная рабочая ветка нового платформенного слоя: anti-DPI hardening, профили, fallback и будущая модульность.';
    Install='Да, но только как тестовый контур. Это не замена main до закрытия Block C1 и regression.';
    Role='Разработка модульной платформы с выбором профилей: classic, stealth-xray, stealth-xhttp, будущий stealth-multi и будущий hardened-awg.';
    Profile='REALITY/Vision для скорости, REALITY/XHTTP для снижения сигнатурности, подготовка нескольких проверенных fallback-путей.';
    Done=@('Добавлен selection-layer для выбора профилей без ломки classic-поведения.', 'Добавлен acceptance stage: установка должна пройти проверку готовности.', 'Зафиксированы mobile-safe tuning и отдельные профили stealth-xray / stealth-xhttp.', 'Заведены документы по DPI, RST/drop, single-IP co-tenancy и mobile whitelist fallback.', 'Сформирована стратегия: несколько управляемых маршрутов вместо одного “магического” протокола.');
    Now=@('Block C1: сравнить stealth-xray и stealth-xhttp по стабильности, скорости, reconnect и мобильной сети.', 'Разделить причины сбоев: DPI-сигнатура, active probing, IP/ASN-блок, mobile whitelist, совместное размещение Xray+AWG.', 'Собрать production-рекомендацию: основной профиль, DPI fallback и мобильный fallback-класс.');
    Next=@('Закрыть Block C1 и выбрать порядок включения профилей.', 'Собрать stealth-multi только из проверенных transport-путей.', 'Усилить admin/subscription-контур: панель, секреты, публикация подписок, rollback.', 'Подготовить hardened-awg как opt-in модуль.', 'Позже исследовать white IP/cloud allowlist: Yandex Cloud, VK Cloud, специальные подсети.');
    Risks=@('Абсолютной невидимости не обещаем: цель - снижать сигнатурность и быстро переключаться при деградации.', 'AWG и Xray на одном IP могут давать корреляционный риск.', 'Mobile whitelist может блокировать IP/ASN, а не конкретный протокол.', 'Слишком агрессивная обфускация может ухудшить скорость.');
    Tests=@('Install на чистом staging-сервере.', 'Проверка x-ui, nginx, сертификатов, inbound JSON и service health.', 'Клиентские тесты V2RayN / v2rayNG: Wi-Fi, LTE, reconnect, смена сети.', 'Нагрузочный smoke: несколько 4K-потоков, web, мессенджеры, долгий тест 30-60 минут.', 'Сравнение логов: closed pipe, read/write, TLS/REALITY errors, nginx/x-ui restarts.');
    Stop=@('Не сливать platform-v2 в main без regression.', 'Не добавлять протоколы без проверяемого выигрыша.', 'Не хранить в GitHub личные заметки, пароли, реальные тестовые домены.', 'Не включать AWG по умолчанию до hardening-реализации.');
  },
  @{
    Slug='codex-staging-reset-workflow'; Branch='codex/staging-reset-workflow'; Status='ИСТОРИЧЕСКАЯ'; Tag='frozen';
    Summary='Закрытая историческая ветка, где отрабатывался безопасный reset/staging workflow.';
    Install='Нет. Для установки использовать main или тестовую implementation-ветку.';
    Role='История безопасной работы со staging, восстановлением и проверками перед regression.';
    Profile='Transport-изменения не являются целью ветки.';
    Done=@('Сценарий staging/reset зафиксирован и перенесён в общий процесс.', 'Исторический контекст сохранён для аудита.', 'Ветка признана нерабочей для новой реализации.');
    Now=@('Новых задач нет.');
    Next=@('Использовать только как ссылку на историю workflow.');
    Risks=@('Новые правки создадут путаницу с platform-v2.', 'Установка из этой ветки не поддерживается.');
    Tests=@('Новые тесты не требуются.', 'Исторический код поднимается только как отдельный ad-hoc анализ.');
    Stop=@('Не использовать как install-source.', 'Не переносить новые platform-функции сюда.');
  },
  @{
    Slug='codex-operational-regression'; Branch='codex/operational-regression'; Status='ИСТОРИЧЕСКАЯ'; Tag='frozen';
    Summary='Историческая ветка regression-этапа: установка, operational verify, backup/restore и uninstall.';
    Install='Нет как основной путь. Её результаты уже должны жить в stable/рабочих ветках.';
    Role='Справочник по operational regression и проверке жизненного цикла сервера.';
    Profile='Основной фокус - надёжность операций, а не новые transport-профили.';
    Done=@('Отработаны проверки установки и состояния служб.', 'Зафиксирована необходимость проверять backup/uninstall/restore.', 'Regression-подход перенесён в общий workflow проекта.');
    Now=@('Новых implementation-задач нет.');
    Next=@('Использовать подход ветки как шаблон для будущих regression-блоков.');
    Risks=@('Нельзя считать ветку актуальнее main/platform-v2.', 'Исторические команды могут не соответствовать текущей архитектуре.');
    Tests=@('Сама ветка не тестируется как активная.', 'Regression-чеклист используется в main и platform-v2.');
    Stop=@('Не устанавливать как production.', 'Не продолжать разработку внутри исторической ветки.');
  },
  @{
    Slug='codex-legacy-audit'; Branch='codex/legacy-audit'; Status='ПЕРЕХОДНАЯ ИСТОРИЧЕСКАЯ'; Tag='frozen';
    Summary='Ветка аудита старого состояния: что было в исходном форке и какие выводы были сделаны.';
    Install='Нет. Это не install-source.';
    Role='Legacy audit, фиксация различий старого форка и нашей будущей структуры.';
    Profile='Не является transport-веткой.';
    Done=@('Сохранены уникальные подготовительные коммиты.', 'Зафиксирована история старого форка и причины реорганизации.', 'Определено, что новая большая разработка идёт в platform-v2.');
    Now=@('Новых задач нет.');
    Next=@('Переносить только идеи, а не продолжать ветку как рабочую.');
    Risks=@('Можно ошибочно принять legacy-аудит за актуальное состояние проекта.', 'Новые изменения усложнят историю веток.');
    Tests=@('Тестирование не требуется.', 'Содержимое используется как справочный материал.');
    Stop=@('Не использовать для установки.', 'Не добавлять новые anti-DPI или AWG изменения.');
  },
  @{
    Slug='codex-stealth-awg-architecture'; Branch='codex/stealth-awg-architecture'; Status='АРХИТЕКТУРНЫЙ ИСТОЧНИК / FROZEN'; Tag='frozen';
    Summary='Замороженный design-source по будущему AWG-модулю и общей модульной архитектуре.';
    Install='Нет. Это не рабочая install-ветка.';
    Role='Архитектурный источник для будущего hardened-awg и модульных сервисов.';
    Profile='AWG рассматривается как будущий opt-in модуль с отдельной приёмкой.';
    Done=@('Зафиксирована идея модульности и будущего AWG-контура.', 'Design-контекст отделён от implementation-кода.', 'Определено, что AWG нельзя включать без hardening и оценки single-IP риска.');
    Now=@('Новых кодовых задач в этой ветке нет.');
    Next=@('Перенести проверенные идеи в platform-v2 на этапе hardened-awg.', 'Сначала закрыть Xray/DPI Block C1.');
    Risks=@('Обычный AWG-контейнер может иметь узнаваемые паттерны.', 'Смешивание AWG и Xray без приёмки может ухудшить устойчивость узла.');
    Tests=@('Пока только архитектурная проверка.', 'Будущий hardened-awg должен иметь install, auth, backup, update и rollback тесты.');
    Stop=@('Не разворачивать как production.', 'Не переносить docker-compose вслепую.', 'Не включать AWG в общий installer до hardening-плана.');
  },
  @{
    Slug='upstream-master'; Branch='upstream/master'; Status='READ-ONLY'; Tag='readonly';
    Summary='Основная upstream-ветка для сравнения и точечного переноса идей.';
    Install='Нет в рамках нашего форка. Для установки используется наш репозиторий и наши ветки.';
    Role='Внешняя база проекта до наших изменений.';
    Profile='Зависит от upstream-состояния; не является утверждённым профилем нашего форка.';
    Done=@('Ветка помечена как read-only.', 'Роль upstream отделена от stable и implementation-контуров.');
    Now=@('Только периодическое сравнение при необходимости.');
    Next=@('Переносить идеи только через review и тесты в нашей ветке.');
    Risks=@('Прямое смешивание upstream и fork-кода может сломать исправленные сценарии.', 'Upstream README может не соответствовать нашему fork-flow.');
    Tests=@('Перед переносом идеи: diff, code review, staging, regression.', 'Без тестов upstream-изменения не попадают в main.');
    Stop=@('Не пушить в upstream/*.', 'Не использовать как документацию нашего форка.', 'Не заменять наш README upstream-текстом.');
  },
  @{
    Slug='upstream-reality'; Branch='upstream/reality'; Status='READ-ONLY'; Tag='readonly';
    Summary='Вспомогательная upstream-ветка для изучения REALITY-идей.';
    Install='Нет. Это не наш install-source.';
    Role='Read-only анализ и сравнение с нашей anti-DPI стратегией.';
    Profile='REALITY-контекст для сравнения, не готовый профиль нашего форка.';
    Done=@('Ветка добавлена в матрицу как вспомогательная read-only.', 'HTML фиксирует, что это не рабочая ветка форка.');
    Now=@('Новых задач нет, кроме чтения при необходимости.');
    Next=@('Полезные идеи переносить через platform-v2 и staging.');
    Risks=@('REALITY-настройки нельзя переносить механически: важны SNI, домены, fallback, ошибки клиентов и DPI-поведение.', 'Непроверенные изменения могут ухудшить скорость и устойчивость.');
    Tests=@('После переноса: install, client, reconnect, long-running.', 'Сама upstream-ветка не тестируется как наша поставка.');
    Stop=@('Не использовать для установки.', 'Не считать заменой platform-v2.', 'Не делать прямой merge без review.');
  },
  @{
    Slug='upstream-subscriptions'; Branch='upstream/subscriptions'; Status='READ-ONLY'; Tag='readonly';
    Summary='Вспомогательная upstream-ветка для идей по подпискам и клиентской выдаче конфигов.';
    Install='Нет. Это не install-source.';
    Role='Анализ upstream-идей по подпискам, web-sub и выдаче клиентских конфигураций.';
    Profile='Transport-фокус отсутствует; ветка касается subscription/admin слоя.';
    Done=@('Ветка заведена в read-only матрицу.', 'Отделена от active веток.');
    Now=@('Новых задач нет.');
    Next=@('Идеи переносить только после review в admin/subscription hardening этап platform-v2.');
    Risks=@('Публичная подписка - чувствительный контур.', 'Ошибки subscription могут раскрыть конфиги или упростить active probing.');
    Tests=@('После переноса: секреты, доступ, ссылки, token-flow, client import.', 'Сама upstream-ветка не является тестовой поставкой.');
    Stop=@('Не использовать как инструкцию нашего форка.', 'Не публиковать реальные subscription URL.', 'Не включать без security review.');
  }
)

$IndexCards = foreach ($B in $Branches) {
  $Strategy = if ($B.Slug -eq 'codex-platform-v2') { '<a class="pill" href="codex-platform-v2-strategy.html">Стратегия</a>' } else { '' }
@"
      <article class="card strong">
        <h2>$($B.Branch)</h2>
        <span class="tag $($B.Tag)">$($B.Status)</span>
        <p>$($B.Summary)</p>
        <h3>Когда открывать</h3>
        <p class="muted">$($B.Install)</p>
        <div class="links">
          <a class="pill" href="$($B.Slug)-overview.html">Обзор</a>
          <a class="pill" href="$($B.Slug)-progress.html">Прогресс и план</a>
          $Strategy
        </div>
      </article>
"@
}

Write-Report 'index.html' @"
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AT-VPN-System: документация по веткам</title>
  <link rel="stylesheet" href="assets/branch-report.css" />
</head>
<body>
  <main class="container">
    <section class="header">
      <div class="eyebrow">Интерактивная документация</div>
      <h1>AT-VPN-System: понятные отчёты по веткам</h1>
      <p class="lead">Здесь собрана project-safe документация по каждой ветке: что она делает, зачем нужна, можно ли из неё устанавливать систему, какие функции уже готовы, какие риски известны и что дальше по плану.</p>
      <div class="meta-grid">
        <div class="meta"><b>Формат</b>Только техническая информация о проекте, без приватного контекста.</div>
        <div class="meta"><b>Источник правды</b><code>BRANCH_MATRIX</code>, <code>MASTER_PLAN</code>, <code>RESUME_POINT</code>.</div>
        <div class="meta"><b>Обновлено</b>$Stamp (MSK)</div>
      </div>
    </section>

    <h2 class="section-title">Как читать эти страницы</h2>
    <section class="grid section">
      <article class="card accent"><h2>Обзор</h2><p>Назначение ветки, сценарии установки, ограничения, технический профиль и правила использования.</p></article>
      <article class="card accent"><h2>Прогресс и план</h2><p>Что сделано, что в работе, какие проверки нужны перед merge и какие действия запрещены.</p></article>
      <article class="card accent"><h2>Стратегия</h2><p>Для platform-v2 отдельно описана идея: снижение сигнатурности, fallback-профили, устойчивость и будущие модули.</p></article>
    </section>

    <h2 class="section-title">Ветки репозитория</h2>
    <section class="grid wide section">
$($IndexCards -join "`n")
    </section>

    <p class="footer">Источник правды: <code>docs/BRANCH_MATRIX.md</code>, <code>docs/MASTER_PLAN.md</code>, <code>docs/RESUME_POINT.md</code>. Обновлено: $Stamp (MSK).</p>
  </main>
</body>
</html>
"@

foreach ($B in $Branches) {
  $OverviewName = "$($B.Slug)-overview.html"
  $ProgressName = "$($B.Slug)-progress.html"
  $StrategyNav = if ($B.Slug -eq 'codex-platform-v2') { '<a href="codex-platform-v2-strategy.html">Стратегия</a>' } else { '' }

  Write-Report $OverviewName @"
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Обзор ветки - $($B.Branch)</title>
  <link rel="stylesheet" href="assets/branch-report.css" />
</head>
<body>
  <main class="container">
    <section class="header">
      <div class="eyebrow">Обзор ветки</div>
      <h1>$($B.Branch)</h1>
      <p class="lead">$($B.Summary)</p>
      <div class="nav">
        <span class="tag $($B.Tag)">$($B.Status)</span>
        <a href="index.html">К индексу</a>
        <a href="$ProgressName">Прогресс и план</a>
        $StrategyNav
      </div>
      <div class="meta-grid">
        <div class="meta"><b>Можно устанавливать</b>$($B.Install)</div>
        <div class="meta"><b>Основной фокус</b>$($B.Role)</div>
        <div class="meta"><b>Технический профиль</b>$($B.Profile)</div>
      </div>
    </section>

    <section class="callout"><b>Короткий вывод.</b> $($B.Install)</section>

    <h2 class="section-title">Что важно понимать</h2>
    <section class="grid wide section">
      <article class="card strong">
        <h2>Назначение</h2>
        <p>$($B.Role)</p>
        <details open>
          <summary>Где эта ветка в общем процессе</summary>
          <div><p>$($B.Summary)</p><p><b>Правило:</b> если ветка не помечена как stable или active implementation, её нельзя использовать как основной источник установки.</p></div>
        </details>
      </article>
      <article class="card strong">
        <h2>Технический профиль</h2>
        <p>$($B.Profile)</p>
        <details>
          <summary>Почему это важно</summary>
          <div><p>Мы разделяем stable, implementation, historical и upstream-ветки, чтобы не смешивать рабочую установку, эксперименты, архитектурные заметки и внешние источники.</p></div>
        </details>
      </article>
    </section>

    <h2 class="section-title">Состояние ветки</h2>
    <section class="grid section">
      <article class="card accent"><h2>Уже сделано</h2>$(Bullets $B.Done)</article>
      <article class="card warning"><h2>Риски и ограничения</h2>$(Bullets $B.Risks)</article>
      <article class="card"><h2>Как проверять</h2>$(Bullets $B.Tests)</article>
    </section>

    <section class="card danger section">
      <h2>Что нельзя делать с этой веткой</h2>
$(Bullets $B.Stop)
    </section>

    <p class="footer">Обновлено: $Stamp (MSK). Репозиторий: AT-VPN-System. Ветка: $($B.Branch). Формат: project-safe.</p>
  </main>
</body>
</html>
"@

  Write-Report $ProgressName @"
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Прогресс и план - $($B.Branch)</title>
  <link rel="stylesheet" href="assets/branch-report.css" />
</head>
<body>
  <main class="container">
    <section class="header">
      <div class="eyebrow">Прогресс и план</div>
      <h1>$($B.Branch)</h1>
      <p class="lead">Страница показывает, что уже выполнено, что находится в работе, какие проверки нужны и какие следующие шаги допустимы для этой ветки.</p>
      <div class="nav">
        <span class="tag $($B.Tag)">$($B.Status)</span>
        <a href="index.html">К индексу</a>
        <a href="$OverviewName">Обзор</a>
        $StrategyNav
      </div>
      <div class="meta-grid">
        <div class="meta"><b>Текущий режим</b>$($B.Status)</div>
        <div class="meta"><b>Установка</b>$($B.Install)</div>
        <div class="meta"><b>Фокус</b>$($B.Role)</div>
      </div>
    </section>

    <h2 class="section-title">Дорожная карта ветки</h2>
    <section class="grid wide section">
      <article class="card accent"><h2>Выполнено</h2>$(Bullets $B.Done)</article>
      <article class="card warning"><h2>В работе</h2>$(Bullets $B.Now)</article>
    </section>

    <section class="card strong section">
      <h2>Следующие шаги</h2>
      <div class="timeline">
$(Steps $B.Next)
      </div>
    </section>

    <section class="grid section">
      <article class="card"><h2>Проверки перед завершением этапа</h2>$(Bullets $B.Tests)</article>
      <article class="card danger"><h2>Стоп-условия</h2>$(Bullets $B.Stop)</article>
    </section>

    <section class="callout warning">
      <b>Правило проекта.</b> После значимого исправления, debug-этапа, документационного блока или новой функции изменения фиксируются в документации, коммитятся и отправляются в GitHub. Stable-ветка принимает только проверенные изменения.
    </section>

    <p class="footer">Обновлено: $Stamp (MSK). Репозиторий: AT-VPN-System. Ветка: $($B.Branch). Формат: project-safe.</p>
  </main>
</body>
</html>
"@
}

Write-Report 'codex-platform-v2-strategy.html' @"
<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Стратегия platform-v2</title>
  <link rel="stylesheet" href="assets/branch-report.css" />
</head>
<body>
  <main class="container">
    <section class="header">
      <div class="eyebrow">Стратегия платформы</div>
      <h1>platform-v2: невидимость, устойчивость и управляемые профили</h1>
      <p class="lead">Цель ветки - превратить форк в локально контролируемую multi-transport платформу: не зависеть от одного протокола, снижать сигнатурность, иметь fallback-пути и проверять каждую гипотезу через staging и полевые тесты.</p>
      <div class="nav">
        <span class="tag active">АКТИВНАЯ СТРАТЕГИЯ</span>
        <a href="index.html">К индексу</a>
        <a href="codex-platform-v2-overview.html">Обзор ветки</a>
        <a href="codex-platform-v2-progress.html">Прогресс и план</a>
      </div>
      <div class="meta-grid">
        <div class="meta"><b>Главная идея</b>Снижение сигнатурности плюс быстрый fallback, а не вера в один “вечный” протокол.</div>
        <div class="meta"><b>Текущий этап</b>Block C1: сравнение stealth-xray и stealth-xhttp.</div>
        <div class="meta"><b>Источник</b><code>docs/PLATFORM_VISION_PLAN.md</code></div>
      </div>
    </section>

    <section class="callout">
      <b>Практический вывод.</b> Наша цель - не обещать абсолютную невидимость, а системно уменьшать признаки, по которым DPI может классифицировать трафик, и не терять доступ надолго, если сеть деградировала, включила whitelist или начала сбрасывать соединения.
    </section>

    <h2 class="section-title">Что мы строим</h2>
    <section class="grid wide section">
      <article class="card accent">
        <h2>Локальная платформа</h2>
        <p>Всё, что относится к нашему форку, должно жить в нашем репозитории: installer, профили, документация, будущие модули, правила проверки и HTML-отчёты. Внешние проекты можно изучать, но production-поведение должно быть управляемым нами.</p>
      </article>
      <article class="card accent">
        <h2>Несколько профилей</h2>
        <p>Платформа должна иметь основной профиль, DPI fallback, мобильный fallback-класс и резервный контур. Профили не должны конфликтовать и не должны включаться все сразу без причины.</p>
      </article>
    </section>

    <h2 class="section-title">Модель угроз</h2>
    <section class="grid section">
      <article class="card warning"><h2>DPI и сигнатуры</h2><p>Проверяем TLS/SNI/ALPN/HTTP-поведение, количество соединений, тип транспорта, реакцию клиента и характер ошибок. Цель - уменьшать узнаваемость, не ломая скорость.</p></article>
      <article class="card warning"><h2>Active probing</h2><p>Публичный 443 должен выглядеть правдоподобно. Если сканер приходит не как наш клиент, он не должен видеть открытую служебную поверхность.</p></article>
      <article class="card warning"><h2>RST/drop</h2><p>RST-инъекции и silent drop нельзя лечить одной настройкой. Нужны reconnect-проверки, fallback-профили, наблюдаемость логов и аккуратная работа с транспортами.</p></article>
      <article class="card warning"><h2>Mobile whitelist</h2><p>Если мобильная сеть пропускает только белые IP/ASN, transport-тюнинг может не помочь. Это отдельное будущее направление: white IP, Yandex Cloud, VK Cloud, специальные подсети.</p></article>
      <article class="card warning"><h2>Single-IP co-tenancy</h2><p>Если Xray и AWG активно шумят на одном IP, DPI может коррелировать поведение. Поэтому AWG должен идти отдельным hardened-модулем и с отдельной приёмкой.</p></article>
      <article class="card warning"><h2>Скорость</h2><p>Слишком тяжёлая обфускация может снизить скорость. Поэтому каждый профиль должен иметь баланс: невидимость, устойчивость, задержка, throughput и стабильность при нагрузке.</p></article>
    </section>

    <h2 class="section-title">Технологические направления</h2>
    <section class="grid wide section">
      <article class="card strong"><h2>REALITY / Vision</h2><p>Быстрый low-latency профиль. Подходит как основной кандидат, если сеть не режет его по признакам или IP/ASN. Требует проверки на reconnect и мобильной сети.</p></article>
      <article class="card strong"><h2>REALITY / XHTTP</h2><p>Более выраженный anti-DPI кандидат. Его задача - дать другой сетевой рисунок и fallback, когда обычный Vision деградирует или становится нестабильным.</p></article>
      <article class="card strong"><h2>stealth-multi</h2><p>Будущий объединённый профиль. Он должен собираться только из проверенных transport-путей, а не просто добавлять “много подключений” без понятной цели.</p></article>
      <article class="card strong"><h2>Admin hardening</h2><p>Панель, подписки, секреты и web-sub должны быть защищены отдельно. Нельзя усиливать transport и оставлять слабую выдачу конфигов.</p></article>
      <article class="card strong"><h2>Hardened AWG</h2><p>AmneziaWG остаётся будущим opt-in модулем. Его нужно локализовать в репозитории, настроить безопаснее дефолта, добавить auth и проверить IP-риск общего узла.</p></article>
      <article class="card strong"><h2>Наблюдаемость</h2><p>Нужны verify-команды, диагностика nginx/x-ui/xray, фиксация ошибок closed pipe/read-write, service health, inbound JSON и поведения клиентов.</p></article>
    </section>

    <h2 class="section-title">План реализации</h2>
    <section class="card strong section">
      <div class="timeline">
        <div class="step"><b>Закрыть Block C1.</b> Сравнить stealth-xray и stealth-xhttp: Wi-Fi, LTE, reconnect, 30-60 минут, 4K-нагрузка, Telegram/web, ошибки клиентов и серверные логи.</div>
        <div class="step"><b>Выбрать production-профиль.</b> Отдельно назначить основной путь, DPI fallback и мобильный fallback-класс.</div>
        <div class="step"><b>Собрать stealth-multi.</b> Включать только проверенные transport-пути, чтобы не создавать лишний шум и не ухудшить скорость.</div>
        <div class="step"><b>Усилить admin/subscription.</b> Защитить панель, web-sub, секреты, выдачу конфигов и rollback.</div>
        <div class="step"><b>Подготовить hardened-awg.</b> Локальный модуль, docker-управление, auth, безопасные параметры, отдельная приёмка и оценка single-IP риска.</div>
        <div class="step"><b>Позже исследовать white IP.</b> Отдельно проверить Yandex Cloud, VK Cloud, специальные подсети и сценарии mobile whitelist. Сейчас это идея, не текущая реализация.</div>
        <div class="step"><b>Оптимизировать скорость.</b> После transport/security-стабилизации открыть performance-блок: throughput, latency, mux, параметры клиентов и нагрузочные профили.</div>
      </div>
    </section>

    <section class="grid section">
      <article class="card accent">
        <h2>Критерии успеха</h2>
        <ul>
          <li>Есть минимум один стабильный основной профиль и один реально проверенный fallback.</li>
          <li>Понятно, где проблема transport/DPI, а где IP/ASN или mobile whitelist.</li>
          <li>Каждый модуль имеет install, verify, rollback и документацию.</li>
          <li>HTML и MD-документы обновлены после каждого этапа.</li>
        </ul>
      </article>
      <article class="card danger">
        <h2>Чего не делаем</h2>
        <ul>
          <li>Не обещаем абсолютную невидимость.</li>
          <li>Не добавляем протоколы без тестовой пользы.</li>
          <li>Не публикуем приватный контекст в GitHub.</li>
          <li>Не включаем AWG в общий installer до hardening-плана.</li>
        </ul>
      </article>
    </section>

    <p class="footer">Обновлено: $Stamp (MSK). Источник: <code>docs/PLATFORM_VISION_PLAN.md</code>. Ветка: codex/platform-v2. Формат: project-safe.</p>
  </main>
</body>
</html>
"@

Write-Host "Branch HTML reports rendered at $Stamp (MSK)."
