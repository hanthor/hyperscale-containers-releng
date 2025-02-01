#!/bin/sh

set -eu

export TZ='America/Los_Angeles'

# Hyperscale Centos Stream version, default 8
VERSION="${VERSION:-10}"

# Date for next build
DATE="${DATE:-'8:00 next Fri'}"

# Push to quay.io
Push () {
  buildah login -u $USERNAME -p $PASSWORD quay.io
  buildah tag centos-stream-hyperscale-${VERSION} quay.io/jreilly112/centos:stream${VERSION}-hyperscale
  buildah push quay.io/centoshyperscale/centos:stream${VERSION}
  buildah logout quay.io
}

# Always run once immediately for easy testing.
./make-hyperscale-container.sh $VERSION
./verify_rpmdb.sh
Push

while true; do
  TIME=$(($(date -d "$DATE" +%s) - $(date +%s)))
  echo "Next build at $(date -d "$DATE")"
  sleep "$TIME"
  echo "Starting at $(date)"
  ./make-hyperscale-container.sh $VERSION
  ./verify_rpmdb.sh
  Push
  echo "Done at $(date)"
  echo
done
