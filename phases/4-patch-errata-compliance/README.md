# Phase 4 — patch, errata, compliance: hosts patched, and proven so

**Hop:** errata published → hosts patched, compliance proven. **Mechanism:** errata carried by a
content view version (phase 2) · applied by remote execution or a playbook (phase 5) · proven
by an OpenSCAP scan against a policy. **Product:** Satellite errata management and remote
execution; Insights vulnerability, patch and compliance; Satellite compliance (OpenSCAP inside
Satellite). **Upstream:** `dnf updateinfo` · Ansible · `oscap` with the SCAP Security Guide — the
same project Satellite ships. **State: 🔨 lab — both halves run on the minimum tier on 2026-09-15: the errata model by hand
in phase 2, and on the registered RHEL host a CIS Level 1 scan, one rule fixed and re-scanned, a
tailoring file for one exception, the generated remediation playbook, and one advisory applied by
its id; every command and its output in [`lab/phase4.log`](../../lab/phase4.log) · 🔨 the patch
cycle as a daily operation on the author's prior estates, package-version based, not advisory
based.**

The problem has two halves that get confused. *Patching* is changing what is installed.
*Compliance* is proving what is installed and configured against a policy someone else wrote.
A fleet can be patched and unable to prove it, which to an auditor is unpatched.

## Before you start

- **Hosts pinned to environments** (phase 2); the patch cycle is *promote a version*, then
  *apply on the hosts in that environment*, never `dnf update` against the internet.
- **The policy**: a SCAP profile (CIS, STIG, PCI — from the SCAP Security Guide, `scap-security-guide`
  package; 20 profiles in the RHEL 9 datastream) and a tailoring file for the exceptions the
  fleet has agreed to. Without the tailoring every scan fails and nobody reads it. This run:
  `openscap-scanner` 1.3.14, `scap-security-guide` 0.1.82, `openscap-utils` for `autotailor`,
  `yum-utils` for `needs-restarting`, on the RHEL 9.8 VM from phases 0 and 1.
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

Three of these came out of the run.

- **The image is not the baseline; the policy is.** A host born from phase 1's blueprint — two
  hardening settings baked, SELinux enforcing, born at today's patch level — fails **109 of the
  260 CIS Level 1 rules it is evaluated against**: no AIDE, no custom crypto policy, no separate
  `/tmp`, `sudo` not logging to its own file. A gold image that was never scanned is a baseline
  nobody measured; the scan result is the list of what the next blueprint version bakes.
- **Advisories and packages are different units, and reports mix them.** `updateinfo summary`
  said 93 security notices; `updateinfo list --security` has 326 rows; one advisory closed four
  of them. A dashboard that says "326 open" and one that says "93 open" are both right about the
  same host. Pick the unit before the number is quoted.
- **The tailoring file is the audit artefact, not a convenience.** 614 bytes, one line that says
  *this rule is not selected for this profile*, and the scan's fail count moved by exactly one.
  An exception that lives in a person's head moves the count by one too, and cannot be shown.
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

Per hop, the command and what the run produced ([`lab/phase4.log`](../../lab/phase4.log);
the errata-by-hand rows are from [phase 2](../2-content-lifecycle/)).

| | Command | Seen |
|---|---|---|
| 1 | `dnf updateinfo list` on a `dev` host after promotion | the advisory · phase 2 |
| 2 | `dnf update --advisory RHSA-2026:58572` · `dnf updateinfo list --all` | `applied` · `i RHSA-2026:58572 Moderate/Sec. NetworkManager-1:1.54.3-5.el9_8.aarch64` |
| 2 | `dnf updateinfo list --security \| grep -c ^RHSA` before / after | **326 → 322** — four package rows closed by one advisory; `updateinfo summary` counts advisories (93), `list` counts packages |
| 2 | `needs-restarting -r` | exit `0` — `No core libraries or services have been updated since boot-up` after a NetworkManager update |
| 3 | `oscap xccdf eval --profile cis_server_l1 --results r1.xml --report r1.html` | exit 2 · **fail 109 · pass 151 · notapplicable 35 · notselected 1245** on the host as built by phases 0 and 1 |
| 3 | `sshd_set_max_auth_tries`: `fail` → write `MaxAuthTries 4` to `sshd_config.d/40-cis.conf` → `oscap … --rule` | `pass` |
| 3 | full scan again, untailored | fail **108** — exactly the one rule |
| 3 | `autotailor --unselect partition_for_tmp` → `--tailoring-file` scan | fail **107** · the rule `notselected` · the tailoring is 614 bytes of XML, one `<select selected="false">` |
| 4 | `oscap xccdf generate fix --fix-type ansible --profile …` | a playbook of **1,714 tasks** for the whole profile |
| 4 | `… generate fix --result-id … r1.xml` | **961 tasks** — only what failed on this host |
| — | the artefacts | `r1.html` 3.4 MB (the report a person reads) · `r1.xml` 19 MB (the results a system ingests) · `tailoring.xml` · `remediation.yml` |
| — | Satellite: the host's *Errata* tab, the environment's applicable count, the compliance report per policy | ⛔ full |

## Acceptance

🔴 **For any host, three questions answered from data: what is it owed, what has it received,
and does it pass the policy — and the third from a scan, not from the second.**

```
owed:     326 security package rows (93 advisories) → 322 after one advisory
received: i RHSA-2026:58572 Moderate/Sec. NetworkManager-1:1.54.3-5.el9_8.aarch64
policy:   CIS L1 Server — fail 109 → 108 (one fix) → 107 (one agreed exception, tailored)
```

✅ Met on one host, one afternoon. ⛔ Not claimed: a remediation playbook *run* (generated only —
running 961 tasks on a lab host is phase 5's job and was not done), Satellite's errata screens
or compliance feature, Insights' compliance report (no policy assigned), remote execution, any
host that is not the lab VM, a reboot cycle (the advisory applied needed none).

## Rollback

A version rolled back in phase 2 removes the offer, not the installed package: `dnf history
undo <id>` or `dnf downgrade` per host is the package rollback, and the reason the phase-2 run
says *a rollback changes what is offered, not what is installed*.

## Escape Hatch

The zero-day that cannot wait for the cycle: phase 2's hotfix content view (one package,
promoted straight to `prod`), applied by a targeted job with a ticket number, recorded as an
exception so the next scheduled cycle does not "correct" it back. Never `dnf update` against
the internet on the affected hosts; that is the hatch that has no return.
