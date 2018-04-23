FROM fedora:26


RUN dnf install -y virt-v2v jq origin-clients libosinfo python-pip && dnf clean all
RUN curl -L http://download.libguestfs.org/binaries/appliance/appliance-1.36.1.tar.xz | tar -C /usr/lib64/guestfs -xJf -
RUN pip install j2cli

ENV LIBGUESTFS_BACKEND=direct
ENV LIBGUESTFS_PATH=/usr/lib64/guestfs/appliance

WORKDIR /v2v.d
ENTRYPOINT ["/v2v.d/job"]

ADD bin/job templates/ /v2v.d/