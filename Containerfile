FROM quay.io/centoshyperscale/centos

# Based on https://developers.redhat.com/blog/2019/08/14/best-practices-for-running-buildah-in-a-container

RUN dnf -y update
RUN dnf -y install buildah fuse-overlayfs --exclude container-selinux
RUN dnf -y clean all

# Adjust storage.conf to enable Fuse storage.
RUN sed -i /etc/containers/storage.conf \
        -e 's|^#mount_program|mount_program|g' \
        -e '/additionalimage.*/a "/var/lib/shared",'
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers \
 && touch /var/lib/shared/overlay-images/images.lock \
          /var/lib/shared/overlay-layers/layers.lock

# Define uid/gid ranges for our user
# https://github.com/containers/buildah/issues/3053
RUN echo build:2000:50000 > /etc/subuid \
 && echo build:2000:50000 > /etc/subgid

# Set an environment variable to default to chroot isolation
ENV BUILDAH_ISOLATION=chroot

COPY make-hyperscale-container.sh make-hyperscale-container

ENTRYPOINT ["./make-hyperscale-container"]
CMD ["make-hyperscale-container"]
