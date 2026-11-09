# A bare Ubuntu server: systemd, an SSH daemon, Python (Ansible needs it) and a sudo user. Nothing else.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y -qq systemd systemd-sysv openssh-server python3 sudo curl ca-certificates iproute2 >/dev/null \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
 && systemctl enable ssh >/dev/null 2>&1 \
 && useradd -m -s /bin/bash deploy \
 && echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy && chmod 440 /etc/sudoers.d/deploy
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
