# x-ui-pro

Форк установщика `x-ui + nginx`, изначально основанный на проекте [GFW4Fun/x-ui-pro](https://github.com/GFW4Fun/x-ui-pro), адаптированный под сценарий с `REALITY`, `WebSocket`, `XHTTP`, `Trojan gRPC`, локальной web-sub страницей и локальным набором шаблонов/ассетов.

## Что делает проект

- Автоматически разворачивает `3x-ui`, `nginx`, `certbot`, `sqlite3`, `ufw`
- Работает через порт `443`
- Поддерживает `VLESS Reality`, `VLESS WS`, `VLESS XHTTP`, `Trojan gRPC`
- Публикует локальную web-sub страницу
- Публикует локальные `Clash`-шаблоны
- Поднимает локальный экземпляр `sub2sing-box`
- Использует локально встроенные fake-site шаблоны
- Настраивает сертификаты и базовую firewall-конфигурацию

## Требования

- Debian 12+ или Ubuntu 24+
- Права `root`
- Два домена или поддомена:
  1. Для панели, `WebSocket`, `gRPC`, `HTTP Upgrade`, `SplitHTTP`
  2. Для `REALITY`

Полезные ссылки:

- Бесплатные поддомены: [Notion](https://scarce-hole-1e2.notion.site/14d1666462e48069818cf42553bfae1f?pvs=74)
- Русская инструкция по исходной идее: [Notion](https://scarce-hole-1e2.notion.site/3X-UI-pro-with-REALITY-panel-and-inbaunds-on-port-443-10d1666462e48085be0fee4c136ce417)

## Установка

Рекомендуемый и поддерживаемый режим для этого форка: запускать установщик из локального клона репозитория. В этом режиме web-sub страница, fake-site шаблоны, `vendor`-ассеты и зеркалированные `rule-set` файлы берутся из локального репозитория.

```bash
git clone https://github.com/mozaroc/x-ui-pro.git
cd x-ui-pro
sudo bash ./x-ui-pro.sh -install yes -panel 1 -ONLY_CF_IP_ALLOW no
```

Важно:

- Для этого форка режим `wget | bash` не считается основным путём установки
- Не меняйте домен/поддомен после выпуска сертификата, если хотите сохранить штатное продление SSL

## Диагностика и debug-mode

Для диагностики без полной переустановки используйте `x-ui-pro-updated.sh`.

Проверка действующей установки:

```bash
sudo bash ./x-ui-pro-updated.sh -stage verify -debug yes -keep_artifacts yes
```

Быстрая переустановка только web-sub контура:

```bash
sudo bash ./x-ui-pro-updated.sh -stage websub -verify yes -debug yes
```

Безопасный предпросмотр полной установки:

```bash
sudo bash ./x-ui-pro-updated.sh -dry_run yes -install yes -panel 1 -subdomain <домен> -reality_domain <reality-домен>
```

## Удаление

```bash
sudo bash ./x-ui-pro.sh -uninstall yes
```

## Резервная копия панели и nginx-конфигов

```bash
sudo bash ./backup.sh
```

## Скриншоты

**Как открыть custom web sub page**

![](./media/CustomWebSubHow2Open.png)

**Главная страница custom web sub**

![](./media/CustomWebSub.png)

**Блок sub2sing-box на custom web sub page**

![](./media/CustomWebSubSingBox.png)

**Локальный экземпляр sub2sing-box**

![](./media/sub2sing.png)
