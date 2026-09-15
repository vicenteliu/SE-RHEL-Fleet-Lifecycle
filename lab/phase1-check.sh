#!/bin/sh
# Phase 1 — the checks from inside a host booted from the image. Exit 1 on any miss.
# Ran on 2026-09-15 inside the booted rhel9-base 2026.9.15 image; output in lab/phase1.log.
rc=0
chk() { if eval "$2"; then echo "  ok   $1"; else echo "  MISS $1"; rc=1; fi; }
echo "===== inside the booted image ====="
echo "  $(cat /etc/redhat-release) · $(uname -r) · $(uname -m)"
chk "image version file"      'grep -q "^rhel9-base 2026.9.15$" /etc/image-version'
chk "package from blueprint"  'rpm -q tmux >/dev/null'
chk "agent from blueprint"    'rpm -q insights-client >/dev/null'
chk "sshd: no password auth"  'sudo sshd -T 2>/dev/null | grep -qi "^passwordauthentication no"'
chk "sshd: no root login"     'sudo sshd -T 2>/dev/null | grep -qi "^permitrootlogin no"'
chk "kernel arg from blueprint" 'grep -qw "audit=1" /proc/cmdline'
chk "chronyd enabled"         'systemctl is-enabled chronyd >/dev/null 2>&1'
chk "SELinux enforcing"       '[ "$(getenforce)" = Enforcing ]'
chk "not registered (birth is not registration)" '! sudo subscription-manager identity >/dev/null 2>&1'
echo "  hostname: $(hostname)"
exit $rc
