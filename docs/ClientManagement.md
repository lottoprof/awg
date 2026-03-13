# Управление клиентами AWG

## Цель
Зафиксировать, как на новом сервере будет устроено управление клиентами `AWG`: создание, учет, отзыв, хранение клиентских артефактов и обновление серверного конфига.

## Входные условия
- Принята структура из [docs/ServerLayout.md](ServerLayout.md).
- `AmneziaWG` установлен.
- Серверный интерфейс управляется через `awg-quick@awg0.service`.
- Основной серверный конфиг хранится в `/etc/amnezia/amneziawg/awg0.conf`.
- Параметры автоматизации хранятся в `/etc/amnezia/params`.

## Основные команды
На новом сервере используем такой набор backend-команд:
- `awg-add-client`
- `awg-list-clients`
- `awg-export-client`
- `awg-revoke-client`

Все команды размещаются в:
```text
/usr/local/bin
```

Их исходники в репозитории лежат в:
```text
script_srv/
```

## Источник стартовой реализации
Стартовая реализация `awg-add-client` взята за основу с рабочего сервера и адаптирована под новую структуру.

Что переносим из существующего скрипта:
- автоматическую нумерацию клиентов;
- генерацию ключей;
- выбор следующего свободного IP;
- генерацию клиентского `.conf`;
- генерацию QR;
- обновление серверного конфига;
- `systemctl restart awg-quick@awg0`.

Что меняем при переносе:
- клиентские файлы пишем не в `/etc/amnezia/clients`, а в `/var/lib/amnezia/clients`;
- QR пишем не рядом с конфигами, а в `/var/lib/amnezia/qr`;
- служебный state выносим в `/var/lib/amnezia/state`;
- читаем параметры из `/etc/amnezia/params`.
- при выдаче файлов используем `/home/<operator_user>/export`.

## Размещение клиентских данных
Принятая структура:
```text
/var/lib/amnezia/clients
/var/lib/amnezia/qr
/var/lib/amnezia/state
```

Назначение:
- `clients/` — клиентские `.conf`;
- `qr/` — PNG-файлы QR-кодов;
- `state/` — реестр клиентов, индексы, служебные файлы.

`/home/<operator_user>/export` используется как временная транзитная зона выдачи. Детали операторского процесса описаны в [docs/OperatorWorkflow.md](OperatorWorkflow.md) и [docs/Awgctl.md](Awgctl.md).

## Именование клиентов
Принимаем формат:
```text
clientNN_name
```

Примеры:
```text
client01_anna
client02_iphone
client03_laptop
```

Правила:
- `NN` — двухзначный или расширяемый порядковый номер;
- `name` — короткий ASCII-идентификатор без пробелов;
- один и тот же клиент не должен получать дублирующее имя без явного решения оператора.

## Распределение IP
Принцип:
- сервер занимает `10.66.66.1/24`;
- клиенты получают адреса по одному, начиная с `10.66.66.2`;
- каждому клиенту выдается `AllowedIPs = 10.66.66.X/32`.

Правило:
- `awg-add-client` должен искать следующий свободный IP по текущему серверному конфигу и состоянию;
- повторное использование IP допускается только после явного отзыва клиента.

## Как работает `awg-add-client`
Текущая реализация работает так:
1. Проверяет запуск от `root`.
2. Загружает переменные из `/etc/amnezia/params`.
3. Проверяет наличие каталогов:
   - `/var/lib/amnezia/clients`
   - `/var/lib/amnezia/qr`
   - `/var/lib/amnezia/state`
4. Определяет следующий номер клиента.
5. Определяет следующий свободный IP.
6. Генерирует:
   - `client_private`
   - `client_public`
   - `psk`
7. Добавляет новый `[Peer]` в `/etc/amnezia/amneziawg/awg0.conf`.
8. Генерирует клиентский `.conf`.
9. Генерирует QR-код.
10. Обновляет client registry в `/var/lib/amnezia/state/clients.tsv`.
11. Копирует `.conf` и `.png` в `/home/<operator_user>/export`.
12. Выставляет владельца exported-файлов по владельцу каталога `/home/<operator_user>/export`.
13. Выполняет:
```bash
systemctl restart awg-quick@awg0
```
14. Проверяет, что сервис поднялся корректно.
15. Показывает оператору путь к `.conf`, QR и назначенный IP.

Дополнительно:
- использует backup серверного конфига;
- при ошибке возвращает `awg0.conf` из backup;
- берет пути `CLIENTS_DIR`, `QR_DIR`, `STATE_DIR`, `REGISTRY_FILE` из `params`.
- использует `SERVER_PUB_IP` как endpoint для клиента.

## Что пишет `awg-add-client`
После успешного выполнения должны появиться файлы:

Клиентский конфиг:
```text
/var/lib/amnezia/clients/clientNN_name.conf
```

QR-код:
```text
/var/lib/amnezia/qr/clientNN_name.png
```

Служебная запись:
```text
/var/lib/amnezia/state/clients.tsv
```

Файлы для выдачи оператору:
```text
/home/<operator_user>/export/clientNN_name.conf
/home/<operator_user>/export/clientNN_name.png
```

Важно:
- эти файлы являются копиями;
- source of truth остается в `/var/lib/amnezia/clients` и `/var/lib/amnezia/qr`;
- `export` не является архивом.

## Формат client registry
Принимаем отдельный реестр клиентов:
```text
/var/lib/amnezia/state/clients.tsv
```

Минимальные поля:
```text
client_id<TAB>name<TAB>ip<TAB>public_key<TAB>status
```

Пример:
```text
client01_anna	anna	10.66.66.2	BASE64_PUBLIC_KEY	active
client02_laptop	laptop	10.66.66.3	BASE64_PUBLIC_KEY	revoked
```

Назначение реестра:
- быстрый список клиентов;
- учет занятых и отозванных адресов;
- упрощение `awg-list-clients` и `awg-revoke-client`.

## Как работает `awg-list-clients`
Текущая реализация:
- читать `/var/lib/amnezia/state/clients.tsv`;
- показывать:
  - `client_id`
  - имя
  - IP
  - статус
  - наличие `.conf`
  - наличие QR

Минимальный результат:
- понятный табличный список активных и отозванных клиентов.

Практическое использование:
- оператор сначала вызывает `awg-list-clients`;
- выбирает нужный `client_id`.

## Как работает `awg-export-client`
Текущая реализация:
1. Проверяет запуск от `root`.
2. Читает `/etc/amnezia/params`.
3. Проверяет наличие клиента в `clients.tsv`.
4. Берет `.conf` из `/var/lib/amnezia/clients`.
5. Берет `.png` из `/var/lib/amnezia/qr`, если файл существует.
6. Копирует файлы в `/home/<operator_user>/export`.
7. Выставляет владельца exported-файлов по владельцу каталога `/home/<operator_user>/export`.
8. Показывает оператору итоговые пути.

## Как работает `awg-revoke-client`
Текущая реализация:
1. Проверяет запуск от `root`.
2. Находит клиента по `client_id`.
3. Удаляет соответствующий `[Peer]` из `/etc/amnezia/amneziawg/awg0.conf`.
4. Обновляет статус клиента в `clients.tsv` на `revoked`.
5. Не удаляет клиентский `.conf` и QR автоматически, если не включен явный флаг очистки.
6. Выполняет:
```bash
systemctl restart awg-quick@awg0
```
7. Проверяет, что сервис поднялся.

Дополнительно:
- поддерживает флаг `--purge`;
- использует backup для `awg0.conf` и `clients.tsv`;
- при ошибке возвращает файлы из backup.

## Политика удаления клиентских файлов
По умолчанию:
- отзыв клиента не удаляет его `.conf`;
- отзыв клиента не удаляет QR;
- артефакты остаются для аудита и истории.

Опционально позже можно добавить флаг:
```text
--purge
```

## Работа с `/home/<operator_user>/export`
Правила:
- `awg-add-client` и `awg-export-client` копируют туда `.conf` и `.png`;
- после успешной передачи на рабочее место `export` очищается;
- повторная выдача всегда опирается на основное хранилище, а не на старые копии в `export`.

## Что считается успешным добавлением клиента
Успех есть только если одновременно выполнено все:
- новый `[Peer]` записан в `/etc/amnezia/amneziawg/awg0.conf`;
- клиентский `.conf` создан;
- QR создан;
- запись появилась в `clients.tsv`;
- `awg-quick@awg0` успешно перезапущен.

## Что считается успешным отзывом клиента
Успех есть только если одновременно выполнено все:
- peer удален или отключен в `awg0.conf`;
- статус в `clients.tsv` изменен;
- `awg-quick@awg0` успешно перезапущен.

## Проверки результата этапа
- Зафиксированы команды `awg-add-client`, `awg-list-clients`, `awg-export-client`, `awg-revoke-client`.
- Зафиксировано, что базовая реализация этих команд уже существует в репозитории.
- Зафиксировано размещение `.conf`, QR и state.
- Зафиксирован формат именования клиентов.
- Зафиксировано правило выдачи IP.
- Зафиксирован формат `clients.tsv`.
- Зафиксирован обязательный `systemctl restart awg-quick@awg0` после изменения peer list.

## Ожидаемый итог
Серверный lifecycle клиента зафиксирован без привязки к ручному SSH-процессу оператора.
