ARG architecture

FROM --platform=linux/${architecture} registry.access.redhat.com/ubi9-minimal:latest as gcc-build

RUN microdnf install gcc --nodocs --noplugins --setopt=install_weak_deps=0 -y && \
    mkdir -p /tmp/lfcopy
COPY lock-file.c /tmp/lfcopy
RUN gcc -o /tmp/lfcopy/lock-file /tmp/lfcopy/lock-file.c

FROM --platform=linux/${architecture} cp.stg.icr.io/cp/cpd/ansible-operator-base:latest

LABEL name="k8s-storage-test" \
      maintainer="IBM" \
      vendor="IBM" \
      version="CP4D_VERSION" \
      release="Containerized packaging for the K8s storage validation ansible playbooks" \
      summary="This is a containerized version of the k8s-storage-tests ansible playbooks" \
      description="This image contains the ansible playbooks for running the storage test execution suite"

ARG architecture

USER 0

ENV HOME=/opt/ansible \
    USER_NAME=ansible \
    USER_UID=1001

RUN echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd \
    && mkdir -p ${HOME}/.ansible/tmp \
    && chown -R ${USER_UID}:0 ${HOME} \
    && chmod -R ug+rwx ${HOME}

ENV ANSIBLE_PYTHON_INTERPRETER /usr/local/bin/python
ENV PATH ${PATH}:${HOME}/bin
ENV ARCHITECTURE=${architecture}

RUN mkdir -p /licenses
COPY --chown=${USER_UID}:0 LICENSE /licenses

COPY bin ${HOME}/bin
COPY roles ${HOME}/roles
COPY *.yml LICENSE *.py *.sh ${HOME}
COPY cleanup.sh /usr/local/bin/cleanup.sh
COPY --from=gcc-build /tmp/lfcopy/lock-file /usr/local/bin/lock-file

RUN ln -fs ${HOME}/bin/entrypoint /usr/local/bin/entrypoint \
    && ln -s /usr/bin/python3 /usr/local/bin/python

###
ENV EXTRA_UID=1000321000
ENV EXTRA_GID=1000321000

RUN groupadd -g ${EXTRA_GID} cpuser && \
    useradd -l -u ${EXTRA_UID} -g ${EXTRA_GID} -d /home/cpuser -s /bin/sh cpuser &&\
    echo "User added."

RUN chgrp ${EXTRA_GID} -R /home/cpuser && \
  chmod g+rwx,o+r /home/cpuser

RUN umask 007 && echo "file permissions test create file " >> /home/cpuser/gidtest.txt && \
    echo "file permissions test create file " >> /home/cpuser/sgtest.txt

RUN chown ${EXTRA_UID}:${EXTRA_GID} /home/cpuser/gidtest.txt && \
    chown 3000:3000 /home/cpuser/sgtest.txt
###

RUN microdnf install -y --nodocs python3.12-setuptools-wheel python3.12-pip-wheel tar gzip util-linux-core \
    && export PIP_NO_CACHE_DIR=1 PIP_ROOT_USER_ACTION=ignore \
    && python3 -m ensurepip \
    && python3 -m pip install --upgrade pip setuptools \
    && python3 -m pip install openshift Jinja2 yasha argparse oauthlib \
    && python3 -m pip uninstall -y pip setuptools \
    && rpm --erase --nodeps python3.12-setuptools-wheel python3.12-pip-wheel \
    && microdnf clean all && rm -rf /var/cache/* /var/log/dnf* /var/log/yum.* /usr/share/zoneinfo

COPY oc.tgz /usr/local/bin
RUN cd /usr/local/bin \
    && tar -xvzf oc.tgz \
    && rm -f oc.tgz \
    && chown -R ${USER_UID}:0 ${HOME} && chmod -R ug+rwx ${HOME}


WORKDIR ${HOME}
USER ${USER_UID}

ENTRYPOINT ["/usr/local/bin/entrypoint"]
