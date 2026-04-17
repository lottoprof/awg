# План перевода resume service на novpn-only recovery

## Цель
После deep sleep восстанавливать только `novpn/policy routing`, не пытаясь делать `awg-quick up/restart`, если `awg` интерфейс уже жив в ядре.

## Шаги
1. Переписать `awg-resume-restart.sh` на вызов `novpn-recover.sh` при наличии живых `amneziawg` интерфейсов.
2. Обновить `README.md` и `APPLY.md`.
3. Выполнить `bash -n` и `shellcheck`.
4. Установить helper в систему и проверить manual recovery без `awg restart`.
