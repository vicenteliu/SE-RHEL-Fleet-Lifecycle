#!/bin/bash
# Phase 0 — subscription and support, on the minimum tier: one RHEL 9 aarch64 VM.
# Needs a Red Hat account with a subscription (a free developer subscription is enough) and an
# activation key made in the Hybrid Cloud Console (Inventory → System Configuration → Activation
# Keys). The organisation id and the key name come in as environment variables and are never
# written to disk by this script:
#   RH_ORG=<org-id> RH_KEY=<key-name> bash phase0.sh
#
# Ran on 2026-09-15. Every command below ran in this order; the output is lab/phase0.log with the
# organisation id and consumer UUID replaced by <org-id> / <uuid>.
set -euo pipefail
: "${RH_ORG:?set RH_ORG}" "${RH_KEY:?set RH_KEY}"
step() { printf '\n===== %s =====\n' "$*"; }

step "0 · what this host is"
cat /etc/redhat-release; uname -m
sudo subscription-manager version | sed 's/^/  /'
echo "  registered before we start?"; sudo subscription-manager identity 2>&1 | sed 's/^/    /' || true

step "1 · register with an activation key (the fleet path; no password touches the host)"
sudo subscription-manager register --org "$RH_ORG" --activationkey "$RH_KEY" | sed "s/$RH_ORG/<org-id>/g; s/^/  /"
sudo subscription-manager status | sed 's/^/  /'
sudo subscription-manager identity | sed "s/$RH_ORG/<org-id>/g; s/^/  /"
echo "  repositories the key enabled:"; sudo subscription-manager repos --list-enabled | grep -E 'Repo ID|Enabled' | sed 's/^/    /'

step "2 · entitled content: the CDN, and errata as advisories"
sudo dnf -q repolist | sed 's/^/  /'
echo "  advisories applicable to this image, by type:"; sudo dnf -q updateinfo summary 2>/dev/null | sed 's/^/    /'
echo "  one security advisory, named:"; sudo dnf -q updateinfo list --security 2>/dev/null | sed -n '1,3p' | sed 's/^/    /'

step "3 · Insights: what leaves the host, and what comes back"
sudo dnf -q -y install insights-client >/dev/null 2>&1 && echo "  insights-client installed"
sudo insights-client --register 2>&1 | sed 's/account [0-9]*/account <account>/; s/^/  /'
echo "  (waiting 120 s before --status: the inventory has not processed the upload yet, and a"
echo "   --status run too early reports NOT registered and removes the local registration — seen on the first run)"
sleep 120
sudo insights-client --status 2>&1 | sed 's/^/  /' || true
echo "  the collection is defined here (what is uploaded):"; ls /etc/insights-client/ | sed 's/^/    /'

step "4 · sos report: the first attachment on any case"
sudo dnf -q -y install sos >/dev/null 2>&1 && echo "  sos installed: $(rpm -q sos)"
sudo sos report --batch --case-id LAB-0001 --tmp-dir /var/tmp --quiet 2>&1 | grep -E 'saved in|sha256|size' | sed 's/^/  /' || true
f=$(ls -t /var/tmp/sosreport-*.tar.xz | sed -n '1p')
echo "  archive: $(basename "$f") · $(du -h "$f" | cut -f1)"
echo "  entries: $(sudo tar -tf "$f" | wc -l | tr -d ' ')  · top level:"; sudo tar -tf "$f" | awk -F/ 'NF>1{print $2}' | sort -u | sed -n '1,12p' | tr '\n' ' '; echo
echo "  a thing a person checks before sending — hostnames and IPs are in it:"; sudo tar -xOf "$f" --wildcards '*/sos_commands/host/hostname' 2>/dev/null | sed -n '1p' | sed 's/^/    sos_commands\/host\/hostname: /' || true
echo "  and every interface address:"; sudo tar -xOf "$f" --wildcards '*/ip_addr' 2>/dev/null | grep -c 'inet ' | sed 's/^/    inet lines in ip_addr: /' || true

step "5 · what a case would carry (no case is opened here)"
echo "  version:  $(cat /etc/redhat-release)"; echo "  kernel:   $(uname -r)"; echo "  identity: $(sudo subscription-manager identity | grep -i 'system identity' | sed "s/.*: //")" | sed 's/[0-9a-f]\{8\}-[0-9a-f-]\{27\}/<uuid>/'
echo "  bundle:   $(basename "$f")"
echo "  severity: chosen by business impact, not by the person's anxiety; a lab is Sev 4"

step "6 · leave the tier registered for the next hops; how to unregister is in the runbook"
sudo subscription-manager status | grep -i 'overall' | sed 's/^/  /'
