#!/bin/bash
# Phase 5 — automation, the 🔨 half at lab scale, from a control node that is the workstation:
#   a patch playbook for the `dev` host, --check then real, the state read back into one directory.
#   Not the controller.
# Control node: the macOS workstation with ansible-core (`uv tool install ansible-core`); the hosts
# are the two Lima VMs, reached through the ssh config the VM tool writes (lab/ansible/inventory.yml).
# Ran on 2026-09-15 from lab/ansible/. Every command below ran in this order; the output is lab/phase5.log.
set -euo pipefail
cd "$(dirname "$0")/ansible"
export PATH="$HOME/.local/bin:$PATH"
step() { printf '\n===== %s =====\n' "$*"; }
run()  { printf '  $ %s\n' "$*"; "$@" < /dev/null 2>&1 | sed 's/^/  /'; }
on_dev() { limactl shell rhel-lab -- bash -c "$1" 2>&1 | sed 's/^/  /'; }

step "0 · the control node and its inventory"
run ansible --version
run ansible-inventory --graph
run ansible all -m ping

step "1 · the state before: phase 2's model, with version 2.0 just promoted to dev and the host's cache not cleared"
on_dev '
set -e
ln -sfn /srv/content/cv/cv-base/1.0 /srv/content/env/dev
sudo ln -sfn /srv/content/cv/cv-base/1.0 /srv/content/env/prod
sudo sed -i "s#localhost:8080/[a-z]*/#localhost:8080/dev/#g; s/(prod)/(dev)/" /etc/yum.repos.d/lab.repo
pgrep -f "http.server 8080" >/dev/null || (cd /srv/content/env && nohup python3 -m http.server 8080 >/tmp/content-http.log 2>&1 &)
sudo dnf -q clean all; dnf -q clean all                                               # root'"'"'s cache and the login user'"'"'s
sudo dnf -q -y --disablerepo="*" --enablerepo="lab-*" downgrade lab-hello >/dev/null 2>&1 || true
sudo dnf -q --disablerepo="*" --enablerepo="lab-*" repoquery lab-hello >/dev/null   # root'"'"'s cache warm on 1.0; the user'"'"'s empty
ln -sfn /srv/content/cv/cv-base/2.0 /srv/content/env/dev                              # the promotion (row 2.4), without its cache step
echo "env:"; ls -l /srv/content/env | awk "NR>1{print \"  \" \$9 \" -> \" \$11}"
echo "host pinned to: $(grep -m1 baseurl /etc/yum.repos.d/lab.repo | sed "s#.*8080/##; s#/.*##")"
echo "installed: $(rpm -q lab-hello)"
echo "what root'"'"'s warm cache says the environment offers: $(sudo dnf -q --disablerepo="*" --enablerepo="lab-*" repoquery lab-hello | tr "\n" " ")"'

step "2 · the same ad-hoc question, asked as the login user and as root: two caches, two answers"
run ansible dev -m ansible.builtin.dnf -a "name=* state=latest disablerepo=* enablerepo=lab-*" --check
run ansible dev -m ansible.builtin.dnf -a "name=* state=latest disablerepo=* enablerepo=lab-*" --check --become

step "3 · the playbook, --check: what would change"
run ansible-playbook patch-dev.yml --check

step "4 · the playbook, for real"
run ansible-playbook patch-dev.yml

step "5 · read back from outside the playbook: the version on the host, and the erratum"
on_dev 'echo "installed: $(rpm -q lab-hello)"
echo "updateinfo --all, lab repositories: $(sudo dnf -q --disablerepo="*" --enablerepo="lab-*" updateinfo list --all 2>/dev/null | grep -i lab-hello || echo none)  (i = installed)"'

step "6 · the playbook again: nothing to do"
run ansible-playbook patch-dev.yml

step "7 · state read back from every host into one directory on the control node"
run ansible-playbook state.yml
for f in state/*.txt; do echo "  --- $f"; sed 's/^/  /' "$f"; done
