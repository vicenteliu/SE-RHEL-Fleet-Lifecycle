# The chain — from a subscription to a machine you can explain

Eight hops. Each one is owned end to end by one mechanism, and what proves it is usually one
outcome across several steps, which is why each is published as one **Runbook**. The interesting
failures are at the joints: a gold image that registers to the wrong environment, a patch cycle
that reads errata from a repository the host is not pinned to, an automation controller that
runs a playbook nobody can trace back to a version.

| # | Hop | Mechanism | Product | Upstream / alternative | State | Runbook |
|---|---|---|---|---|---|---|
| 0 | Subscription → entitled, supported host | `subscription-manager` · Insights · `sos` · a support case | RHEL subscription, Red Hat Insights, Customer Portal | CentOS Stream / Rocky / Alma (no entitlement, no case) | 🔨 lab — run 2026-09-15 | [0](../phases/0-subscription-and-support/) |
| 1 | Nothing → a versioned, reviewed baseline every host is born from | Kickstart `%packages`/`%post` · Image Builder blueprints | RHEL Image Builder (`osbuild-composer`) | osbuild (same project); Packer; a repacked ISO with preseed/cloud-init (the author's 🔨) | 🔨 lab — Image Builder, run 2026-09-15 · Kickstart 🔨 (RHCE) | [1](../phases/1-gold-image/) |
| 2 | Upstream content → a version hosts are pinned to | sync → **content view version** → promote through **lifecycle environments** → host pinned by activation key | Red Hat Satellite (Katello + Pulp) | Foreman + Katello; Uyuni; **by hand: `reposync` + `createrepo_c` + a symlink per environment** | 🔨 lab — by hand, this tier | [2](../phases/2-content-lifecycle/) |
| 3 | A serial number → an installed, registered host | Capsule DHCP/TFTP/DNS · host group · Kickstart template · activation key | Satellite provisioning (Foreman) | Cobbler; the author's own PXE chain (dnsmasq + TFTP + preseed) 🔨 | ⛔ · PXE chain 🔨 (prior) | [3](../phases/3-provisioning/) |
| 4 | Errata published → hosts patched, compliance proven | errata filters in a content view · remote execution · OpenSCAP policy | Satellite errata + REX; Insights advisor; compliance | `dnf updateinfo` · Ansible · `oscap` (same project) | 🔨 lab — errata by hand (phase 2); OpenSCAP 🧭 | [4](../phases/4-patch-errata-compliance/) |
| 5 | A playbook on one laptop → automation with an owner, a record and a permission model | job templates · credentials · RBAC · schedules · execution environments | Ansible Automation Platform | AWX (controller upstream) · ansible-core · Galaxy · `ansible-runner` · playbooks from a control node (the author's 🔨) | ⛔ · playbooks 🔨 (prior) | [5](../phases/5-automation/) |
| 6 | Hosts → a platform (VMs, images, networks on demand) | overcloud/undercloud · director · Nova/Neutron/Cinder | Red Hat OpenStack Services on OpenShift (RHOSO, formerly RHOSP) | OpenStack via RDO / DevStack / Kolla; OpenShift ↔ OKD; RHV ↔ oVirt (both winding down) | ⛔ | [6](../phases/6-platform/) |
| 7 | A Satellite server → one that survives its own upgrades | `satellite-maintain` · Capsule sync · backup/restore · database | Satellite operations | `foreman-maintain` (same tool) | ⛔ | [7](../phases/7-satellite-operations/) |

**Read the State column as the honesty ledger.** 🔨 = operated for real, with consequences (the
author's prior work, on Ubuntu and CentOS-era estates — see the footing table in the README).
🔨 lab = run on the minimum tier in this repository, commands and output on the page. 🧭 =
mapped and doc-checked, not run. ⛔ = specified in full, deliberately not run, reason stated
(ADR-0001). Three hops are ⛔ because the product that owns them runs only on x86_64 and the
minimum tier is Apple silicon; [docs/02](02-lab-tiers.md) names the machine that would move each.
Phases 0 and 1 ran the day a developer subscription was registered on the tier.

## What the next hop assumes about the previous one

- **1 assumes 0**: the image's first boot registers with an activation key that exists, against
  an environment that exists. An image with a hard-coded repository URL is a hop-2 failure
  waiting to be born.
- **2 assumes 1**: hosts born from the same image differ only by the content they were later
  pinned to; if they differ at birth, promotion tells you nothing.
- **3 assumes 2**: the host group's activation key names an environment; provisioning a host
  into `Library` is provisioning it into *whatever synced last night*.
- **4 assumes 2**: an erratum is only applicable to a host that can *see* it — the phase-2 run
  shows a rolled-back environment hiding an advisory from a host whose cache had not expired.
- **5 assumes 2 and 4**: a job template that patches runs *what the host is pinned to*; the
  controller adds who, when and the record, not what.
- **6 assumes 1 and 2**: a platform's images are gold images; its guests are hosts in the same
  lifecycle as the metal.
- **7 assumes all of it**: a Satellite upgrade that fails leaves every hop above without its
  mechanism, which is why the backup is the first command in that runbook and not the last.

## What this chain is not

Not a product tour: [docs/01](01-product-vs-upstream.md) is where product and upstream are set
side by side, per service, with what a subscription buys and what it does not. Not a claim of
having run Satellite: the author has not, and the footing table says so; every job on the
Satellite list appears here as it was done with separate tools, and once — on this tier — with
the promotion model rebuilt by hand so that the model itself is verified, not only described.
