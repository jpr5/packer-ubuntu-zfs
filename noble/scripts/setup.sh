#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o xtrace

# install helpful packages
apt-get install -y --no-install-recommends --no-install-suggests \
        net-tools ngrep tcpdump wget curl telnet netcat-traditional whois \
        bc screen tmux psmisc strace lsof file rsync parallel pcp htop grc \
        unzip zip bzip2 xz-utils \
        gnupg \
        vim emacs-nox autoconf git git-lfs \
        build-essential cargo rustc pkg-config \
        libffi-dev libyaml-dev libssl-dev libreadline-dev zlib1g-dev \
        libmysqlclient-dev libpq5 libpq-dev \
        nfs-common \
        nginx ssl-cert certbot graphicsmagick

apt-get install -y --no-install-recommends --no-install-suggests \
        python3.12-dev python3-pip libsox-dev sox

python3 -V

# update the distribution to the latest
apt-get dist-upgrade -y
apt-get autoremove

# TIME
# tzselect #  2 <enter> 49 <enter> 21 <enter> 1 <enter>
rm /etc/localtime && ln -s /usr/share/zoneinfo/US/Pacific /etc/localtime

# SSHD
sed -ie 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
# Sudo should keep the ssh agent connection
echo Defaults env_keep = \"SSH_AUTH_SOCK\" > /etc/sudoers.d/keep_auth_sock

# Nuke default special perms for ubuntu
#rm -f /etc/sudoers.d/90-cloud-init-users

# tcp/ip timeouts
echo net.ipv4.tcp_keepalive_time = 60    > /etc/sysctl.d/50-keepalive.conf
echo net.ipv4.tcp_keepalive_intvl = 60  >> /etc/sysctl.d/50-keepalive.conf
echo net.ipv4.tcp_keepalive_probes = 10 >> /etc/sysctl.d/50-keepalive.conf

# ZFS ARC limits
cp -v /tmp/zfs.conf /etc/modprobe.d/

update-initramfs -u