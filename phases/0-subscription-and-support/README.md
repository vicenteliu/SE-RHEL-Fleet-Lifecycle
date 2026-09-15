# Phase 0 — subscription and support: an entitled host, and what "supported" means in practice

**Hop:** a subscription → an entitled, supported host. **Mechanism:** `subscription-manager` ·
`insights-client` · `sos report` · a support case with the right attachments. **Product:** the
RHEL subscription, Red Hat Insights, the Customer Portal. **Upstream:** none — a Rocky or Alma
host has the OS and none of this. **State: 🔨 lab — run on 2026-09-15 on a RHEL 9.8 aarch64 VM
under a developer subscription, every command and its output in [`lab/phase0.log`](../../lab/phase0.log).**
The run took three attempts to get a clean log, and the two things that broke the first two are
in *How the phase fails* because they will break a reader's first run too.

Why this is hop 0 and not an appendix: everything downstream assumes the host can reach
entitled content and that, when it breaks, someone can build the case that gets it fixed. A
fleet where `sos report` is a mystery has no support contract in practice, whatever the invoice
says.

## Before you start

- **Host**: RHEL 9 or 10. This run: the RHEL 9.8 **KVM Guest Image** for aarch64 from the Customer
  Portal (1.2 GB, checksum on the download page), booted under Lima with
  [`lab/rhel-lab.yaml`](../../lab/rhel-lab.yaml). Rocky/Alma cannot do this phase — that is the
  point of the phase.
- **An account** on the Customer Portal with a subscription attached; for a lab, the Red Hat
  Developer Subscription for Individuals (free). The image download is what attaches it.
- **An activation key**, made once in the Hybrid Cloud Console (Inventory → System Configuration →
  Activation Keys → *Create*; name, workload *Latest release*, system purpose left undefined) or
  through the RHSM API (`POST /api/rhsm/v2/activation_keys`). The organisation id is on that page.
  Neither is a secret, and neither is in this repository: the script reads both from the
  environment.
- **Network**: outbound HTTPS to `subscription.rhsm.redhat.com`, `cdn.redhat.com`,
  `cert-api.access.redhat.com` (Insights). Behind a proxy, `subscription-manager config
  --server.proxy_hostname` before anything else.

## Permissions

- Root on the host for registration and for `sos` — **and for every `subscription-manager`
  read**: as an ordinary user, `subscription-manager status` opens a polkit prompt for a password
  and fails without a terminal. The first run stopped there. Everything in this phase is `sudo`.
- On the portal side, an **activation key** is the right credential for a fleet — it carries the
  environment, the content view (Satellite) or the repositories to enable, and never the
  account password. A username/password registration is for one person's one machine.

## Minimum test

One host registered with an activation key, one entitled repository enabled, one package
installed from it, one `sos report` produced and inspected, one Insights registration with at
least one recommendation shown. That is the whole support relationship exercised once.

## Hops

### Hop 1 — register

```sh
subscription-manager register --org <org-id> --activationkey <key>       # fleet path
subscription-manager register --username <user>                          # one person, one lab box
subscription-manager status
subscription-manager repos --list-enabled
```

Since RHEL 9 with **simple content access**, registration entitles; there is no per-host
attach step and `subscription-manager attach` is gone. A host that registers and sees no
repositories is looking at the wrong organisation or an activation key with no content.

### Hop 2 — entitled content

```sh
subscription-manager repos --enable rhel-9-for-aarch64-baseos-rpms \
                            --enable rhel-9-for-aarch64-appstream-rpms
dnf repolist
dnf updateinfo summary          # advisories, by type — the errata the subscription exists for
```

This is where phase 2's model gets its real source: with Satellite, the CDN is what the library
syncs from, and the host's repositories point at the Capsule, not at `cdn.redhat.com`.

### Hop 3 — Insights

```sh
dnf -y install insights-client
insights-client --register
insights-client --status
insights-client --compliance      # after a policy is assigned in the console
```

What it uploads is a metadata collection (installed packages, configuration facts, no file
contents by default); what comes back is the advisor's recommendations, vulnerability status by
CVE, and the compliance report if a policy is assigned. The upload is the one thing to know
before a security review asks — `insights-client --show-results` and the collection spec in
`/etc/insights-client/` say exactly what leaves the host.

### Hop 4 — 🥇 `sos report`, and what a case needs

```sh
dnf -y install sos
sos report --batch --case-id <case-number> --tmp-dir /var/tmp
tar -tf /var/tmp/sosreport-*.tar.xz | head                       # know what you are sending
```

A support case with a description and no `sos report` is a case that starts with "please run
sos report". A case with the report and the *one command that reproduces it* skips a day. The
report contains hostnames, IPs, configuration files and logs; `sos report --clean` obfuscates
some of it, and knowing that the option exists is the difference between a case and a data
incident.

### Hop 5 — the case itself

Severity is chosen by business impact and is what determines the response SLA; a Sev 1 for a
lab is a credibility cost the next real Sev 1 pays. The case gets: the exact version (`cat
/etc/redhat-release`, `uname -r`), the `sos report`, the reproduction, what changed last, and
what was already tried. The Knowledgebase search before the case is not optional — a large
share of cases are answered by an article the customer could have found, and the support
engineer will link it first.

## How the phase fails

Two of these came out of the run.

- **`insights-client --status` run right after `--register` reports *NOT registered* and
  removes the local registration.** On the first run: `--register` uploaded successfully,
  `--status` a few seconds later said `Insights API says this machine is NOT registered` and
  wrote `.unregistered` — the inventory had not processed the upload yet, and the client treats
  the API's answer as authoritative. 120 seconds later the same check says `Insights API
  confirms registration`. A fleet automation that registers and verifies in one step will
  unregister every host it touches; wait, then verify (the script now does).
- **`subscription-manager` as a non-root user prompts for a password through polkit and fails
  without a terminal.** Even `status` and `identity`. The first run stopped on
  `repos --list-enabled` for that reason; every call is `sudo` now.
- A host registered with a username stays entitled through that person's account; when they
  leave, it does not. Activation keys exist so that entitlement is a property of the fleet.
- Simple content access means every enabled repository is available — including ones the fleet
  standard says are not. Enabling repositories is a decision the activation key or Satellite
  should make, not each host.
- `insights-client` on a host that is not allowed to talk to the internet either fails quietly or
  goes through a proxy nobody documented; `--status` says which.
- A `sos report` sent to a case without `--clean` on a host with credentials in a configuration
  file has just sent the credentials to a vendor. It is redacted on request; it was still sent.

## Verify

Per hop, the command and what the run produced ([`lab/phase0.log`](../../lab/phase0.log), unedited
except the organisation id, account number and consumer UUIDs).

| | Command | Seen |
|---|---|---|
| 1 | `subscription-manager register --org … --activationkey …` | `The system has been registered with ID: <uuid>` · `The registered system name is: lima-rhel9` |
| 1 | `subscription-manager status` | `Overall Status: Registered` · `Content Access Mode is set to Simple Content Access. This host has access to content, regardless of subscription status.` |
| 1 | `subscription-manager repos --list-enabled` | `rhel-9-for-aarch64-baseos-rpms` and `-appstream-rpms`, both `Enabled: 1` — the key's *Latest release* workload, nothing else |
| 2 | `dnf repolist` | the same two, named `Red Hat Enterprise Linux 9 for ARM 64 - BaseOS / AppStream (RPMs)` |
| 2 | `dnf updateinfo summary` | on the 9.8 image as shipped: **93 security notices** (1 Critical, 56 Important, 31 Moderate, 5 Low), 37 bugfix |
| 2 | `dnf updateinfo list --security` | `RHSA-2026:58572 Moderate/Sec. NetworkManager-1:1.54.3-5.el9_8.aarch64` — an advisory with a name, which is the thing the subscription buys |
| 3 | `insights-client --register` | `Successfully registered host lima-rhel9` · `Successfully uploaded report from lima-rhel9 to account <account>` |
| 3 | `insights-client --status`, **120 s later** | `System is registered locally via .registered file` · `Insights API confirms registration` |
| 3 | `ls /etc/insights-client/` | `cert-api.access.redhat.com.pem  insights-client.conf  insights-client.motd  machine-id` |
| 4 | `sos report --batch --case-id LAB-0001` | `sosreport-lima-rhel9-LAB-0001-2026-09-15-psybidh.tar.xz`, **11 MB, 10,476 entries**, sha256 printed by `sos` |
| 4 | `tar -tf … \| awk -F/ '{print $2}' \| sort -u` | `boot date df dmidecode environment etc free hostname installed-rpms ip_addr ip_route …` — the top level is a mix of directories and symlinks into `sos_commands/` |
| 4 | `tar -xOf … '*/sos_commands/host/hostname'` | `lima-rhel9` — the hostname is in the bundle, as are the addresses; the `ip_addr` at the top level is a symlink, which is why counting `inet` lines through it returned 0 |
| 5 | `uname -r` | `5.14.0-687.5.3.el9_8.aarch64` |

## Acceptance

🔴 **A host that can name its entitlement, its errata and its own diagnostic bundle without a
person remembering anything.** `subscription-manager identity` answers the first, `dnf
updateinfo` the second, `sos report` the third.

```
Overall Status: Registered
93 Security notice(s) · RHSA-2026:58572 Moderate/Sec. NetworkManager-1:1.54.3-5.el9_8.aarch64
sosreport-lima-rhel9-LAB-0001-2026-09-15-psybidh.tar.xz · 11M · 10476 entries
Insights API confirms registration.
```

✅ Met, on one VM, one afternoon, one developer subscription. ⛔ Not claimed: a case actually
opened, Insights' advisor or compliance results read back (a policy was not assigned), a fleet
key with system purpose set, a disconnected host, a Satellite-registered host, any scale.

## Rollback

`subscription-manager unregister` (removes the host from the portal's count), `insights-client
--unregister`, `dnf remove insights-client sos`. On a developer subscription, unregistering is
what frees one of the sixteen.

## Escape Hatch

A host that cannot reach the CDN — an isolated network. The documented path is a **disconnected
Satellite** (content exported from a connected one and imported), or, at one host, `dnf
reposync` on a connected machine and a local repository, which is phase 2's library with a
sneakernet in front of it. The undocumented path is copying `/etc/pki/entitlement` between
hosts, which works and violates the subscription; it is named here so that it is recognised, not
recommended.
