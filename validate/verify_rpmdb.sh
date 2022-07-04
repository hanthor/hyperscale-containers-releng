#!/bin/sh

set -eux

# start container for testing
ctr=$(buildah from "centos-stream-hyperscale-${VERSION}")

RPMDB_PATH=$(buildah run $ctr -- rpm -E "%{_dbpath}")
RPMDB_BACKEND=$(buildah run $ctr -- rpm -E "%{_db_backend}")

# Check if the container is using sqlite or bdb backend
if [ "${RPMDB_BACKEND}" != "sqlite" ] && [ "${RPMDB_BACKEND}" != "bdb" ]; then
       echo "script only works with sqlite or bdb rpmdb backend"
       buildah rm $ctr
       exit 1
fi

# Simple rpmdb verification
# for c9s mount container to avoid install sqlite every time
if [ "${RPMDB_BACKEND}" == "sqlite" ]; then
  mnt=$(buildah unshare -- sh -c "buildah mount $ctr")
  sqlite3 "$mnt${RPMDB_PATH}"/rpmdb.sqlite "pragma integrity_check;"
  buildah unshare -- sh -c "buildah unmount $ctr"
else
    buildah run $ctr -- /usr/lib/rpm/rpmdb_verify "${RPMDB_PATH}"/Packages
fi

buildah run $ctr -- rpmdb -vv --verifydb

# Query all headers in the DB
buildah run $ctr -- rpm -qa 1> /dev/null

# Remove container
buildah rm $ctr

exit 0
