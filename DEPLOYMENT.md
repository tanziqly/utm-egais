# Установка УТМ ЕГАИС с Rutoken на отдельном ПК

## Назначение

Этот проект запускает УТМ ЕГАИС 4.2.0-2644 в Docker на 64-битном Debian 12/13 (Intel/AMD). Он передаёт Rutoken из USB хоста в контейнер, запускает `pcscd` для связи с ключом и открывает УТМ по адресу `http://localhost:8080`.

Схема работы: `Rutoken → USB хоста → контейнер → pcscd/libccid → УТМ`.

`entrypoint.sh` заново определяет подключённый ключ при каждом старте контейнера: это нужно потому, что образ собирается без физического Rutoken. Данные УТМ разделены на Docker-тома для настроек, базы, очереди документов и логов; код УТМ обновляется при пересборке.

## Подготовка хоста

1. Клонируйте репозиторий на целевой компьютер, например в `/opt/utm-egais`:

   ```bash
   git clone <URL_РЕПОЗИТОРИЯ> /opt/utm-egais
   ```

2. Скачайте пакет УТМ из релиза и положите его рядом с `Dockerfile`:

   ```bash
   cd /opt/utm-egais
   curl -fL -o u-trans-4.2.0-2644-i386.deb \
     https://github.com/tanziqly/utm-egais/releases/download/utm-4.2.0-2644/u-trans-4.2.0-2644-i386.deb
   ```
3. Подключите Rutoken и убедитесь, что он виден:

   ```bash
   lsusb | grep -i rutoken
   ```

   При отсутствии `lsusb`: `sudo apt update && sudo apt install usbutils`.
4. Остановите хостовый PC/SC, чтобы ключом управлял контейнер:

   ```bash
   sudo systemctl stop pcscd.socket pcscd.service
   ```

5. Установите обычный Docker Engine с плагином Compose по официальной инструкции Docker для Debian: <https://docs.docker.com/engine/install/debian/>. Не используйте rootless Docker, Docker Desktop, Windows/macOS или ARM — им недоступен этот прямой USB-проброс.

## Запуск

```bash
cd /opt/utm-egais
sudo docker build -t utm-egais .
sudo docker compose up -d
```

## Проверка

```bash
sudo docker exec -it utm-egais lsusb | grep -i rutoken
sudo docker exec -it utm-egais pcsc_scan
sudo docker exec -it utm-egais supervisorctl status
```

`pcsc_scan` интерактивный — после проверки выйдите через `Ctrl+C`. У `pcscd` и `utm` ожидается `RUNNING`. Откройте `http://localhost:8080`.

## Управление и диагностика

```bash
sudo docker compose logs -f
sudo docker compose restart
sudo docker compose down
sudo docker compose up -d
```

Если ключ не виден, сначала проверьте его через `lsusb` на хосте, убедитесь, что он не подключён к другой ВМ и что на хосте остановлен `pcscd`. Не публикуйте порт 8080 в интернет и не запускайте два УТМ с одним Rutoken.

## Обновление УТМ

Остановите контейнер, замените `.deb`, измените его имя в `Dockerfile`, `docker-compose.yml` и `.dockerignore`, затем пересоберите:

```bash
sudo docker compose down
sudo docker build --no-cache -t utm-egais .
sudo docker compose up -d
```

Не используйте `docker compose down -v` без резервной копии: эта команда удаляет рабочие данные УТМ.
