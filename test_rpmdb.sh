#!/bin/sh

set -eu

# rpmdb files for each rpmdb backend
declare -A RPMDB_FILES
RPMDB_FILES[ndb]="Packages.db"
RPMDB_FILES[sqlite]="rpmdb.sqlite"
RPMDB_FILES[bdb]="Packages"

RPMDB_PATH=$(rpm -E "%{_dbpath}")
RPMDB_BACKEND=$(rpm -E "%{_db_backend}")
PARENT_DB_PATH=$(dirname "${RPMDB_PATH}")

echo "using ${RPMDB_BACKEND} backend"

# If correct rpmdb file for current backend does not exist, try to rebuild rpmdb to add the correct files
if [ ! -e "${RPMDB_PATH}/${RPMDB_FILES[${RPMDB_BACKEND}]}" ]; then
        echo "${RPMDB_FILES[${RPMDB_BACKEND}]} does not exist"
        echo "Rebuilding rpmdb..."
        if ! rpmdb --rebuilddb; then
                echo "Rebuild of rpmdb failed. Trying to rebuild manually..."
                REBUILD_FOLDER="$(ls $(dirname "${RPMDB_PATH}") | grep -m 1 rpmrebuild)"
                REBUILD_PATH="${PARENT_DB_PATH}/${REBUILD_FOLDER}"
                rm -fr "${RPMDB_PATH}"/*
                cp -a "${REBUILD_PATH}"/* "${RPMDB_PATH}"/
                rm -rf "${REBUILD_PATH}"
        fi

        echo "Rebuild of rpmdb done"
fi

# Simple rpmdb verification
if [ "${RPMDB_BACKEND}" == "sqlite" ]; then
    sqlite3 "${RPMDB_PATH}"/rpmdb.sqlite "pragma integrity_check;"
fi

if [ "${RPMDB_BACKEND}" == "bdb" ]; then
    /usr/lib/rpm/rpmdb_verify "${RPMDB_PATH}"/Packages
fi

rpmdb -vv --verifydb

echo "DONE"

exit 0
