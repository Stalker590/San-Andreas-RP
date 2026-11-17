# Продакшн-окружение Linux (ROADMAP 9.3)

Каталог `deploy/` содержит готовую конфигурацию для запуска SAN ANDREAS RP
как системной службы Linux с автоматическими резервными копиями и ротацией
логов.

## Состав

| Файл | Назначение |
| --- | --- |
| `omp-server.service` | Шаблон systemd-юнита: автоперезапуск, `LimitNOFILE=65535`, песочница. |
| `backup_mysql.sh` | Дамп БД `mysqldump --single-transaction --quick \| gzip`, хранение 14 суток. |
| `prune_audit_logs.sh` | Порционная очистка `audit_logs` старше 90 суток. |
| `sarp.cron` | Cron-задачи: бэкап каждые 6 часов, очистка аудита ежедневно. |
| `logrotate-sarp` | Ротация `log.txt`, `logs/*.log`, `scriptfiles/audit_fallback.log` (14 дней). |
| `install_devops.sh` | Идемпотентная установка всего перечисленного. |

## Быстрая установка

```bash
cd /opt/san-andreas-rp
sudo ./deploy/install_devops.sh
```

Скрипт:

1. Создаёт системного пользователя `sarp` (если его нет).
2. Создаёт `logs/` и `scriptfiles/backups/` с правами `sarp:sarp`.
3. Подставляет реальные пути в шаблоны и устанавливает:
   * `/etc/systemd/system/omp-server.service`;
   * `/etc/cron.d/sarp`;
   * `/etc/logrotate.d/sarp`.
4. Выполняет `systemctl daemon-reload`, включает и перезапускает службу.

Переопределение путей:

```bash
sudo SARP_DIR=/srv/sarp SARP_USER=omp ./deploy/install_devops.sh
```

## Проверка

```bash
systemctl status omp-server.service
systemctl show omp-server.service -p LimitNOFILE
journalctl -u omp-server.service -n 100 --no-pager
sudo logrotate -d /etc/logrotate.d/sarp
sudo -u sarp /opt/san-andreas-rp/deploy/backup_mysql.sh
ls -lh /opt/san-andreas-rp/scriptfiles/backups/
```

Ожидаемые результаты:

* `LimitNOFILE=65535`;
* служба перезапускается автоматически при падении (`Restart=always`);
* в `scriptfiles/backups/` появляется архив `sarp_<db>_<timestamp>.sql.gz`;
* архивы старше 14 суток удаляются автоматически;
* `log.txt` и логи компонентов ротируются ежедневно с `copytruncate`
  (сервер не требуется останавливать).

## Переменные окружения

Скрипты читают `.env` из корня сервера (файл уже исключён из Git).
Дополнительные параметры:

| Переменная | По умолчанию | Назначение |
| --- | --- | --- |
| `SARP_ENV_FILE` | `<server>/.env` | Путь к файлу с доступами к БД. |
| `SARP_BACKUP_DIR` | `<server>/scriptfiles/backups` | Каталог архивов. |
| `SARP_BACKUP_RETENTION_DAYS` | `14` | Срок хранения дампов. |
| `SARP_AUDIT_RETENTION_DAYS` | `90` | Срок хранения записей `audit_logs`. |
| `SARP_AUDIT_DELETE_BATCH` | `5000` | Размер порции удаления аудита. |

## Требования

* systemd 240+ (поддерживает `StandardOutput=append:`);
* MySQL/MariaDB с клиентскими утилитами `mysqldump` и `mysql`;
* `flock` (пакет `util-linux`);
* свободное место под архивы БД (рекомендуется отдельный диск или LVM).
