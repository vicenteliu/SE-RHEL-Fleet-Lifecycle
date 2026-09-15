# Phase 3 — provisioning: a serial number → an installed, registered host

**Hop:** a serial number → an installed, registered host. **Mechanism:** the provisioning
server's DHCP/TFTP/DNS (a Satellite **Capsule** with those features; a Foreman Smart Proxy), a
**host group** (OS, partition table, Kickstart template, activation key, environment), PXE →
Kickstart → first boot → registered. **Product:** Satellite provisioning (Foreman). **Upstream:**
Foreman; Cobbler; a self-built chain — dnsmasq (DHCP + TFTP), an installer, an answer file.
**State: ⛔ Specced-Not-Run — Foreman is x86_64 and the tier is not; the mid tier moves it. The
self-built chain is 🔨: the author ran one (dnsmasq + TFTP + preseed, a repacked ISO, a first-boot
report back) in production — the same mechanism with different file formats.**

The problem: a machine arrives, and the time between *rack it* and *someone can use it* is where
fleets differ by an order of magnitude. Provisioning makes it minutes and makes the hundredth
machine identical to the first, because the host group decided everything before the box was
unpacked.

## Before you start

- **Host**: the provisioning server on the network the new machines boot from, or a DHCP relay
  pointing at it. Mid tier: Foreman on the x86_64 machine, the minimum-tier VM as the client on
  a Lima user-v2 network.
- **The image or installer tree** (phase 1) reachable from the server; the Kickstart template
  referencing an environment's content (phase 2) and an activation key (phase 0).
- **A host group** per class of machine. The host group is the product; hosts are instances.

## Permissions

- Root on the server; DHCP authority on the provisioning VLAN (or a relay configured by the
  network team — the coordination that takes longer than the install).
- The activation key the template registers with, scoped to the environment the host group
  names.
- In Satellite, the *Capsule* must be assigned the subnet and the domain; a subnet with no
  Capsule provisions nothing and says so quietly.

## Minimum test

One MAC address in one host group, one PXE boot, one unattended install, one registration, one
`dnf repolist` on the new host showing only its environment. That is the whole chain from a
serial number to a host on a version.

## Hops

### Hop 1 — the network side: DHCP, TFTP, DNS

The client asks for an address; the answer carries `next-server` and the boot file; TFTP serves
the loader; the loader fetches the kernel, the initrd and the Kickstart URL. Satellite's Capsule
does all four when those features are enabled; a self-built chain does the same with dnsmasq —
which the author ran, with an installer and preseed instead of Kickstart.

### Hop 2 — the host group decides

OS and version, architecture, partition table, the Kickstart template, the environment, the
content view, the activation key, the root password or key, the compute profile if virtual.
A host is created by naming its MAC and its host group; everything else is inherited.

### Hop 3 — 🥇 the Kickstart template is where the phases meet

`%packages` from phase 1's baseline; `%post` registering with phase 0's key into phase 2's
environment; a first-boot unit that calls phase 5. A template is versioned with the host group;
a change to it is a change to every future host in the group.

### Hop 4 — the report back

The install reports completion (Satellite: the host's build status flips; the author's chain:
a callback to the server, so that a machine that never finished is a row, not an absence). A
provisioning system that cannot list *machines that started and did not finish* has a hole
exactly where the failures are.

## How the phase fails

- A second DHCP server on the provisioning VLAN wins some of the time; hosts boot from the wrong
  answer intermittently, which is the worst kind of failure to reproduce.
- The Kickstart registers into `Library`, so the new host gets *whatever synced last night*.
- The template has the right packages and the wrong partition table; the host installs and fills
  its root filesystem in a month.
- Re-provisioning a host that is still registered creates a second record with the same name in
  every system that trusts the first.
- The report-back is a log line nobody reads; the machine that hung at 60% is discovered by the
  person who needed it.

## Verify

| | Command | Expected · tier |
|---|---|---|
| 1 | `tcpdump -ni <if> port 67 or port 69` during a boot | one DHCP offer, one TFTP read of the loader · mid |
| 2 | `hammer hostgroup info --name <group>` (Foreman: `hammer` works upstream too) | OS, environment, content view, activation key, template all set · mid |
| 3 | the new host: `subscription-manager identity` · `dnf repolist` | registered to the right org; only the environment's repositories · mid |
| 4 | `hammer host list --search 'build = true'` | empty after the install completes · mid |
| — | the author's chain: the server's callback log | one row per machine with a finished timestamp; the unfinished ones by absence of it · 🔨 prior |

## Acceptance

🔴 **A host provisioned from a host group registers into the group's environment and nothing
else, and the server can list the hosts that started and did not finish.** ⛔ Not run here.
The mid tier runs the Foreman half; nothing runs a real PXE boot of a physical machine in this
repository.

## Rollback

Delete the host record; the machine is a serial number again. A host group change is rolled back
by reverting its template version.

## Escape Hatch

A machine that cannot PXE boot — no network boot, a firmware that will not, a site with no
provisioning VLAN. The documented path is **boot media with the Kickstart embedded** (an ISO
built by Image Builder or `mkksiso`), so that the host still comes from the template and still
registers where the group says; USB-and-hands is the same path with a person as the network.
