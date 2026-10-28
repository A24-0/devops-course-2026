#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"                     # псевдоним из ~/.ssh/config (ПР № 5, шаг 1.6)
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${ROOT}/site/"
RSYNC="${RSYNC:-rsync}"

# 1. Разбор аргумента --dry-run
DRY=""
case "${1:-}" in
    "")        ;;
    --dry-run) DRY="--dry-run" ;;
    *) echo "Использование: $0 [--dry-run]" >&2; exit 2 ;;
esac

# 2. Проверки по требованиям 4 и 5
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует, доставка не выполняется" >&2
    exit 1
fi
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения, доставка не выполняется" >&2
    exit 1
fi

# 3. Синхронизация: одно SSH-соединение, без интерактивного запроса пароля
# Права по модели «владелец пишет, веб-сервер читает»: каталоги 755, файлы 644.
# Штатный rsync macOS (openrsync) не поддерживает --chmod, поэтому права задаются
# в промежуточной копии, откуда архивный режим переносит их на сервер без изменений.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "${LOCAL_DIR}." "$STAGE/"
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f -exec chmod 644 {} +
if ! "$RSYNC" -avz --delete ${DRY} \
        -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
        "${STAGE}/" "${REMOTE}:${REMOTE_DIR}/"; then
    echo "Ошибка: синхронизация не выполнена" >&2
    exit 1
fi

# 4. При --dry-run завершение без проверки доступности
if [[ -n "$DRY" ]]; then
    echo "Пробный запуск завершён, состояние сервера не изменено"
    exit 0
fi

# 5. Проверка доступности ресурса с проверкой сертификата (без -k)
if ! curl -fsS --cacert "$CA_CERT" -o /dev/null "$SITE_URL"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
    exit 1
fi
echo "Доставлен коммит $(git -C "$ROOT" rev-parse --short HEAD)"
