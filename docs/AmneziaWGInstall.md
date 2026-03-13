# Установка AmneziaWG на Debian 12

## Цель этапа
Установить `AmneziaWG` на сервер `Debian 12` по основному сценарию `A`: через официальный пакетный путь, проверить наличие модуля ядра и утилит `awg`/`awg-quick`, а также подготовить переход к настройке серверного конфига.

## Входные условия
- Выполнен этап из [docs/ServerPreparation.md](/home/az/git/awg/docs/ServerPreparation.md).
- На раннем этапе еще допустима работа под `root`.
- Целевая ОС: `Debian 12`.
- Для первой версии выбран основной сценарий установки через пакетный путь.

Важно:
- для `v1` этот этап лучше выполнять как можно раньше, еще до изменения `sshd` и до полного bootstrap;
- если установка требует нового ядра, reboot должен происходить сразу на этом этапе.

## Источник установки
Основной сценарий основан на официальном репозитории модуля ядра AmneziaWG:
- `https://github.com/amnezia-vpn/amneziawg-linux-kernel-module`

Утилиты `awg` и `awg-quick` относятся к проекту:
- `https://github.com/amnezia-vpn/amneziawg-tools`

## Параметры этапа
Перед началом зафиксируйте:
- текущую версию ядра;
- наличие `deb-src` в `APT`;
- достаточное место на диске и в `/tmp`.

## Шаг 1. Проверка текущего ядра
Сначала фиксируем версию ядра, под которую будут нужны заголовки.

Команда:
```bash
uname -r
```

Ожидаемый результат:
- выводит текущую версию ядра, например `6.1.0-30-amd64`.

## Шаг 2. Обновление пакетов системы
Перед установкой `AmneziaWG` подтягиваем свежие пакеты и сразу допускаем ранний reboot, если изменилось ядро.

Команды:
```bash
sudo apt update
sudo apt upgrade -y
```

Примечание:
- если после обновления появился новый kernel package, лучше reboot сделать сразу, а не переносить его на поздний этап.

## Шаг 3. Решение по ядру и backports
Если на сервере есть проблемы с headers или совместимостью модуля, используем более свежее ядро и заголовки из `bookworm-backports`.

Для `v1` принимаем правило:
- если есть сомнение по совместимости, ядро лучше нормализовать сразу;
- старое ядро не считаем хорошей базой для fallback manual build.

Команды:
```bash
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt update
sudo apt install -t bookworm-backports linux-image-amd64 linux-headers-amd64 -y
```

После обновления ядра:
```bash
sudo reboot
```

Проверка после входа:
```bash
uname -r
```

## Шаг 4. Проверка source repositories
Официальная инструкция для Debian требует, чтобы в `APT` были включены source repositories.

Проверка:
```bash
grep -R '^deb-src ' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null
```

Ожидаемый результат:
- найден хотя бы один активный `deb-src`.

Если `deb-src` отсутствует:
- включите source repositories вручную в файлах `APT`;
- затем выполните:
```bash
sudo apt update
```

## Шаг 5. Установка зависимостей пакетного сценария
Устанавливаем зависимости, указанные в официальной инструкции для Debian, и набор build packages, который уже используется в ручной практике.

Команда:
```bash
sudo apt install -y software-properties-common python3-launchpadlib gnupg2 linux-headers-$(uname -r) git build-essential dkms libmnl-dev libelf-dev libqrencode-dev pkg-config curl wget
```

Проверка:
```bash
dpkg -l | grep -E 'software-properties-common|python3-launchpadlib|gnupg2|git|build-essential|dkms|libmnl-dev|libelf-dev|libqrencode-dev|pkg-config|curl|wget'
dpkg -l | grep "linux-headers-$(uname -r)"
```

## Шаг 6. Добавление ключа и репозитория Amnezia
Добавляем ключ и пакетный источник, указанный в официальной инструкции для Debian.

Команды:
```bash
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee /etc/apt/sources.list.d/amnezia-ppa.list
echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" | sudo tee -a /etc/apt/sources.list.d/amnezia-ppa.list
sudo apt update
```

Проверка:
```bash
cat /etc/apt/sources.list.d/amnezia-ppa.list
apt-cache policy amneziawg
```

Ожидаемый результат:
- `amneziawg` виден в `apt-cache policy`.

## Шаг 7. Установка пакета AmneziaWG
Устанавливаем основной пакет.

Команда:
```bash
sudo apt install -y amneziawg
```

Примечание:
- если в процессе установки обновляется DKMS-модуль, дождитесь полного завершения сборки;
- если установка завершилась ошибкой на этапе DKMS, не переходите сразу к fallback;
- сначала проверьте, не требуется ли более новое ядро и корректные headers;
- только после нормализации ядра и повторной попытки переходите к fallback-сценарию из [docs/AmneziaWGManualBuild.md](/home/az/git/awg/docs/AmneziaWGManualBuild.md).

## Шаг 8. Проверка загрузки модуля ядра
После установки проверяем, что модуль доступен ядру.

Команда:
```bash
sudo modprobe amneziawg
```

Проверка:
```bash
lsmod | grep -E 'amneziawg|wireguard'
```

Ожидаемый результат:
- в выводе есть `amneziawg`;
- при наличии CPU-specific crypto модулей могут быть строки вроде `curve25519_x86_64`, `libchacha20poly1305`.

## Шаг 9. Проверка пользовательских утилит
Проверяем, что установлены CLI-утилиты.

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

## Шаг 10. Проверка systemd-окружения
На этом этапе достаточно убедиться, что сервер готов к запуску `awg-quick@...` после появления конфига.

Проверка:
```bash
systemctl list-unit-files | grep awg
```

Ожидаемый результат:
- могут появиться unit-файлы, связанные с `awg-quick`;
- если unit пока не виден, это не блокирует этап, пока есть `awg-quick`.

## Шаг 11. Контрольная проверка после установки
Убедитесь, что пакетная установка завершилась без скрытых проблем.

Команды:
```bash
dkms status
sudo dmesg | tail -n 50
```

Что проверяем:
- есть запись про установленный модуль `amneziawg`, если он ставился через DKMS;
- нет явных ошибок про несовместимость модуля с текущим ядром.

Если `dkms status` показывает сборку под другим ядром, а не под текущим `uname -r`:
- это не считаем успешным завершением этапа;
- нужно reboot в новое ядро и повторная проверка `modprobe amneziawg`.

## Проверки результата этапа
- Текущее ядро определено.
- Source repositories включены.
- Установлены зависимости пакетного сценария.
- Добавлен пакетный источник Amnezia.
- Пакет `amneziawg` установлен.
- Модуль `amneziawg` загружается через `modprobe`.
- Команды `awg` и `awg-quick` доступны в системе.

## Ожидаемый итог
Сервер готов к следующему этапу настройки `AWG`:
- модуль установлен;
- пользовательские утилиты установлены;
- можно переходить к созданию серверного конфига и запуску интерфейса.

## Fallback на вариант B
Если основной сценарий не сработал, переходите к [docs/AmneziaWGManualBuild.md](/home/az/git/awg/docs/AmneziaWGManualBuild.md).

Типовые причины перехода на fallback:
- пакет `amneziawg` недоступен через `APT`;
- сборка DKMS завершилась ошибкой;
- `modprobe amneziawg` не находит модуль;
- текущая версия ядра требует ручной работы с source tree;
- пакетный путь не совместим с окружением VPS.

Порядок принятия решения:
1. Проверить kernel/headers.
2. Если нужно, обновить ядро и reboot.
3. Повторить пакетную установку.
4. Только после этого переходить в manual build.
