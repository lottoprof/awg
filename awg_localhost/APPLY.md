# Применение локальных hook-скриптов

## Цель
Перенести проектные версии `postup.sh` и `postdown.sh` из `awg_localhost/` в локальную систему и проверить, что перед `suspend` активные `AWG`-инстансы полностью останавливаются, а после возврата сети поднимается только сохраненный набор.

## Входные условия
- Текущие рабочие версии подготовлены в:
  - `awg_localhost/postup.sh`
  - `awg_localhost/postdown.sh`
- Общий `systemd` override уже использует:
  - `/etc/amnezia/amneziawg/postup.sh`
  - `/etc/amnezia/amneziawg/postdown.sh`
- Доступен root-shell.

## Копирование в систему
```bash
install -m 755 /home/az/git/awg/awg_localhost/postup.sh /etc/amnezia/amneziawg/postup.sh
install -m 755 /home/az/git/awg/awg_localhost/postdown.sh /etc/amnezia/amneziawg/postdown.sh
install -m 755 /home/az/git/awg/awg_localhost/novpn-recover.sh /etc/amnezia/amneziawg/novpn-recover.sh
install -m 755 /home/az/git/awg/awg_localhost/awg-resume-restart.sh /etc/amnezia/amneziawg/awg-resume-restart.sh
install -m 644 /home/az/git/awg/awg_localhost/awg-resume-restart.service /etc/systemd/system/awg-resume-restart.service
install -m 755 /home/az/git/awg/awg_localhost/90-awg-resume-dispatcher /etc/NetworkManager/dispatcher.d/90-awg-resume-dispatcher
install -m 755 /home/az/git/awg/awg_localhost/awg-novpn-resume.sh /usr/lib/systemd/system-sleep/awg-novpn-resume
systemctl daemon-reload
```

## Проверка синтаксиса
```bash
bash -n /etc/amnezia/amneziawg/postup.sh
bash -n /etc/amnezia/amneziawg/postdown.sh
bash -n /etc/amnezia/amneziawg/novpn-recover.sh
bash -n /etc/amnezia/amneziawg/awg-resume-restart.sh
bash -n /etc/NetworkManager/dispatcher.d/90-awg-resume-dispatcher
bash -n /usr/lib/systemd/system-sleep/awg-novpn-resume 
shellcheck /etc/amnezia/amneziawg/postup.sh
shellcheck /etc/amnezia/amneziawg/postdown.sh
shellcheck /etc/amnezia/amneziawg/novpn-recover.sh
shellcheck /etc/amnezia/amneziawg/awg-resume-restart.sh
shellcheck /etc/NetworkManager/dispatcher.d/90-awg-resume-dispatcher
shellcheck /usr/lib/systemd/system-sleep/awg-novpn-resume
```

## Проверка recovery после resume
Проверка выполняется через `systemd system-sleep` hook, `NetworkManager-dispatcher` и отдельный `systemd service`.

```bash
systemctl start awg-quick@awg2.service
/usr/lib/systemd/system-sleep/awg-novpn-resume pre
systemctl status awg-quick@awg2.service --no-pager || true
ip link show awg2 || true

/usr/lib/systemd/system-sleep/awg-novpn-resume post
SYSTEMD_LOG_LEVEL=debug /etc/NetworkManager/dispatcher.d/90-awg-resume-dispatcher enp0s31f6 up

systemctl status awg-resume-restart.service --no-pager
systemctl status awg-quick@awg2.service --no-pager
ip route get 1.1.1.1
```

## Ожидаемый результат recovery
- Hook на `pre` сохраняет активные `awg-quick@...` и полностью их останавливает.
- После `pre` интерфейс активного инстанса отсутствует в ядре.
- Hook на `post` только помечает pending restore.
- `NetworkManager-dispatcher` после возврата default route запускает `awg-resume-restart.service`.
- Service ждет WAN route и запускает только юниты из сохраненного списка.
- После recovery `awg-quick@awg2.service` снова активен, а `ip route get 1.1.1.1` использует поднятый `AWG`-инстанс.

## Перезапуск сценария
Проверка выполняется на переключении между двумя инстансами.

```bash
systemctl stop awg-quick@awg2.service
systemctl start awg-quick@awg0.service

ip route show table novpn
ip route get 77.88.8.8 mark 200

systemctl stop awg-quick@awg0.service
systemctl start awg-quick@awg2.service

ip route show table novpn
ip route get 77.88.8.8 mark 200
```

## Ожидаемый результат
- После старта любого активного `AWG`-инстанса в `table novpn` есть:
  - `default via <WAN_GW> dev <WAN_IF>`
- `ip route get 77.88.8.8 mark 200` идет через WAN, а не через `table 51820`.
- Остановка одного `AWG`-инстанса не разрушает общий `novpn/ru_nets`, если другой инстанс остается активным.
