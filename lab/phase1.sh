#!/bin/bash
# Phase 1 — the gold image, build-it route: one blueprint → one qcow2, on the minimum tier.
# Runs on the registered RHEL 9 VM (phase 0), where osbuild-composer resolves packages against
# the entitled repositories. Booting the result and checking it from inside is the host's job
# (see the runbook: Lima boots the qcow2; phase1-check.sh runs inside).
#
# Ran on 2026-09-15. Every command below ran in this order; the output is lab/phase1.log.
set -euo pipefail
BP=${1:-rhel9-base.toml}
step() { printf '\n===== %s =====\n' "$*"; }

step "0 · the builder"
rpm -q osbuild-composer osbuild weldr-client | sed 's/^/  /'
sudo composer-cli status show | sed 's/^/  /'
echo "  sources (entitled, via the subscription):"; sudo composer-cli sources list | sed 's/^/    /'

step "1 · the blueprint: push, depsolve"
sudo composer-cli blueprints push "$BP"
name=$(awk -F'"' '/^name = /{print $2; exit}' "$BP"); ver=$(awk -F'"' '/^version = /{print $2; exit}' "$BP")
echo "  pushed $name $ver"
sudo composer-cli blueprints depsolve "$name" | sed -n '1,4p;$p' | sed 's/^/  /'
echo "  packages depsolved: $(sudo composer-cli blueprints depsolve "$name" | grep -c '^    ')"

step "2 · compose: start, wait"
out=$(sudo composer-cli compose start "$name" qcow2); echo "  $out"
uuid=$(echo "$out" | awk '{print $2}')
t0=$(date +%s)
while :; do
  st=$(sudo composer-cli compose status | awk -v u="$uuid" '$1==u {print $2}')
  case "$st" in
    FINISHED|FAILED) break ;;
  esac
  sleep 20
done
echo "  $uuid $st after $(( $(date +%s) - t0 )) s"
[ "$st" = FINISHED ] || { sudo composer-cli compose log "$uuid" | tail -30; exit 1; }
sudo composer-cli compose info "$uuid" | sed -n '1,3p' | sed 's/^/  /'

step "3 · the image"
sudo composer-cli compose image "$uuid" | sed 's/^/  /'
img="$uuid-disk.qcow2"; sudo chown "$USER" "$img" "$uuid-metadata.tar" 2>/dev/null || sudo chown "$USER" "$img"
ls -la "$img" | awk '{print "  " $5 " bytes  " $9}'
qemu-img info "$img" 2>/dev/null | grep -E 'file format|virtual size' | sed 's/^/  /' || true
sha256sum "$img" | sed 's/^/  /'
echo "  metadata (what went in):"; sudo composer-cli compose metadata "$uuid" >/dev/null && sudo tar -tf "$uuid-metadata.tar" | sed 's/^/    /'
mkdir -p /tmp/out && cp "$img" /tmp/out/"$name-$ver.qcow2" && echo "  copied to /tmp/out/$name-$ver.qcow2 for the host to boot"
