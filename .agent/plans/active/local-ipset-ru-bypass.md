# План диагностики локального `ipset` для обхода `ru` вне VPN

## Цель
Разобрать фактическую локальную схему, при которой трафик в сети `ru` должен обходить `AmneziaWG` и идти через обычный WAN, и зафиксировать подтвержденные точки настройки.

## Контекст
- Задача относится к локальной машине оператора, а не к чистому VPS из основной документации репозитория.
- В самом репозитории явной реализации локального `ipset`-сценария не найдено.
- Обязательные проектные документы прочитаны:
  - `docs/AgentManifest.md`
  - `docs/AgentExecutionRules.md`
  - `docs/DeploymentPlan.md`

## Проверенные факты на локальной машине
### Policy routing
- `ip rule show` показывает отдельное правило:
  - `10: from all fwmark 0xc8 lookup novpn`
- Там же присутствует стандартная схема `wg-quick` для full-tunnel:
  - `32765: not from all fwmark 0xca6c lookup 51820`
- `/etc/iproute2/rt_tables` содержит:
  - `200 novpn`

### Маршруты
- `ip route show table all` показывает:
  - основной default route через `192.168.1.1 dev enp0s31f6`
  - VPN default route через `dev awg2 table 51820`
- Команда `ip route show table novpn` на момент проверки вернула пустой вывод.
- Дополнительная проверка из root-shell через `tmux` подтвердила тот же результат:
  - `ip route show table novpn` пуст.
- При этом журнал `awg-quick@awg2` подтверждает, что во время `PostUp` выполнялась команда:
  - `ip route add default via 192.168.1.1 dev enp0s31f6 table novpn`

Вывод:
- таблица `novpn` должна наполняться локальным hook-скриптом;
- отличие между привилегированным и непривилегированным просмотром здесь не подтвердилось;
- реальное runtime-состояние сейчас действительно содержит правило `ip rule`, но не содержит маршрута в таблице `novpn`.

### Источник настройки
- `systemctl cat awg-quick@awg2` показывает drop-in:
  - `ExecStartPost=/etc/amnezia/amneziawg/postup.sh`
  - `ExecStopPost=/etc/amnezia/amneziawg/postdown.sh`
- `systemctl status awg-quick@awg2 --no-pager` показывает:
  - unit активен с `2026-04-02 15:31:26 MSK`
  - `ExecStartPost` завершился успешно

### Что делает `postup.sh`
Из `journalctl -u awg-quick@awg2 --no-pager -n 200` подтвержден следующий порядок:
1. Включается `net.ipv4.ip_forward=1`.
2. Определяется WAN:
   - gateway: `192.168.1.1`
   - interface: `enp0s31f6`
3. Добавляется NAT:
   - `iptables -t nat -A POSTROUTING -o enp0s31f6 -j MASQUERADE`
4. Загружается список RU-сетей:
   - `RU_URL=https://www.ipdeny.com/ipblocks/data/countries/ru.zone`
   - `RU_SRC=/etc/amnezia/amneziawg/ru.zone`
5. Выполняется агрегация:
   - `RU_AGGR=/etc/amnezia/amneziawg/ru_aggr.zone`
   - используется утилита `aggregate`
6. Генерируется ipset restore-файл:
   - `RU_IPSET=/etc/amnezia/amneziawg/ru.ipset`
   - `IPSET_NAME=ru_nets`
7. Выполняется загрузка набора:
   - `ipset create ru_nets hash:net family inet hashsize 1024 maxelem 20000`
   - `ipset flush ru_nets`
   - `grep '^add ' /etc/amnezia/amneziawg/ru.ipset | ipset restore`
8. Обновляется policy routing:
   - `ip rule del fwmark 200 table novpn || true`
   - `ip route add default via 192.168.1.1 dev enp0s31f6 table novpn`
   - `ip rule add fwmark 200 table novpn priority 10`
9. Ставятся правила маркировки:
   - `iptables -t mangle -I OUTPUT -m set --match-set ru_nets dst -j MARK --set-mark 200`
   - `iptables -t mangle -I PREROUTING -m set --match-set ru_nets dst -j MARK --set-mark 200`
   - `iptables -t mangle -I PREROUTING -j CONNMARK --restore-mark`
   - `iptables -t mangle -I POSTROUTING -j CONNMARK --save-mark`

### Подтвержденное привилегированное состояние
- `ipset list ru_nets` из root-shell показывает, что набор существует и заполнен агрегированными IPv4-подсетями RU.
- `iptables-save | grep -E 'ru_nets|MARK --set-mark 200|CONNMARK|novpn'` показывает активные правила:
  - `-A PREROUTING -j CONNMARK --restore-mark --nfmask 0xffffffff --ctmask 0xffffffff`
  - `-A PREROUTING -m set --match-set ru_nets dst -j MARK --set-xmark 0xc8/0xffffffff`
  - `-A OUTPUT -m set --match-set ru_nets dst -j MARK --set-xmark 0xc8/0xffffffff`
  - `-A POSTROUTING -j CONNMARK --save-mark --nfmask 0xffffffff --ctmask 0xffffffff`
- `ip rule show` из root-shell подтверждает:
  - `10: from all fwmark 0xc8 lookup novpn`
- `ip route show table novpn` из root-shell пуст.

### Фактический эффект на маршрутизацию
- `ip route get 77.88.8.8 mark 200` возвращает:
  - `77.88.8.8 dev awg2 table 51820 src 10.66.66.4 mark 0xc8`
- `ip route get 1.1.1.1 mark 200` возвращает:
  - `1.1.1.1 dev awg2 table 51820 src 10.66.66.4 mark 0xc8`

Вывод:
- mark `200` назначается корректно;
- набор `ru_nets` существует и используется в `iptables`;
- но обход `ru` по WAN сейчас фактически не работает;
- помеченный трафик продолжает уходить через `awg2`, потому что таблица `novpn` пуста.

## Итоговый вывод
- Локальная схема обхода `ru` уже реализована и живет вне репозитория, в `/etc/amnezia/amneziawg/postup.sh`.
- Основа схемы:
  - `ipset`-набор `ru_nets`
  - маркировка пакетов mark `200`
  - таблица маршрутизации `novpn`
  - отдельное правило `ip rule` с приоритетом `10`
- Список `ru` берется не из проекта, а скачивается с `ipdeny.com` при `PostUp`.
- Главная поломка текущего состояния:
  - правило `fwmark 200 -> novpn` есть;
  - `ru_nets` заполнен;
  - правила `iptables` стоят;
  - таблица `novpn` пуста;
  - поэтому bypass для `ru` не работает и трафик идет в full-tunnel через `awg2`.

## Возможная причина
- По журналу `PostUp` маршрут в `novpn` добавляется успешно.
- По текущему runtime-состоянию маршрут в `novpn` отсутствует.
- Это означает, что после `PostUp` его либо что-то удаляет, либо он не сохраняется в итоговой таблице при последующей сетевой перестройке.
- Наиболее вероятные источники:
  - повторная переработка маршрутов после запуска `awg2`;
  - внешняя логика NetworkManager/systemd-networkd;
  - ручной/дополнительный `postdown`-подобный cleanup.

## Следующие шаги
1. Проверить, восстанавливается ли bypass после ручного добавления маршрута:
   - `ip route add default via 192.168.1.1 dev enp0s31f6 table novpn`
   - затем `ip route get 77.88.8.8 mark 200`
2. Если ручное добавление исправляет маршрут:
   - искать, кто удаляет таблицу `novpn` после `PostUp`.
3. Если потребуется перенести эту схему в репозиторий:
   - вынести логику генерации `ru.zone`/`ru.ipset` в явный локальный скрипт;
   - задокументировать зависимость на `aggregate`, `ipset`, `iptables`, `ip rule`.
