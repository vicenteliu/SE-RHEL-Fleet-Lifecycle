# The lab — what actually ran

These are the files the runs on the phase pages came from, byte for byte. A script is here
because it was run; there are no scripts here for the ⛔ hops.

| File | Used by |
|---|---|
| `rhel-lab.yaml` | the Lima template that boots the RHEL 9.8 aarch64 KVM Guest Image (not redistributable; download it yourself) |
| `phase0.sh` | register with an activation key → entitled repositories → errata counted and one named → Insights registered (with the wait) → `sos report` produced and inspected. Reads the organisation id and key name from the environment, never from a file |
| `phase0.log` | that run, with the organisation id, account number and consumer UUIDs replaced |
| `rhel9-base.toml` | phase 1's blueprint — the minimum baseline, versioned |
| `phase1.sh` | push → depsolve → compose to `qcow2` → download → checksum → metadata, on the registered RHEL VM |
| `phase1-check.sh` | the nine checks from inside a host booted from the image; exit 1 on a miss |
| `phase1.log` | the build, then both boots — the first with the VM tool's provisioning (SELinux left permissive), the second without (all nine ok) |
| `gold-boot.yaml` | the Lima template that boots a built image with the VM tool's containerd provisioning off |
| `phase4.sh` | CIS L1 baseline scan → one rule fixed → a tailoring for one exception → the generated playbook → one advisory applied by id → `needs-restarting` |
| `phase4.log` | that run |
| `tailoring-lab-cis-l1.xml` | the 614-byte tailoring `autotailor` wrote: one rule unselected, profile `lab_cis_l1` extending CIS L1 Server |
| `phase5.sh` | from the workstation as control node: the inventory pinged → the `dev` host reset to 1.0 with version 2.0 just promoted and its cache not cleared → the same ad-hoc `--check` as the login user and as root → the patch playbook `--check`, real, again → the read-back from outside → state read back from both VMs |
| `phase5.log` | that run; the account name and home path replaced |
| `ansible/` | the control node's files: `ansible.cfg`, `inventory.yml` (two Lima VMs, reached through the VM tool's own ssh config), `patch-dev.yml`, `state.yml`, and `state/<host>.txt` as the run left them |
| `phase2.sh` | library sync → custom RPM → content view versions → environments → a pinned host → an erratum → promotion → rollback |
| `phase2.log` | the output of that run, unedited except the account name (`lab-user`) and the home path (`~`); with an addendum for the two findings verified separately |
| `lab-hello.spec` | the custom package's spec, as it stood after the second build (version 1.1) |
| `updateinfo.xml` | the erratum attached to content view version 2.0 |
| `agent/phase2-rows2.4-2.6/` | the harness for the first ledger rows handed to models: context, two tasks, acceptance, resets, verify |
| `check_secrets.sh` | refuses a transcript with a key, a token or a private host in it — runs over `agent-runs/` before commit |
| `agent-runs/` | the evidence behind each 🔨 row in [`AGENT_BOUNDARY.md`](../AGENT_BOUNDARY.md); the record format is in its README |

## The minimum tier, reproduced

A Rocky Linux 9 VM on an Apple-silicon workstation. Any RHEL-family machine works; the VM is
only how the author has one.

```sh
# host (macOS): a Rocky 9 VM via Lima
limactl start --name rhel-lab --cpus 2 --memory 4 --disk 20 --tty=false template://rocky-9
limactl copy lab/phase2.sh rhel-lab:/tmp/phase2.sh
limactl shell rhel-lab -- sudo dnf -y install createrepo_c dnf-plugins-core rpm-build rpmdevtools python3
limactl shell rhel-lab -- bash /tmp/phase2.sh
```

`phase2.sh` is idempotent enough to re-run after `rm -rf /srv/content ~/rpmbuild
/etc/yum.repos.d/lab.repo` and `dnf remove lab-hello`; it is not idempotent on top of itself.
It leaves a `python3 -m http.server` on `:8080` serving the environments; kill it when done.

Phase 5's control node is the workstation itself:

```sh
uv tool install ansible-core        # or pipx; 2.21 was used
cd lab/ansible && ansible all -m ping
bash ../phase5.sh                   # resets the dev host to 1.0 first; needs phase 2's layout on rhel-lab
```

## What the phase-2 run is, and is not

It is Satellite's content model — sync, versioned snapshot, environment as pointer, host pinned
by its repository file, errata as version metadata — rebuilt with `reposync`, `createrepo_c`,
`cp -al` and `ln -sfn`, on one package at two versions. It is not Katello, not Pulp, not a
Capsule, not GPG-signed content, not the Red Hat CDN, not two hosts, not scale. Every line of
[phase 2](../phases/2-content-lifecycle/) that could be misread as the product says so.
