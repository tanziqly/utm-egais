# УТМ ЕГАИС + Rutoken в Docker

Отдельный проект для запуска УТМ ЕГАИС **4.2.0-2644** с физически подключённым Rutoken ECP. Контейнер получает доступ к USB-токену, запускает `pcscd` и УТМ, а веб-интерфейс доступен по адресу `http://localhost:8080`.

> Требования: Debian 12/13, 64-битный компьютер Intel/AMD, обычный Docker Engine (не rootless), один физически подключённый Rutoken. Не подходит для macOS/Windows Docker Desktop, ARM-компьютеров и одновременного использования одного токена в нескольких ВМ/контейнерах.

## Как это работает

```text
Rutoken → USB хоста → контейнер → pcscd + libccid → УТМ → http://localhost:8080
```

- `Dockerfile` устанавливает УТМ и необходимые 32-битные библиотеки.
- `pcscd` и `libccid` дают УТМ доступ к Rutoken по PC/SC.
- При старте `entrypoint.sh` повторно настраивает УТМ под обнаруженный Rutoken. Это необходимо, поскольку во время сборки образа USB-ключа нет.
- `supervisord` запускает `pcscd` и УТМ и автоматически перезапускает их при сбое.
- Настройки, база, очередь документов и логи живут в Docker-томах; обновление образа не должно их удалять.

## Установка с нуля

Подключите Rutoken напрямую к USB-порту Linux-компьютера. Затем выполните команды по порядку.

### 1. Подготовка системы

```bash
sudo apt update
sudo apt install -y ca-certificates curl git usbutils
```

Проверьте, что Debian видит токен:

```bash
lsusb | grep -i rutoken
```

Для Rutoken ECP ожидается строка с идентификатором производителя `0a89`, например `ID 0a89:0030`.

Если на хосте есть служба `pcscd`, остановите её — токеном должен управлять только контейнер:

```bash
sudo systemctl stop pcscd.socket pcscd.service
```

### 2. Установка Docker Engine

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
```

### 3. Клонирование и загрузка УТМ

```bash
sudo git clone https://github.com/tanziqly/utm-egais.git /opt/utm-egais
cd /opt/utm-egais
sudo curl -fL -o u-trans-4.2.0-2644-i386.deb \
  https://github.com/tanziqly/utm-egais/releases/download/utm-4.2.0-2644/u-trans-4.2.0-2644-i386.deb
```

### 4. Сборка и запуск

```bash
cd /opt/utm-egais
sudo docker compose build
sudo docker compose up -d
```

## Проверка

```bash
sudo docker exec -it utm-egais lsusb | grep -i rutoken
sudo docker exec -it utm-egais pcsc_scan
sudo docker exec -it utm-egais supervisorctl status
```

`pcsc_scan` интерактивный: после того как увидите считыватель, выйдите через `Ctrl+C`. В выводе `supervisorctl status` процессы `pcscd` и `utm` должны иметь статус `RUNNING`.

Откройте в браузере:

```text
http://localhost:8080
```

Для доступа из локальной сети используйте `http://IP_АДРЕС_ПК:8080`, если это разрешено вашей сетью. Не открывайте этот порт в интернет.

## Управление

Логи:

```bash
cd /opt/utm-egais
sudo docker compose logs -f
```

Перезапуск:

```bash
sudo docker compose restart
```

Остановка без удаления рабочих данных:

```bash
sudo docker compose down
```

Повторный запуск:

```bash
sudo docker compose up -d
```

## Если не работает

| Симптом | Что делать |
| --- | --- |
| Токен не виден в контейнере | Проверьте `lsusb` на хосте, прямое подключение токена и отсутствие rootless Docker. |
| `pcsc_scan` не видит ключ | Убедитесь, что хостовый `pcscd` остановлен, а токен не используется другой ВМ или ПК. |
| УТМ не `RUNNING` | Выполните `sudo docker compose logs --tail=200`. |
| Не открывается интерфейс | Проверьте `sudo docker compose ps` и откройте `http://localhost:8080`. |

## Обновление УТМ

1. Сделайте резервную копию рабочих данных и убедитесь, что в очереди нет необработанных документов.
2. Остановите контейнер:

   ```bash
   cd /opt/utm-egais
   sudo docker compose down
   ```

3. Скачайте новый `.deb` и измените его имя в `Dockerfile`, `docker-compose.yml` и `.dockerignore`.
4. Пересоберите и запустите:

   ```bash
   sudo docker build --no-cache -t utm-egais .
   sudo docker compose up -d
   ```

Не используйте `sudo docker compose down -v` без резервной копии: ключ `-v` удаляет Docker-тома с рабочими данными УТМ.
