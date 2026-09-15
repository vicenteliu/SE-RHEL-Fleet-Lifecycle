# Phase 0 — subscription and support: an entitled host, and what "supported" means in practice

**Hop:** a subscription → an entitled, supported host. **Mechanism:** `subscription-manager` ·
`insights-client` · `sos report` · a support case with the right attachments. **Product:** the
RHEL subscription, Red Hat Insights, the Customer Portal. **Upstream:** none — a Rocky or Alma
host has the OS and none of this. **State: ⛔ Specced-Not-Run — the minimum tier has no Red Hat
account yet.** The commands below are the real ones; the expected outputs are from the
documentation, marked so, and will be replaced by seen ones the day a developer subscription
(free, sixteen systems) is registered on the tier. That is first in [TODO.md](../../TODO.md).

Why this is hop 0 and not an appendix: everything downstream assumes the host can reach
entitled content and that, when it breaks, someone can build the case that gets it fixed. A
fleet where `sos report` is a mystery has no support contract in practice, whatever the invoice
says.

## Before you start

- **Host**: RHEL 9 or 10 (the developer subscription's images; aarch64 exists). Rocky/Alma cannot
  do this phase — that is the point of the phase.
- **An account** on the Customer Portal with a subscription attached; for a lab, the Red Hat
  Developer Subscription for Individuals.
- **Network**: outbound HTTPS to `subscription.rhsm.redhat.com`, `cdn.redhat.com`,
  `cert-api.access.redhat.com` (Insights). Behind a proxy, `subscription-manager config
  --server.proxy_hostname` before anything else.

## Permissions

- Root on the host for registration and for `sos`.
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

The commands and, ⛔ **from documentation, not seen**, what they return.

| | Command | Expected (doc) |
|---|---|---|
| 1 | `subscription-manager status` | `Overall Status: Registered` (RHEL 9+, simple content access) |
| 1 | `subscription-manager identity` | the org and the consumer UUID — the object the portal and Satellite both track |
| 2 | `dnf repolist` | the enabled `rhel-9-for-<arch>-baseos-rpms` / `appstream-rpms` |
| 2 | `dnf updateinfo summary` | counts by `Security`, `Bugfix`, `Enhancement` |
| 3 | `insights-client --status` | `This host is registered` and the last upload time |
| 4 | `sos report --batch` | `Your sosreport has been generated and saved in: /var/tmp/sosreport-<host>-<case>-<date>.tar.xz` |
| 4 | `tar -tf … \| grep -c ''` | thousands of entries; `sos_commands/`, `etc/`, `var/log/` at the top level |

## Acceptance

🔴 **A host that can name its entitlement, its errata and its own diagnostic bundle without a
person remembering anything.** `subscription-manager identity` answers the first, `dnf
updateinfo` the second, `sos report` the third. ⛔ Not run here; the tier that runs it is one
free account away and is named in [docs/02](../../docs/02-lab-tiers.md).

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
