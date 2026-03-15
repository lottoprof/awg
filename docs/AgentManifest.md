# Единый входной манифест для AI-агента

## Цель
Зафиксировать единый набор входных параметров и правил по умолчанию, чтобы AI-агент не собирал их по частям из нескольких документов.

## Назначение
Этот документ является стартовой точкой для агента перед чтением остальных operational docs.

Агент должен:
- сначала заполнить или получить значения из этого манифеста;
- затем подставлять их в команды, шаблоны и проверки;
- не переопределять значения по контексту других документов без явного правила.

## Базовая модель
Для `v1` принимается:
- один VPS;
- один сервер `AWG`;
- `Debian 12`;
- `IPv4-only`;
- `iptables`;
- один операторский пользователь на сервере;
- один локальный операторский CLI `awgctl`.

## Правило имен пользователей
По умолчанию:
```text
admin_user == operator_user
```

Это значит:
- пользователь, который создается на этапе `BootstrapSSH`, является тем же пользователем, который использует `sudoers` для `awg-*` backend-команд;
- каталог `/home/<operator_user>/export` создается в домашнем каталоге этого же пользователя.

Если в конкретной установке нужно развести роли:
```text
admin_user != operator_user
```

это нужно зафиксировать явно до начала установки.

Для `v1` раздельная схема не считается значением по умолчанию.

## Обязательные входные параметры
```yaml
server_ip: ""
server_hostname: ""
server_alias: ""

admin_user: ""
operator_user: ""
admin_temp_password: ""
public_key_path: ""

ssh_port: 22
ssh_change_port: false

server_iface: "auto"
server_public_nic: "auto"
awg_iface: "awg0"
awg_port: 443
awg_ipv4: "10.66.66.1/24"

client_dns_1: "1.1.1.1"
client_dns_2: "8.8.8.8"
allowed_ips: "0.0.0.0/0"
keepalive: 0

use_ipv6: false
use_nftables: false
store_client: true

clients_dir: "/var/lib/amnezia/clients"
qr_dir: "/var/lib/amnezia/qr"
state_dir: "/var/lib/amnezia/state"
registry_file: "/var/lib/amnezia/state/clients.tsv"
export_dir: "/home/<operator_user>/export"

server_awg_jc: 6
server_awg_jmin: 50
server_awg_jmax: 1000
server_awg_s1: 40
server_awg_s2: 79
server_awg_h1: 760714308
server_awg_h2: 342415505
server_awg_h3: 91894224
server_awg_h4: 675799984
```

## Обязательные правила интерпретации
### `server_alias`
- SSH alias для рабочего места оператора.
- Используется в `awgctl`.
- Для `v1` считается уже созданным вручную в `~/.ssh/config`.
- Агент не должен автоматически модифицировать `~/.ssh/config`, если это не оговорено отдельно.

### `server_ip`
- Публичный IPv4 сервера.
- Используется как `SERVER_PUB_IP`.

### `server_hostname`
- Системное имя узла.
- Не используется в `awg0.conf`, но используется в inventory и проверках.

### `admin_user`
- Пользователь для административного SSH-доступа.

### `admin_temp_password`
- Временный пароль административного пользователя на этап установки.
- Используется только для bootstrap и локальных `sudo`-операций.
- После завершения установки пользователь должен сменить этот пароль вручную.

### `operator_user`
- Пользователь, от имени которого работает `awgctl` через `sudoers`.
- По умолчанию равен `admin_user`.

### `public_key_path`
- Путь к публичному SSH-ключу оператора на локальной машине.

### `ssh_port`
- Порт SSH.
- По умолчанию `22`.
- Если `ssh_change_port=false`, агент должен оставить `22`.

### `server_iface` и `server_public_nic`
- Для `v1` считаются одним и тем же внешним сетевым интерфейсом.
- Если задано `auto`, агент должен определить интерфейс командой:
```bash
ip route get 1.1.1.1
```
- Из вывода нужно взять значение после `dev`.

### `awg_iface`
- Имя VPN-интерфейса.
- Для `v1` по умолчанию `awg0`.

### `awg_port`
- UDP-порт `AWG`.

### `awg_ipv4`
- Адрес сервера внутри туннеля в формате CIDR.
- Для `params` агент должен использовать только IP-часть без маски.
- Для `awg0.conf` агент должен использовать полное значение с маской.

### `use_ipv6`
- Для `v1` всегда `false`.
- Если `false`, агент должен:
  - не добавлять IPv6 в `params`;
  - не добавлять `::/0` в `ALLOWED_IPS`;
  - отключать IPv6 на сервере по [docs/NetworkBase.md](NetworkBase.md).

### `use_nftables`
- Для `v1` всегда `false`.
- Если `false`, агент должен использовать `iptables`.

### `store_client`
- Для `v1` всегда `true`.
- Соответствует `STORE_CLIENT=y`.

## Правило по параметрам obfuscation
Для `v1` параметры:
- `Jc`
- `Jmin`
- `Jmax`
- `S1`
- `S2`
- `H1`
- `H2`
- `H3`
- `H4`

считаются фиксированными константами установки.

Правило:
- агент не должен генерировать их случайно;
- агент должен использовать значения из манифеста буквально;
- если нужно поменять эти значения, их меняют в манифесте до начала установки.

## Производные значения
Из манифеста агент должен собирать:

### `/etc/amnezia/params`
```bash
SERVER_PUB_IP=<server_ip>
SERVER_PUB_NIC=<server_public_nic>
SERVER_AWG_NIC=<awg_iface>
SERVER_AWG_IPV4=<awg_ipv4 without CIDR mask>
SERVER_PORT=<awg_port>
CLIENT_DNS_1=<client_dns_1>
CLIENT_DNS_2=<client_dns_2>
STORE_CLIENT=y
USE_NFTABLES=n
ALLOWED_IPS=<allowed_ips>
KEEPALIVE=<keepalive>
CLIENTS_DIR=<clients_dir>
QR_DIR=<qr_dir>
STATE_DIR=<state_dir>
REGISTRY_FILE=<registry_file>
EXPORT_DIR=<export_dir>
```

### `/etc/amnezia/amneziawg/awg0.conf`
```ini
[Interface]
Address = <awg_ipv4>
ListenPort = <awg_port>
PrivateKey = <server_private_key>
```

### `awgctl`
- `AWGCTL_HOST=<server_alias>`
- `AWGCTL_OUTPUT_DIR=./awg_clients`
- `AWGCTL_REMOTE_EXPORT_DIR=<export_dir>`

## Правила по умолчанию для агента
- Если параметр обязателен и не заполнен, агент должен остановить применение и запросить значение.
- Если параметр имеет default, агент должен использовать default без догадки.
- Если документ использует placeholder, агент должен сначала искать соответствие в этом манифесте.
- Если в других документах встречается конфликт с манифестом, приоритет у манифеста.

## Связь с другими документами
- SSH-параметры: [docs/BootstrapSSH.md](BootstrapSSH.md)
- Сетевые параметры: [docs/NetworkBase.md](NetworkBase.md)
- Формат `params` и `awg0.conf`: [docs/ServerConfigFormat.md](ServerConfigFormat.md)
- Инициализация сервера: [docs/ServerConfigInit.md](ServerConfigInit.md)
- Операторский workflow: [docs/OperatorWorkflow.md](OperatorWorkflow.md)
- Локальный CLI: [docs/Awgctl.md](Awgctl.md)

## Проверки результата этапа
- Зафиксирован единый набор входных параметров.
- Зафиксировано правило `admin_user == operator_user` по умолчанию.
- Зафиксированы defaults для `ssh_port`, `iptables`, `IPv4-only`.
- Зафиксировано, что obfuscation-параметры для `v1` не генерируются случайно.

## Ожидаемый итог
AI-агент получает один документ, в котором собраны обязательные входные значения, правила их интерпретации и defaults для `v1`.
