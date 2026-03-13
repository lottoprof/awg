# Ручная сборка AmneziaWG как fallback

## Цель этапа
Установить `AmneziaWG` по резервному сценарию `B`, если пакетный путь не сработал: вручную собрать kernel module и при необходимости пользовательские утилиты, затем проверить загрузку модуля и доступность `awg`/`awg-quick`.

## Входные условия
- Выполнен этап из [docs/ServerPreparation.md](/home/az/git/awg/docs/ServerPreparation.md).
- Выполнен этап из [docs/BootstrapSSH.md](/home/az/git/awg/docs/BootstrapSSH.md).
- Выполнен этап из [docs/NetworkBase.md](/home/az/git/awg/docs/NetworkBase.md).
- Основной сценарий из [docs/AmneziaWGInstall.md](/home/az/git/awg/docs/AmneziaWGInstall.md) не сработал или признан неподходящим.
- Есть рабочий вход по SSH новым административным пользователем.
- Пользователь может выполнять `sudo`.
- Целевая ОС: `Debian 12`.

## Источник исходников
- kernel module:
  `https://github.com/amnezia-vpn/amneziawg-linux-kernel-module`
- userspace tools:
  `https://github.com/amnezia-vpn/amneziawg-tools`

## Параметры этапа
Перед началом зафиксируйте:
- текущую версию ядра;
- наличие `linux-headers-$(uname -r)`;
- наличие полного kernel source tree, если ядро `5.6+`;
- рабочий каталог для сборки, например `/root/awg-build` или `/tmp/awg-build`.

## Шаг 1. Проверка версии ядра
Команда:
```bash
uname -r
```

Ожидаемый результат:
- вы знаете точную версию текущего ядра.

## Шаг 2. Установка зависимостей для сборки
Устанавливаем минимальный набор пакетов для ручной сборки.

Команда:
```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) libmnl-dev libelf-dev libqrencode-dev pkg-config curl wget
```

Проверка:
```bash
dpkg -l | grep -E 'git|dkms|build-essential|libmnl-dev|libelf-dev|libqrencode-dev|pkg-config|curl|wget'
dpkg -l | grep "linux-headers-$(uname -r)"
```

## Шаг 3. Подготовка рабочего каталога
Переходим в каталог временной сборки.

Команды:
```bash
mkdir -p /root/awg-build
cd /root/awg-build
```

## Шаг 4. Загрузка исходников kernel module
Команды:
```bash
git clone https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git
cd amneziawg-linux-kernel-module/src
```

## Шаг 5. Проверка требования к kernel source tree
Официальный README предупреждает, что на современных ядрах `5.6+` может понадобиться полный source tree, а не только headers.

Проверка:
```bash
uname -r
```

Если вы работаете на современном ядре:
- подготовьте полный source tree ядра;
- создайте символическую ссылку `kernel` в каталоге сборки.

Пример:
```bash
ln -s /path/to/kernel/source kernel
```

Примечание:
- здесь нужен полный source tree, а не только `/usr/src/linux-headers-*`.

## Шаг 6. Ручная сборка kernel module
Базовый вариант сборки:

Команды:
```bash
make
sudo make install
```

Альтернативный вариант через DKMS:
```bash
sudo make dkms-install
sudo dkms add -m amneziawg -v 1.0.0
sudo dkms build -m amneziawg -v 1.0.0
sudo dkms install -m amneziawg -v 1.0.0
```

Примечание:
- версию `1.0.0` используйте только если она соответствует фактической версии исходников;
- при расхождении версии сначала уточните ее в исходниках проекта.

## Шаг 7. Проверка загрузки kernel module
Команда:
```bash
sudo modprobe amneziawg
```

Проверка:
```bash
lsmod | grep -E 'amneziawg|wireguard'
```

Ожидаемый результат:
- модуль `amneziawg` присутствует в системе.

## Шаг 8. Проверка, нужны ли отдельные userspace tools
Если после установки модуля команды `awg` и `awg-quick` отсутствуют, соберите их отдельно.

Проверка:
```bash
which awg
which awg-quick
```

Если утилиты не найдены, переходите к следующему шагу.

## Шаг 9. Загрузка и сборка amneziawg-tools
Команды:
```bash
cd /root/awg-build
git clone https://github.com/amnezia-vpn/amneziawg-tools.git
cd amneziawg-tools/src
make
sudo make install
```

## Шаг 10. Проверка userspace tools
Команды:
```bash
which awg
which awg-quick
```

Ожидаемый результат:
```text
/usr/bin/awg
/usr/bin/awg-quick
```

Дополнительная проверка:
```bash
awg --version
awg-quick --version
```

## Шаг 11. Контрольная диагностика
После ручной установки проверьте, что модуль и утилиты действительно готовы к использованию.

Команды:
```bash
dkms status
sudo dmesg | tail -n 100
```

Что проверяем:
- нет ошибок сборки модуля;
- нет ошибок загрузки `amneziawg`;
- нет явной несовместимости с текущим ядром.

## Проверки результата этапа
- Установлены зависимости для сборки.
- Исходники kernel module загружены.
- При необходимости подключен полный kernel source tree.
- Модуль `amneziawg` собран и загружается.
- Утилиты `awg` и `awg-quick` доступны.

## Ожидаемый итог
Даже без пакетного сценария сервер приведен к рабочему состоянию для дальнейшей настройки `AWG`:
- модуль ядра установлен;
- userspace tools установлены;
- можно переходить к созданию серверного конфига.

## Следующий этап
После этого этапа переходим к настройке серверного конфига `AWG`:
- генерация ключей;
- создание `awg0.conf`;
- запуск `awg-quick@awg0`;
- проверка интерфейса и handshake.
