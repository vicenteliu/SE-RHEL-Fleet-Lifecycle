#!/bin/sh
# State before task B: both environments on 2.0; the host pinned to prod, its metadata cache warm on 2.0.
set -eu
limactl shell rhel-lab -- bash -c '
set -e
ln -sfn /srv/content/cv/cv-base/2.0 /srv/content/env/dev
sudo ln -sfn /srv/content/cv/cv-base/2.0 /srv/content/env/prod
sudo sed -i "s#localhost:8080/[a-z]*/#localhost:8080/prod/#g; s/(dev)/(prod)/" /etc/yum.repos.d/lab.repo
sudo dnf -q clean all; dnf -q clean all
dnf -q --disablerepo="*" --enablerepo="lab-tools" repoquery lab-hello >/dev/null
sudo dnf -q --disablerepo="*" --enablerepo="lab-tools" repoquery lab-hello >/dev/null
pgrep -f "http.server 8080" >/dev/null || (cd /srv/content/env && nohup python3 -m http.server 8080 >/tmp/content-http.log 2>&1 &)
echo "reset-b: dev->2.0 prod->2.0, host pinned to prod, caches warm on 2.0"
ls -l /srv/content/env | sed "s/^/  /"
find /srv/content/cv -type f | sort | xargs md5sum | md5sum | sed "s/^/  cv fingerprint: /"'
