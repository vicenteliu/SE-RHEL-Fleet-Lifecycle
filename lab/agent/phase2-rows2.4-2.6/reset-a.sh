#!/bin/sh
# State before task A: both environments on 1.0; the host pinned to dev, its metadata cache warm on 1.0.
set -eu
limactl shell rhel-lab -- bash -c '
set -e
ln -sfn /srv/content/cv/cv-base/1.0 /srv/content/env/dev
sudo ln -sfn /srv/content/cv/cv-base/1.0 /srv/content/env/prod
sudo sed -i "s#localhost:8080/[a-z]*/#localhost:8080/dev/#g; s/(prod)/(dev)/; s/(dev)/(dev)/" /etc/yum.repos.d/lab.repo
sudo dnf -q clean all; dnf -q clean all
dnf -q --disablerepo="*" --enablerepo="lab-tools" repoquery lab-hello >/dev/null   # warm the user cache on 1.0
sudo dnf -q --disablerepo="*" --enablerepo="lab-tools" repoquery lab-hello >/dev/null  # and root'"'"'s
pgrep -f "http.server 8080" >/dev/null || (cd /srv/content/env && nohup python3 -m http.server 8080 >/tmp/content-http.log 2>&1 &)
echo "reset-a: dev->1.0 prod->1.0, host pinned to dev, caches warm on 1.0"
ls -l /srv/content/env | sed "s/^/  /"
find /srv/content/cv -type f | sort | xargs md5sum | md5sum | sed "s/^/  cv fingerprint: /"'
