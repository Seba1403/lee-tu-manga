#!/usr/bin/env bash
# Corre en la Pi, parado en /opt/stacks/projects/lee-tu-manga-stack/
# (via cron, antes de que corra backup-offsite.sh).
#
# Requiere el cliente sqlite3 en la Pi (no el contenedor): sudo apt install sqlite3
#
# Solo respalda production.sqlite3 (series, tomos, progreso de lectura,
# usuario) porque es lo único irremplazable. Las portadas y las bases de
# queue/cache/cable se pueden regenerar o perder sin problema.
#
# Genera backups/daily/ y backups/last/ para que backup-offsite.sh los
# recoja con la misma convención que el resto de los stacks.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p backups/daily backups/last
timestamp=$(date +%Y%m%d-%H%M%S)

# ".backup" es el comando "online" de sqlite3: hace una copia consistente
# aunque la app esté escribiendo en ese momento (algo que un "cp" normal no
# garantiza cuando la base usa WAL, como en este proyecto). storage/ está
# bind-mounteado desde el contenedor, así que se puede leer directo sin
# entrar a él.
sqlite3 storage/production.sqlite3 ".backup backups/daily/production-${timestamp}.sqlite3"
cp "backups/daily/production-${timestamp}.sqlite3" backups/last/production.sqlite3

# Conserva solo los últimos 14 backups diarios locales (el historial más
# largo queda en Drive vía backup-offsite.sh).
ls -1t backups/daily/production-*.sqlite3 | tail -n +15 | xargs -r rm --

echo "Backup creado: backups/daily/production-${timestamp}.sqlite3 (+ backups/last/production.sqlite3)"
