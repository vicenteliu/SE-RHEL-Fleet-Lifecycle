# RHEL Fleet Lifecycle

**From a subscription to a host you can explain to an auditor. One runbook per phase, product
and upstream side by side, and every hop says whether it was run or only specified.**

`SE-` is the project prefix of [The Scrappy Engineer](https://linkedin.com/in/vicenteliu), the
author's channel; this is the third `SE-` project. It is a playbook — not a Satellite tutorial,
not a case study, and not a claim of having run the products it describes. It publishes no
fleet and no employer; [DISCLOSURE.md](DISCLOSURE.md) says where that line sits and why.

## Why this exists

A role specification named the daily work of a RHEL fleet — gold images, Satellite, Ansible
Automation Platform, custom RPMs, patch cycles — and the author had done every job on that list
with separate tools on other distributions and never with Red Hat's products. That is a
common shape and an honest one, and the usual ways of handling it are both wrong: pretend, or
apologise. This repository is the third way. The **chain** says what the work *is*, hop by hop,
in a form that can be run. The **comparison** says, per service, what the product is, what its
open-source counterpart is, what the subscription buys and — the honest axis for a chapter
about support — what you actually lose without it. The **runs** rebuild the one model that
matters most, Satellite's content lifecycle, by hand on one machine, so that it is verified
rather than recited, and record what the run taught that the documentation does not lead with.
The **ledger** says, per responsibility, where a model may act and where a person decides, with
the model and the date on every row that was tried. And the **interview page** says what a
technical round asks about each hop and what a good answer contains, for the reader preparing
to be asked and the one preparing to ask.

| If you have… | Read |
|---|---|
| **five minutes** | the [footing table](#where-the-author-stands) below, then [the chain](#the-chain), then [phase 2](phases/2-content-lifecycle/) — the model rebuilt by hand, with two findings |
| **fifteen** | [product vs upstream](docs/01-product-vs-upstream.md) — six services, one pattern, no prices; then [phase 0](phases/0-subscription-and-support/) — what "supported" means in commands, run |
| **a fleet to run** | the runbooks in order, [0](phases/0-subscription-and-support/) → [7](phases/7-satellite-operations/); [docs/02](docs/02-lab-tiers.md) first if you want to run any of it |
| **an interview next week** | [docs/04](docs/04-what-an-interviewer-asks.md) — the questions per hop, what a good answer contains, where the evidence is |
| **a model you want to hand part of this to** | [AGENT_BOUNDARY.md](AGENT_BOUNDARY.md) — per responsibility, what a person decides and what a model executes |
| **someone to explain it to** | [EXPLAIN.md](EXPLAIN.md) — the same chain with zero jargon |

---

## Where the author stands

Markers, not adjectives. The legend is [below](#honesty-markers); the test behind every line is
*"walk me through a time you did this, in detail — would it hold?"*

| Marker | Claim |
|---|---|
| 🔨 | **Standardised OS images in production** — a repacked Ubuntu installer with drivers and first-boot hooks, unattended install, cloud-init, a self-built PXE chain, every machine reporting back; years, batches of dozens, peaks of a couple of hundred a day. Earlier, CentOS-era deployment tooling |
| 🔨 | **RPM and .deb packaging at maintainer level** — spec files and build for CentOS-era tooling, .deb for the Ubuntu fleet, into managed repositories; source, patches, dependencies, build, release, rollback |
| 🔨 | **Package and repository management** — local mirrors and managed repositories as the only path software takes into a fleet |
| 🔨 | **Ansible from a control node** — playbooks pushing upgrades and pulling state back on a schedule across a couple of hundred hosts; playbook-driven, not a role library |
| 🔨 | **Patching, OS upgrades and hardening as daily operations** — package-version based, on the estates above |
| 🔨 | **KVM/libvirt and vSphere operations** — the hypervisors under a platform; not the platform |
| 🔨 lab | **The content-lifecycle model by hand** — sync, content view versions, environments, a pinned host, a custom RPM, an erratum, promotion, rollback — [phase 2](phases/2-content-lifecycle/), one VM, one afternoon, output on the page |
| 🔨 | **Kickstart** at RHCE level — the syntax and the `%post` pattern, not a Kickstart fleet |
| ⛔ | **Satellite, Foreman + Katello, Uyuni** — never administered; specified to the tier that could run them ([docs/02](docs/02-lab-tiers.md)), the model verified by hand |
| ⛔ | **Ansible Automation Platform / AWX** — the controller never operated; what it adds over the 🔨 line above is stated exactly in [phase 5](phases/5-automation/) |
| ⛔ | **OpenStack** in any form — specified, not run on any tier here |
| 🔨 lab | **`subscription-manager`, Insights, `sos`** — [phase 0](phases/0-subscription-and-support/) on a RHEL 9.8 aarch64 VM under a developer subscription: registered with an activation key, entitled content, 93 advisories counted, Insights registered, an 11 MB `sos report` inspected; two things the first run broke on, recorded |
| 🔨 lab | **Image Builder** — [phase 1](phases/1-gold-image/): one blueprint, 249 packages depsolved against entitled content, a 10 GiB `qcow2` in 139 s, booted, nine checks from inside; the first boot found the VM tool's provisioner had left SELinux permissive |
| 🔨 lab | **OpenSCAP** — [phase 4](phases/4-patch-errata-compliance/): CIS Level 1 Server on the host phases 0 and 1 built — 109 fail / 151 pass; one rule fixed and re-scanned; a 614-byte tailoring for one exception; the generated remediation playbook (1,714 tasks for the profile, 961 for this host); one RHSA applied by id |
| 🔨 lab | **A patch playbook against a pinned host** — [phase 5](phases/5-automation/): the workstation as control node, `ansible-core` 2.21, phase 2's `dev` host taken 1.0 → 1.1 by playbook, `--check` then real, `changed=0` on the second run, state read back from both VMs; a `--check` as one user and the change as another read two different metadata caches |

Everything above is stated at the depth the phases state it, and no deeper. The number behind
*"a couple of hundred"* and the organisations behind the estates are exactly the details
[DISCLOSURE.md](DISCLOSURE.md) keeps out.

---

## The chain

Eight hops, each owned end to end by one mechanism. [docs/00](docs/00-the-chain.md) has the
full table with what each hop assumes about the previous one.

| # | Hop | Product · upstream | State |
|---|---|---|---|
| 0 | Subscription → an entitled, supported host | RHEL subscription, Insights, the Customer Portal · none | **🔨 lab** |
| 1 | Nothing → a baseline every host is born from | Image Builder · osbuild, Packer, a repacked ISO | **🔨 lab** (Image Builder) · Kickstart 🔨 (RHCE) · Ubuntu version 🔨 |
| 2 | Upstream content → a version hosts are pinned to | Satellite (Katello + Pulp) · Foreman + Katello · Uyuni · **by hand** | **🔨 lab** |
| 3 | A serial number → an installed, registered host | Satellite provisioning · Foreman, Cobbler, a self-built PXE chain | ⛔ · PXE chain 🔨 (prior) |
| 4 | Errata → hosts patched, compliance proven | Satellite errata + REX, Insights · `dnf updateinfo`, Ansible, OpenSCAP | **🔨 lab** (errata, one advisory applied, CIS L1 scan + fix + tailoring) |
| 5 | A playbook → automation with an owner, a record, a permission model | Ansible Automation Platform · AWX, ansible-core | **🔨 lab** (the playbook half) · ⛔ controller · playbooks 🔨 (prior) |
| 6 | Hosts → a platform | RHOSO / RHOSP · OpenStack RDO, DevStack, Kolla; OKD; oVirt | ⛔ |
| 7 | A Satellite → one that survives its upgrades | `satellite-maintain` · `foreman-maintain` | ⛔ |

---

## The runbooks

One per phase — *Before you start · Permissions · Minimum test · Hops · How the phase fails ·
Verify · Acceptance · Rollback · Escape Hatch*. A command appears wherever a lab tier can
produce it; a script appears only where one was run.

| Phase | The one thing to take from it |
|---|---|
| [0 · subscription and support](phases/0-subscription-and-support/) | A fleet where `sos report` is a mystery has no support contract in practice, whatever the invoice says. **Run here.** `insights-client --status` right after `--register` unregisters the host — the inventory has not caught up; wait, then verify |
| [1 · gold image](phases/1-gold-image/) | The fleet's differences stop at the image; a change is a diff someone approved and the version records it. **Run here.** What the first-boot provisioner does to the baseline is part of the baseline — check from inside the booted host, never from the image's config |
| [2 · content and lifecycle](phases/2-content-lifecycle/) | A content view version is a snapshot with its own metadata; an environment is a pointer; a host is pinned to a pointer and never sees the library. **Run here.** Two findings: a rollback behind the same URL is invisible until the host's metadata cache expires — including the non-root user's own cache; and `updateinfo list` counts what a host is *owed*, not what an environment *published* |
| [3 · provisioning](phases/3-provisioning/) | The host group decides everything before the box is unpacked; the report-back is what makes a machine that hung a row instead of an absence |
| [4 · patch, errata, compliance](phases/4-patch-errata-compliance/) | Promote, then apply, per environment — the promotion is the control; and compliance is proven by a scan, not by the patch log. **Run here.** The image is not the baseline, the policy is: a freshly built host fails 109 of 260 CIS L1 rules |
| [5 · automation](phases/5-automation/) | The controller does not add automation; it adds who, when, with what credential, and a record — and you do not need it until a second team does. **Playbook half run here.** A `--check` that runs as a different user from the change reads a different metadata cache — the dry run and the change must look at the same data |
| [6 · platform](phases/6-platform/) | A guest is a host: born from the fleet's image, pinned, inventoried, scanned — or it is a second fleet |
| [7 · Satellite operations](phases/7-satellite-operations/) | The backup is hop 2 and the upgrade is hop 3, never the other way round; a backup that was never restored is a hope |

---

## Honesty markers

Inherited from [`sysadmin-self-cultivation`](https://github.com/vicenteliu/sysadmin-self-cultivation)'s
ADR-0003 through the two earlier `SE-` playbooks.

| | Means |
|---|---|
| 🔨 | **Operated for real**, with consequences. Survives a deep follow-up question. |
| 🔨 lab | **Run in this repository's lab tier** — real commands, real output, one machine. Not production, and the page says so. |
| 🧭 | **Verified ramp** — mapped and doc-checked, sometimes lab-verified. Not run. |
| ⛔ | **Specced-Not-Run** — a complete environment spec, verification steps and acceptance criteria, **deliberately not executed, with the reason stated**. Not a missing 🧭: a 🧭 has no plan, this has a reason ([ADR-0001](docs/adr/0001-specced-not-run-is-a-third-marker.md)). |

The test, unchanged: *if an interviewer said "walk me through a time you did this, in detail,"
would it hold?* A 🔨 with nothing behind it is the overclaim these markers exist to make
impossible — and an under-claim is the same defect pointing the other way.

### Why the markers exist, in one example

Phase 2's runbook could have described promotion as *moving content between environments*, as
half the internet does. The run showed it is moving a pointer, that a version costs no space
because it is hardlinks plus metadata, and that a rolled-back environment stays invisible to a
host whose non-root `dnf` cache has not expired — a thing the author would have answered wrong
in an interview the day before. **Doc-checked and run are different states.** Every claim here
says which one it is.

---

## Layout

<details>
<summary>Every file, one line each</summary>

| Path | What |
|---|---|
| [`docs/00-the-chain.md`](docs/00-the-chain.md) | The spine — every hop, product and upstream, and what the next one assumes about it |
| [`docs/01-product-vs-upstream.md`](docs/01-product-vs-upstream.md) | Six services: product, counterpart, what the subscription adds, what differs, what you lose without a contract, when the counterpart is right |
| [`docs/02-lab-tiers.md`](docs/02-lab-tiers.md) | Three tiers, defined by **the hop each one cannot verify**; why this tier is aarch64 and what an x86_64 machine would move |
| [`docs/04-what-an-interviewer-asks.md`](docs/04-what-an-interviewer-asks.md) | Per hop: the questions, what a good answer contains, the mistake, where the evidence is |
| [`docs/adr/`](docs/adr/) | Decisions that would otherwise look arbitrary |
| [`phases/`](phases/) | One runbook per phase |
| [`lab/`](lab/) | `phase0.sh`, `phase1.sh` + `phase1-check.sh`, `phase2.sh`, `phase4.sh` and their logs; the tailoring file; the blueprint; the Lima templates for the RHEL image and for booting a built image; the spec file and the erratum — what ran, byte for byte; `agent-runs/` and `check_secrets.sh` for the ledger |
| [`AGENT_BOUNDARY.md`](AGENT_BOUNDARY.md) | The ledger: where a model acts and where a person decides, a dated model line per row tried |
| [`EXPLAIN.md`](EXPLAIN.md) | The same chain with zero jargon — and a stated test for whether it worked |
| [`DISCLOSURE.md`](DISCLOSURE.md) | What this repository deliberately does not contain |
| [`CONTEXT.md`](CONTEXT.md) | The words this repository uses, and what each is chosen against |
| [`TODO.md`](TODO.md) | What gets written next, and why in that order |

</details>

---

## Disclosure

No employer, no client, no specification text, no claim of having run the products, no
subscription material, no prices. [DISCLOSURE.md](DISCLOSURE.md) is the full statement.

**Other `SE-` projects**: [`SE-macOS-Endpoint-Automation`](https://github.com/vicenteliu/SE-macOS-Endpoint-Automation)
(the first playbook — endpoints), [`SE-Agent-Environment-Sandbox`](https://github.com/vicenteliu/SE-Agent-Environment-Sandbox)
(the second — the sandbox under an agent).

MIT. The author is Vicente Liu.
