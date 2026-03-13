# Формат `/etc/amnezia/amneziawg/awg0.conf` и `/etc/amnezia/params`

## Цель этапа
Зафиксировать целевой формат двух основных серверных файлов:
- `/etc/amnezia/amneziawg/awg0.conf`
- `/etc/amnezia/params`

Эти файлы являются источником истины для работы `AWG` и shell-автоматизации.

## Входные условия
- Принята структура из [docs/ServerLayout.md](/home/az/git/awg/docs/ServerLayout.md).
- Принята модель управления клиентами из [docs/ClientManagement.md](/home/az/git/awg/docs/ClientManagement.md).
- `awg-quick@awg0.service` является основным unit управления.

## Назначение файлов
### `/etc/amnezia/amneziawg/awg0.conf`
Это рабочий конфиг интерфейса `awg0`, который использует `awg-quick@awg0`.

Важно:
- пакетный `awg-quick` из `AmneziaWG` жестко ищет конфиг по пути `/etc/amnezia/amneziawg/<name>.conf`;
- поэтому для `awg0` основной путь должен быть `/etc/amnezia/amneziawg/awg0.conf`;
- использование отдельного файла `/etc/amnezia/awg0.conf` не допускается.

Он содержит:
- секцию `[Interface]`;
- серверные ключи;
- сетевые параметры интерфейса;
- параметры обфускации;
- список `[Peer]` для клиентов.

### `/etc/amnezia/params`
Это машинно-читаемый файл параметров для shell-скриптов.

Он содержит:
- сетевые переменные;
- DNS;
- публичный IP сервера;
- параметры обфускации;
- правила генерации клиентских конфигов;
- имена интерфейсов и каталогов.

## Формат `/etc/amnezia/amneziawg/awg0.conf`
Принятый шаблон:

```ini
[Interface]
Address = 10.66.66.1/24
ListenPort = 443
PrivateKey = <server_private_key>
Jc = 6
Jmin = 50
Jmax = 1000
S1 = 40
S2 = 79
H1 = 760714308
H2 = 342415505
H3 = 91894224
H4 = 675799984

[Peer]
# client01_anna
PublicKey = <client_public_key>
PresharedKey = <client_psk>
AllowedIPs = 10.66.66.2/32
```

## Правила для `/etc/amnezia/amneziawg/awg0.conf`
- В файле только один `[Interface]`.
- Серверный адрес фиксирован в CIDR-формате.
- `ListenPort` должен соответствовать `SERVER_PORT` в `params`.
- `PrivateKey` хранится только здесь и не дублируется в открытых generated files.
- Каждый клиент добавляется отдельным `[Peer]`.
- Над каждым `[Peer]` должна быть строка-комментарий с `client_id`.
- `AllowedIPs` клиента всегда имеет формат `/32`.

## Шаблон клиентского конфига
Клиентский `.conf`, который генерирует `awg-add-client`, должен иметь такой формат:

```ini
[Interface]
PrivateKey = <client_private_key>
Address = 10.66.66.2/32
DNS = 1.1.1.1,8.8.8.8
Jc = 6
Jmin = 50
Jmax = 1000
S1 = 40
S2 = 79
H1 = 760714308
H2 = 342415505
H3 = 91894224
H4 = 675799984

[Peer]
PublicKey = <server_public_key>
PresharedKey = <client_psk>
Endpoint = 89.125.209.44:443
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 0
```

Правила:
- `PrivateKey` клиента уникален для каждого клиента;
- `PublicKey` сервера должен соответствовать `SERVER_PUB_KEY`;
- `Endpoint` собирается из `SERVER_PUB_IP` и `SERVER_PORT`;
- `AllowedIPs` клиента берется из `ALLOWED_IPS`.

## Формат `/etc/amnezia/params`
Принятый шаблон:

```bash
SERVER_PUB_IP=89.125.209.44
SERVER_PUB_NIC=eth0
SERVER_AWG_NIC=awg0
SERVER_AWG_IPV4=10.66.66.1
SERVER_PORT=443
SERVER_PRIV_KEY=
SERVER_PUB_KEY=

CLIENT_DNS_1=1.1.1.1
CLIENT_DNS_2=8.8.8.8
STORE_CLIENT=y
USE_NFTABLES=n
ALLOWED_IPS=0.0.0.0/0
KEEPALIVE=0

CLIENTS_DIR=/var/lib/amnezia/clients
QR_DIR=/var/lib/amnezia/qr
STATE_DIR=/var/lib/amnezia/state
REGISTRY_FILE=/var/lib/amnezia/state/clients.tsv
EXPORT_DIR=/home/awgesrv/export

SERVER_AWG_JC=6
SERVER_AWG_JMIN=50
SERVER_AWG_JMAX=1000
SERVER_AWG_S1=40
SERVER_AWG_S2=79
SERVER_AWG_H1=760714308
SERVER_AWG_H2=342415505
SERVER_AWG_H3=91894224
SERVER_AWG_H4=675799984
```

## Правила для `/etc/amnezia/params`
- Формат только `KEY=value`.
- Без пробелов вокруг `=`.
- Без shell-логики, условий и команд.
- Значения должны быть пригодны для прямого `source`.
- Все пути должны быть абсолютными.
- Все сетевые параметры из `params` должны совпадать с тем, что реально используется в `awg0.conf`.
- `SERVER_PUB_IP` используется как endpoint для клиентских конфигов.

## Какие переменные обязательны
- `SERVER_PUB_IP`
- `SERVER_PUB_NIC`
- `SERVER_AWG_NIC`
- `SERVER_AWG_IPV4`
- `SERVER_PORT`
- `SERVER_PRIV_KEY`
- `SERVER_PUB_KEY`
- `CLIENT_DNS_1`
- `CLIENT_DNS_2`
- `STORE_CLIENT`
- `USE_NFTABLES`
- `ALLOWED_IPS`
- `KEEPALIVE`
- `CLIENTS_DIR`
- `QR_DIR`
- `STATE_DIR`
- `REGISTRY_FILE`
- `EXPORT_DIR`
- `SERVER_AWG_JC`
- `SERVER_AWG_JMIN`
- `SERVER_AWG_JMAX`
- `SERVER_AWG_S1`
- `SERVER_AWG_S2`
- `SERVER_AWG_H1`
- `SERVER_AWG_H2`
- `SERVER_AWG_H3`
- `SERVER_AWG_H4`

## Что читают скрипты
### `awg-add-client`
Читает:
- `/etc/amnezia/params`
- `/etc/amnezia/amneziawg/awg0.conf`

Пишет:
- новый `[Peer]` в `/etc/amnezia/amneziawg/awg0.conf`
- клиентский `.conf`
- QR
- `clients.tsv`

Использует:
- `SERVER_PUB_IP` как endpoint в клиентском конфиге;
- `SERVER_PUB_KEY` и `SERVER_PRIV_KEY`, если они заданы в `params`.

### `awg-export-client`
Читает:
- `/etc/amnezia/params`
- `/var/lib/amnezia/state/clients.tsv`

Пишет:
- копию клиентского `.conf` в `EXPORT_DIR`
- копию QR в `EXPORT_DIR`, если QR существует

## Проверки результата этапа
- Зафиксирован формат `/etc/amnezia/amneziawg/awg0.conf`.
- Зафиксирован формат `/etc/amnezia/params`.
- Зафиксирован список обязательных переменных.
- Зафиксировано соответствие между `params` и `awg0.conf`.

## Ожидаемый итог
Формат серверных файлов зафиксирован, и на его основе уже можно поддерживать shell-автоматизацию без двусмысленности.

## Следующий этап
После этого этапа логично:
- синхронизировать все `awg-*` скрипты с template-файлами;
- добавить команды и шаблоны в каркас развертывания;
- при необходимости подготовить документ по первичной инициализации этих файлов на новом сервере.
