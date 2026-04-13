# AWG VPS Deployment

Система развертывания `AmneziaWG` на чистых `Debian 12 VPS` с bash-автоматизацией, серверными backend-скриптами и локальным операторским CLI.

## Что есть в репозитории
- `docs/` — архитектурные и операционные документы
- `script_srv/` — серверные backend-скрипты
- `script_client/` — локальные операторские скрипты
- `templates/` — шаблоны конфигов
- `awg_clients/` — локальный каталог для полученных клиентских `.conf` и `.png`
- `awg_localhost/` — локальные артефакты и документация по настройке `AWG` на рабочей машине

## Порядок реализации
1. [Спланировать систему развертывания](docs/DeploymentPlan.md)
2. [Заполнить единый манифест для AI-агента](docs/AgentManifest.md)
3. [Прочитать правила выполнения для AI-агента](docs/AgentExecutionRules.md)
4. [Подготовить чистый сервер](docs/ServerPreparation.md)
5. [Установить AmneziaWG пакетным способом](docs/AmneziaWGInstall.md)
6. [Настроить безопасный SSH-доступ](docs/BootstrapSSH.md)
7. [Подготовить сетевую основу и firewall](docs/NetworkBase.md)
8. [Зафиксировать размещение файлов на сервере](docs/ServerLayout.md)
9. [Зафиксировать формат серверных конфигов](docs/ServerConfigFormat.md)
10. [Инициализировать `/etc/amnezia` и `/var/lib/amnezia`](docs/ServerConfigInit.md)
11. [Настроить управление клиентами](docs/ClientManagement.md)
12. [Провести smoke-test сервера и клиента](docs/SmokeTest.md)
13. [Зафиксировать workflow оператора](docs/OperatorWorkflow.md)
14. [Использовать локальный CLI `awgctl`](docs/Awgctl.md)
15. [Перейти на manual build при необходимости](docs/AmneziaWGManualBuild.md)

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
