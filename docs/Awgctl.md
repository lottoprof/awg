# Спецификация локальной команды `awgctl`

## Цель
Зафиксировать интерфейс локальной операторской команды `awgctl`, через которую оператор будет управлять `AWG` со своего рабочего места.

## Назначение
`awgctl` — это локальная CLI-обертка.

Она использует серверные `awg-*` скрипты как backend.

## Модель прав доступа
Для первой версии принимаем такую модель:
- `awg-list-clients` должен выполняться через `sudo`;
- `awg-add-client` должен выполняться через `sudo`;
- `awg-export-client` должен выполняться через `sudo`;
- `awg-revoke-client` должен выполняться через `sudo`.

Причина:
- все четыре команды читают или изменяют серверные данные, которые не должны открываться оператору отдельными file permissions;
- используем одну модель доступа вместо специальных исключений.

## Требование к `sudoers`
На сервере нужно выдать операторскому пользователю точечные `sudoers`-права только на:
- `/usr/local/bin/awg-add-client`
- `/usr/local/bin/awg-list-clients`
- `/usr/local/bin/awg-export-client`
- `/usr/local/bin/awg-revoke-client`

Принцип:
- не выдаем общий `NOPASSWD: ALL`;
- разрешаем только конкретные backend-команды.

Готовое содержимое `/etc/sudoers.d/awg-operator`:
```sudoers
User_Alias AWG_OPERATOR = <operator_user>
Cmnd_Alias AWG_MANAGE = /usr/local/bin/awg-add-client, /usr/local/bin/awg-list-clients, /usr/local/bin/awg-export-client, /usr/local/bin/awg-revoke-client

AWG_OPERATOR ALL=(root) NOPASSWD: AWG_MANAGE
Defaults:AWG_OPERATOR !requiretty
```

Порядок применения:
```bash
sudo visudo -f /etc/sudoers.d/awg-operator
sudo chmod 440 /etc/sudoers.d/awg-operator
sudo visudo -c
```

Проверка:
```bash
sudo -l -U <operator_user>
```

Ожидаемый результат:
- пользователь `<operator_user>` может выполнять `awg-add-client`, `awg-list-clients`, `awg-export-client`, `awg-revoke-client` без запроса пароля;
- общий root-доступ и другие команды через `sudo` не выдаются.

## Минимальные зависимости рабочего места
Для первой версии считаем обязательными:
- `bash`
- `ssh`
- `rsync`

Опционально:
- `qrencode` не требуется на рабочем месте;
- `tmux` на рабочем месте не требуется.

## Базовая модель вызовов
`awgctl` должен знать:
- alias сервера;
- имя remote user;
- путь к транзитной зоне;
- локальный каталог для загрузки клиентских файлов.

## Команды `awgctl`
Для первой версии фиксируем такой интерфейс:
- `awgctl list-clients`
- `awgctl add-client <name>`
- `awgctl export-client <client_id>`
- `awgctl revoke-client <client_id>`

## `awgctl list-clients`
Внутренний вызов:
```bash
ssh <server_alias> sudo awg-list-clients
```

Результат:
- показать текущий список клиентов без изменения состояния.

## `awgctl add-client <name>`
Внутренний поток:
1. Выполнить на сервере:
```bash
ssh <server_alias> sudo awg-add-client <name>
```
2. Забрать `.conf` и `.png` из `/home/<operator_user>/export` на локальную машину через `rsync`.
3. После успешной передачи удалить remote-копии из `/home/<operator_user>/export`.

Итог:
- оператор получает локальные файлы без отдельного ручного шага `export-client`.

## `awgctl export-client <client_id>`
Внутренний поток:
1. Выполнить на сервере:
```bash
ssh <server_alias> sudo awg-export-client <client_id>
```
2. Забрать `.conf` и `.png` из `/home/<operator_user>/export` на локальную машину через `rsync`.
3. После успешной передачи удалить remote-копии из `/home/<operator_user>/export`.

## `awgctl revoke-client <client_id>`
Внутренний вызов:
```bash
ssh <server_alias> sudo awg-revoke-client <client_id>
```

Результат:
- peer удаляется из серверного конфига;
- клиент в registry получает статус `revoked`.

## Локальный каталог получения
Для первой версии принимаем локальный каталог:
```text
./awg_clients/
```

Туда `awgctl` должен складывать:
- `clientNN_name.conf`
- `clientNN_name.png`

## Работа с транзитной зоной сервера
`/home/<operator_user>/export` остается временной зоной выдачи.

Для `awgctl` принимаем правило:
- если локальная передача завершилась успешно, удалять remote-файлы из `export`;
- если передача завершилась ошибкой, remote-файлы не удалять;
- повторная выдача всегда делается через `awg-export-client`.

## Что не делаем в первой версии
Пока не включаем:
- массовые операции на нескольких клиентах;
- интерактивное меню;
- TUI;
- удаленный shell как часть нормального workflow;
- хранение локальной базы состояния оператора.

## Ошибки, которые должен обрабатывать `awgctl`
- SSH alias недоступен;
- серверная backend-команда завершилась ошибкой;
- клиент не найден;
- файл не появился в `/home/<operator_user>/export`;
- `rsync` завершился ошибкой;
- удаление remote-файлов после передачи не удалось.

## Проверки результата этапа
- Зафиксирован интерфейс `awgctl`.
- Зафиксирована модель `sudoers`.
- Зафиксирован локальный каталог `awg_clients/`.
- Зафиксировано использование `ssh` и `rsync`.

## Что считаем успешной работой `awgctl`
### `list-clients`
- оператор получил актуальный список клиентов.

### `add-client`
- клиент создан на сервере;
- файлы получены локально;
- remote-файлы из транзитной зоны удалены.

### `export-client`
- клиент найден;
- файлы получены локально;
- remote-файлы из транзитной зоны удалены.

### `revoke-client`
- клиент отозван;
- статус изменился на `revoked`.

## Ожидаемый итог
Локальная операторская оболочка уже имеет зафиксированный контракт и реализуется без двусмысленности.
