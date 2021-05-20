#!/bin/sh

releasever='8'
packages='centos-release-hyperscale dnf systemd'

if ! grep -q "CentOS Stream $releasever" /etc/os-release; then
  echo "You need to run this on a CentOS Stream $releasever host"
  exit 1
fi

script=$(mktemp)
trap 'rm -f $script' EXIT

newcontainer=$(buildah from scratch)

cat > "$script" <<EOF
#!/bin/sh
scratchmnt=\$(buildah mount "$newcontainer")
dnf -y install \
  --disableplugin product-id \
  --installroot "\$scratchmnt" \
  --releasever "$releasever" \
  --setopt install_weak_deps=false \
  $packages
dnf -y --installroot "\$scratchmnt" clean all
buildah unmount "$newcontainer"
EOF
chmod +x "$script"
buildah unshare "$script"

buildah config \
  --created-by "CentOS Hyperscale SIG" \
  --author "CentOS Hyperscale SIG" \
  --label name="centos-stream-hyperscale-${releasever}" \
  "$newcontainer"
buildah commit "$newcontainer" "centos-stream-hyperscale-${releasever}"
buildah rm "$newcontainer"

exit 0
