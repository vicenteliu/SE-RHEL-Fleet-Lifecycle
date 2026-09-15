# What an interviewer asks, hop by hop — and what a good answer contains

For the reader who is preparing to be asked, and for the reader who is preparing to ask. Each
hop of the chain has three or four questions a technical round on a RHEL fleet reliably
contains. For each: **what a good answer contains** (the structure, not a script), **the
mistake** that a weak answer makes, and **where in this repository the evidence is**. None of
this is the author's own answer — that stays private, on the author's own footing — it is what
the question is testing for, written so that anyone can check their own answer against it.

The pattern across all of them: an interviewer at this level is rarely testing whether you know
the product's screens. They are testing whether you understand the **model** underneath — a
version hosts are pinned to, a baseline hosts are born from, a job someone can trace — and
whether you can say **where the boundary of your own experience is** without being asked twice.
The second half is the one candidates fail.

## Hop 0 — subscription and support

**"Walk me through registering a new RHEL host into our environment."** A good answer names
the activation key (not a username), what the key carries (organisation, environment, content
view or repositories), that since RHEL 9 simple content access means register-then-entitled with
no attach step, and what to check afterwards (`subscription-manager status`, `dnf repolist`
showing only the environment's repositories). *Mistake:* describing `subscription-manager
register --username`, which is one person's lab box. *Evidence:* [phase 0](../phases/0-subscription-and-support/), hop 1.

**"A host is down and we're opening a case. What do you send?"** Version and kernel, `sos
report` with the case ID, the one command that reproduces it, what changed last, what was tried,
and — the sentence that marks experience — that you know `sos report --clean` exists and what
the report contains before it leaves. *Mistake:* "I'd describe the problem"; the first reply
will ask for the report. *Evidence:* phase 0, hops 4–5.

**"What does the subscription actually buy us over Rocky?"** Not the OS. An advisory ID to put
in an audit, EUS, a party obliged to fix a kernel bug on your timeline, Insights' rules, a
certification matrix. *Mistake:* "support" as one word. *Evidence:* [docs/01](01-product-vs-upstream.md), §1 and the pattern at the end.

## Hop 1 — the gold image

**"How do you build and maintain gold images?"** A good answer says *versioned, reviewed
baseline every host is born from* in the first sentence, then the two routes (Kickstart
`%post` vs Image Builder blueprints), what goes in (hardening that bakes, agents, repository
pointers, first-boot hand-off), and that a change is a diff someone approved and the image
version records it. *Mistake:* listing the packages in your image. The interviewer wants the
process that produces the next version. *Evidence:* [phase 1](../phases/1-gold-image/), hop 3.

**"Kickstart or Image Builder?"** Install-it vs build-it: Kickstart when hosts are installed
over the network from a provisioning server; Image Builder when you need a disk image for a
platform or the cloud; both from the same baseline definition, and both should register at
first boot. *Mistake:* choosing one as a matter of taste. *Evidence:* phase 1, hops 1–2; [docs/01](01-product-vs-upstream.md) §4.

**"What breaks first with gold images in practice?"** Drift after birth, because the image is
the start and configuration management is the rest; a hard-coded repository URL; two images
for two teams becoming two fleets. *Evidence:* phase 1, *How the phase fails*.

## Hop 2 — content and lifecycle

**"Explain content views and lifecycle environments."** The answer that shows the model:
a content view version is a *snapshot with its own metadata*, frozen at publish; an environment
is a *pointer* to one version; promotion moves the pointer; hosts are pinned by their
activation key to an environment and never see the library; rollback is the pointer pointed
back. A candidate who has only read the screens says "you promote content through Dev, Test,
Prod"; a candidate who understands says why a host on Prod cannot see Dev's erratum.
*Mistake:* describing it as copying content between environments. *Evidence:* [phase 2](../phases/2-content-lifecycle/), hops 2–5, run on this tier by hand with output.

**"We rolled back Prod and some hosts still show the new packages. Why?"** The host's metadata
cache — `metadata_expire` — and, on a host where someone ran `dnf` as a non-root user, that
user's own cache under `/var/tmp`. The rollback happened; the hosts have not looked yet. *This
question separates people who have run it from people who have read it.* *Evidence:* phase 2,
*How the phase fails*, first bullet, with the run that produced it.

**"How do you get a custom package into the fleet?"** Spec file → build → signed package →
custom product/repository → into the next content view version → promoted like everything
else, never `scp`'d to hosts. *Mistake:* stopping at `rpmbuild`. *Evidence:* phase 2, hop 1;
[`lab/lab-hello.spec`](../lab/lab-hello.spec).

**"Satellite or Foreman?"** Not a feature question: who owns the upgrade, and what does the
audit need to see. *Evidence:* [docs/01](01-product-vs-upstream.md) §2.

## Hop 3 — provisioning

**"Describe provisioning a new server end to end."** DHCP/TFTP/DNS from the Capsule, the host
group deciding everything (OS, partition table, template, environment, key), PXE → Kickstart →
`%post` registration → first boot → in the automation inventory, and *the report back* so that
the machine that hung is a row and not an absence. *Mistake:* stopping at "it PXE boots".
*Evidence:* [phase 3](../phases/3-provisioning/), hops 1–4.

**"You've done this without Satellite. What's different?"** The same four steps with dnsmasq,
an installer and an answer file; what Satellite adds is the host group as a first-class object,
the same host record across provisioning, content and patching, and the Capsule as a supported
role. *Evidence:* phase 3, hop 1; the footing table.

## Hop 4 — patching and compliance

**"Describe your patch cycle."** Promote a version to `dev`, apply there (remote execution or a
playbook), verify, promote to `test`, repeat, `prod` — the promotion is the gate; reboots are in
the job, not after it; `needs-restarting -r` is the check. *Mistake:* "monthly we run `dnf
update`". *Evidence:* [phase 4](../phases/4-patch-errata-compliance/), hop 2.

**"How do you know a host is compliant?"** From a scan (OpenSCAP against a profile with a
tailoring file), not from the patch log; and the report is about drift once the fleet's
exceptions are in the tailoring. *Mistake:* answering with the errata count. *Evidence:* phase 4,
hop 3.

**"Our errata report says zero applicable advisories on Prod. Are we patched?"** `updateinfo
list` counts what is *owed*, relative to what is installed — a host with the fix installed lists
nothing; `--all` shows it with `i`. Zero owed is good news only if the environment was ever
published with the advisories. *Evidence:* phase 2, finding B, verified on this tier.

## Hop 5 — automation

**"Playbooks versus Ansible Automation Platform — what does the controller give you?"** Not
automation; the playbooks already do that. RBAC on job templates, credentials as objects users
cannot read, a job history someone else can audit, execution environments that pin the runtime,
schedules and workflows. The answer that shows judgement adds *when you do not need it yet*: one
team, one control node. *Evidence:* [phase 5](../phases/5-automation/), hops 3–4; [docs/01](01-product-vs-upstream.md) §3.

**"Where does your inventory come from?"** The system of record — Satellite's inventory
plugin, the provisioning system — never a hand-kept file. *Evidence:* phase 5, hop 2.

**"Tell me about a playbook that went wrong."** The structure of a good answer: what it was
supposed to do, the blast radius (`limit`, `--check`, the inventory), what the record showed
afterwards, what changed in the template. The boundary sentence: if you ran playbooks from a
control node and never a controller, say so and say what the controller would have changed
about that incident.

## Hop 6 — the platform

**"How do OpenStack guests fit into your patch and compliance process?"** As hosts: born from
the fleet's image (Glance takes phase 1's `qcow2`), registered on first boot into an environment,
in the automation inventory through the platform's plugin, scanned like the metal; the compute
nodes are hosts with an evacuate step. *Mistake:* treating the platform as outside the fleet.
*Evidence:* [phase 6](../phases/6-platform/), hops 2–4.

**"RHOSP, RHOSO, RDO — what's the difference?"** Same services; the deployment method and who
owns the upgrade. RHOSO runs the control plane on OpenShift; RHOSP 17 was director; RDO is the
community packaging and the upgrade is yours. *Evidence:* [docs/01](01-product-vs-upstream.md) §6.

## Hop 7 — Satellite operations

**"How do you upgrade Satellite?"** Health check, backup, *restore the backup once on a test
machine*, `upgrade check`, `upgrade run`, one minor at a time, Capsules after, a case opened
beforehand for production. The sentence that marks experience is the restore rehearsal.
*Mistake:* "run the upgrade command". *Evidence:* [phase 7](../phases/7-satellite-operations/), hops 2–3.

**"What fills up first?"** Pulp's storage from content view versions nobody deleted; the
database from hosts and facts. *Evidence:* phase 7, hop 5.

## The two questions that are really one question

**"Have you run Satellite?"** and **"Have you run AAP?"** are asked to find the boundary, not to
disqualify. The answer that works has three parts and takes twenty seconds: *what you have run*
(the jobs on that list with separate tools, at what scale), *what the product changes* (the
versioned promotion model; the controller's RBAC and record), and *what you would be learning*
(the server itself; the controller's operations). It works because it is checkable and because
the interviewer already suspected the answer — what they are scoring is whether you drew the
line yourself. The chain above is built so that every part of that answer points at a page.
