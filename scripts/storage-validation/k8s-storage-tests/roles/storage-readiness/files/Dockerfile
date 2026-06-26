FROM registry.redhat.io/ubi8/ubi

RUN yum install -y sudo

RUN useradd -l -u 1000321000 -d /home/cpuser -s /bin/sh cpuser &&\
    echo "cpuser ALL=(ALL)   NOPASSWD: /bin/chmod, /bin/chown" >> /etc/sudoers && \
    echo "User added."

# set group permissions
RUN chgrp 1000321000 -R /home/cpuser && \
  chmod g+rwx,o+r /home/cpuser

RUN umask 007 && echo "file permissions test create file " >> /home/cpuser/gidtest.txt && \
    echo "file permissions test create file " >> /home/cpuser/sgtest.txt

RUN chown 1000321000:1000321000 /home/cpuser/gidtest.txt && \
    chown 3000:3000 /home/cpuser/sgtest.txt 

USER cpuser 

CMD /bin/bash