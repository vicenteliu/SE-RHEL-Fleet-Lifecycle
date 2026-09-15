# Phase 7 — Satellite operations: a server that survives its own upgrades

**Hop:** a Satellite server → one that survives its own upgrades. **Mechanism:**
`satellite-maintain` (upstream `foreman-maintain`): health check, backup, upgrade, restore;
Capsule sync; the database; storage for Pulp. **Product:** Satellite. **Upstream:** Foreman +
Katello with the same tool under its upstream name. **State: ⛔ Specced-Not-Run — no tier here
runs Satellite; the mid tier runs Foreman + Katello, which is the same operations surface
without the entitlement. 🔨 only for the parts that are generic operations: PostgreSQL
backup/restore and service operations on prior estates.**

This is the phase with no glamour and the highest cost of getting wrong: every hop above
depends on this one server (or this one server and its Capsules). Its upgrade is the single
most valuable supported thing in the whole chain ([docs/01](../../docs/01-product-vs-upstream.md)),
because a failed Katello/Pulp/PostgreSQL migration takes provisioning, content, errata and
remote execution down together.

## Before you start

- **Sizing**: Pulp's storage (`/var/lib/pulp`) is the content the fleet draws; it grows with
  every synced repository and every content view version that is kept. The database grows with
  hosts and facts. Both are sized before install and checked monthly.
- **A backup that has been restored once**, on a test machine, before the first upgrade. A
  backup that has never been restored is a hope.
- **The upgrade path**: Satellite upgrades one minor at a time (6.17 → 6.18 → 6.19); skipping is
  not supported. The release notes' *known issues* are read before, not after.

## Permissions

- Root on the Satellite and each Capsule; the organisation admin in the web UI / `hammer`.
- A support case *opened before* a major upgrade on a production Satellite is a habit that
  costs nothing and starts the clock early if something goes wrong.

## Minimum test

`satellite-maintain health check` clean; `satellite-maintain backup offline` to a directory;
that backup restored onto a second machine of the same version; `hammer ping` green on the
restored one. That is the whole survival property exercised once, before it matters.

## Hops

### Hop 1 — health, on a schedule

```sh
satellite-maintain health check
satellite-maintain service status
hammer ping
```

The health check covers what breaks upgrades: disk space, service state, database state,
pending tasks, Capsule sync. Run it weekly and before every change; its output is the first
attachment on a case.

### Hop 2 — 🥇 backup, and restore it once

```sh
satellite-maintain backup offline /var/backup/satellite     # consistent; services stop
satellite-maintain backup online  /var/backup/satellite     # services up; longer, PostgreSQL snapshot
satellite-maintain restore /var/backup/satellite/<dir>       # on a machine of the same version
```

Offline is the reliable one; online is the one for a Satellite that cannot stop. Either way the
backup includes the database, Pulp content (or a reference to it, with `--skip-pulp-content` for
the fast variant), and the configuration. The restore is rehearsed on a throwaway machine; the
throwaway machine is what the mid tier is for.

### Hop 3 — the upgrade

```sh
satellite-maintain upgrade check  --target-version 6.19
satellite-maintain upgrade run    --target-version 6.19
```

Check first (it runs the health check and the pre-upgrade checks); then run, which stops
services, migrates the database and content, and starts them. Capsules upgrade after the
Satellite, one at a time, with `capsule-certs-generate` if certificates changed. The window is
hours; the fleet keeps running on what it already has — hosts do not notice unless they need
content mid-upgrade.

### Hop 4 — Capsules, sync and the disconnected case

Capsules sync content from the Satellite on a schedule or on promotion (`hammer capsule
content synchronize`); a Capsule behind on sync serves an old version to its hosts, silently.
For an isolated network, a connected Satellite exports (`hammer content-export complete
version`) and the disconnected one imports; the version numbers are the audit trail across the
gap.

### Hop 5 — the database and the storage

PostgreSQL vacuum and size; `/var/lib/pulp` usage against the retention of content view
versions (delete old versions; Pulp reclaims what no version references); `foreman-rake
katello:delete_orphaned_content`. The generic parts here are ordinary database and disk
operations, and are the only 🔨 the author has in this phase.

## How the phase fails

- The upgrade was run without the check; the pre-upgrade check would have found the full disk.
- The backup exists and was never restored; the restore fails on the day because the Pulp path
  differed.
- Capsule sync failed a week ago; hosts behind it are patching from a stale version and every
  compliance number for that site is wrong.
- Old content view versions were never deleted; Pulp's disk fills the night before the errata
  window.
- A Satellite two minors behind can no longer be upgraded in one step and needs a plan nobody
  has time for.

## Verify

| | Command | Expected · tier |
|---|---|---|
| 1 | `satellite-maintain health check` | every check `OK` · mid (`foreman-maintain`) / full |
| 2 | `satellite-maintain backup offline …` · restore on a second machine · `hammer ping` | all services `ok` on the restored machine · mid / full |
| 3 | `satellite-maintain upgrade check --target-version …` | `Checks passed` · full |
| 4 | `hammer capsule content synchronization-status --id <n>` | last sync time within the schedule · full |
| 5 | `du -sh /var/lib/pulp` before and after deleting an old version | the reclaimed space · mid / full |

## Acceptance

🔴 **The Satellite can be restored from its own backup onto a fresh machine, and the fleet did
not notice the exercise.** ⛔ Not run here. The mid tier can run the Foreman + Katello version of
every hop; only a subscribed Satellite runs the product's.

## Rollback

The restore, from the backup taken before the change — which is why the backup is hop 2 and the
upgrade is hop 3, and never the other way round.

## Escape Hatch

A Satellite that is down during a patch window with a fix that cannot wait: hosts still have
their pinned content cached (`dnf` metadata) for as long as `metadata_expire` allows, and a
Capsule that is up serves its last sync. The documented path is *patch from the Capsule, fix
the Satellite after*; the undocumented one is pointing hosts at the internet, which unpins every
host it touches and is the failure phase 2 exists to prevent.
