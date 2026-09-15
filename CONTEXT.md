# Context

The vocabulary this repository uses, and what each word is chosen *against*. Terms are
defined by what they **are**, not by what they do.

## Language

**Playbook**:
What this repository is: the **Chain**, one **Runbook** per phase, and the decisions between
them — written first for a reader with five minutes and second for whoever runs a RHEL fleet
from it. Not a product tour: product and upstream are set side by side once, in `docs/01`.
_Avoid_: "method repository," "portfolio," "reference architecture," "framework," "guide to Satellite"

**Chain**:
The ordered set of hops between a subscription and a host someone can explain to an auditor.
Named as a chain because the interesting failures are at the joints: an image that registers
into the wrong environment, an erratum a host cannot see, a job nobody can trace.
_Avoid_: "workflow," "pipeline," "stack"

**Hop**:
One transition in the **Chain**, owned end to end by one mechanism. A hop is the unit that gets
verified; a phase is the boundary of **Acceptance** and is published as one **Runbook**. Also
the weekly unit of work on this repository: one row turned into a command and run, one section
written to shape, or one ledger row handed to a model — committed with a message starting `hop:`.
_Avoid_: "step," "stage," "task," "sprint"

**Runbook**:
One phase, as published: *Before you start · Permissions · Minimum test · Hops · How the phase
fails · Verify · Acceptance · Rollback · Escape Hatch*. A command appears wherever a **Lab Tier**
can produce it; a script appears only where one was run.
_Avoid_: "guide," "procedure," "SOP," "checklist"

**Content View Version**:
A snapshot of synced content with its own metadata, frozen at publish time. What a host is
pinned to. Not a copy of the library and not "the latest" — a number. Rebuilt by hand in phase 2
as a hardlinked directory with its own `repodata`, which is the whole definition.
_Avoid_: "the repo," "the mirror," "a channel" (that is Satellite 5 / Spacewalk / Uyuni's word for a different model)

**Lifecycle Environment**:
A name that resolves to exactly one **Content View Version** — `Library`, `Dev`, `Test`,
`Prod`. Promotion moves the pointer; rollback moves it back; nothing is copied. A host belongs to
one environment through its activation key.
_Avoid_: "stage," "tier" (that word is taken by **Lab Tier**), "branch"

**Errata**:
An advisory — an id, a severity, a type, the packages that close it — carried as metadata
(`updateinfo`) by a **Content View Version**. Visible to a host only through the version its
environment points to, and listed by `dnf updateinfo list` only while still *applicable* to that
host; `--all` lists it regardless. The phase-2 run made both properties visible.
_Avoid_: "patches," "updates" (a package update without an advisory is not an erratum)

**Gold Image**:
A versioned, reviewed baseline every host is born from — OS, partitioning, hardening that can be
baked, agents, repository pointers, a first-boot hand-off — produced by Kickstart (*install-it*)
or Image Builder (*build-it*). The fleet's differences stop at the image; what happens after
birth belongs to phases 4 and 5.
_Avoid_: "golden image" (same thing; the repository picks one spelling), "template," "base install"

**Activation Key**:
The credential a host registers with, carrying the organisation, the **Lifecycle Environment**,
the content view or repositories, and never a person's password. Entitlement as a property of
the fleet rather than of whoever set the host up. In phase 2's hand-built model its content
half is the host's `.repo` file.
_Avoid_: "the subscription," "credentials," "login"

**Capsule**:
Satellite's name for a **Smart Proxy**: the server that holds a copy of the content and provides
DHCP, TFTP, DNS and remote execution at a site. A Capsule behind on sync serves an old version
silently; the runbooks name that failure in three phases.
_Avoid_: "mirror," "proxy" (unqualified), "satellite" (lower-case, as if it were a second Satellite)

**Lab Tier**:
One of three declared environment levels — minimum, mid, full — each stating exactly which
**Hop** it can verify *and which it cannot*. Here the shape is set by architecture: the
minimum tier is aarch64 and the products that own three hops are x86_64. `docs/02` names the
machine that would move each.
_Avoid_: "environment," "setup," "tier" (unqualified)

**Specced-Not-Run** (⛔):
Work carrying a complete environment specification, step-by-step verification and acceptance
criteria, deliberately **not executed**, with the reason stated. Distinct from 🧭, which is
doc-checked with no plan to execute. In this repository most ⛔ hops have one reason (x86_64)
and phase 0 has another (no account yet), and each page says which (ADR-0001).
_Avoid_: "planned," "TODO," "future work," "not done"

**Acceptance**:
The condition under which a **Hop** is finished — a command and its expected output, never a
feeling that it worked. A hop with no stated acceptance is not designed, it is described.
_Avoid_: "definition of done," "success criteria," "testing"

**Escape Hatch**:
The stated path for a host or a person the design would otherwise block — the hotfix content
view, the boot media with the Kickstart embedded, the ad-hoc job template. Every phase has one,
because the undocumented workaround (a `.repo` pointing at the library, SSH with the shared
key, a host installed by hand) is the failure the phase exists to prevent, made deliberate.
_Avoid_: "exception," "override," "bypass"

**Responsibility Item**:
One duty from the chain, concrete enough that the line between what a person decides and what
a model executes can be drawn through it and argued — a row in the **Agent Boundary Ledger**.
Taken from a **Runbook** hop, never invented for the ledger.
_Avoid_: "task," "duty," "use case," "job"

**Agent Boundary Ledger** (`AGENT_BOUNDARY.md`):
One row per **Responsibility Item**, four lines each — *Human decides / Agent executes / How /
How you know it worked* — and a **model line**: the exact model identifier, where it ran, the
date. A row is 🔨 only when an **Agent Run** stands behind it; a model that did not run the
task has no line; when a model generation changes the old line stays and a new one is added,
because the ledger's payload is the boundary *moving*. A model line older than 90 days, or from
a superseded generation, is ⏳ until re-run (ADR-0002).
_Avoid_: "AI policy," "automation matrix," "capability map," "what AI can do"

**Agent Run**:
One file in `lab/agent-runs/` — the command, the model as the endpoint reported it, the task
and acceptance verbatim, the complete transcript, and the pass/fail against the acceptance.
Made through an agent CLI when the responsibility needs tools, through the bare API when it
does not, and the file says which. It is the credential behind a ledger row, screened for
secrets before it is committed.
_Avoid_: "experiment," "eval," "benchmark," "demo"

**Verification row** (rule, ADR-0002):
A command and what it must return. Where a hop is ⛔ the row names the tier that could produce
the output and marks the expected value *doc*, never *seen*. No row in this chain is GUI-only,
by construction.
_Avoid_: "manual check," "eyeball," "confirm in the console"
