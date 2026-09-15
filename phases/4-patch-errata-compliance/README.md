# Phase 4 — patch, errata, compliance: hosts patched, and proven so

**Hop:** errata published → hosts patched, compliance proven. **Mechanism:** errata carried by a
content view version (phase 2) · applied by remote execution or a playbook (phase 5) · proven
by an OpenSCAP scan against a policy. **Product:** Satellite errata management and remote
execution; Insights vulnerability, patch and compliance; Satellite compliance (OpenSCAP inside
Satellite). **Upstream:** `dnf updateinfo` · Ansible · `oscap` with the SCAP Security Guide — the
same project Satellite ships. **State: 🔨 lab for the errata half (phase 2 attached and read an
advisory on this tier) · ⛔ OpenSCAP — runnable here, not yet run, next after phase 1 · 🔨 the
patch cycle as a daily operation on the author's prior estates, package-version based, not
advisory based.**

The problem has two halves that get confused. *Patching* is changing what is installed.
*Compliance* is proving what is installed and configured against a policy someone else wrote.
A fleet can be patched and unable to prove it, which to an auditor is unpatched.

## Before you start

- **Hosts pinned to environments** (phase 2); the patch cycle is *promote a version*, then
  *apply on the hosts in that environment*, never `dnf update` against the internet.
- **The policy**: a SCAP profile (CIS, STIG, PCI — from the SCAP Security Guide, `scap-security-guide`
  package) and a tailoring file for the exceptions the fleet has agreed to. Without the tailoring
  every scan fails and nobody reads it.
- **A window and an order**: `dev` hosts, then `test`, then `prod`, with the promotion between
  them being the gate. Kernel updates need a reboot; the schedule needs to know which hosts can.

## Permissions

- Root on the hosts, through the automation's credential (phase 5), never a shared password.
- The person who promotes to `prod` and the person who applies in `prod` can be the same person
  and should not be the same step.
- Scan results leave the host (Satellite, Insights, or a report directory); they contain the
  configuration state the policy checked, which is sensitive on its own.

## Minimum test

One advisory in one version, promoted to one environment, applied to one host, the advisory
gone from `dnf updateinfo list` and present in `--all` with the `i` flag; one `oscap` scan
before and after a setting change, with the rule flipping from `fail` to `pass`. Errata half:
[phase 2's run](../2-content-lifecycle/) did the first sentence on this tier.

## Hops

### Hop 1 — what is owed: errata against the environment

`dnf updateinfo list` on a host lists advisories *applicable* to it from the repositories it is
pinned to; `dnf updateinfo list --all` includes the ones already applied (`i`). Satellite's host
page shows the same per host and sums it per environment. The phase-2 run showed the trap: a
host with the fix already installed lists nothing, and a report built from that counts *owed*,
not *published*.

### Hop 2 — 🥇 applying is promote, then apply — in that order, per environment

Promote the version carrying the errata to `dev`; apply (`dnf update --advisory RHSA-…`, or
`dnf update` for everything the version offers) on `dev`'s hosts via remote execution or a
playbook; verify; promote to `test`; repeat; `prod`. A host in `prod` cannot receive the fix
before `prod` has the version — which is the control. Reboot handling is part of the job
template, not an afterthought.

### Hop 3 — proving it: OpenSCAP

```sh
dnf -y install openscap-scanner scap-security-guide
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis \
     --tailoring-file fleet-tailoring.xml \
     --results results.xml --report report.html \
     /usr/share/xml/scap/ssg/content/ssg-rl9-ds.xml
```

Same tool, same content whether run by hand, by a playbook, or by Satellite's compliance
feature (which schedules it, collects the results and shows the delta per host). The report is
per rule, `pass`/`fail`/`notapplicable`, and the tailoring file is where the fleet's agreed
exceptions live so that the report is about drift, not about policy disagreements.

### Hop 4 — remediation is the same loop

`oscap` can emit an Ansible playbook or a bash script for the failed rules (`--remediate`, or the
SSG's shipped playbooks per profile). It is phase 5's job to run it and phase 1's job to bake the
result into the next image so that the rule never fails again on a new host.

## How the phase fails

- Patching by `dnf update` from the library (or the internet) on a host that is supposed to be
  pinned: the host now has content no environment vouches for, and the next promotion may
  *downgrade* it in the report while not touching the package.
- A compliance report with no tailoring: 40% fail on every host, forever, and the two real
  regressions are invisible in it.
- Errata applied and the reboot deferred indefinitely: the running kernel is the old one; the
  advisory is `i` and the host is vulnerable. `needs-restarting -r` is the check.
- A scan run as a non-root user reads half the configuration and passes rules it could not check.
- Reporting from `updateinfo list` (owed) when the question was *published* (phase 2, finding B).

## Verify

| | Command | Expected · tier |
|---|---|---|
| 1 | `dnf updateinfo list` on a `dev` host after promotion | the advisory · 🔨 lab (phase 2) |
| 2 | `dnf update --advisory LAB-2026:0001` · `dnf updateinfo list --all` | applied; the advisory with `i` · 🔨 lab (phase 2, via `dnf update lab-hello`) |
| 2 | `needs-restarting -r` | exit 1 (reboot needed) after a kernel update, 0 otherwise · minimum |
| 3 | `oscap xccdf eval … --results results.xml` · `grep -c 'result>pass' results.xml` | a count that rises after the remediation · minimum |
| 3 | change one setting the profile checks, re-scan | that rule flips · minimum |
| 4 | `oscap xccdf generate fix --fix-type ansible …` | a playbook whose tasks name the failed rules · minimum |
| — | Satellite: the host's *Errata* tab, the environment's applicable count, the compliance report per policy | · ⛔ full |

## Acceptance

🔴 **For any host, three questions answered from data: what is it owed, what has it received,
and does it pass the policy — and the third from a scan, not from the second.** Errata half met
on the minimum tier (phase 2); scan half ⛔ on this tier until the next hop runs it. Not claimed:
Satellite's errata screens, Insights, remote execution, any host that is not the lab VM.

## Rollback

A version rolled back in phase 2 removes the offer, not the installed package: `dnf history
undo <id>` or `dnf downgrade` per host is the package rollback, and the reason the phase-2 run
says *a rollback changes what is offered, not what is installed*.

## Escape Hatch

The zero-day that cannot wait for the cycle: phase 2's hotfix content view (one package,
promoted straight to `prod`), applied by a targeted job with a ticket number, recorded as an
exception so the next scheduled cycle does not "correct" it back. Never `dnf update` against
the internet on the affected hosts; that is the hatch that has no return.
