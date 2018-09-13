FROM fedora:28

RUN dnf install -y virt-v2v jq origin-clients libguestfs libguestfs-tools-c libvirt-daemon libvirt-daemon-config-network python-pip && dnf clean all
RUN pip install j2cli

ENV LIBGUESTFS_BACKEND=direct

WORKDIR /v2v.d
ENTRYPOINT ["/v2v.d/job"]

ADD bin/job templates/ /v2v.d/
