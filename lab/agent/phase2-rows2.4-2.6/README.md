# Rows 2.4 and 2.6 — promote to `dev`, roll `prod` back — the harness

The first ledger rows in this repository handed to models, on 2026-09-15, on the phase-2 lab as
[`lab/phase2.sh`](../../phase2.sh) left it. The two rows were chosen because the phase-2 run found
the trap that makes them interesting: a host's `dnf` metadata cache — root's and, separately,
each user's — hides a promotion or a rollback until it expires or is cleared. A model that moves
the pointer and then reports what a stale cache shows has done half the job and reported the
wrong half.

## The protocol

Each model gets the same context ([`context.md`](context.md): the layout, the environments as
symlinks, the host pinned by its `.repo`, how to run commands on the VM) and two tasks in
order, with the lab reset between them. Nothing in either task mentions caches, refreshing, or
how to verify; the row tests judgement.

| | Start state (`reset-a.sh` / `reset-b.sh`) | Task | The trap |
|---|---|---|---|
| **A · 2.4** | `dev` and `prod` both on 1.0; the host pinned to `dev`; root's and the user's caches warm on 1.0 | [`task-a.md`](task-a.md): promote 2.0 to `dev`, `prod` must not change; report what a `dev`-pinned and a `prod`-pinned host are offered for `lab-hello` | a query on the `dev`-pinned host that does not refresh still shows 1.0 only; `prod`'s answer needs a way to ask without re-pinning the host |
| **B · 2.6** | both on 2.0; the host pinned to `prod`; caches warm on 2.0 | [`task-b.md`](task-b.md): roll `prod` back to 1.0; report what a `prod`-pinned host is now offered | a query that does not refresh still shows 1.1 — "the rollback did not take" or "prod offers 1.0 and 1.1" are the naive conclusions |

After each run, [`verify.sh`](verify.sh) records what a person can check: the pointers, a
fingerprint of every file under `cv/` (must be unchanged — a model that "fixes" a version is a
FAIL), the host's pin, the installed package, and the **true** offer after clearing the querying
user's cache. [`acceptance.md`](acceptance.md) has PASS / PARTIAL / FAIL.

## Per-model harness

| Model | Through | Permission model |
|---|---|---|
| `claude-opus-5` | `claude -p`, stream-json, from the workstation | No OS sandbox; the only tool allowed is `Bash(limactl shell rhel-lab *)` — every command runs on the VM, where the user can `sudo` |
| `gpt-6-astra` | `codex exec --json`, clean `CODEX_HOME` | OS sandbox `workspace-write` with `~/.lima` as a writable root (the VM's socket) and network on (the VM is reached over loopback ssh); same `sudo` on the VM |
| `ornith-1.5:9b` (Ollama) | `codex exec --oss`, same clean `CODEX_HOME` | Same sandbox; same 142K-token-per-turn harness cost as the endpoint repository recorded — runs in the background, minutes per turn |

Unlike the endpoint repository's row 3.3, the sandbox costs nothing here: every command crosses
into the VM and the VM has no sandbox. All three models ran the same tasks under a comparable
permission model.

## What the run found about the harness, not the models

- The two hosted models finished each task in 16–67 seconds. The local model, through
  `codex --oss`, took **23 minutes to not start** task A (three exploratory commands, then a
  session error from the CLI) and **46 minutes** to finish task B — the first turns cost 10–11
  minutes each in prompt processing, then the cache held and turns dropped to about a minute.
  The 142K-token prompt is the endpoint repository's finding, unchanged.
- `dnf list available` hides a version older than the one installed. The local model read
  "No matching Packages" as *nothing offered* and went to the server's metadata instead; a
  reader reproducing this should use `repoquery --showduplicates` or `list --showduplicates`,
  which is what both hosted models did.
- `verify.sh` clears the *user's* cache to read the true offer. It is the grader's tool; a model
  that clears root's cache with `sudo dnf clean` and then queries as the user is still looking
  at the stale copy — which is exactly the phase-2 finding, and exactly what was being tested.

## Reproduce

```sh
cd lab/agent/phase2-rows2.4-2.6
./reset-a.sh            # then one model on context.md + task-a.md, capturing its event stream
./verify.sh             # grade against acceptance.md
./reset-b.sh            # then the same model on context.md + task-b.md
./verify.sh
python3 <SE-macOS-Endpoint-Automation>/lab/agent/render_run.py --cli claude|codex --events <events> \
    --row 2.4|2.6 --task <context+task> --acceptance acceptance.md --provider <p> --command "<exact>" --out-dir ../../agent-runs
../../check_secrets.sh
```

`verify.sh` clears the user's cache to read the true offer — run it after grading the report,
not before the model has answered, and reset before the next model.
