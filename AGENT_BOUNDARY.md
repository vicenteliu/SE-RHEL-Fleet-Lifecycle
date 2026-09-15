# Agent Boundary Ledger

Where, in this chain, a model is allowed to act, and where a person decides — one row per
responsibility, and a **model line** on every row that was actually tried, because the boundary
moves as models change and a boundary with no date on it is an opinion.

**Rules** (ADR-0002):

- A row is a **Responsibility Item**: one duty concrete enough that the line through it can be
  drawn and argued. Rows come from this repository's own runbooks; nothing here was invented
  for the ledger, and phases that are ⛔ have no rows until a tier runs them.
- **Human decides** / **Agent executes** / **How** / **How you know it worked** are the four lines
  every row carries. The fourth is an **Acceptance** — a command and what it must return.
- **Model** is the exact identifier that ran, and where: `anthropic:<id>`, `openai:<id>`,
  `ollama:<id>@<host>`, `lmstudio:<id>@<host>`. **Tested on** is the date. One row per model
  tried; when a model generation changes the old row stays and a new one is added.
- Only a model that **actually ran** the task gets a model line.
- Every 🔨 row points at a file in [`lab/agent-runs/`](lab/agent-runs/). That file is the
  evidence; a row without one is 🧭 no matter what it says.

**Status**:

| | Means |
|---|---|
| 🔨 | An agent ran it against the acceptance, and the run is in `lab/agent-runs/`. |
| 🧭 | The line is drawn by judgement. Nobody has handed this to a model yet. |
| ⛔ | Deliberately not handed to a model, with the reason in the row. |
| ⏳ | The model line is stale: the generation changed, or it is more than 90 days old. Re-run before citing. |

---

## Phase 2 — content and lifecycle (run on the minimum tier, by hand)

| # | Responsibility | Human decides | Agent executes | How | How you know it worked | Model | Tested on | Status | Run |
|---|---|---|---|---|---|---|---|---|---|
| 2.1 | Sync an upstream repository into the library | Which repositories the fleet carries at all — a repository in the library is content a version can include | The sync, the metadata rebuild, the count read back | `dnf reposync … --download-metadata` · `createrepo_c --update` | The package count matches upstream's; `repomd.xml` newer than the last sync; no version changed (the library is not what hosts see) | | | 🧭 | |
| 2.2 | Build a custom package from a spec and add it to a custom product | Whether the thing being packaged belongs in the fleet at all, and its version number | The build, the copy into the product, the metadata rebuild | `rpmbuild -bb` · `createrepo_c` | `rpm -qip` reports the spec's name/version/release; the product's `repodata` lists it | | | 🧭 | |
| 2.3 | Publish a content view version | **When** — a version published mid-sync is a version of a half-sync; the person confirms the library is quiescent | The hardlinked snapshot and its own `repodata` per repository | `cp -al` · `createrepo_c` per repository | The version's package count; its `repodata` timestamp; the library's later changes not visible in it | | | 🧭 | |
| 2.4 | Promote a version to `dev` / `test` | The order and the gate between them — promotion *is* the change control | Moving the pointer, clearing the cache on the affected hosts, reading back what those hosts are now offered | `ln -sfn` · `dnf clean all` (as every user who runs `dnf`) · `dnf repoquery` | `ls -l env/<env>` shows the version; a host pinned to it is offered exactly that version's packages | | | 🧭 | |
| 2.5 | Promote a version to `prod` | Always. This is the release; the agent prepares the diff of what changes for the `prod` hosts and the count of hosts affected | The report only | `diff` of the two versions' package lists · the host count per environment | The report names every package delta and the advisory list; `prod` has **not** moved until a person moves it | | | ⛔ — the release decision stays with a person by design |  |
| 2.6 | Roll an environment back | Whether to — a rollback removes the *offer*, not the installed packages, so the person decides the host-side action too | Pointing the environment at the previous version and telling every affected host to drop its metadata cache | `ln -sfn` · `dnf clean all` on each host, as root **and** as any non-root user who has run `dnf` | The host is offered the previous version's packages — checked from the host, not from the server, because the phase-2 run showed the stale-cache case | | | 🧭 | |
| 2.7 | Attach an erratum to a version | The advisory's content — id, severity, which package fixes it — is a statement someone signs | Writing `updateinfo.xml` from the person's statement and attaching it | `modifyrepo_c --mdtype=updateinfo` | A host on that version lists the advisory with `dnf updateinfo list` (if the fix is not yet installed) and with `--all` regardless | | | 🧭 | |

## Phase 0 — subscription and support (run on the minimum tier)

| # | Responsibility | Human decides | Agent executes | How | How you know it worked | Model | Tested on | Status | Run |
|---|---|---|---|---|---|---|---|---|---|
| 0.1 | Register a host with an activation key | Which key — the key is the environment and the content the host will live with | The registration and the read-back | `subscription-manager register --activationkey` · `status` · `repos --list-enabled` | `Registered`; only the key's repositories enabled — and, from the run, the check is `sudo` and the Insights verification waits for the inventory | | | 🧭 | |
| 0.2 | Build the diagnostic bundle for a case | Whether it may leave the host as-is or must be cleaned; which case it attaches to | `sos report` with the case id, the listing of what is in it, the cleaned variant if asked | `sos report --batch --case-id` · `--clean` · `tar -tf` | The archive exists and its listing was shown to the person before anything was sent | | | ⛔ — the *send* is a person's act; the bundle contains configuration and logs | |
| 0.3 | Open a support case and choose its severity | Always — severity is business impact and is a relationship the fleet has with the vendor | The draft: version, kernel, reproduction, what changed, what was tried, the Knowledgebase search results | the portal's API or a drafted text | A draft that a person edits and submits; the agent never submits | | | ⛔ — severity and submission stay with a person | |

---

*Rows are added when a runbook hop is handed to a model for the first time, never ahead of
that. The first rows to earn a model line are 2.4 and 2.6 — promotion and rollback, where the
phase-2 run found the stale-cache trap that a model either knows to clear or does not — and are
in [TODO.md](TODO.md).*
