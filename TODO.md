# What gets written next, and why in that order

Depth first, not breadth. One phase filled completely is worth more than one section filled
everywhere, because the thing a reader cannot judge yet is *what a finished section looks like
here*. Markers in a table are a promise; a worked section is the evidence.

The unit is a **hop**, one a week across the `SE-` repositories: one verification row turned into
a command and run, one section written to shape, or one ledger row handed to a model. Three
hours at most; over is split, not stretched. Its commit message starts `hop:`.

## 1. ✅ Phase 2 — the content-lifecycle model by hand — **run 2026-09-15**

Why first: it is the claim this repository most needs to stand behind — that Satellite's model
is understood, not recited — and it is the one runnable on the minimum tier without an account
or an x86_64 machine. The run produced two findings the documentation does not lead with (the
non-root metadata cache hiding a rollback; `updateinfo list` being relative to the host).

- [x] library sync · custom RPM from a spec · content view versions as hardlinked snapshots ·
      environments as symlinks · a host pinned by its `.repo` · an erratum in `updateinfo.xml` ·
      promotion · rollback — `lab/phase2.sh`, `lab/phase2.log`
- [x] both findings verified separately and recorded (log addendum)

## 2. ✅ The chain, the comparison, the tiers, the interview page, six ⛔/🧭 phases — **written 2026-09-15**

Every phase has the full shape (five headings, hops, failures, verify with the tier named,
acceptance, rollback, escape hatch), so that a reader with the right tier can act on a ⛔ page.

## What actually remains — in this order

### 3. ✅ Phase 0 — register the tier — **run 2026-09-15, the same afternoon**

A developer subscription, the RHEL 9.8 aarch64 KVM Guest Image under Lima (`lab/rhel-lab.yaml`),
an activation key. Phase 0's verification table has *seen* values; two findings (the
`insights-client --status` race after `--register`; `subscription-manager` needing root even to
read). `lab/phase0.sh`, `lab/phase0.log`.

### 4. ✅ Phase 1 — Image Builder on the tier — **run 2026-09-15**

On the registered RHEL VM rather than the Rocky one, so the blueprint resolved against entitled
content: one blueprint, 249 packages, a 10 GiB `qcow2` in 139 s, booted under Lima, nine checks
from inside (`lab/phase1-check.sh`). Two findings: the VM tool's first-boot provisioner left
SELinux permissive on the first boot (`lab/gold-boot.yaml` keeps it off the baseline); first
boot's hostname wins over the image's. `lab/phase1.sh`, `lab/phase1.log`, `lab/rhel9-base.toml`.

### 5. Phase 4 — the OpenSCAP half

`oscap xccdf eval` with the SCAP Security Guide's CIS profile and a tailoring file on the tier;
one rule flipped from fail to pass by a change; the generated remediation playbook. Moves the
*proving* half from ⛔ to 🔨 lab.

### 6. The first 🔨 ledger rows — 2.4 and 2.6

Promotion and rollback handed to three models on the phase-2 lab. The boundary the run exposed:
does a model clear the non-root metadata cache on the affected host, or report a rollback that
the host cannot see? Same harness as the endpoint repository's row 3.3.

### 7. Phase 5 — playbooks against the tier

The 🔨 half of the phase, reproduced here at lab scale: a patch playbook for the `dev` host,
`--check` then real, the state read back. Not the controller.

### 8. The mid tier, if it is ever bought

Foreman + Katello on one x86_64 machine, with the Rocky VM as its client: phases 2 (product
half) and 3 from ⛔ to 🔨 lab; AWX on a single-node cluster for phase 5. Not bought for the
marker; recorded so the price of each is known.

### 9. `docs/03-inheriting-a-fleet.md`

The verification rows re-ordered into the sequence you run them on arrival at a RHEL estate you
did not build — *which environment is prod pointing at* first, *when did the Capsule last sync*
second, *when was the backup last restored* third — each with what you decide from the answer.
Cheap, because every row exists; written after the rows above have seen values.
