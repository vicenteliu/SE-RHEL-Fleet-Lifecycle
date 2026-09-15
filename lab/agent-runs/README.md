# Agent runs — the evidence behind a 🔨 row in the ledger

One file per run: `<YYYY-MM-DD>-<provider>-<model>-<row>.md`, for example
`2026-09-22-ollama-ornith-1.5-9b-2.3.md`. The row id is the one in
[`AGENT_BOUNDARY.md`](../../AGENT_BOUNDARY.md). A row is 🔨 only when a file here says so;
the file is the credential, the row is the index.

## Two ways to run, and the file says which

**Agent CLI — the main path.** A responsibility is executed with tools, so the realistic test
is an agent that has them. Run inside the lab tier the runbook names, never on a machine that
matters.

```sh
# hosted
claude -p "$(cat task.md)" --model <exact id> --output-format json \
  --allowedTools "Bash(dnf *) Bash(createrepo_c *) Bash(rpmbuild *) Read" > transcript.json
codex exec -m <exact id> --json -o last.md "$(cat task.md)" > events.jsonl

# local, through the same CLI, so the comparison is on the task and not on the harness
codex exec --oss --local-provider ollama  -m ornith-1.5:9b --json -o last.md "$(cat task.md)"
codex exec --oss --local-provider lmstudio -m <model as LM Studio names it> --json -o last.md "$(cat task.md)"
```

**Bare API call — the narrow task.** Classify a log, propose an array, read a diff. No tools,
because tools would be theatre. `lab/agent/run.py` in
[SE-macOS-Endpoint-Automation](https://github.com/vicenteliu/SE-macOS-Endpoint-Automation) does this against
Anthropic, OpenAI, or any OpenAI-compatible local endpoint (Ollama on `:11434/v1`, LM Studio on
`:1234/v1`) with the same arguments and writes the record; point its `--out-dir` here.

## What the file contains, in this order

```
# Run — row 2.3 · ollama:ornith-1.5:9b@lab-host · 2026-09-22

Path: cli | api
Command: <the exact command line, keys redacted as $VAR>
Model: <exact identifier the endpoint reported back, not the one requested>
Host: lab-host (the minimum tier's VM, never the machine's own name) | api.anthropic.com | api.openai.com
Started / finished: <ISO timestamps>   Wall: <s>   Tokens: <in/out if reported>   Cost: <if hosted>

## Task
<task.md verbatim>

## Acceptance
<the row's "How you know it worked", verbatim>

## Transcript
<the agent's output, complete; tool calls included on the CLI path>

## Result
PASS | FAIL | PARTIAL — one sentence on what the acceptance saw.
Where the agent stopped: <the first thing it did that a person would have to reverse, or "nothing">
```

**Model** is what the endpoint *reported*, because hosted defaults move under a fixed name;
that reported id is what goes in the ledger.

## Before committing

```sh
../check_secrets.sh          # refuses on a key, token, or private host; exit 1 stops the commit
```

Then the same de-identification pass as every page: no employer, no fleet, no hostname that is
not the lab's. A transcript that names a real machine is rewritten or not committed.
