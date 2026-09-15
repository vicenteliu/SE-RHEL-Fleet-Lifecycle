# Phase 6 — the platform: hosts → VMs, images and networks on demand

**Hop:** hosts → a platform that hands out VMs, images and networks. **Mechanism:** a control
plane (Keystone, Nova, Neutron, Glance, Cinder) over compute nodes; guests born from phase 1's
images, managed as hosts in phase 2–5's lifecycle. **Product:** Red Hat OpenStack Services on
OpenShift (RHOSO 18), the successor to Red Hat OpenStack Platform (RHOSP 17.1, director /
TripleO). **Upstream:** OpenStack via RDO (community packaging for RHEL-family), DevStack (the
developer all-in-one), Kolla-Ansible (services in containers). Adjacent: OpenShift ↔ OKD,
RHV ↔ oVirt (winding down), OpenShift Virtualization ↔ KubeVirt. **State: ⛔ Specced-Not-Run
on every tier here — no tier runs OpenStack. 🔨 underneath it: KVM/libvirt and vSphere
operations on prior estates; the platform layer above them is 🧭.**

This phase is in the chain because a RHEL fleet at scale usually stands on one of these, and
because the first three questions about the platform — *where do its images come from, are its
guests in the lifecycle, who patches the control plane* — are answered by phases 1, 2 and 4,
not by the platform. A platform whose guests are outside the lifecycle is a second fleet.

## Before you start

- **Machines**: RHOSO needs an OpenShift cluster for the control plane and RHEL compute nodes;
  RDO/Kolla need three machines to be a platform and one to be a demo; DevStack needs one
  machine with 16 GB and a tolerance for rebuilding it. None of this exists on the minimum or
  mid tier; the full tier is three nodes with KVM.
- **Images**: Glance takes what phase 1 builds (`qcow2` from Image Builder). A platform with
  hand-made images is phase 1's failure at scale.
- **Networks**: the provider networks and the tenant model decided before the first `openstack
  server create`, because they are the hard thing to change.

## Permissions

- The platform's own identity (Keystone) — projects, roles, quotas — which is a second RBAC
  next to the automation's and the OS's; an OpenStack admin can create a host the fleet's
  provisioning never saw.
- Storage and network backends (Cinder, Neutron) with vendor drivers; the certification matrix
  in [docs/01](../../docs/01-product-vs-upstream.md) is what the vendor points at when a
  volume detaches.

## Minimum test

One image from phase 1 uploaded to Glance; one instance booted from it that registers (phase 0)
into an environment (phase 2) on first boot and appears in the automation inventory (phase 5).
If a guest is a host, the platform is in the chain; if it is not, it is a second fleet.

## Hops

### Hop 1 — the control plane, and who runs it

RHOSO: the OpenStack services as operators on OpenShift, upgraded with it. RHOSP 17: director,
an undercloud that deploys the overcloud. RDO/Kolla: you. The upgrade is the difference between
the product and upstream here more than anywhere else in the chain.

### Hop 2 — 🥇 images are phase 1's images

`openstack image create --disk-format qcow2 --file rhel9-base-2026.09.qcow2`. The image
version is the same version; a platform with its own image pipeline has two baselines.

### Hop 3 — guests are hosts

Cloud-init on first boot registers with an activation key into an environment; the automation
inventory (phase 5) reads the platform (`openstack.cloud` inventory plugin) so the guest is
patched on the same cycle as the metal. A guest that lives a week is still patched; one that
lives an hour is rebuilt from the next image instead.

### Hop 4 — the compute nodes are hosts too

RHEL under Nova is a RHEL host in the fleet: pinned, patched, scanned, with the platform's
maintenance mode (evacuate, patch, reboot, return) as the extra step in the job template.

## How the phase fails

- Two image pipelines, and the platform's is the one nobody hardened.
- Guests registered by hand, or not at all, because "they're ephemeral" — the ones that were not
  are the unpatched hosts the scan (phase 4) never sees.
- The compute node patched without evacuating; the guests learned about the kernel update at
  reboot.
- An OpenStack upgrade attempted in place on upstream packaging without a rehearsal; the
  project's own documentation calls this the hard problem for a reason.

## Verify

| | Command | Expected · tier |
|---|---|---|
| 2 | `openstack image list` | the image with phase 1's name and version · full |
| 3 | instance's first boot: `subscription-manager identity` · `dnf repolist` | registered; only the environment's repositories · full |
| 3 | `ansible-inventory -i openstack.yml --graph` | the instance in the automation inventory · full |
| 4 | `openstack compute service set --disable <node>` · `openstack server migrate` · patch · enable | no guest lost during the node's patch · full |

## Acceptance

🔴 **A guest booted on the platform is a host in the fleet's lifecycle: born from the fleet's
image, pinned to an environment, in the automation inventory, in the scan.** ⛔ Not run on any
tier here. Not claimed: any OpenStack deployment, RHOSO, director, OpenShift, oVirt. 🔨 claimed
only for what is underneath: KVM/libvirt and vSphere operation on prior estates.

## Rollback

The platform's own: a snapshot of the control-plane state before an upgrade; for the guests,
the previous image version. There is no rollback of an OpenStack upgrade that was not
rehearsed, which is the sentence to say in a room where it is being planned.

## Escape Hatch

The team that needs VMs before the platform exists: KVM/libvirt on a RHEL host with the same
images (`virt-install --import` of the phase-1 `qcow2`), registered and in the inventory like
any guest. The platform can absorb them later; a snowflake hypervisor with hand-built guests
cannot be absorbed by anything.
