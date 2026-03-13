# Install Checklist

## Назначение
Документ фиксирует фактический прогон установки на целевом сервере.
Каждый шаг отмечается по результату выполнения.
Все ошибки и их решения записываются в этот же файл.

## Сервер
- Alias: `<server_alias>`
- Hostname: `<server_hostname>`
- OS: `Debian 12`

## Чек-лист
- [x] Подключение по SSH под операторским пользователем
- [x] Проверка группы `sudo`
- [x] Проверка локали `UTF-8`
- [x] Проверка наличия `tmux`
- [x] Проверка и установка базовых пакетов
- [x] Подготовка `tmux`-сессии для установки
- [x] Проверка `sudo`
- [x] Обновление пакетов `apt update`
- [x] Установка зависимостей `curl wget git build-essential dkms libmnl-dev libelf-dev libqrencode-dev pkg-config`
- [x] Отключение IPv6 для `v1`
- [x] Настройка `iptables` и `ip_forward`
- [x] Установка `AmneziaWG`
- [x] Создание `/etc/amnezia`
- [x] Создание `/var/lib/amnezia/{clients,qr,state}`
- [ ] Генерация серверных ключей
- [x] Создание `/etc/amnezia/params`
- [x] Создание `/etc/amnezia/amneziawg/awg0.conf`
- [x] Создание `clients.tsv`
- [x] Установка `awg-add-client` в `/usr/local/bin`
- [x] Установка `awg-list-clients` в `/usr/local/bin`
- [x] Установка `awg-revoke-client` в `/usr/local/bin`
- [x] Запуск `awg-quick@awg0`
- [x] Создание тестового клиента
- [x] Настройка `EXPORT_DIR=/home/<operator_user>/export`
- [x] Проверка выгрузки `.conf` и `.png` в `/home/<operator_user>/export`
- [x] Проверка handshake
- [ ] Проверка выхода клиента в интернет

## Ошибки и решения
- `tmux new -s awgsetup` -> `duplicate session: awgsetup`
  Решение: использовать существующую сессию `tmux attach -t awgsetup`.
- `sudo -v` запросил пароль, первые попытки в общей сессии завершились `Sorry, try again.`
  Решение: выполнить `sudo apt update` и повторно ввести пароль на реальном шаге установки.
- После reboot сессия `awgsetup` отсутствовала.
  Решение: использовать фактически существующую рабочую `tmux`-сессию.
- Для текущего ядра `6.1.0-11-amd64` отсутствовали пакеты `linux-headers-6.1.0-11-amd64`.
  Решение: завершить установку DKMS под новым ядром `6.1.0-43-amd64`, перезагрузить сервер и продолжить на новом ядре.
- `awg-quick strip awg0` не принял `/etc/amnezia/awg0.conf`.
  Решение: зафиксировать реальный пакетный путь `/etc/amnezia/amneziawg/awg0.conf`, перенести конфиг туда и обновить документацию и `awg-*` скрипты.
- Первые экспортные файлы в `/home/<operator_user>/export` создавались с владельцем `root:root`, поэтому получение файлов оператором было неудобно.
  Решение: добавить `EXPORT_DIR` в `/etc/amnezia/params`, обновить `awg-add-client` и выставлять владельца exported-файлов по владельцу каталога `/home/<operator_user>/export`.
- После импорта `client01_test.conf` требовалось подтвердить реальное подключение клиентом.
  Решение: проверить `awg show awg0 latest-handshakes`, `endpoints` и `transfer`; handshake и трафик для клиента `10.66.66.2/32` подтверждены.
