# Smoke-проверка первого клиента AWG

## Цель
Проверить полный минимальный рабочий цикл `AWG` на новом сервере:
- серверный сервис запускается;
- `awg-add-client` создает клиента;
- peer попадает в `awg0.conf`;
- клиентский `.conf` и QR генерируются;
- handshake происходит;
- клиент выходит в интернет через туннель.

## Входные условия
- Выполнен этап из [docs/ServerConfigInit.md](ServerConfigInit.md).
- Скрипты `awg-add-client`, `awg-list-clients`, `awg-export-client`, `awg-revoke-client` уже размещены на сервере.
- `AmneziaWG` установлен.
- `awg-quick@awg0.service` доступен.
- Есть тестовое клиентское устройство или клиентское приложение для проверки подключения.

## Шаг 1. Размещение `awg-*` команд
Копируем команды в `/usr/local/bin`.

Команды:
```bash
sudo install -m 755 script_srv/awg-add-client /usr/local/bin/awg-add-client
sudo install -m 755 script_srv/awg-list-clients /usr/local/bin/awg-list-clients
sudo install -m 755 script_srv/awg-export-client /usr/local/bin/awg-export-client
sudo install -m 755 script_srv/awg-revoke-client /usr/local/bin/awg-revoke-client
```

Проверка:
```bash
command -v awg-add-client
command -v awg-list-clients
command -v awg-export-client
command -v awg-revoke-client
```

## Шаг 2. Проверка серверного сервиса до добавления клиента
Проверить, что `awg0` поднимается и systemd видит сервис.

Команды:
```bash
sudo systemctl enable awg-quick@awg0
sudo systemctl restart awg-quick@awg0
sudo systemctl status awg-quick@awg0 --no-pager
```

Дополнительная проверка:
```bash
ip addr show awg0
sudo awg show
```

Ожидаемый результат:
- сервис активен;
- интерфейс `awg0` существует;
- конфиг читается без ошибок.

## Шаг 3. Создание первого клиента
Создаем тестового клиента.

Команда:
```bash
sudo awg-add-client test
```

Ожидаемый результат:
- выводит `client_id`;
- показывает путь к `.conf`;
- показывает путь к QR;
- показывает путь в `/home/<operator_user>/export`;
- показывает назначенный IP.

## Шаг 4. Проверка серверных файлов после добавления клиента
Убеждаемся, что клиент действительно записан в серверное состояние.

Проверки:
```bash
sudo grep -n 'client01_test' /etc/amnezia/amneziawg/awg0.conf
sudo tail -n 20 /etc/amnezia/amneziawg/awg0.conf
sudo cat /var/lib/amnezia/state/clients.tsv
ls -l /var/lib/amnezia/clients
ls -l /var/lib/amnezia/qr
ls -l /home/<operator_user>/export
```

Ожидаемый результат:
- в `awg0.conf` появился новый `[Peer]`;
- в `clients.tsv` появилась строка со статусом `active`;
- в `clients/` создан `.conf`;
- в `qr/` создан `.png`, если установлен `qrencode`.
- в `/home/<operator_user>/export` появились копии файлов для выдачи оператору с владельцем `<operator_user>`.

## Шаг 5. Проверка списка клиентов
Проверяем, что операторская команда корректно показывает состояние.

Команда:
```bash
sudo awg-list-clients
```

Ожидаемый результат:
- в списке есть `client01_test`;
- статус `active`;
- `CONF=yes`;
- `QR=yes` или `QR=no`, если `qrencode` не установлен.

## Шаг 6. Импорт клиентского конфига
Передайте тестовый `.conf` в клиентское приложение `AmneziaWG`.

Правило:
- этот шаг выполняет пользователь или оператор с реальным клиентским устройством;
- агент не автоматизирует импорт конфига в мобильное приложение или включение туннеля на клиенте;
- после ручного подключения агент продолжает серверные проверки.

При повторной выдаче используйте:
```bash
sudo awg-export-client client01_test
```

Источники для оператора:
- файл:
```text
/home/<operator_user>/export/client01_test.conf
```
- QR:
```text
/home/<operator_user>/export/client01_test.png
```

## Шаг 7. Проверка handshake на сервере
После подключения клиента проверяем появление handshake.

Команды:
```bash
sudo awg show
sudo awg show awg0
sudo awg show awg0 latest-handshakes
sudo awg show awg0 endpoints
sudo awg showconf awg0
```

Ожидаемый результат:
- у тестового peer появляется endpoint;
- у тестового peer появляется `latest-handshake`;
- передаются байты трафика.
- `showconf` показывает актуальный runtime-конфиг интерфейса.

## Шаг 8. Проверка клиентского выхода в интернет
На клиентском устройстве включить туннель и проверить внешний IP.

Правило:
- включение туннеля и проверка внешнего IP на клиентском устройстве остаются ручной частью smoke-test;
- агент использует результат этого шага как подтверждение end-to-end проверки.

Проверки на клиенте:
- открыть сайт проверки IP;
- убедиться, что трафик идет через сервер;
- убедиться, что интернет работает не только handshake-уровне, но и на реальном трафике.

Ожидаемый результат:
- у клиента есть доступ в интернет через VPN;
- внешний IP совпадает с сервером;
- DNS работает.

## Шаг 9. Проверка отзыва клиента
Проверяем обратный цикл на одном тестовом клиенте.

Команда:
```bash
sudo awg-revoke-client client01_test
```

Проверки:
```bash
sudo awg-list-clients
sudo grep -n 'client01_test' /etc/amnezia/amneziawg/awg0.conf || true
```

Ожидаемый результат:
- статус клиента меняется на `revoked`;
- peer удален из `awg0.conf`;
- сервис перезапущен без ошибки.

## Шаг 10. Проверка purge-режима
Если нужно, проверяем удаление локальных артефактов.

Команда:
```bash
sudo awg-revoke-client client01_test --purge
```

Проверка:
```bash
ls -l /var/lib/amnezia/clients
ls -l /var/lib/amnezia/qr
```

Ожидаемый результат:
- `.conf` и `.png` удалены;
- запись в `clients.tsv` остается со статусом `revoked`.

## Проверки результата этапа
- `awg-quick@awg0` запускается.
- `awg-add-client` успешно создает клиента.
- `awg-list-clients` показывает актуальное состояние.
- `awg-revoke-client` корректно отзывает клиента.
- В `awg0.conf` peer добавляется и удаляется корректно.
- `clients.tsv` синхронизирован с реальным состоянием.
- Первый клиент проходит handshake.
- Клиент выходит в интернет через туннель.

## Ожидаемый итог
Есть подтверждение, что минимальный end-to-end цикл работает:
- сервер готов;
- клиент создается;
- клиент подключается;
- клиент отзывается;
- базовая shell-автоматизация рабочая.
