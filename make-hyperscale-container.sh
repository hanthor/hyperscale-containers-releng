#!/bin/sh

releasever="$1"
[ -z "$releasever" ] && releasever='10'
dnf_opts="-y --setopt install_weak_deps=false"
packages='centos-release-hyperscale centos-release-hyperscale-kernel centos-release-hyperscale-experimental centos-release-hyperscale-spin epel-release dnf dnf-plugins-core systemd'
if [ "$releasever" -eq 8 ]; then
  packages="$packages centos-release-hyperscale-hotfixes"
  crb_repo="powertools"
  dnf_opts="$dnf_opts --disableplugin product-id"
  release_pkg="centos-stream-hyperscale-spin-release"
else
  crb_repo="crb"
  release_pkg="centos-stream-spin-hyperscale-release"
fi
summary="CentOS Stream $releasever Hyperscale container"
description="Provides a base CentOS Stream $releasever Hyperscale variant container"

if ! grep -q "CentOS Stream $releasever" /etc/os-release; then
  echo "You need to run this on a CentOS Stream $releasever host"
  exit 1
fi

if [ ! -r /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-HyperScale ]; then
  echo "Hyperscale GPG key not found, please install centos-release-hyperscale"
  exit 1
fi

script=$(mktemp)
trap 'rm -f $script' EXIT

# Hack to make these work with docker on el7
# https://access.redhat.com/solutions/6843481
export BUILDAH_FORMAT=docker

newcontainer=$(buildah from scratch)

cat > "$script" <<EOF
#!/bin/sh -x
scratchmnt=\$(buildah mount "$newcontainer")
dnf="dnf $dnf_opts --installroot \$scratchmnt"
\$dnf install --releasever "$releasever" $packages
\$dnf config-manager --set-enabled "$crb_repo"
\$dnf swap centos-stream-release "$release_pkg"
\$dnf distro-sync
\$dnf clean all
buildah unmount "$newcontainer"
EOF
chmod +x "$script"
buildah unshare "$script"

buildah config \
  --created-by 'make-hyperscale-container.sh' \
  --author 'CentOS Hyperscale SIG' \
  --label name='centos-stream-hyperscale' \
  --label version="${releasever}" \
  --label architecture="$(uname -m)" \
  --label maintainer="CentOS Hyperscale SIG" \
  --label summary="${summary}" \
  --label description="${description}" \
  --label url='https://quay.io/centoshyperscale/centos' \
  --label io.k8s.display-name="CentOS Stream ${releasever} Hyperscale" \
  --label io.k8s.description="${description}" \
  --label io.openshift.tags='base centos centos-stream hyperscale' \
  --cmd '/bin/bash' \
  "$newcontainer"
buildah commit "$newcontainer" "centos-stream-hyperscale-${releasever}"
buildah rm "$newcontainer"

exit 0
