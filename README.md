# AWG VPS Deployment

Система развертывания `AmneziaWG` на чистых `Debian 12 VPS` с bash-автоматизацией, серверными backend-скриптами и локальным операторским CLI.

## Что есть в репозитории
- `docs/` — архитектурные и операционные документы
- `script_srv/` — серверные backend-скрипты
- `script_client/` — локальные операторские скрипты
- `templates/` — шаблоны конфигов
- `awg_clients/` — локальный каталог для полученных клиентских `.conf` и `.png`

## Порядок реализации
1. [Спланировать систему развертывания](docs/DeploymentPlan.md)
2. [Подготовить чистый сервер](docs/ServerPreparation.md)
3. [Установить AmneziaWG пакетным способом](docs/AmneziaWGInstall.md)
4. [Настроить безопасный SSH-доступ](docs/BootstrapSSH.md)
5. [Подготовить сетевую основу и firewall](docs/NetworkBase.md)
6. [Зафиксировать размещение файлов на сервере](docs/ServerLayout.md)
7. [Зафиксировать формат серверных конфигов](docs/ServerConfigFormat.md)
8. [Инициализировать `/etc/amnezia` и `/var/lib/amnezia`](docs/ServerConfigInit.md)
9. [Настроить управление клиентами](docs/ClientManagement.md)
10. [Провести smoke-test сервера и клиента](docs/SmokeTest.md)
11. [Зафиксировать workflow оператора](docs/OperatorWorkflow.md)
12. [Использовать локальный CLI `awgctl`](docs/Awgctl.md)
13. [Перейти на manual build при необходимости](docs/AmneziaWGManualBuild.md)

## Скрипты
Серверные:
- [script_srv/awg-add-client](script_srv/awg-add-client)
- [script_srv/awg-list-clients](script_srv/awg-list-clients)
- [script_srv/awg-export-client](script_srv/awg-export-client)
- [script_srv/awg-revoke-client](script_srv/awg-revoke-client)

Локальные:
- [script_client/awgctl](script_client/awgctl)

## Текущий рабочий принцип
- ранняя проверка `kernel/headers/AmneziaWG` еще под `root`
- затем безопасный `SSH bootstrap`
- затем `iptables`, `awg0`, клиенты и smoke-test
- оператор работает локально через `awgctl`
