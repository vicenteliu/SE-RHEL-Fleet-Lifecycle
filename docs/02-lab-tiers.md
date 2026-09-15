# Lab tiers

A tier is a named environment with an explicit list of what it can verify **and what it
cannot**. The second list is the payload. This chain has a particular shape: the products that
own three of its hops — Satellite (Foreman + Katello), Uyuni, OpenStack — run only on x86_64,
and the machine the author has is Apple silicon. So the minimum tier verifies the *models* by
hand and the *host side* of every hop, and names exactly which x86_64 machine would move each
⛔ to 🔨 lab.

| Tier | What it is | Verifies | Cannot verify |
|---|---|---|---|
| **minimum** — *the one the runs in this repository used* | one RHEL-family VM on an Apple-silicon workstation (Rocky Linux 9.8, aarch64, 2 vCPU, 4 GB, under Lima); a second VM of the same kind when a client is needed; no subscription until an account exists | **phase 2 by hand**: `reposync` → content view versions (hardlinked snapshots) → environments as symlinks → a host pinned by its `.repo` → a custom RPM from a spec → an erratum in `updateinfo.xml` → promotion → rollback, and the two things the run exposed (cache, applicability) · **phase 1**: Kickstart syntax and `%post` (in a nested install, slow), Image Builder blueprints and `composer-cli` (osbuild runs on aarch64) · **phase 4**: `dnf updateinfo`, `oscap` with the SCAP Security Guide · **phase 5**: playbooks from a control node against the VMs · **phase 0** once a Red Hat account exists: `subscription-manager`, `insights-client`, `sos report` on a RHEL 9/10 aarch64 image from the developer subscription | Satellite / Foreman / Katello / Pulp themselves (x86_64) · Capsule sync · Uyuni · AAP / AWX controller (AWX needs Kubernetes; on this tier that is a cluster on a VM on a laptop, ⛔ by cost not by possibility) · OpenStack in any form · PXE boot of a real machine · anything at fleet scale |
| **mid** | one x86_64 machine, 4 vCPU / 12 GB / 80 GB — a cloud instance by the hour or a spare box — running Rocky 9, plus the minimum tier as its client | Foreman + Katello installed from the upstream installer: the same content view, environment and activation-key model *as the product does it*, a real Capsule-less provisioning of the minimum-tier VM over the network, remote execution; AWX via the operator on a single-node cluster; Uyuni on openSUSE Leap, for the Spacewalk lineage | Satellite itself (needs an entitlement and a manifest), OpenStack (needs three machines or 32 GB for a serious DevStack), an upgrade of Satellite across a major version, any real fleet |
| **full** | a subscribed Satellite with a Capsule and three or more RHEL clients; or an OpenStack lab (three nodes with KVM) | everything, including the upgrade path and the audit trail across an estate | nothing — but nothing here was run there, and the repository says so |

## Why the minimum tier is a VM on a laptop-class machine

Because it is what exists, and because the claim this repository most needs to stand behind —
*the content-lifecycle model is understood, not recited* — is verifiable there. A page that says
*Satellite promotes a content view to an environment* verifies nothing; a run that publishes
version 2.0, promotes it to `dev`, shows the `prod`-pinned host still offered 1.0, then rolls
`prod` back and catches the host's stale metadata cache hiding the rollback — verifies the model
and teaches one thing the product documentation does not lead with. That run is in
[phase 2](../phases/2-content-lifecycle/) with its output.

## What one machine would change

An x86_64 machine with 12 GB moves phase 3 (provisioning through Foreman) and the product half of
phase 2 (Katello doing what the script does) from ⛔ to 🔨 lab, and AWX from ⛔ to 🔨 lab. It
does not move Satellite itself — that needs a subscription and a manifest — and it does not move
OpenStack. Recorded here so the reader knows the price of each marker; recorded in
[TODO.md](../TODO.md) as *not bought for the marker*.

## Reproducing the minimum tier

```sh
# host (macOS, Apple silicon): a Rocky Linux 9 VM via Lima
limactl start --name rhel-lab --cpus 2 --memory 4 --disk 20 --tty=false template://rocky-9
limactl shell rhel-lab
# guest
sudo dnf -y install createrepo_c dnf-plugins-core rpm-build rpmdevtools python3
```

Any RHEL-family machine works; the VM is only how the author has one. The scripts under
[`lab/`](../lab/) assume nothing about Lima.
