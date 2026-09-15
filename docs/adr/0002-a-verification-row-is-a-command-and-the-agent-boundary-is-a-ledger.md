# A verification row is a command, and the agent boundary is a ledger with a date on every model

The same decision the two earlier `SE-` playbooks took on 2026-09-15, adopted here from the
first commit rather than retrofitted, for the same reason: a reader now brings the question
*which of this can I hand to a model?*, and an answer given in prose is wrong within a model
generation.

## Decision

**1. A verification row is a command or an API call, plus what it must return.** Every runbook
here was written under that rule. Where a hop is ⛔, the row names the tier that could produce
the output and marks the expected value *doc*, never *seen*. There are no GUI-only rows in this
chain by construction: Satellite, Foreman, AWX and OpenStack all expose an API (`hammer`, the
REST API, `awx-cli`, `openstack`), and a row that could only be done in a web console has no
place in a runbook meant to be run.

**2. Every runbook section opens with the same five headings**: **Before you start** ·
**Permissions** · **Minimum test** · **Verify** · **Rollback** — here as *Before you start ·
Permissions · Minimum test · Hops · How the phase fails · Verify · Acceptance · Rollback ·
Escape Hatch*, the two earlier playbooks' shape with the five headings inside it.

**3. The agent boundary is a ledger, [`AGENT_BOUNDARY.md`](../../AGENT_BOUNDARY.md).** One row
per **Responsibility Item**, four lines — *Human decides / Agent executes / How / How you know
it worked* — and a **model line**: exact model identifier, where it ran, the date. A model that
did not run the task has no line. A run leaves a file in [`lab/agent-runs/`](../../lab/agent-runs/),
and that file is what turns a 🧭 row into a 🔨 one. When a model generation changes the old line
stays and a new one is added. A line older than 90 days, or from a superseded generation, is ⏳
until re-run.

What is specific to this chain: several rows have a **person's decision that is also a
contractual one** — re-pinning trust on a parent recipe was the endpoint chain's case; here it
is *promote to prod*, *enable a repository the standard does not list*, *open a Sev 1*, *send an
un-cleaned `sos report`*, *apply an advisory outside the cycle*. Those rows are ⛔ for the agent
by design, and the ledger says why on each.

**4. A run is made through an agent CLI when the responsibility needs tools** (`claude -p`,
`codex exec`; a local model through `codex exec --oss --local-provider ollama|lmstudio`) **and
through a bare API call when it does not.** At least three models per row — the current hosted
default from two vendors and one local model. The runner script and the record renderer live
in `SE-macOS-Endpoint-Automation/lab/agent/`; they are not duplicated here until a row here
needs them.

**5. Transcripts are public, so they are screened.** `lab/check_secrets.sh` runs over
`lab/agent-runs/` before anything is committed and refuses on a hit. The local host is a label
(`lab-host`), never a name; the lab VM's user is `lab-user` in every published output.

## What this does not change

The markers (ADR-0001). The private/public split. Phases that are ⛔ get no ledger rows until a
tier runs them; a ledger of predictions is a blog post.
