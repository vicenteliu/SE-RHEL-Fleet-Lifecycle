#!/bin/bash
# Phase 4, hop 4, the careful second pass (TODO 10b) — what an operator does after the first,
# unattended run aborted on the firewall rule and locked the host out (lab/phase4-remediation.log):
#   run the generated playbook with the rule that locks out and the two that abort held back by tag,
#   to a residual scan; then make the two decisions the playbook refuses — START the firewall so its
#   loopback rules can pass, and EXCEPT the below-UID_MIN login account in a tailoring (phase 4's
#   partition_for_tmp pattern) rather than let the rule set it nologin; then a final scan and a reboot.
#   host:    gold1 — a FRESH boot from phase 1's image (the first one is spent)
#   control: the workstation, ansible-core, lab/ansible/inventory.yml (the `gold` group)
# Reads RH_ORG and RH_KEY from the environment. Ran on 2026-09-15; output is lab/phase4-remediation-pass2.log.
set -euo pipefail
cd "$(dirname "$0")/ansible"
export PATH="$HOME/.local/bin:$PATH"
: "${RH_ORG:?set RH_ORG}" "${RH_KEY:?set RH_KEY}"
DS=/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
P=xccdf_org.ssgproject.content_profile_cis_server_l1
P2=xccdf_org.ssgproject.content_profile_lab_cis_l1_pass2
LOCKOUT=no_shelllogin_for_systemaccounts
FWABORT=firewalld_loopback_traffic_restricted,firewalld_loopback_traffic_trusted
W=/tmp/scap
step()  { printf '\n===== %s =====\n' "$*"; }
run()   { printf '  $ %s\n' "$*"; "$@" < /dev/null 2>&1 | sed 's/^/  /'; }
on()    { limactl shell gold1 -- bash -lc "$1" 2>&1 | sed 's/^/  /'; }
# tally/rulestate read a results file already on the VM; they take the basename.
tally() { on "grep -o '<result>[a-z]*</result>' $W/$1 | sed 's/<[^>]*>//g' | sort | uniq -c | awk '{printf \"  %-14s %s\n\", \$2, \$1}'"; }
scan()  { # $1 results basename; $2 optional extra oscap args (profile defaults to $P)
  local extra="${2:---profile $P}"
  on "sudo oscap xccdf eval $extra --results $W/$1 $DS >/dev/null 2>&1; echo oscap exit \$?; sudo chown \$(id -un) $W/$1"
  tally "$1"
}

step "0 · a fresh throwaway host, registered, scanner installed"
on 'cat /etc/image-version; getenforce; printf "login: %s uid=%s shell=%s\n" "$(id -un)" "$(id -u)" "$(getent passwd "$(id -un)" | cut -d: -f7)"'
on "sudo subscription-manager register --force --org $RH_ORG --activationkey $RH_KEY 2>&1 | sed 's/ID: .*/ID: <uuid>/'"
on 'sudo dnf -q -y install openscap-scanner openscap-utils scap-security-guide yum-utils >/dev/null 2>&1 && rpm -q scap-security-guide'
on "mkdir -p /tmp/scap"

step "1 · baseline, then the playbook generated from it"
scan r0.xml
on "RID=\$(grep -o 'TestResult id=\"[^\"]*\"' $W/r0.xml | head -1 | cut -d'\"' -f2); sudo oscap xccdf generate fix --fix-type ansible --result-id \"\$RID\" --output $W/remediation-gold1.yml $W/r0.xml 2>/dev/null; sudo chown \$(id -un) $W/remediation-gold1.yml; grep -c '^  *- name:' $W/remediation-gold1.yml | sed 's/^/  tasks: /'"
on "echo held-back tags present: lockout=\$(grep -c \"  *- $LOCKOUT\" $W/remediation-gold1.yml) fw_loopback=\$(grep -cE '  *- firewalld_loopback_traffic_(restricted|trusted)' $W/remediation-gold1.yml)"
limactl copy gold1:$W/remediation-gold1.yml ./remediation-gold1.yml >/dev/null 2>&1

step "2 · the run, with the lock-out rule and the two abort rules held back by tag"
t0=$(date +%s)
set +e; ansible-playbook remediation-gold1.yml --limit gold1 --become --skip-tags "$LOCKOUT,$FWABORT" < /dev/null > /tmp/r2run.out 2>&1; rc=$?; set -e
echo "  exit $rc · $(( $(date +%s) - t0 )) s"
grep -A2 'PLAY RECAP' /tmp/r2run.out | sed 's/^/  /'
echo "  'Remediation aborted' occurrences: $(grep -c 'Remediation aborted' /tmp/r2run.out)"
grep -B1 '^fatal:' /tmp/r2run.out | grep '^TASK' | sed 's/^TASK \[//; s/\] \*.*//; s/^/  failed: /' | head -3 || true

step "3 · still reachable, and the residual scan"
run ansible gold -m ping
on 'printf "login shell still: %s\n" "$(getent passwd "$(id -un)" | cut -d: -f7)"'
scan r1.xml
on "for r in $LOCKOUT firewalld_loopback_traffic_restricted service_firewalld_enabled; do printf '  %-42s %s\n' \$r \"\$(grep -A3 \"content_rule_\$r\\\"\" $W/r1.xml | grep -o '<result>[a-z]*</result>' | head -1 | sed 's/<[^>]*>//g')\"; done"

step "4 · decision A — START the firewall (the playbook enables but never starts it), then the two loopback rules"
on 'sudo systemctl enable --now firewalld; printf "is-active: %s · state: %s\n" "$(systemctl is-active firewalld)" "$(sudo firewall-cmd --state 2>&1)"'
t0=$(date +%s)
set +e; ansible-playbook remediation-gold1.yml --limit gold1 --become --tags "$FWABORT" < /dev/null > /tmp/r2fw.out 2>&1; rc=$?; set -e
echo "  exit $rc · $(( $(date +%s) - t0 )) s"; grep -A2 'PLAY RECAP' /tmp/r2fw.out | sed 's/^/  /'
scan r2.xml
on "printf '  firewalld_loopback_traffic_restricted now: %s\n' \"\$(grep -A3 'content_rule_firewalld_loopback_traffic_restricted\\\"' $W/r2.xml | grep -o '<result>[a-z]*</result>' | head -1 | sed 's/<[^>]*>//g')\""

step "5 · decision B — the below-UID_MIN login account: EXCEPT it in a tailoring, do not nologin it"
on "printf '  UID_MIN is %s; the login account is uid %s — the rule reads the access account as a system account\n' \"\$(awk '/^UID_MIN/{print \$2}' /etc/login.defs)\" \"\$(id -u)\""
on "autotailor --output $W/tailoring-pass2.xml --new-profile-id lab_cis_l1_pass2 --unselect $LOCKOUT $DS $P; sudo chown \$(id -un) $W/tailoring-pass2.xml; grep -c '<xccdf-1.2:select' $W/tailoring-pass2.xml | sed 's/^/  select elements in the tailoring: /'"
limactl copy gold1:$W/tailoring-pass2.xml ../tailoring-pass2-cis-l1.xml >/dev/null 2>&1
scan r3.xml "--tailoring-file $W/tailoring-pass2.xml --profile $P2"
on "printf '  %s in the tailored scan: %s\n' $LOCKOUT \"\$(grep -A3 'content_rule_${LOCKOUT}\\\"' $W/r3.xml | grep -o '<result>[a-z]*</result>' | head -1 | sed 's/<[^>]*>//g')\""

step "6 · reboot — the host is still a host"
limactl stop gold1 >/dev/null 2>&1; limactl start gold1 --tty=false >/dev/null 2>&1
on 'printf "up: %s · %s · firewalld %s · login=%s\n" "$(uptime -s)" "$(getenforce)" "$(systemctl is-active firewalld)" "$(whoami)"; sudo -n true && echo "sudo without a password: still works"'
run ansible gold -m ping
scan r4.xml "--tailoring-file $W/tailoring-pass2.xml --profile $P2"
on "echo '  still failing after the careful pass (first 12):'; grep -B2 '<result>fail</result>' $W/r4.xml | grep -o 'idref=\"[^\"]*\"' | sed 's/.*content_rule_//; s/\"//' | sed -n '1,12p' | sed 's/^/    /'; sudo needs-restarting -r >/dev/null 2>&1; echo needs-restarting-r-exit \$?"
