# Bootstrap SSH-доступа для AWG

## Цель
Подготовить безопасный административный SSH-доступ к чистому VPS: создать отдельного пользователя, включить вход по ключу и отключить небезопасный вход по паролю только после проверки нового доступа.

## Входные условия
- Выполнен этап из [docs/ServerPreparation.md](ServerPreparation.md).
- Есть рабочий доступ к серверу под `root`.
- Есть публичный SSH-ключ оператора.
- Целевая ОС: `Debian 12`.
- Настройка выполняется вручную в `tmux`.
- Пакет `sudo` уже установлен на этапе подготовки сервера.
- Вопрос с kernel/headers и ранней установкой `AmneziaWG` уже решен на этапе подготовки сервера.

## Параметры этапа
Перед началом зафиксировать:
- `server_ip` — IP сервера.
- `admin_user` — имя административного пользователя, например `awgadm`.
- `ssh_port` — SSH-порт. По умолчанию `22`, смена порта опциональна.
- `public_key` — публичный SSH-ключ оператора.

## Шаг 1. Проверка доступа под root
Проверить, что текущая root-сессия активна и не будет закрыта до завершения всех проверок.

Проверка:
```bash
whoami
```

Ожидаемый результат:
```text
root
```

## Шаг 2. Создание административного пользователя
Создать отдельного пользователя для дальнейшей работы.

Команда:
```bash
adduser <admin_user>
```

## Шаг 3. Добавление пользователя в группу sudo
Добавить его в группу `sudo`:
```bash
usermod -aG sudo <admin_user>
```

Проверка:
```bash
id <admin_user>
```

Ожидаемый результат:
```text
... groups=...,27(sudo)
```

## Шаг 4. Подготовка каталога .ssh
Создать каталог для SSH-ключей нового пользователя.

Команды:
```bash
mkdir -p /home/<admin_user>/.ssh
chmod 700 /home/<admin_user>/.ssh
chown -R <admin_user>:<admin_user> /home/<admin_user>/.ssh
```

## Шаг 5. Добавление authorized_keys
Открыть файл `authorized_keys` и вставить публичный ключ оператора.

Команда:
```bash
vim /home/<admin_user>/.ssh/authorized_keys
```

После сохранения выставить права:
```bash
chmod 600 /home/<admin_user>/.ssh/authorized_keys
chown <admin_user>:<admin_user> /home/<admin_user>/.ssh/authorized_keys
```

Проверка:
```bash
ls -ld /home/<admin_user>/.ssh
ls -l /home/<admin_user>/.ssh/authorized_keys
```

Ожидаемый результат:
```text
drwx------ ...
-rw------- ...
```

## Шаг 6. Проверка sudo для нового пользователя
Проверить, что новый пользователь может выполнять команды через `sudo`.

Команда:
```bash
su - <admin_user>
sudo whoami
```

Ожидаемый результат:
```text
root
```

После проверки вернуться в root-сессию:
```bash
exit
```

## Шаг 7. Резервная копия конфигурации SSH
Перед изменением SSH сделать резервную копию.

Команда:
```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

Проверка:
```bash
ls -l /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

## Шаг 8. Настройка sshd_config
Открыть основной конфиг SSH и привести его к целевому состоянию.

Команда:
```bash
vim /etc/ssh/sshd_config
```

Целевой вариант:
```text
Include /etc/ssh/sshd_config.d/*.conf

Port <ssh_port>
HostKey /etc/ssh/ssh_host_ed25519_key
LoginGraceTime 60
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 60
ClientAliveCountMax 5
MaxStartups 10:30:100
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
```

Правила:
- `Port` можно оставить `22` или заменить на выбранный порт;
- `PermitRootLogin no` включать только при условии, что ключ нового пользователя уже проверен;
- `PasswordAuthentication no` оставлять только после проверки входа по ключу.

## Шаг 9. Проверка синтаксиса SSH-конфига
До рестарта проверить конфигурацию.

Команда:
```bash
sshd -t
```

Ожидаемый результат:
- пустой вывод;
- код завершения без ошибки.

## Шаг 10. Перезапуск SSH
Если синтаксис корректен, перезапустить службу.

Команда:
```bash
systemctl restart ssh
```

Проверка:
```bash
systemctl status ssh --no-pager
```

Ожидаемый результат:
```text
Active: active (running)
```

## Шаг 11. Проверка прослушивания SSH-порта
Проверить, что `sshd` слушает выбранный порт.

Команда:
```bash
ss -tulnp | grep sshd
```

Ожидаемый результат:
- виден `LISTEN` на `0.0.0.0:<ssh_port>` или `:<ssh_port>`;
- процесс `sshd` активен.

## Шаг 12. Проверка нового SSH-входа
Не закрывая текущую root-сессию, открыть второе подключение с локальной машины.

Команда:
```bash
ssh -p <ssh_port> <admin_user>@<server_ip>
```

Проверка после входа:
```bash
whoami
sudo whoami
```

Ожидаемый результат:
```text
<admin_user>
root
```

## Шаг 13. Контрольная проверка запрета root и password login
После успешного входа новым пользователем проверить, что старый небезопасный доступ больше не является рабочим сценарием.

Проверка root login:
```bash
ssh -p <ssh_port> root@<server_ip>
```

Ожидаемый результат:
- вход запрещен.

Проверка password login:
```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -p <ssh_port> <admin_user>@<server_ip>
```

Ожидаемый результат:
- вход по паролю не выполняется.

## Проверки результата этапа
- Создан отдельный административный пользователь.
- Пользователь включен в группу `sudo`.
- Публичный ключ установлен в `authorized_keys`.
- SSH работает на выбранном порту.
- Вход под `root` по SSH отключен.
- Вход по паролю отключен.
- Вход новым пользователем по ключу подтвержден.

## Ожидаемый итог
Сервер переведен на безопасный административный SSH-доступ:
- дальнейшая работа выполняется не под `root`, а под выделенным пользователем;
- доступ идет только по ключу;
- SSH слушает выбранный порт;
- риск блокировки сервера снижен за счет проверки нового входа до отключения старого режима.

После этого этапа:
- уже не возвращаемся к раннему kernel/reboot-сценарию ради `AmneziaWG`;
- можно переходить к firewall и дальнейшей серверной настройке.
