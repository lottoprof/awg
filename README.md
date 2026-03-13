# AWG VPS Deployment

Система развертывания `AmneziaWG` на чистых `Debian 12 VPS` с bash-автоматизацией, серверными backend-скриптами и локальным операторским CLI.

## Что есть в репозитории
- `docs/` — архитектурные и операционные документы
- `script_srv/` — серверные backend-скрипты
- `script_client/` — локальные операторские скрипты
- `templates/` — шаблоны конфигов
- `awg_clients/` — локальный каталог для полученных клиентских `.conf` и `.png`

## Порядок чтения документации
Документы лучше читать и применять в таком порядке:

1. [docs/DeploymentPlan.md](docs/DeploymentPlan.md)
2. [docs/ServerPreparation.md](docs/ServerPreparation.md)
3. [docs/AmneziaWGInstall.md](docs/AmneziaWGInstall.md)
4. [docs/BootstrapSSH.md](docs/BootstrapSSH.md)
5. [docs/NetworkBase.md](docs/NetworkBase.md)
6. [docs/ServerLayout.md](docs/ServerLayout.md)
7. [docs/ServerConfigFormat.md](docs/ServerConfigFormat.md)
8. [docs/ServerConfigInit.md](docs/ServerConfigInit.md)
9. [docs/ClientManagement.md](docs/ClientManagement.md)
10. [docs/SmokeTest.md](docs/SmokeTest.md)
11. [docs/OperatorWorkflow.md](docs/OperatorWorkflow.md)
12. [docs/Awgctl.md](docs/Awgctl.md)
13. [docs/AmneziaWGManualBuild.md](docs/AmneziaWGManualBuild.md)
14. [docs/InstallChecklist.md](docs/InstallChecklist.md)

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
