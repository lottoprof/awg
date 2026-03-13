# Сетевое основание сервера для AWG

## Цель
Подготовить сетевую основу сервера для дальнейшего запуска `AWG`: включить `ip_forward`, настроить firewall на `iptables`, разрешить нужные входящие подключения, включить маршрутизацию и `NAT`, а также сохранить правила между перезагрузками.

Правила порядка:
- этот этап идет уже после ранней проверки `AmneziaWG` и после `BootstrapSSH`;
- здесь не возвращаемся к обновлению ядра или позднему reboot ради `AmneziaWG`.

## Входные условия
- Выполнен этап из [docs/ServerPreparation.md](ServerPreparation.md).
- Выполнен этап из [docs/BootstrapSSH.md](BootstrapSSH.md).
- На этапе подготовки сервера уже проверены kernel/headers и ранняя установка `AmneziaWG`.
- Есть рабочий вход по SSH новым административным пользователем.
- Новый SSH-порт уже проверен отдельным повторным входом с локальной машины.
- Пользователь может выполнять `sudo`.
- Целевая ОС: `Debian 12`.
- Для первой версии выбран `iptables`.

## Параметры этапа
Перед началом зафиксировать:
- `ssh_port` — порт SSH, например `4022`.
- `awg_port` — UDP-порт `AWG`, например `443`.
- `server_iface` — внешний сетевой интерфейс сервера, например `eth0`.
- `awg_iface` — VPN-интерфейс, например `awg0`.

## Решение по IPv6
Принять модель `IPv4-only`.

Это значит:
- `AWG` поднимаем только на IPv4;
- firewall настраиваем только для IPv4;
- IPv6 на сервере отключаем, чтобы не оставлять неконтролируемый сетевой стек вне текущей модели безопасности.

## Шаг 1. Проверка сетевого интерфейса сервера
Перед настройкой правил определить внешний интерфейс сервера.
Перед этим еще раз проверить, что вход по новому SSH-порту стабильно работает.

Контрольная проверка:
```bash
ssh -p <ssh_port> <admin_user>@<server_ip>
```

Ожидаемый результат:
- вход выполняется без использования пароля;
- пользователь получает рабочую shell-сессию;
- `sudo whoami` возвращает `root`.

Команда:
```bash
ip route get 1.1.1.1
```

Ожидаемый результат:
- в выводе виден `dev <server_iface>`.

Пример:
```text
1.1.1.1 via 85.85.249.1 dev eth0 src 85.85.249.249
```

## Шаг 2. Проверка наличия iptables
Проверить наличие `iptables`.

Проверка:
```bash
sudo iptables --version
```

Если команда отсутствует, установить пакет:
```bash
sudo apt update
sudo apt install -y iptables
```

## Шаг 3. Отключение IPv6
Так как в первой версии IPv6 не используется, отключить его на сервере через `sysctl`.

Команды:
```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/80-ipv6-disable.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sudo sysctl --system
```

Проверка:
```bash
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6
```

Ожидаемый результат:
```text
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

## Шаг 4. Включение IPv4 forwarding
Для маршрутизации трафика клиентов через сервер включить `ip_forward`.

Проверка текущего значения:
```bash
sysctl net.ipv4.ip_forward
```

Временное включение до перезагрузки:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Постоянное включение:
```bash
printf 'net.ipv4.ip_forward=1\n' | sudo tee /etc/sysctl.d/99-awg.conf
sudo sysctl --system
```

Проверка:
```bash
sysctl net.ipv4.ip_forward
cat /etc/sysctl.d/99-awg.conf
```

Ожидаемый результат:
```text
net.ipv4.ip_forward = 1
```

## Шаг 5. Установка iptables-persistent
Чтобы правила переживали перезагрузку, установить `iptables-persistent`.

Команда:
```bash
sudo apt install -y iptables-persistent
```

Если установщик спрашивает про сохранение текущих правил:
- можно отвечать `No`, если правила еще не настроены;
- правила будут сохранены вручную после настройки.

Проверка:
```bash
systemctl status netfilter-persistent --no-pager
```

## Шаг 6. Сброс текущих правил
Перед применением новой схемы очистить старое состояние.

Команды:
```bash
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
```

Правило:
- выполнять только если это новый сервер и вы уверены, что других критичных правил нет.

## Шаг 7. Разрешение базового входящего трафика
Сначала открыть то, без чего сервер потеряет управляемость.

Команды:
```bash
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport <ssh_port> -j ACCEPT
sudo iptables -A INPUT -p udp --dport <awg_port> -j ACCEPT
```

Опционально для диагностики разрешить `ping`:
```bash
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
```

## Шаг 8. Настройка FORWARD для AWG
Разрешить клиентам `AWG` выходить наружу и принимать обратный трафик.

Команды:
```bash
sudo iptables -A FORWARD -i <awg_iface> -o <server_iface> -j ACCEPT
sudo iptables -A FORWARD -i <server_iface> -o <awg_iface> -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

## Шаг 9. Настройка NAT
Включить маскарадинг на внешнем интерфейсе сервера.

Команда:
```bash
sudo iptables -t nat -A POSTROUTING -o <server_iface> -j MASQUERADE
```

## Шаг 10. Установка политик по умолчанию
После явных разрешающих правил включить политики по умолчанию.

Команды:
```bash
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

## Шаг 11. Проверка активных правил
До сохранения проверить, что правила выглядят именно так, как ожидается.

Проверка политик:
```bash
sudo iptables -L
```

Проверка правил:
```bash
sudo iptables -L -n -v
sudo iptables -S
```

Проверка NAT:
```bash
sudo iptables -t nat -L -n -v
sudo iptables -t nat -S
```

Проверка `FORWARD`:
```bash
sudo iptables -L FORWARD -n -v
```

## Шаг 12. Сохранение правил
Сохранить текущие правила для загрузки после перезапуска сервера.

Команда:
```bash
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
```

Проверка:
```bash
sudo systemctl is-enabled netfilter-persistent
```

Ожидаемый результат:
```text
enabled
```

## Шаг 13. Контрольная проверка SSH после firewall
После включения firewall проверить, что SSH не отрезан.

Проверка с локальной машины:
```bash
ssh -p <ssh_port> <admin_user>@<server_ip>
```

Ожидаемый результат:
- вход по SSH продолжает работать.

## Шаг 14. Проверка сохранения после перезагрузки
После сохранения правил проверить, что они вернутся после reboot.

Проверка перед перезагрузкой:
```bash
sudo systemctl status netfilter-persistent --no-pager
```

После плановой перезагрузки:
```bash
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v
sysctl net.ipv4.ip_forward
```

Ожидаемый результат:
- правила сохранены;
- `ip_forward` остается равным `1`;
- SSH-вход работает.

## Проверки результата этапа
- Определен внешний интерфейс сервера.
- IPv6 отключен через `sysctl`.
- Включен `net.ipv4.ip_forward=1`.
- SSH-порт разрешен в `iptables`.
- UDP-порт `AWG` разрешен в `iptables`.
- Настроен `FORWARD` для `AWG`.
- Настроен `MASQUERADE` на внешнем интерфейсе.
- Политики по умолчанию применены.
- Правила сохранены через `iptables-persistent`.
- SSH доступ не потерян после применения правил.

## Ожидаемый итог
Сервер готов с точки зрения сети к установке и запуску `AWG`:
- маршрутизация включена;
- базовый firewall работает;
- NAT настроен;
- правила переживают перезагрузку;
- административный доступ по SSH сохранен.
