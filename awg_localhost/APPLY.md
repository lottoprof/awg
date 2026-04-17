# Применение локальных hook-скриптов

## Цель
Перенести проектные версии `postup.sh` и `postdown.sh` из `awg_localhost/` в локальную систему и проверить, что общий `novpn/ru_nets` не теряется при переключении между `AWG`-инстансами.

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
install -m 755 /home/az/git/awg/awg_localhost/awg-novpn-resume.sh /usr/lib/systemd/system-sleep/awg-novpn-resume
systemctl daemon-reload
```

## Проверка синтаксиса
```bash
bash -n /etc/amnezia/amneziawg/postup.sh
bash -n /etc/amnezia/amneziawg/postdown.sh
bash -n /etc/amnezia/amneziawg/novpn-recover.sh
bash -n /etc/amnezia/amneziawg/awg-resume-restart.sh
bash -n /usr/lib/systemd/system-sleep/awg-novpn-resume 
shellcheck /etc/amnezia/amneziawg/postup.sh
shellcheck /etc/amnezia/amneziawg/postdown.sh
shellcheck /etc/amnezia/amneziawg/novpn-recover.sh
shellcheck /etc/amnezia/amneziawg/awg-resume-restart.sh
shellcheck /usr/lib/systemd/system-sleep/awg-novpn-resume
```

## Проверка recovery после resume
Проверка выполняется через отдельный `systemd service`.

```bash
systemctl start awg-quick@awg2.service
ip route flush table novpn
ip route get 77.88.8.8 mark 200

systemctl start awg-resume-restart.service
/usr/lib/systemd/system-sleep/awg-novpn-resume post

systemctl status awg-resume-restart.service --no-pager
ip route show table novpn
ip route get 77.88.8.8 mark 200
```

## Ожидаемый результат recovery
- Hook только запускает `awg-resume-restart.service`.
- Service ждет WAN route и проверяет живые `AWG`-интерфейсы в ядре.
- Service не делает `awg restart`, если интерфейс уже существует.
- Service вызывает `novpn-recover.sh` и восстанавливает `table novpn`, `ip rule`, `ipset` и `mangle`.
- После recovery `ip route get 77.88.8.8 mark 200` идет через WAN и `table novpn`.

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
