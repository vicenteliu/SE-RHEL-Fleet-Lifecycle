#!/bin/bash
# Phase 4 — patch, errata, compliance, on the minimum tier: the registered RHEL 9 VM (phase 0).
#   scan half:   OpenSCAP + the SCAP Security Guide, CIS Level 1 Server — baseline scan, one rule
#                fixed and re-scanned, a tailoring file for one agreed exception, the generated
#                remediation playbook
#   patch half:  one advisory applied by its id, the applicability list before and after,
#                needs-restarting
# Ran on 2026-09-15. Every command below ran in this order; the output is lab/phase4.log.
set -euo pipefail
DS=/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
P=xccdf_org.ssgproject.content_profile_cis_server_l1
W=/tmp/scap; mkdir -p $W
own() { sudo chown -R "$USER" $W; }
step() { printf '\n===== %s =====\n' "$*"; }
tally() { grep -o '<result>[a-z]*</result>' "$1" | sed 's/<[^>]*>//g' | sort | uniq -c | awk '{printf "  %-14s %s\n", $2, $1}'; }

step "0 · the scanner and the content"
sudo dnf -q -y install openscap-scanner openscap-utils scap-security-guide yum-utils >/dev/null 2>&1 || true
rpm -q openscap-scanner openscap-utils scap-security-guide | sed 's/^/  /'
echo "  profiles in the datastream: $(oscap info --profiles $DS | wc -l | tr -d ' ')"
oscap info --profiles $DS | grep -E 'cis' | sed 's/^/    /'

step "1 · baseline scan: CIS Level 1 Server, as the host stands after phases 0 and 1"
set +e; sudo oscap xccdf eval --profile $P --results $W/r1.xml --report $W/r1.html $DS >/dev/null 2>&1; rc=$?; set -e; own
echo "  oscap exit $rc  (0 = all pass, 2 = at least one fail)"
tally $W/r1.xml
echo "  a few of the failing rules:"; grep -B2 '<result>fail</result>' $W/r1.xml | grep -o 'idref="[^"]*"' | sed 's/idref="xccdf_org.ssgproject.content_rule_//; s/"$//' | sed -n '1,8p' | sed 's/^/    /'

step "2 · one rule, fixed and re-scanned"
R=xccdf_org.ssgproject.content_rule_sshd_set_max_auth_tries
echo "  before: $(grep -A3 "idref=\"$R\"" $W/r1.xml | grep -o '<result>[a-z]*</result>' | sed 's/<[^>]*>//g')"
echo "MaxAuthTries 4" | sudo tee /etc/ssh/sshd_config.d/40-cis.conf >/dev/null
echo "  wrote /etc/ssh/sshd_config.d/40-cis.conf: MaxAuthTries 4"
set +e; sudo oscap xccdf eval --profile $P --rule $R --results $W/r2.xml $DS >/dev/null 2>&1; set -e; own
echo "  after:  $(grep -A3 "idref=\"$R\"" $W/r2.xml | grep -o '<result>[a-z]*</result>' | sed 's/<[^>]*>//g')"

step "3 · a tailoring file: one agreed exception, so the report is about drift"
X=xccdf_org.ssgproject.content_rule_partition_for_tmp
echo "  the exception: $X — a single-disk lab VM has no separate /tmp partition, and the fleet standard for this tier says so"
echo "  in the baseline scan: $(grep -A3 "idref=\"$X\"" $W/r1.xml | grep -o '<result>[a-z]*</result>' | sed 's/<[^>]*>//g')"
autotailor --output $W/tailoring.xml --new-profile-id lab_cis_l1 --unselect $X $DS $P
grep -c "<xccdf-1.2:select" $W/tailoring.xml | sed 's/^/  select elements in tailoring.xml: /'
echo "  full scan again, untailored (step 2's fix is the only change since the baseline):"
set +e; sudo oscap xccdf eval --profile $P --results $W/r3a.xml $DS >/dev/null 2>&1; set -e; own
tally $W/r3a.xml
echo "  full scan, tailored:"
set +e; sudo oscap xccdf eval --tailoring-file $W/tailoring.xml --profile xccdf_org.ssgproject.content_profile_lab_cis_l1 --results $W/r3.xml $DS >/dev/null 2>&1; set -e; own
tally $W/r3.xml
echo "  the exception now: $(grep -A3 "idref=\"$X\"" $W/r3.xml | grep -o '<result>[a-z]*</result>' | sed 's/<[^>]*>//g' || echo 'not evaluated')"

step "4 · remediation is the same loop: the playbook the scan generates"
sudo oscap xccdf generate fix --fix-type ansible --profile $P --output $W/remediation.yml $DS 2>/dev/null; own
echo "  tasks in the generated playbook: $(grep -c '^  *- name:' $W/remediation.yml)"
grep -m3 'name:' $W/remediation.yml | sed 's/^ *//; s/^/    /'
echo "  from the results instead (only what failed on this host):"
sudo oscap xccdf generate fix --fix-type ansible --result-id "$(grep -o 'TestResult id="[^"]*"' $W/r1.xml | sed -n '1p' | cut -d'"' -f2)" --output $W/remediation-this-host.yml $W/r1.xml 2>/dev/null; own
echo "  tasks: $(grep -c '^  *- name:' $W/remediation-this-host.yml)"

step "5 · the patch half: one advisory, applied by its id"
sec_before=$(sudo dnf -q updateinfo list --security 2>/dev/null || true)
A=$(printf '%s\n' "$sec_before" | awk '/^RHSA/{print $1; exit}')
echo "  advisory: $A"
all_before=$(sudo dnf -q updateinfo list --all 2>/dev/null || true)
echo "  before: $(printf '%s\n' "$all_before" | awk -v a="$A" '$1==a || $2==a {print; exit}')"
sudo dnf -q -y update --advisory "$A" >/dev/null 2>&1 && echo "  applied"
all_after=$(sudo dnf -q updateinfo list --all 2>/dev/null || true)
echo "  after:  $(printf '%s\n' "$all_after" | awk -v a="$A" '$1==a || $2==a {print; exit}')  (i = installed)"
sec_after=$(sudo dnf -q updateinfo list --security 2>/dev/null || true)
echo "  security advisories still applicable: $(printf '%s\n' "$sec_before" | grep -c '^RHSA') before → $(printf '%s\n' "$sec_after" | grep -c '^RHSA') after"
set +e; sudo needs-restarting -r >/dev/null 2>&1; nr=$?; set -e
echo "  needs-restarting -r exit $nr  (0 = no reboot needed, 1 = reboot needed)"
sudo needs-restarting -r 2>/dev/null | sed -n '1,4p' | sed 's/^/    /'

step "6 · what an auditor gets: the report, the results, the tailoring, the playbook"
ls -la $W | awk 'NR>1 && $9 ~ /\./ {print "  " $5 " bytes  " $9}'
