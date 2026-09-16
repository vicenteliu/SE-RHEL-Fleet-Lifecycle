#!/bin/bash
# Phase 4, hop 4, through phase 5 — the seam: the remediation playbook oscap generates from a host's
# own results, run from the control node against a host that can be thrown away, --check first, then real.
#   host:     gold1 — booted from phase 1's image (lab/gold-boot.yaml), unregistered at the start
#   control:  the workstation, ansible-core (phase 5), lab/ansible/inventory.yml
# Reads RH_ORG and RH_KEY from the environment (phase 0's rule), never from a file.
# Ran on 2026-09-15 from lab/ansible/. Every command below ran in this order; the output is
# lab/phase4-remediation.log. The run ended at step 8 (firewalld) and, on reboot, the host had no
# login account left (step 10, the finding) — so a second, careful pass to a clean scan is a
# separate hop, not this one; it is TODO 10.
set -euo pipefail
cd "$(dirname "$0")/ansible"
export PATH="$HOME/.local/bin:$PATH"
: "${RH_ORG:?set RH_ORG}" "${RH_KEY:?set RH_KEY}"
DS=/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
P=xccdf_org.ssgproject.content_profile_cis_server_l1
W=/tmp/scap
step()  { printf '\n===== %s =====\n' "$*"; }
run()   { printf '  $ %s\n' "$*"; "$@" < /dev/null 2>&1 | sed 's/^/  /'; }
on()    { limactl shell gold1 -- bash -c "$1" 2>&1 | sed 's/^/  /'; }
tally() { on "grep -o '<result>[a-z]*</result>' $1 | sed 's/<[^>]*>//g' | sort | uniq -c | awk '{printf \"  %-14s %s\\n\", \$2, \$1}'"; }
scan()  { on "sudo oscap xccdf eval --profile $P --results $W/$1 $DS >/dev/null 2>&1; rc=\$?; sudo chown \$USER $W/$1; echo \"oscap exit \$rc  (0 = all pass, 2 = at least one fail)\""; tally $W/$1; }

step "0 · the throwaway host, as phase 1 left it"
on 'cat /etc/image-version; getenforce; uname -r; sudo subscription-manager identity 2>&1 | head -1; rpm -q openscap-scanner 2>&1 || true'

step "1 · the hand-off phase 1 named: register with the key, install the scanner from entitled content"
on "sudo subscription-manager register --org $RH_ORG --activationkey $RH_KEY 2>&1 | sed 's/ID: .*/ID: <uuid>/'
sudo subscription-manager repos --list-enabled | grep 'Repo ID' | sed 's/^ *//'
sudo dnf -q -y install openscap-scanner openscap-utils scap-security-guide yum-utils >/dev/null 2>&1 && rpm -q scap-security-guide
mkdir -p $W
rpm -qa | sort > $W/rpm-before.txt; systemctl list-unit-files --state=enabled --no-legend | awk '{print \$1}' | sort > $W/enabled-before.txt
echo \"packages: \$(wc -l < $W/rpm-before.txt) · enabled units: \$(wc -l < $W/enabled-before.txt)\""

step "2 · the host in the inventory"
run ansible-inventory --graph
run ansible gold -m ping

step "3 · the baseline: CIS L1 Server on the host as born"
scan r0.xml

step "4 · the playbook, generated from this host's own results, fetched to the control node"
on "sudo oscap xccdf generate fix --fix-type ansible --result-id \"\$(grep -o 'TestResult id=\"[^\"]*\"' $W/r0.xml | sed -n '1p' | cut -d'\"' -f2)\" --output $W/remediation-gold1.yml $W/r0.xml 2>/dev/null; sudo chown \$USER $W/remediation-gold1.yml
echo \"tasks: \$(grep -c '^  *- name:' $W/remediation-gold1.yml) · sha256 \$(sha256sum $W/remediation-gold1.yml | cut -c1-16)…\"
echo \"hosts line: \$(grep -m1 '^- hosts:' $W/remediation-gold1.yml)  ·  become: \$(grep -c '^  become:' $W/remediation-gold1.yml)\"
echo 'modules outside ansible-core:'; grep -oE '^ +(ansible\.posix|community\.[a-z]+)\.[a-z_]+:' $W/remediation-gold1.yml | sed 's/^ *//; s/:\$//' | sort | uniq -c | sed 's/^/    /'"
limactl copy gold1:$W/remediation-gold1.yml ./remediation-gold1.yml
echo "  copied to lab/ansible/remediation-gold1.yml (not committed; generated per host)"

step "5 · what the control node was missing: the two collections the generated playbook needs"
run ansible-galaxy collection install ansible.posix community.general
run ansible-galaxy collection list

step "6 · hosts: all — what the playbook would run against without a limit"
run ansible-playbook remediation-gold1.yml --list-hosts
run ansible-playbook remediation-gold1.yml --limit gold1 --list-hosts

step "7 · --check as the user the run will use — and the finding: the generated playbook has no become:"
set +e; ansible-playbook remediation-gold1.yml --limit gold1 --check < /dev/null > /tmp/rc.out 2>&1; rc=$?; set -e
echo "  exit $rc"; grep -A2 'PLAY RECAP' /tmp/rc.out | sed 's/^/  /'
echo "  it stops at the first task that writes a root file:"; grep -A3 '^fatal:' /tmp/rc.out | grep 'msg:' | sed 's/^ *//; s/^/    /'

step "7b · --check again, with --become, so the dry run is the run's own privilege"
set +e; ansible-playbook remediation-gold1.yml --limit gold1 --become --check < /dev/null > /tmp/rcb.out 2>&1; rc=$?; set -e
echo "  exit $rc"; grep -A2 'PLAY RECAP' /tmp/rcb.out | sed 's/^/  /'
echo "  firewalld-not-active aborts in this --check: $(grep -c 'firewalld service is not active' /tmp/rcb.out)  (the assert is guarded by 'ansible_check_mode or …')"

step "8 · the run, --become"
set +e; ansible-playbook remediation-gold1.yml --limit gold1 --become < /dev/null > /tmp/rr.out 2>&1; rc=$?; set -e
echo "  exit $rc"; grep -A2 'PLAY RECAP' /tmp/rr.out | sed 's/^/  /'
echo "  firewalld-not-active aborts in the real run: $(grep -c 'firewalld service is not active' /tmp/rr.out)  — the check said 0"
echo "  it failed at:"; grep -B1 '^fatal:' /tmp/rr.out | grep '^TASK' | sed 's/^TASK \[//; s/\] \*.*//; s/^/    /' | head -2
grep -A3 '^fatal:' /tmp/rr.out | grep -A2 'msg:' | sed 's/^ *//; s/^/      /' | head -3

step "9 · the scan again, no reboot; what the partial run changed besides the rules"
scan r1.xml
on "rpm -qa | sort > $W/rpm-after.txt; systemctl list-unit-files --state=enabled --no-legend | awk '{print \$1}' | sort > $W/enabled-after.txt
echo 'packages added:'; comm -13 $W/rpm-before.txt $W/rpm-after.txt | sed 's/^/    /'
echo 'units enabled:'; comm -13 $W/enabled-before.txt $W/enabled-after.txt | sed 's/^/    /'
sudo needs-restarting -r >/dev/null 2>&1; echo \"needs-restarting -r exit \$?\"
getenforce; sudo -n true && echo 'sudo without a password: still works'"

step "10 · reboot, then the scan a third time — and the finding that ends the run"
limactl stop gold1 >/dev/null 2>&1; limactl start gold1 --tty=false >/dev/null 2>&1
echo '  $ limactl shell gold1 -- whoami'
limactl shell gold1 -- whoami 2>&1 | sed 's/^/  /' || true
echo "  the run's own record of why (step 8):"
grep -m1 "'$(id -un)'" /tmp/rr.out | sed 's/^ *//; s/^/    /'
echo "  the login user's UID is 501 — inherited from the workstation; RHEL's UID_MIN is 1000, so the"
echo "  rule 'System Accounts Do Not Run a Shell' treats it as a system account and sets nologin."
echo "  there is no account left to run a third scan as; the last good scan is step 9. gold1 is spent."
limactl stop gold1 >/dev/null 2>&1 || true
