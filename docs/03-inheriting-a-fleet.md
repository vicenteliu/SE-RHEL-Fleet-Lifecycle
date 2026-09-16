# Inheriting a fleet

The eight runbooks describe how a chain is *built*. Almost nobody gets to build one. You arrive
at an estate somebody else assembled — a Satellite of some version, environments with names
that made sense to someone, hosts registered by three generations of Kickstart — and the
question is not *how do I do this* but **what is actually true here**, and what you decide
from it.

This page is the verification rows from the eight phases, re-ordered into the sequence you run
them in when you arrive, each with the decision the answer forces. Nothing here is new; the
order is the content. Where a row was run on the minimum tier, the lab's form of the command
is given next to the product's, because the answer has the same shape. No employer and no
fleet appears in it, by design ([DISCLOSURE.md](../DISCLOSURE.md)).

## Three rules before the first command

1. **Read before you change.** Every row below is read-only. The first thing you change is the
   one whose answer surprised you, and not before the whole pass is done — a promotion made on
   day one is made against a picture that is still wrong, and a promotion is a change on every
   host in the environment.
2. **The order is by cost of being wrong, not by the chain's order.** The chain runs
   subscription → image → content → provisioning → patching → automation → platform → the
   Satellite itself. Arrival runs from the two things that hurt most when they are wrong — *what
   `prod` is actually serving* and *whether the server can come back* — outward to the hosts,
   and only then to how hosts are born.
3. **Read from the host, not from the console.** Every row that can be answered on a host is
   answered on a host. The runs behind this repository found the server's answer and the host's
   answer disagreeing three times ([phase 2](../phases/2-content-lifecycle/) twice,
   [phase 5](../phases/5-automation/) once), and each time the host's answer was the one that
   mattered, because the host is what gets patched.

Markers are the ones the runbooks carry: 🔨 hands-on · 🔨 lab run here on the minimum tier ·
🧭 mapped, not operated · ⛔ specified, not run. They mark the *author's* footing on each row,
not the row's importance.

---

## Day one — what `prod` is serving, and whether the server can come back

Four rows. Everything else can wait a week; these cannot, because they are invisible until the
patch window or the outage in which they fail.

| # | Run | The answer looks like | What you decide from it | From |
|---|---|---|---|---|
| 1 | 🥇 **Which version is `prod` pointing at, and what do `prod`'s hosts actually see.** Product: `hammer lifecycle-environment list`, `hammer content-view version list --lifecycle-environment prod`. Then on a `prod` host: `ls /etc/yum.repos.d/`, `dnf repolist`, and `dnf --refresh repoquery <a package that differs between versions>`. Lab form: `ls -l /srv/content/env`, then the same two on the pinned host | A version with a publish date, and hosts whose only repositories are that environment's — or **hosts with a second `.repo` file** pointing at the Library, the internet, EPEL, or a URL nobody remembers | A host with a repository outside its environment is pinned to nothing: the next promotion may downgrade it *in the report* while not touching the package, and the next `dnf update` on it takes whatever the internet has. Count those hosts before the next cycle; they are the first fix, and the fix is a file on the host, not a click in the console | [2 · hops 3–4](../phases/2-content-lifecycle/) 🔨 lab |
| 2 | **When did each Capsule last sync**: `hammer capsule content synchronization-status --id <n>` for every Capsule; the schedule it is supposed to be on | Every Capsule within its schedule — or one site weeks behind, serving the `prod` of a month ago | The hosts behind that Capsule are on an older `prod` than `prod`; every "the promotion did not take at site X" ticket in the queue is this row. Do not force a sync on day one — read *why* it is behind (disk, network, a task stuck since an upgrade) because the forced sync fails on the same thing | [7 · hop 4](../phases/7-satellite-operations/) ⛔ |
| 3 | **When was the Satellite's backup last *restored*** — not taken. The backup schedule (`satellite-maintain backup` in a cron or a job), and the last restore rehearsal: a ticket, a date, a machine | A date and a machine — or a backup that has run nightly for two years and has never been restored anywhere | Until it has been restored once, the Satellite is not recoverable and every other row on this page is secondary: a Satellite that cannot come back leaves every hop above without its mechanism. Schedule the rehearsal on a throwaway machine before the upgrade in row 20; that machine is what the mid tier exists for | [7 · hop 2](../phases/7-satellite-operations/) ⛔ |
| 4 | `satellite-maintain health check` and `satellite-maintain service status` | Every check `OK` — or disk on `/var/lib/pulp`, a service down, pending tasks in the hundreds, a Capsule the check cannot reach | The failing check is the first attachment on the first case you open and the thing that will block the upgrade you are asked about in month one. Read it; do not fix it today | [7 · hop 1](../phases/7-satellite-operations/) ⛔ |

**End of day one you can say:** what `prod` is, which hosts are not actually on it, which
site is behind, and whether the server that decides all of this can be rebuilt. If you can say
those four things, the first day was well spent whatever else happened.

## Week one — the hosts: what they are owed, what they received, whether it is proven

Pick a `prod` host and a `dev` host, and run these on both. `subscription-manager` needs root
even to read ([phase 0](../phases/0-subscription-and-support/)).

| # | Run | The answer looks like | What you decide from it | From |
|---|---|---|---|---|
| 5 | `sudo subscription-manager identity` · `status` · `repos --list-enabled`; `hammer activation-key info --name <key>` for the key the host registered with | Registered to the organisation, an environment and a content view named on the key, only that environment's repositories enabled — or `Unknown`, or a key that points at `Library`, or a password in a Kickstart `%post` | The key *is* the environment: a host registered with a key that names `Library` is provisioned into whatever synced last night. `hammer host list --search 'lifecycle_environment = Library'` counts them; a password in a template is a credential in a template and goes in the first change window | [0 · hop 1](../phases/0-subscription-and-support/) 🔨 lab · [3 · hop 2](../phases/3-provisioning/) ⛔ |
| 6 | `dnf updateinfo summary` · `dnf updateinfo list --security \| wc -l` · `dnf updateinfo list --all` for the `i` rows — three numbers, and the unit of each | *N* advisories, *M* package rows, the `i` rows already applied; the lab host showed 93 advisories, 326 rows, and one advisory closing four of them | Pick the unit before any number leaves the room. A dashboard that says 326 open and one that says 93 open are both right about the same host; a report that fell from 326 to 322 after one advisory is not a report that closed four advisories. `updateinfo list` counts what the host is *owed*; it does not count what the environment *published* | [4 · hop 1](../phases/4-patch-errata-compliance/) 🔨 lab |
| 7 | On hosts patched in the last cycle: `needs-restarting -r`; `uname -r` against `rpm -q kernel \| sort -V \| tail -1` | `Reboot should not be necessary` and the running kernel is the newest installed — or the advisory shows `i`, the new kernel is on disk, and the running one is three months old | Those hosts are patched on paper and vulnerable in memory. The missing control is the reboot schedule in the job template, not the patch; find out which hosts *can* reboot before proposing when | [4 · hop 2](../phases/4-patch-errata-compliance/) 🔨 lab |
| 8 | The compliance side: is a policy assigned (Satellite compliance, or an `oscap` run somewhere), which profile, and **is there a tailoring file** — read it | A profile, a tailoring with a short list of unselected rules each with a reason, and a fail count that moves when something drifts — or a 40 %-fail report nobody opens, or no scan at all | Without a tailoring the report is about policy disagreements, not drift, and the two real regressions are invisible in it. The tailoring file is the audit artefact: an exception that lives in someone's head moves the count by one too and cannot be shown. Write the tailoring from the exceptions people can state before touching a single rule | [4 · hop 3](../phases/4-patch-errata-compliance/) 🔨 lab |
| 9 | Where people run `dnf` as themselves: `ls -d /var/tmp/dnf-*` on the host, and `metadata_expire` in its repository files | One cache per user who ever ran `dnf`, each expiring on its own clock | A promotion or a rollback behind the same URL is invisible to every one of those views until it expires. The next "the rollback did not take" ticket is this row before it is anything else; the answer is `dnf clean all` *as that user*, and the playbook that patches must refresh (row 16) | [2 · finding A](../phases/2-content-lifecycle/) 🔨 lab |

## Week one — where hosts come from

| # | Run | The answer looks like | What you decide from it | From |
|---|---|---|---|---|
| 10 | On a running host: whatever names the image it was born from (`cat /etc/image-version` here; `rpm -q --last` for the oldest install date otherwise). On the builder: `composer-cli blueprints list` and `compose list`, or the Kickstart repository's history | A version string on the host and a blueprint or Kickstart with that version — or hosts installed by hand from an ISO with a note in a ticket, and no two alike | Hosts that differ at birth make promotion meaningless: the diff between two hosts' package sets is the measure of how much. Do not build a new image this week; measure the spread first (`rpm -qa \| sort` on five hosts, diffed) so the first image has a stated reason | [1 · hops 2–3](../phases/1-gold-image/) 🔨 lab |
| 11 | Boot one fresh host from the current image and, before it does anything else: `getenforce`, `sshd -T \| grep -iE 'passwordauth\|permitroot'`, then the policy scan from row 8 against it | Enforcing, no password auth, and a fail count against the policy — the lab's image failed **109 of 260** CIS L1 rules at birth | The image is not the baseline; the policy is. That count is the next blueprint version's to-do list, in priority order. And what the first-boot provisioner did to the baseline is part of the baseline — the lab's first boot found SELinux left permissive by the VM tool, visible only from inside the booted host | [1 · hop 3](../phases/1-gold-image/) · [4 · hop 3](../phases/4-patch-errata-compliance/) 🔨 lab |
| 12 | `hammer hostgroup info --name <group>` for every group; `hammer host list --search 'build = true'` | OS, environment, content view, activation key and template all set on every group; the build list empty — or groups missing a key, and machines that have been "building" for months | A group without a key is row 5's finding at the source; a host stuck in build is a machine that started and did not finish, and the server can list them only because it was told to expect a callback. Both lists go in the record; neither is a day-one fix | [3 · hops 2, 4](../phases/3-provisioning/) ⛔ |

## Week one — automation

| # | Run | The answer looks like | What you decide from it | From |
|---|---|---|---|---|
| 13 | On the control node or in the controller: `ansible-inventory --graph`, and where the inventory *comes from* | The Satellite or the platform, through an inventory plugin — or a static file, with the decommissioned hosts still in it and the nightly run failing on them until someone stopped reading the failures | The static inventory is the failure mode (this repository's own lab inventory is one, and says so). Count the unreachable hosts in the last run before proposing the plugin; the number is the argument | [5 · hop 2](../phases/5-automation/) ⛔ · 🔨 lab (static) |
| 14 | Who can run *patch prod* against what: the job template's permissions and its `limit`, or, on a control node, who holds the key | Templates with execute rights per team and a limit that is not `all` — or one shared key on a laptop and a playbook whose `hosts:` line is the only thing between `dev` and everything | The day a second team needs the playbook is the day the controller pays for itself; until then `hosts:` and `--limit` are the blast radius and a limit left open is the phase's listed failure. Read the last ten runs' recaps for what they actually touched | [5 · hop 3](../phases/5-automation/) ⛔ · 🔨 lab |
| 15 | `ansible-playbook <the patch playbook> --check` — as the user the real run will use, and once as a different one | The same answer both ways — or *would install* from one user and *Nothing to do* from the other, on the same host in the same minute | Two users, two metadata caches (row 9 again). A dry run that reads different data from the change is theatre; the playbook runs both under `become` and refreshes metadata, or its `--check` means nothing | [5 · finding](../phases/5-automation/) 🔨 lab |
| 16 | Where does state come back to, and when was it last read: the controller's job history, or the control node's directory of logs | One place, one file per host with a read-at time, from the last scheduled run — or a directory of logs that stopped a year ago, or nothing that reads back at all | Automation that only pushes cannot answer row 6 or 7 for the fleet; it can only answer them for the host you are logged in to. The read-back is cheap and its absence is why every other row here needed a shell | [5 · hop 1](../phases/5-automation/) 🔨 · 🔨 lab |

## Week two — support, visibility, the platform, the server

| # | Run | The answer looks like | What you decide from it | From |
|---|---|---|---|---|
| 17 | `sos report --batch --case-id <last case>` on one host, and the organisation's case history in the portal | An 11 MB bundle in a minute and a list of cases with the severities someone chose — or nobody has opened a case in three years and the bundle is a mystery | A subscription nobody opens cases on is an invoice: the *obligated party* it buys ([docs/01](01-product-vs-upstream.md)) has never been asked anything. Row 3's rehearsal and row 20's upgrade both produce cases; know the path before they do | [0 · hop 4](../phases/0-subscription-and-support/) 🔨 lab |
| 18 | `insights-client --status` on a sample (after the registration has settled — the lab found it reporting *not registered* for two minutes after `--register`); the console's inventory count against `hammer host list \| wc -l` | The two counts agree — or half the fleet never registered and the advisor has only ever seen the half that did | The difference is the fleet Insights cannot see; every advisor, vulnerability and compliance number in the console is a number about the visible half. Fix registration before quoting any of them | [0 · hop 3](../phases/0-subscription-and-support/) 🔨 lab |
| 19 | If there is a platform: `openstack image list` (or the hypervisor's image catalogue) against the fleet's image versions; a guest's `subscription-manager identity` and its presence in row 13's inventory | The fleet's images under the fleet's names, guests registered into environments and inventoried — or a second image pipeline, guests nobody patches, and a pool of hand-built VMs on a hypervisor with a name | A guest is a host or it is a second fleet. The second pipeline is the finding; do not merge them this month, but write down which one is the baseline and which one is the exception, because currently neither is | [6 · hops 2–3](../phases/6-platform/) ⛔ |
| 20 | The Satellite's version against the supported line, and `satellite-maintain upgrade check --target-version <next>` | N or N−1, and `Checks passed` — or three versions behind, with row 4's failing check as the reason nobody tried | The order is backup, restore rehearsal, upgrade — never the other way round. The upgrade is not this month's; the plan for it is, and it starts with row 3. A Satellite three versions behind is also one whose content export/import across a gap may not match the disconnected side's version; ask row 2's question of the disconnected Satellite too, if there is one | [7 · hop 3](../phases/7-satellite-operations/) ⛔ |

---

## What this pass is accepted on

> **For every hop of the chain you can say whether it is true on this estate, from something you
> read on a host or from the server's own data rather than something you were told — and the
> first change you make is the one whose answer surprised you.**

Not *"the fleet is patched."* Nobody can say that in a week, and the estates where someone does
are the ones where row 7 has never been run.

## What is deliberately not here

- **No fixes.** Every row reads; none changes. The runbooks say how to change things, once the
  picture is right. The one exception is `dnf clean all` as a user in row 9, which changes
  nothing a host has installed.
- **No timeline shorter than a week.** A day-one *promotion* is the most expensive kind of
  wrong, because it lands on every host in the environment at once.
- **No 30-60-90 plan.** The document a hiring manager asks for is a derivative of this page,
  written for one organisation, and it names that organisation — so it is never published here.
