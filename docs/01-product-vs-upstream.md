# Product and upstream, side by side

Every Red Hat product in this chain has an open-source counterpart, and in most cases the
product *is* the counterpart with a subscription wrapped around it. That sentence is true and
useless until it is made specific per service: what the subscription adds, what is functionally
different, and — the honest axis for a chapter titled *support* — **what you actually lose when
there is no contract behind the system**. No prices here; they decay in a quarter. Version
numbers are dated where they appear.

Marker on the right is the author's footing for that pair: 🔨 operated · 🧭 doc-checked · ⛔ neither.

## 1 · The operating system

| | Red Hat Enterprise Linux | CentOS Stream · Rocky Linux · AlmaLinux |
|---|---|---|
| **Relationship** | The product. Stream is its *upstream* (what the next minor release will be); Rocky and Alma are *rebuilds* from the published RHEL sources, binary-compatible by intent | Stream: rolling toward the next RHEL point release. Rocky/Alma: track RHEL point releases, lag by days to weeks |
| **The subscription adds** | Entitlement (content from the CDN by channel and lifecycle), errata with advisory IDs and CVE mapping, **Extended Update Support** (stay on a minor release longer), Insights, a support case with an SLA, hardware and software certification lists | None of it. Community errata exist as package updates without a Red Hat advisory to cite |
| **Functionally different** | `subscription-manager` is the registration path; repositories are gated by entitlement | `dnf` against public mirrors; no registration. Rocky/Alma ship the same packages with different branding |
| **Lose without a contract** | Not the OS — the OS runs the same. What is lost is: a party obliged to fix a kernel bug on *your* timeline; an advisory ID to put in an audit; EUS; a certified answer to "is this hardware supported" | Already without it; the trade is made at install |
| **When the counterpart is right** | | Lab tiers (this repository's minimum tier is Rocky 9 for that reason); fleets whose compliance regime does not require a vendor advisory; anywhere the support SLA would never be invoked | 🔨 CentOS-era estate; Ubuntu fleet; RHEL as RHCE |

## 2 · Content and lifecycle management

| | Red Hat Satellite | Foreman + Katello (+ Pulp, Candlepin) |
|---|---|---|
| **Relationship** | Satellite 6 *is* Foreman + Katello + Pulp + Candlepin, packaged, versioned together, tested as one and supported. Satellite 6.19 (2026) tracks one Foreman 3.x / Katello 4.x pair — the exact pair is in each release's notes | The upstream projects, released independently; Katello's version pairs with a Foreman version |
| **The subscription adds** | Red Hat CDN as a content source with the entitlement handled for you (manifest, Candlepin); the **Capsule** as a supported role; the upgrade path (`satellite-maintain`) tested per release; Insights integration; a support case that covers the whole stack including Pulp and PostgreSQL | Community content sources (any yum/apt repo, Red Hat CDN *if you bring a manifest*); the same Smart Proxy under its upstream name; `foreman-maintain` — the same tool |
| **Functionally different** | Very little on the day. Satellite lags upstream by months and drops or gates features that are not yet supportable; some plugins never ship in Satellite | Newer, more plugins, and every version combination is yours to test |
| **Lose without a contract** | **The upgrade.** Satellite's upgrade path is the single most valuable supported thing: a failed Katello/Pulp/PostgreSQL migration on a server every host depends on is the outage this chapter exists to prevent. Also lost: someone to call when Pulp's content sync wedges at 3 a.m. and the errata window closes at 6 | You own the upgrade, and the test bed for it |
| **When the counterpart is right** | | A fleet on Rocky/Alma/Ubuntu with no Red Hat content; a team that already runs Foreman for provisioning and wants Katello for content; anyone who can afford to stage every upgrade themselves | 🧭 both; the *model* 🔨 lab in [phase 2](../phases/2-content-lifecycle/) by hand |

**The one thing to say about Spacewalk.** Spacewalk was the upstream of Satellite **5**, a
different codebase (channels, not content views). It reached end of life in May 2020. Its living
descendant is **Uyuni**, which SUSE forked in 2018 and which is the upstream of SUSE Manager (now
SUSE Multi-Linux Manager). Uyuni manages RHEL-family hosts too, and it is the answer when
someone says *"we want Spacewalk back"*: same channel model, Salt underneath instead of the old
client, actively released. It is not Satellite 6 and does not try to be. ⛔ x86_64 only, not
run here.

## 3 · Automation

| | Ansible Automation Platform | AWX · ansible-core · Galaxy · ansible-runner |
|---|---|---|
| **Relationship** | AAP = **automation controller** (upstream AWX), **automation hub** (upstream Galaxy, curated to certified collections), **execution environments** (upstream `ansible-builder`/`ansible-runner`), **Event-Driven Ansible** (upstream `ansible-rulebook`), a platform gateway over all of it. AAP 2.6 (2026) | The projects. AWX is the controller with the same job templates, inventories, credentials, RBAC, schedules and job history |
| **The subscription adds** | Certified and validated content (collections with a support statement), the controller as a supported install on RHEL or OpenShift, EDA, Insights analytics for automation, and a case that covers a playbook run failing inside the controller | AWX installs on Kubernetes only (the operator); no support statement on any collection; you assemble the pieces |
| **Functionally different** | Feature-for-feature the controller is AWX; AAP's install is on RHEL/OpenShift, AWX's is Kubernetes. AAP gates certain features to the platform gateway | Newer, sometimes broken between releases; the Kubernetes requirement is the practical difference for an ops team without a cluster |
| **Lose without a contract** | Not the playbooks — `ansible-core` is the same. What is lost is the controller as a *supported* thing: the upgrade, the RBAC/credential store's security posture on someone else's conscience, and a collection you can cite as certified when a change board asks | The playbooks, the control node, cron and a log file — the author's 🔨 configuration, which is exactly what a controller replaces: no RBAC, no shared credential store, no per-run record anyone else can read |
| **When the counterpart is right** | | One team, one control node, a repository of playbooks and a log: the controller solves a problem you do not have yet. The moment a second team or a non-engineer needs to press the button, the problem exists | 🔨 playbooks from a control node (220+ hosts) · ⛔ AWX / AAP |

## 4 · Images

| | RHEL Image Builder | osbuild · Packer · a repacked ISO with preseed / Kickstart |
|---|---|---|
| **Relationship** | Image Builder is `osbuild-composer` + `composer-cli` + the web console plugin + the hosted builder in Insights. **Same project** as upstream osbuild | osbuild: identical. Packer: a different tool with the same job (an image from a definition). A repacked installer ISO with an unattended-install answer file and a first-boot hook: the oldest method, and the one the author ran in production 🔨 |
| **The subscription adds** | Blueprints that resolve against entitled content; the hosted builder; images that register on first boot with an activation key | The blueprint format is the same; content is whatever repositories you point it at |
| **Functionally different** | Output formats (qcow2, AMI, VHD, ISO, edge/ostree) come from the same osbuild; Image Builder in Insights adds the hosted path | Nothing at the format level |
| **Lose without a contract** | Nearly nothing for the tool. What a contract adds is content with errata behind the image, i.e. an image you can *prove* is at a patch level | |
| **When the counterpart is right** | | Always, if the content is not Red Hat's. The method is the point: **a versioned, reviewed baseline every host is born from**; the tool is a detail that changes per platform | 🔨 the Ubuntu version of the method (ISO + preseed + cloud-init + PXE, years in production) · 🧭 Image Builder · Kickstart at RHCE level |

## 5 · Errata, compliance, insight

| | Red Hat Insights · Satellite compliance | `dnf updateinfo` · OpenSCAP · your own reporting |
|---|---|---|
| **Relationship** | Insights is a hosted service (advisor, vulnerability, compliance, patch, drift, image builder) fed by `insights-client`; Satellite's compliance is **OpenSCAP** run through Satellite with the SCAP Security Guide content | OpenSCAP and the SCAP Security Guide are the same open-source projects; `oscap` runs them anywhere. `dnf updateinfo` reads errata from whatever repository carries `updateinfo.xml` — [phase 2](../phases/2-content-lifecycle/) attaches one by hand |
| **The subscription adds** | Errata *as advisories* with CVE mapping and severity from Red Hat; Insights' rules (known bad configurations, from Red Hat's support case corpus); a compliance report a regulator recognises; drift baselines | Advisories exist only where a repository publishes `updateinfo`; Rocky/Alma publish some; a custom repository publishes what you write |
| **Functionally different** | Insights has no open-source counterpart — it is a service over Red Hat's knowledge base. The *scanning* half (OpenSCAP) is identical | You can scan; you cannot get Red Hat's rule set |
| **Lose without a contract** | **The advisory ID.** A CVE closed by "we updated the package" and a CVE closed by "RHSA-2026:1234 applied on the 3rd, host list attached" are the same fix and different audits. And the rules: Insights knows a kernel parameter combination will crash under load because a thousand cases said so | You build the mapping from CVE to package version yourself, and keep it |
| **When the counterpart is right** | | A fleet with its own vulnerability tooling already mapping CVEs to packages; a compliance regime satisfied by an OpenSCAP report without a vendor's name on it | 🔨 patch compliance as a daily operation (prior, package-version based) · 🧭 OpenSCAP · ⛔ Insights |

## 6 · Platform

| | Red Hat OpenStack Services on OpenShift (RHOSO 18; RHOSP 17 before it) | OpenStack via RDO · DevStack · Kolla-Ansible |
|---|---|---|
| **Relationship** | RHOSO deploys the OpenStack control plane as operators on OpenShift with RHEL compute nodes; RHOSP 17.1 was the last director-deployed (TripleO) release | RDO is the community packaging of OpenStack for RHEL-family; DevStack is the developer all-in-one; Kolla runs the services in containers with Ansible |
| **The subscription adds** | A tested combination of OpenStack release, OpenShift version and RHEL version, with an upgrade path between them; certified drivers (storage, SDN); a case that spans the stack | Every combination is yours; upgrades between OpenStack releases are the known hard problem of the project |
| **Functionally different** | The deployment method is the whole difference. Same Nova, Neutron, Cinder, Glance, Keystone | Same services, packaged by the community |
| **Lose without a contract** | The upgrade, again — an OpenStack upgrade without a vendor is a project, not a task. And the driver certification matrix, which is what a storage vendor points at when a volume detaches under load | |
| **When the counterpart is right** | | A lab; a team with OpenStack engineers who own upgrades as their job; anywhere OpenShift is not already in the estate (RHOSO requires it) | ⛔ — no tier here runs any of it; 🔨 KVM/libvirt and vSphere operations underneath |

**OpenShift ↔ OKD.** OKD is the community distribution of OpenShift built on Fedora CoreOS
instead of RHEL CoreOS. Same operators, same `oc`. What the subscription buys is the RHCOS base,
certified operators, and the support case; what OKD buys is the platform without either. Not in
this chain's runbooks; here because RHOSO stands on it. **RHV ↔ oVirt.** Red Hat Virtualization
reached end of life, with its extended-life phase running out in 2026; oVirt continues as a community project with
reduced activity. The migration target Red Hat names is OpenShift Virtualization (upstream
KubeVirt). For a fleet on RHV the question is not RHV vs oVirt; it is KubeVirt vs a hypervisor
from outside the family. **Identity Management ↔ FreeIPA.** IdM is FreeIPA shipped in RHEL; same
code, entitled content, a case. Not a hop in this chain, in the table because a Satellite realm
and a Kickstart `%post` both usually enrol into it.

## The pattern

Across all six, the subscription buys three things and the same three every time: **a tested
combination with an upgrade path**, **an advisory or certification with a name on it**, and **a
party obliged to answer**. It almost never buys a feature. The functional differences are
version lag and plugin gating on the product side, and assembly and upgrade ownership on the
upstream side. Which is why the question *"should we pay for Satellite or run Foreman?"* is not a
feature comparison; it is *"who owns the upgrade, and what does the audit need to see?"* — and
the honest answer depends on the fleet, not on the software.
