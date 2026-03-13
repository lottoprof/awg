# Размещение файлов и управление AWG на новом сервере

## Цель этапа
Зафиксировать, как именно на новом сервере будут размещены конфигурация, клиентские артефакты, shell-утилиты и systemd-управление `AWG`.

## Входные условия
- Принята базовая структура сервера для `AWG`.
- Принято решение, что `systemd` используется только на системном уровне.
- Принято решение отделить конфигурацию от generated data.

## Принятое размещение
```text
/etc/amnezia/
  params
  amneziawg/
    awg0.conf

/var/lib/amnezia/
  clients/
  qr/
  state/

/home/<operator_user>/
  export/

/usr/local/bin/
  awg-add-client
  awg-export-client
  awg-revoke-client
  awg-list-clients

script_srv/
  awg-add-client
  awg-export-client
  awg-revoke-client
  awg-list-clients

script_client/
  awgctl

awg_clients/
  clientNN_name.conf
  clientNN_name.png
```

## `/etc/amnezia`
Здесь храним только серверную конфигурацию.

Состав:
- `params` — единый файл параметров для shell-автоматизации.
- `amneziawg/awg0.conf` — основной серверный конфиг интерфейса `awg0`.

Здесь не храним:
- клиентские `.conf`;
- QR-коды;
- временные файлы;
- служебные счетчики и generated state.

Важно:
- пакетный `awg-quick` использует путь `/etc/amnezia/amneziawg/<name>.conf`;
- отдельный `/etc/amnezia/awg0.conf` не используем.

## `/var/lib/amnezia`
Здесь храним все generated data и текущее состояние.

Структура:
```text
/var/lib/amnezia/clients
/var/lib/amnezia/qr
/var/lib/amnezia/state
```

Назначение:
- `clients/` — клиентские `.conf`;
- `qr/` — QR-коды;
- `state/` — служебные файлы автоматизации, индексы, реестры, metadata.

Это основное хранилище generated data. Эти каталоги считаются source of truth.

## `/home/<operator_user>/export`
Здесь размещаем только временные копии файлов для передачи оператору.

Правила:
- `export/` не является архивом и не является source of truth;
- после передачи `.conf` и `.png` оператору каталог можно очищать;
- если файл нужно выдать повторно, его заново копируем из `/var/lib/amnezia/clients` и `/var/lib/amnezia/qr`;
- список доступных клиентов оператор сначала смотрит через `awg-list-clients`.

## `/usr/local/bin`
Здесь размещаем операторские shell-команды.

Базовый набор:
- `awg-add-client`
- `awg-export-client`
- `awg-revoke-client`
- `awg-list-clients`

Их исходники в репозитории храним в `script_srv/`.

## `script_srv/`
Здесь храним серверные backend-скрипты до установки на сервер.

## `script_client/`
Здесь храним локальные операторские скрипты рабочего места.

## `awg_clients/`
Здесь на рабочем месте оператора храним полученные клиентские `.conf` и `.png`.

## Systemd
Основной unit управления:
```text
awg-quick@awg0.service
```

Решение:
- `systemd` управляет только серверным интерфейсом `awg0`;
- отдельные unit-файлы для клиентов не создаются;
- клиентский lifecycle управляется shell-автоматизацией.

## Жизненный цикл клиента
Целевая схема:
1. Shell-скрипт генерирует ключи клиента.
2. Shell-скрипт обновляет `/etc/amnezia/amneziawg/awg0.conf`.
3. Пакетный `awg-quick` использует именно `/etc/amnezia/amneziawg/<name>.conf`, поэтому основной серверный конфиг должен лежать в этом каталоге, а не в корне `/etc/amnezia`.
4. Shell-скрипт сохраняет клиентский `.conf` в `/var/lib/amnezia/clients`.
5. Shell-скрипт сохраняет QR в `/var/lib/amnezia/qr`.
6. Для выдачи оператору shell-скрипт копирует `.conf` и `.png` в `/home/<operator_user>/export`.
7. После изменения серверного конфига выполняется:
```bash
systemctl restart awg-quick@awg0
```

## Права доступа
### `/etc/amnezia`
- владелец `root:root`;
- каталог `755`;
- `awg0.conf` и `params` — `600` или `640`.

### `/var/lib/amnezia`
- владелец `root:root`;
- `clients/` — ограниченный доступ для оператора и `root`;
- `qr/` — доступ по необходимости;
- `state/` — закрытый каталог.

### `/usr/local/bin`
- владелец `root:root`;
- права `755`;
- внутри скриптов обязательна проверка запуска через `sudo` или под `root`.

## Что фиксируем как правило
- Конфигурация живет в `/etc/amnezia`.
- Клиентские файлы и state живут в `/var/lib/amnezia`.
- Операторские команды живут в `/usr/local/bin`.
- `systemd` управляет только `awg-quick@awg0.service`.
- Клиенты не являются отдельными systemd-сущностями.

## Проверки результата этапа
- Зафиксирована целевая структура каталогов нового сервера.
- Зафиксировано место хранения `awg0.conf` и `params`.
- Зафиксировано место хранения клиентских `.conf`, QR и state.
- Зафиксировано, что `/home/<operator_user>/export` является временным delivery buffer, а не основным хранилищем.
- Зафиксирована роль `awg-quick@awg0.service`.
- Зафиксировано отсутствие отдельных unit-файлов на клиентов.

## Ожидаемый итог
Следующие документы и shell-автоматизация будут строиться уже по целевой структуре нового сервера, а не по текущей реализации на существующем хосте.

## Следующий этап
После этого этапа логично оформить документ по управлению клиентами:
- как должен работать `add-awg-client`;
- как обновлять `awg0.conf`;
- как хранить client registry и state;
- когда делать `systemctl restart awg-quick@awg0`.
