# UTM ЕГАИС в Docker с Rutoken

Отдельный проект для запуска УТМ 4.2.0-2644 на Linux-хосте с физическим Rutoken ECP.

Перед сборкой скачайте подходящий пакет `u-trans-*.deb` из раздела [Releases](https://github.com/tanziqly/utm-egais/releases) и положите его рядом с `Dockerfile`. Пакет УТМ хранится как файл релиза, а не в Git-истории, поскольку превышает лимит GitHub для обычных коммитов.

```bash
docker build -t utm-egais .
docker compose up -d
docker exec -it utm-egais pcsc_scan
docker exec -it utm-egais supervisorctl status
```

Полное руководство для целевого Debian-компьютера: [`DEPLOYMENT.md`](DEPLOYMENT.md).
