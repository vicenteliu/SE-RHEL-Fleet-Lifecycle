# Phase 5 — automation: from a playbook on a laptop to automation with an owner, a record and a permission model

**Hop:** a playbook on one control node → automation with an owner, a record and a permission
model. **Mechanism:** job templates (playbook + inventory + credential), workflows, schedules,
RBAC, job history, execution environments. **Product:** Ansible Automation Platform (automation
controller, automation hub, execution environments, Event-Driven Ansible). **Upstream:** AWX
(the controller), `ansible-core`, Galaxy, `ansible-runner`/`ansible-builder`, `ansible-rulebook`.
**State: 🔨 playbooks from a control node across 220+ hosts on a prior estate — push upgrades,
pull state back on a schedule, logs collected to one place · ⛔ the controller (AWX/AAP): not
run; AWX needs a Kubernetes cluster, which on the minimum tier is ⛔ by cost, on the mid tier a
single-node cluster on the x86_64 machine.**

The problem the controller solves is not automation; the playbooks already automate. It is the
three things that appear the day a second team, an auditor, or a non-engineer needs what the
playbooks do: *who is allowed to run this against what*, *who ran what, when, with what result*,
and *where is the credential and who can see it*. A control node with cron and a log file
answers all three with "the person who owns the laptop".

## Before you start

- **Playbooks in a repository** with an inventory that comes from somewhere true (Satellite's
  inventory plugin, or the provisioning system's host list — phase 3), not a hand-kept file.
- **A control node** with `ansible-core` for the 🔨 path; for the controller, RHEL or OpenShift
  (AAP) or a Kubernetes cluster (AWX operator).
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
run.

## Hops

### Hop 1 — 🔨 the playbook and the control node

What the author ran: playbooks pushing a package upgrade to a couple of hundred hosts, and a
scheduled playbook reading state back (versions, service status, a compliance check) into one
directory of logs. Ad-hoc `ansible -m` for the one-off question. This is real automation and it
is the input to the controller, not something the controller replaces.

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

| | Command | Expected · tier |
|---|---|---|
| 1 | `ansible-playbook -i inventory patch-dev.yml --check` then without `--check` | changed hosts listed; the version on the host afterwards · minimum (playbook only) |
| 2 | `ansible-inventory -i satellite.foreman.yml --graph` | host groups from the system of record · mid |
| 3 | run a job template as a user with *execute* only; then try the template's *edit* | the job runs; the edit is refused · mid (AWX) |
| 4 | the job's *Output* and *Details* as a second user with *read* | the full log and the variables · mid |
| 5 | `ansible-builder build -t fleet-ee:2026.09` · a job run under that EE | the job's runtime reports the EE's image · mid |

## Acceptance

🔴 **A patch run in `prod` can be traced to a template, a user, a time, an inventory version and
a full log by someone who did not run it, and the person who ran it could not have run it
against anything else.** 🔨 for the playbook half on a prior estate; ⛔ for the controller on any
tier here. Not claimed: AAP, AWX, Tower, an execution environment build, EDA, roles as a
library — the author's Ansible is playbook-driven.

## Rollback

The playbook's own reversal (a downgrade task, a restore) as a second template; the controller's
job history says exactly what to reverse. A controller rollback is a database restore, which is
why its backup is scheduled.

## Escape Hatch

The engineer who needs to run something *now* that has no template: a template that runs an
ad-hoc command with a survey for the command and a limit on the hosts, in the history like
everything else. The undocumented path is SSH with the shared key, which is the phase's
failure made deliberate.
