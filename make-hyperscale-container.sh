#!/bin/sh

releasever='8'
packages='centos-release-hyperscale centos-release-hyperscale-hotfixes centos-release-hyperscale-spin centos-release-hyperscale-experimental epel-release dnf systemd'
summary="CentOS Stream $releasever Hyperscale container"
description="Provides a base CentOS Stream $releasever Hyperscale variant container"

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
sed -e 's/^enabled=0\$/enabled=1/g' \
    -i "\${scratchmnt}/etc/yum.repos.d/CentOS-Stream-PowerTools.repo"
dnf -y swap centos-stream-release centos-stream-hyperscale-spin-release
dnf -y --setopt install_weak_deps=false distro-sync
dnf -y --installroot "\$scratchmnt" clean all
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
