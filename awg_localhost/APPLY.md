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
```

## Проверка синтаксиса
```bash
bash -n /etc/amnezia/amneziawg/postup.sh
bash -n /etc/amnezia/amneziawg/postdown.sh
shellcheck /etc/amnezia/amneziawg/postup.sh
shellcheck /etc/amnezia/amneziawg/postdown.sh
```

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
