# Первичная инициализация `/etc/amnezia/params`, `/etc/amnezia/amneziawg/awg0.conf` и каталогов

## Цель
Подготовить на новом сервере минимальный рабочий набор файлов и каталогов для `AWG`:
- `/etc/amnezia/params`
- `/etc/amnezia/amneziawg/awg0.conf`
- `/var/lib/amnezia/clients`
- `/var/lib/amnezia/qr`
- `/var/lib/amnezia/state`

Этот этап не дублирует [docs/ServerLayout.md](ServerLayout.md): там зафиксировано, где что должно лежать, а здесь описано, как это создать впервые.

## Входные условия
- Выполнен этап подготовки сервера.
- Выполнен этап bootstrap SSH.
- Выполнен этап сетевой подготовки.
- `AmneziaWG` установлен.
- Есть root-доступ или `sudo`.
- Принят формат из [docs/ServerConfigFormat.md](ServerConfigFormat.md).

## Шаг 1. Создание каталогов
Создаем целевую структуру каталогов.

Команды:
```bash
sudo mkdir -p /etc/amnezia
sudo mkdir -p /etc/amnezia/amneziawg
sudo mkdir -p /var/lib/amnezia/clients
sudo mkdir -p /var/lib/amnezia/qr
sudo mkdir -p /var/lib/amnezia/state
sudo mkdir -p /home/<operator_user>/export
```

## Шаг 2. Выставление прав на каталоги
Сразу задаем ожидаемые права.

Команды:
```bash
sudo chown root:root /etc/amnezia
sudo chown root:root /etc/amnezia/amneziawg
sudo chown -R root:root /var/lib/amnezia

sudo chmod 755 /etc/amnezia
sudo chmod 700 /etc/amnezia/amneziawg
sudo chmod 750 /var/lib/amnezia
sudo chmod 750 /var/lib/amnezia/clients
sudo chmod 750 /var/lib/amnezia/qr
sudo chmod 750 /var/lib/amnezia/state
sudo chown <operator_user>:<operator_user> /home/<operator_user>/export
sudo chmod 700 /home/<operator_user>/export
```

## Шаг 3. Генерация серверных ключей
Генерируем серверный private/public key.

Команды:
```bash
server_private=$(awg genkey)
server_public=$(printf '%s' "$server_private" | awg pubkey)
echo "$server_private"
echo "$server_public"
```

Важно:
- `server_private` записываем только в `/etc/amnezia/params` и `/etc/amnezia/amneziawg/awg0.conf`;
- `server_public` можно использовать в `params` и клиентских конфигах;
- private key не должен попадать в историю shell или посторонние файлы.

## Компрометация `server private key`
Если `server private key` скомпрометирован, считать скомпрометированными все выпущенные клиентские конфиги, которые доверяют старому `SERVER_PUB_KEY`.

Порядок действий:
1. Сгенерировать новый `server_private` и новый `server_public`.
2. Заменить `SERVER_PRIV_KEY` и `SERVER_PUB_KEY` в `/etc/amnezia/params`.
3. Заменить `PrivateKey` в `/etc/amnezia/amneziawg/awg0.conf`.
4. Перезапустить `awg-quick@awg0`.
5. Перевыпустить все клиентские конфиги с новым `SERVER_PUB_KEY`.
6. Передать пользователям новые `.conf` или QR.
7. Старые клиентские конфиги считать недействительными и удалить их из каналов передачи, где это возможно.

Правило:
- замена только `PrivateKey` на сервере без перевыпуска клиентских конфигов не завершает ротацию;
- после смены серверного ключа все клиенты должны получить новый `PublicKey` сервера.

## Шаг 4. Создание `/etc/amnezia/params`
Создаем файл параметров вручную по принятому формату.

Команда:
```bash
sudo vim /etc/amnezia/params
```

Базовое содержимое:
```bash
SERVER_PUB_IP=89.125.209.44
SERVER_PUB_NIC=eth0
SERVER_AWG_NIC=awg0
SERVER_AWG_IPV4=10.66.66.1
SERVER_PORT=443
SERVER_PRIV_KEY=<server_private_key>
SERVER_PUB_KEY=<server_public_key>

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
EXPORT_DIR=/home/<operator_user>/export

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

После сохранения:
```bash
sudo chown root:root /etc/amnezia/params
sudo chmod 600 /etc/amnezia/params
```

## Шаг 5. Создание `/etc/amnezia/amneziawg/awg0.conf`
Создаем серверный конфиг интерфейса `awg0`.

Важно:
- пакетный `awg-quick` читает `awg0` только из `/etc/amnezia/amneziawg/awg0.conf`;
- не нужно создавать отдельный `/etc/amnezia/awg0.conf`;
- symlink для этого пути не используем, храним реальный файл в каталоге `amneziawg`.

Команда:
```bash
sudo mkdir -p /etc/amnezia/amneziawg
sudo vim /etc/amnezia/amneziawg/awg0.conf
```

Базовое содержимое:
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
```

После сохранения:
```bash
sudo chown root:root /etc/amnezia/amneziawg/awg0.conf
sudo chmod 600 /etc/amnezia/amneziawg/awg0.conf
```

## Шаг 6. Создание пустого registry-файла
Готовим реестр клиентов.

Команды:
```bash
sudo touch /var/lib/amnezia/state/clients.tsv
sudo chown root:root /var/lib/amnezia/state/clients.tsv
sudo chmod 640 /var/lib/amnezia/state/clients.tsv
```

## Шаг 7. Проверка согласованности `params` и `awg0.conf`
Проверяем, что ключевые значения совпадают.

Проверки:
```bash
sudo grep '^SERVER_AWG_IPV4=' /etc/amnezia/params
sudo grep '^SERVER_PORT=' /etc/amnezia/params
sudo grep '^SERVER_PRIV_KEY=' /etc/amnezia/params

sudo grep '^Address = ' /etc/amnezia/amneziawg/awg0.conf
sudo grep '^ListenPort = ' /etc/amnezia/amneziawg/awg0.conf
sudo grep '^PrivateKey = ' /etc/amnezia/amneziawg/awg0.conf
```

Что должно совпадать:
- `SERVER_AWG_IPV4` <-> `Address`
- `SERVER_PORT` <-> `ListenPort`
- `SERVER_PRIV_KEY` <-> `PrivateKey`

## Шаг 8. Проверка чтения `params`
Проверить, что файл можно безопасно `source`.

Команда:
```bash
set -a
. /etc/amnezia/params
set +a
printf '%s\n' "$SERVER_PUB_IP" "$SERVER_AWG_NIC" "$CLIENTS_DIR"
```

Ожидаемый результат:
- переменные читаются без ошибок shell.

## Шаг 9. Первичная проверка `awg-quick`
До создания клиентов можно проверить, что конфиг хотя бы читается сервисом.

Проверка:
```bash
sudo awg-quick strip awg0 >/dev/null
```

Если нужен первый запуск:
```bash
sudo systemctl enable awg-quick@awg0
sudo systemctl start awg-quick@awg0
sudo systemctl status awg-quick@awg0 --no-pager
```

Правило:
- если сервис запускается до добавления клиентов, это нормально;
- на этом этапе в `awg0.conf` может быть только `[Interface]`.

## Проверки результата этапа
- Создан `/etc/amnezia/params`.
- Создан `/etc/amnezia/amneziawg/awg0.conf`.
- Созданы `/var/lib/amnezia/clients`, `/var/lib/amnezia/qr`, `/var/lib/amnezia/state`.
- Создан `/var/lib/amnezia/state/clients.tsv`.
- На `params` и `awg0.conf` выставлены права `600`.
- Значения `SERVER_PRIV_KEY`, `SERVER_PORT`, `SERVER_AWG_IPV4` согласованы с `awg0.conf`.

## Ожидаемый итог
Новый сервер готов к дальнейшей автоматизации:
- базовая конфигурация создана;
- структура каталогов и права зафиксированы;
- `awg-add-client` может работать на основе этих файлов без дополнительных ручных действий.
