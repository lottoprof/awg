# AWG Localhost

## Назначение
Каталог для локальной диагностики и локальных артефактов рабочей машины оператора.

Этот каталог не заменяет:
- `docs/` для основной серверной документации проекта;
- `awg_clients/` для полученных клиентских `.conf` и `.png`.

## Текущее содержимое
- `AWG20_LOCAL_INSTALL.md` — локальная инструкция по установке `AmneziaWG` с акцентом на kernel module и переход к `AWG 2.0`;
- `postup.sh` — проектная правка `PostUp` для общего shared-state `novpn/ru_nets`;
- `postdown.sh` — проектная правка `PostDown`, которая не чистит общий shared-state, пока активен хотя бы один `AWG`-интерфейс.
- `novpn-recover.sh` — локальный recovery-скрипт для повторной сборки `novpn` без перезапуска `AWG`.
- `awg-resume-restart.sh` — helper-скрипт для отдельного `systemd service`, который ждет WAN route, проверяет живые `AWG`-интерфейсы в ядре и восстанавливает только `novpn/policy routing` без `awg restart`.
- `awg-resume-restart.service` — `systemd unit`, который запускает helper-скрипт после `resume`.
- `awg-novpn-resume.sh` — hook для `systemd system-sleep`, который после `resume` только запускает `awg-resume-restart.service`.

## Исходная точка
Первоначальные версии локальных скриптов зафиксированы в git в commit:
- `046a10cf95a7c9a0f3e13ac78654c671e03947f7`

Если потребуется восстановить исходное состояние, использовать git.

## Контекст
Локальная схема использует общий `systemd` override для `awg-quick@.service` и общие ресурсы:
- `ipset`-набор `ru_nets`;
- таблицу маршрутизации `novpn`;
- маркировку `fwmark 200`.

При диагностике подтверждено, что `postdown.sh` любого `awg-quick@<instance>` удаляет общий `novpn` и общий `ru_nets`, поэтому каталог создан отдельно, чтобы вести локальные изменения независимо от серверной части проекта.
