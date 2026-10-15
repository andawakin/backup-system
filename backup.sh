#!/usr/bin/env bash
#
# backup.sh — архивирование указанной папки с автоматической ротацией архивов.
# Хранит только последние KEEP_COUNT архивов, остальные удаляет.
# Предполагается запуск через cron каждую ночь.
#
set -euo pipefail

# ---- Настройки ----
SOURCE_DIR="/var/www/my-site"          # что архивируем (поменяйте под свою задачу)
BACKUP_DIR="/var/backups/my-data"      # куда складываем архивы
KEEP_COUNT=7                            # сколько последних архивов хранить
LOG_FILE="/var/log/backup-system.log"
PREFIX="my-data"

mkdir -p "${BACKUP_DIR}"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo "[$(timestamp)] $1" | tee -a "${LOG_FILE}"
}

if [[ ! -d "${SOURCE_DIR}" ]]; then
    log "ОШИБКА: исходная директория ${SOURCE_DIR} не найдена. Прерываю выполнение."
    exit 1
fi

# ---- Создание архива ----
archive_name="${PREFIX}_$(date '+%Y-%m-%d_%H-%M-%S').tar.gz"
archive_path="${BACKUP_DIR}/${archive_name}"

tar -czf "${archive_path}" -C "$(dirname "${SOURCE_DIR}")" "$(basename "${SOURCE_DIR}")"

archive_size=$(du -h "${archive_path}" | cut -f1)
log "Создан архив: ${archive_name} (размер ${archive_size})"

# ---- Ротация: оставляем только последние KEEP_COUNT архивов ----
mapfile -t all_archives < <(find "${BACKUP_DIR}" -maxdepth 1 -name "${PREFIX}_*.tar.gz" -printf '%T@ %p\n' | sort -n | awk '{print $2}')

total_archives=${#all_archives[@]}

if (( total_archives > KEEP_COUNT )); then
    to_delete=$(( total_archives - KEEP_COUNT ))
    log "Найдено архивов: ${total_archives}. Хранить нужно: ${KEEP_COUNT}. Удаляю ${to_delete} старых."

    for (( i=0; i<to_delete; i++ )); do
        old_archive="${all_archives[$i]}"
        rm -f "${old_archive}"
        log "Удалён старый архив: $(basename "${old_archive}")"
    done
else
    log "Архивов: ${total_archives} (не больше ${KEEP_COUNT}). Удаление не требуется."
fi

exit 0
