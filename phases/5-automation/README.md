# Phase 5 — automation: from a playbook on a laptop to automation with an owner, a record and a permission model

**Hop:** a playbook on one control node → automation with an owner, a record and a permission
model. **Mechanism:** job templates (playbook + inventory + credential), workflows, schedules,
RBAC, job history, execution environments. **Product:** Ansible Automation Platform (automation
controller, automation hub, execution environments, Event-Driven Ansible). **Upstream:** AWX
(the controller), `ansible-core`, Galaxy, `ansible-runner`/`ansible-builder`, `ansible-rulebook`.
**State: 🔨 lab — the playbook half run on the minimum tier on 2026-09-15: the workstation as
control node, a patch playbook against phase 2's `dev` host, `--check` then real, run again for
nothing-to-do, state read back from both VMs into one directory; every command and its output in
[`lab/phase5.log`](../../lab/phase5.log) · 🔨 playbooks from a control node across 220+ hosts on
a prior estate — push upgrades, pull state back on a schedule, logs collected to one place · ⛔
the controller (AWX/AAP): not run; AWX needs a Kubernetes cluster, which on the minimum tier is
⛔ by cost, on the mid tier a single-node cluster on the x86_64 machine.**

The problem the controller solves is not automation; the playbooks already automate. It is the
three things that appear the day a second team, an auditor, or a non-engineer needs what the
playbooks do: *who is allowed to run this against what*, *who ran what, when, with what result*,
and *where is the credential and who can see it*. A control node with cron and a log file
answers all three with "the person who owns the laptop".

## Before you start

- **Playbooks in a repository** with an inventory that comes from somewhere true (Satellite's
  inventory plugin, or the provisioning system's host list — phase 3), not a hand-kept file.
  This run's [`inventory.yml`](../../lab/ansible/inventory.yml) is static, two hosts — the failure
  mode by this page's own rule; on this tier the system of record is the VM tool, which has no
  inventory plugin, and the file says so.
- **A control node** with `ansible-core` for the 🔨 path; for the controller, RHEL or OpenShift
  (AAP) or a Kubernetes cluster (AWX operator). This run: `ansible-core` 2.21.4 on the
  workstation (`uv tool install ansible-core`), the two Lima VMs as hosts, each reached through
  the ssh config the VM tool writes for it — no key copied, no password in any file.
- **Credentials that exist as objects**: an SSH key per purpose, a vault password, an API token
  for Satellite — not a shared root password in a group_vars file.

## Permissions

- The controller's RBAC is the phase's product: an organisation, teams, roles per job template
  (execute, read, admin) — the person who can run *patch prod* is not everyone who can log in.
- The credential store: users use credentials without seeing them. On the 🔨 path there is no
  such thing; whoever runs the playbook has the key.
- Execution environments pin the Python, `ansible-core` and collection versions the playbook
  runs under, so that "works on my control node" stops being a category of incident.

## Minimum test

One playbook (patch a `dev` host per phase 4), one inventory (the lab VM), one credential, one
job template, one run from the controller by a user who has *execute* and not *admin*, and the
job's output readable afterwards by someone else. That is the controller's whole value in one
run. The first clause ran here — the playbook, `--check` then real, the read-back; everything
from *one credential* on is the controller's and is ⛔.

## Hops

### Hop 1 — 🔨 the playbook and the control node

What the author ran: playbooks pushing a package upgrade to a couple of hundred hosts, and a
scheduled playbook reading state back (versions, service status, a compliance check) into one
directory of logs. Ad-hoc `ansible -m` for the one-off question. This is real automation and it
is the input to the controller, not something the controller replaces.

At lab scale, run: [`patch-dev.yml`](../../lab/ansible/patch-dev.yml) — `hosts: dev`, `become`,
the `dnf` module held to the environment's repositories with fresh metadata, the package version
and `needs-restarting -r` read back in the same play; [`state.yml`](../../lab/ansible/state.yml)
— every host's package, pin, owed rows and reboot state written to
[`lab/ansible/state/<host>.txt`](../../lab/ansible/state/) on the control node, the scheduled
half at a scale of two. Both runs, with the ad-hoc calls around them, are
[`lab/phase5.log`](../../lab/phase5.log).

### Hop 2 — the inventory comes from the system of record

`inventory` plugins for Satellite (`redhat.satellite.foreman`) or Foreman, filtered by host
group or environment. A host that phase 3 provisioned appears in the next run's inventory
without anyone editing a file; a host that was decommissioned disappears. The static inventory
is the failure mode.

### Hop 3 — 🥇 the job template is the unit of trust

Playbook + inventory + credential + limits + survey (the variables a user may set) + who may
run it. The template is what RBAC is attached to and what the job history records. A playbook
that exists in five templates with five permission sets is the point.

### Hop 4 — workflows, schedules and the record

A workflow strings templates with success/failure branches (promote → patch dev → verify →
approve → patch prod); a schedule runs it in the window; every job leaves its full output and
its variables in the history, attributable to a user or a schedule. That history is what an
auditor is shown.

### Hop 5 — execution environments and event-driven automation

`ansible-builder` builds the container image the jobs run in; the image has a version, so the
runtime is reproducible. EDA (`ansible-rulebook`) runs a playbook when an event arrives
(a webhook from monitoring, a Kafka message) — the "someone got paged and ran the runbook" step
automated, with the same job history.

## How the phase fails

Two of these came out of the run.

- **A dry run and the change must read the same data.** The same ad-hoc `dnf … state=latest
  --check`, on the same host, in the same minute: as the login user, *would install
  lab-hello-1.1*; as root, *Nothing to do*. Two users, two metadata caches — phase 2's finding
  in a new costume: root's cache was warm on the version `dev` pointed at before the promotion,
  the user's was fetched fresh because it had none. A `--check` run without `become` can promise
  what the change under `become` will not do, or the reverse. The playbook runs both under
  `become` and passes `update_cache: true`; that line is what makes its `--check` mean something.
- **The playbook says which repositories it patches from, or it patches from the internet.** The
  `dev` host's state read-back shows 208 security package rows owed — from the upstream
  repositories the lab VM still carries because it doubles as the content server. `name: "*"`,
  `state: latest` and nothing else would have applied them, which is phase 4's hatch with no
  return. `disablerepo: "*"` and `enablerepo: "lab-*"` is what keeps the run inside the
  environment the host is pinned to; on a real pinned host that is the only repository set there
  is, and the line costs nothing.
- The controller runs a playbook from a branch nobody reviewed because the project's SCM update
  is on "latest".
- A credential shared across teams because creating one per purpose was tedious; RBAC now means
  nothing.
- A patch job template with `limit` left open, run by someone with execute rights on "all
  hosts".
- The inventory is a static file synced by hand "for now"; the decommissioned hosts stay in it
  and the job fails on unreachable hosts every night until someone stops looking at the failures.
- AWX upgraded across an operator version without reading the notes; the database migration
  fails on the one thing every team uses.

## Verify

Row 1 is what the run produced ([`lab/phase5.log`](../../lab/phase5.log)); rows 2–5 are what
the mid tier would show.

| | Command | Seen (minimum) · expected (mid) |
|---|---|---|
| 1 | `ansible-playbook patch-dev.yml --check` | `changed=1` — `Installed: lab-hello-1.1-1.el9.noarch`, `Removed: lab-hello-1.0-1.el9.noarch`; the read-back in the same play still says 1.0, because `--check` changed nothing |
| 1 | `ansible-playbook patch-dev.yml` | `changed=1` · `lab-hello-1.0-1.el9.noarch → lab-hello-1.1-1.el9.noarch · reboot not needed` |
| 1 | on the host afterwards: `rpm -q lab-hello` · `dnf updateinfo list --all` | `lab-hello-1.1-1.el9.noarch` · `i LAB-2026:0001 Moderate/Sec.` — phase 2's erratum, received (phase 4, hop 1) |
| 1 | the same playbook again | `changed=0` — nothing to do |
| 1 | `ansible dev -m dnf -a "name=* state=latest …" --check`, then the same with `--become` | **would install 1.1 · Nothing to do** — two caches, the finding above |
| 1 | `ansible-playbook state.yml` | two files in `lab/ansible/state/`: `rhel-lab` on `dev`, 1.1, 208 security rows owed, no reboot · `rhel9` unpinned (the CDN), 322 rows, no reboot |
| 2 | `ansible-inventory -i satellite.foreman.yml --graph` | host groups from the system of record · mid |
| 3 | run a job template as a user with *execute* only; then try the template's *edit* | the job runs; the edit is refused · mid (AWX) |
| 4 | the job's *Output* and *Details* as a second user with *read* | the full log and the variables · mid |
| 5 | `ansible-builder build -t fleet-ee:2026.09` · a job run under that EE | the job's runtime reports the EE's image · mid |

## Acceptance

🔴 **A patch run in `prod` can be traced to a template, a user, a time, an inventory version and
a full log by someone who did not run it, and the person who ran it could not have run it
against anything else.**

```
dev host:  lab-hello 1.0 → 1.1 by playbook, --check first, changed=0 on the second run
record:    lab/phase5.log and lab/ansible/state/<host>.txt, on the control node
who:       the person who owns the workstation — this page's first paragraph, verbatim
```

🔨 lab for the playbook half on this tier; 🔨 on a prior estate. ⛔ for the controller on any
tier here — and the acceptance sentence is the controller's, so it is **not met**: the run is
attributable to the workstation's owner, the credential is the VM tool's ssh config, and nothing
but the playbook's own `hosts: dev` line stood between the run and every host in the inventory.
Not claimed: AAP, AWX, Tower, an
execution environment build, EDA, roles as a library — the author's Ansible is playbook-driven.

## Rollback

The playbook's own reversal (a downgrade task, a restore) as a second template; the controller's
job history says exactly what to reverse. A controller rollback is a database restore, which is
why its backup is scheduled.

## Escape Hatch

The engineer who needs to run something *now* that has no template: a template that runs an
ad-hoc command with a survey for the command and a limit on the hosts, in the history like
everything else. The undocumented path is SSH with the shared key, which is the phase's
failure made deliberate.
