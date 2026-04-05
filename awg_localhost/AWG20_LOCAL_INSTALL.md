# Локальная установка AmneziaWG с упором на AWG 2.0

## Цель
Подготовить локальную Linux-машину оператора к работе с `AWG 2.0`.

Сценарий начинается с установки kernel module и затем разделяет два состояния:
- модуль еще не установлен;
- модуль уже работает, но userspace tools остаются слишком старыми для `AWG 2.0`.

## Когда использовать этот документ
Этот документ нужен для локальной машины, если требуется:
- поднять `AmneziaWG` на ноутбуке или workstation;
- проверить поддержку `AWG 2.0` до переноса решения на сервер;
- отделить проблему kernel module от проблемы `amneziawg-tools`.

## Что уже установлено в проекте
- `DKMS` сам по себе не является главным блокером перехода на `AWG 2.0`.
- На практике модуль собирался корректно, а проблема оставалась в старом `amneziawg-tools`.
- Пакетные tools уровня `amneziawg-tools v1.0.20210914` не покрывают параметры `AWG 2.0`.
- Рациональный порядок для локалки:
  1. сначала добиться рабочего kernel module;
  2. затем проверить userspace tools;
  3. если tools старые, собрать их из upstream GitHub;
  4. только потом проверять `S3/S4/I*` на временном интерфейсе.

Подтверждающий контекст:
- `.agent/plans/active/awg2-upgrade-todo.md`
- `docs/AmneziaWGInstall.md`
- `docs/AmneziaWGManualBuild.md`

## Шаг 1. Проверка текущего состояния локалки
Команды:
```bash
uname -r
dkms status | grep amneziawg || true
modinfo amneziawg | head || true
which awg || true
which awg-quick || true
awg --version || true
```

Что фиксируем:
- установлен ли модуль `amneziawg`;
- есть ли `awg` и `awg-quick`;
- какая версия userspace tools сейчас используется.

## Шаг 2. Установка зависимостей
Если локальная машина еще не подготовлена, установить минимальный набор зависимостей.

Команды:
```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) libmnl-dev libelf-dev libqrencode-dev pkg-config curl wget
```

Проверка:
```bash
dpkg -l | grep -E 'git|dkms|build-essential|libmnl-dev|libelf-dev|libqrencode-dev|pkg-config|curl|wget'
dpkg -l | grep "linux-headers-$(uname -r)"
```

## Шаг 3. Основной путь: установка модуля пакетным способом
Сначала попытаться привести локальную машину в рабочее состояние через пакетный путь.

Команды:
```bash
sudo apt install -y software-properties-common python3-launchpadlib gnupg2
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/amnezia-ppa.list
echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list.d/amnezia-ppa.list
sudo apt update
sudo apt install -y amneziawg
```

Проверка:
```bash
sudo modprobe amneziawg
lsmod | grep -E 'amneziawg|wireguard'
dkms status | grep amneziawg
which awg
which awg-quick
```

Ожидаемый результат:
- модуль загружается через `modprobe`;
- `dkms status` показывает сборку под текущее ядро;
- в системе появились `awg` и `awg-quick`.

## Шаг 4. Fallback: ручная установка kernel module
Если пакетный путь не дал рабочего модуля, переходить к ручной сборке.

Команды:
```bash
sudo mkdir -p /root/awg-build
cd /root/awg-build
sudo rm -rf amneziawg-linux-kernel-module
sudo git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
cd amneziawg-linux-kernel-module/src
make
sudo make install
sudo modprobe amneziawg
```

Альтернативный вариант через `DKMS`:
```bash
sudo make dkms-install
sudo dkms add -m amneziawg -v 1.0.0
sudo dkms build -m amneziawg -v 1.0.0
sudo dkms install -m amneziawg -v 1.0.0
```

Проверка:
```bash
lsmod | grep -E 'amneziawg|wireguard'
dkms status | grep amneziawg || true
```

Правило:
- пока нет рабочего kernel module, к `AWG 2.0` переходить рано;
- сначала локальная машина должна стабильно поднимать сам `amneziawg`.

## Шаг 5. Разделение module vs tools
После того как модуль уже работает, определить, действительно ли оставшаяся проблема находится в userspace tools.

Команды:
```bash
modinfo amneziawg | head
dkms status | grep amneziawg
awg --version
```

Смысл интерпретации:
- если `modprobe amneziawg` и `dkms status` в порядке, но `awg --version` остается на старой ветке `v1.0.20210914`, локальный переход к `AWG 2.0` упирается уже не в модуль, а в tools.

## Шаг 6. Сборка upstream amneziawg-tools из GitHub
Если модуль рабочий, а tools старые, заменить только userspace tools.

Команды:
```bash
cd /root/awg-build
sudo rm -rf amneziawg-tools
sudo git clone https://github.com/amnezia-vpn/amneziawg-tools.git
cd amneziawg-tools/src
make
sudo make install
hash -r
```

Проверка:
```bash
which awg
which awg-quick
awg --version
awg-quick --version
```

Ожидаемый смысл:
- локальная машина использует upstream tools;
- userspace-часть больше не ограничена старым пакетом из репозитория.

## Шаг 7. Безопасный тест поддержки AWG 2.0
Проверять поддержку `AWG 2.0` не на рабочих `awg0/awg1/awg2`, а на временном интерфейсе.

Пример `/tmp/awgtest0.conf`:
```ini
[Interface]
PrivateKey = <test_private_key>
Address = 10.200.0.1/32
Jc = 6
Jmin = 50
Jmax = 1000
S1 = 40
S2 = 79
S3 = 10
S4 = 20
H1 = 1:5
H2 = 6:10
H3 = 11:15
H4 = 16:20

[Peer]
PublicKey = <test_peer_public_key>
PresharedKey = <test_psk>
AllowedIPs = 10.200.0.2/32
I1 = 21
I2 = 22
I3 = 23
I4 = 24
```

Команды:
```bash
sudo ip link add awgtest0 type amneziawg
sudo awg setconf awgtest0 <(sudo awg-quick strip /tmp/awgtest0.conf)
sudo awg show awgtest0
sudo ip link del awgtest0
```

Положительный результат:
- `awg setconf` завершается без ошибки;
- `awg show awgtest0` не сводится к legacy-only полям.

Отрицательный результат:
- `Unable to modify interface: Invalid argument`;
- `awg show` по-прежнему показывает только legacy-поля.

Если результат отрицательный:
- считать, что только обновления tools недостаточно;
- отдельно исследовать необходимость пересборки `amneziawg-linux-kernel-module` из upstream.

## Шаг 8. Контроль legacy-сценария
После обновления tools проверить, что текущая локальная схема не сломалась.

Команды:
```bash
sudo systemctl status awg-quick@awg0 --no-pager || true
sudo awg show awg0 || true
```

Что проверяем:
- существующий рабочий интерфейс продолжает жить;
- переход к `AWG 2.0` не ломает текущий legacy-сценарий.

## Ожидаемый итог
Локальная машина приведена к состоянию, в котором:
- kernel module установлен и загружается;
- userspace tools при необходимости заменены на upstream GitHub build;
- проверка `AWG 2.0` выполняется безопасно на временном интерфейсе;
- только после успешного локального теста есть смысл переносить решение на сервер.
