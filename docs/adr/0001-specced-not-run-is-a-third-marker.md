# Specced-Not-Run is a third marker, not a missing one

This repository inherits a two-marker honesty system — 🔨 operated for real, 🧭 mapped and
doc-checked but not run — and, following the first two `SE-` playbooks, keeps a third: ⛔
**Specced-Not-Run**. It adds a qualifier, **🔨 lab**, and this file says why both exist.

## ⛔ — the difference from 🧭

🧭 is *doc-checked with no plan to execute*. ⛔ carries the complete environment specification,
the step-by-step verification, the acceptance criteria, and **an explicit stated reason for not
executing**. One is an absence. The other is a decision.

Four hops carry it here, for one reason and one exception. **Foreman + Katello, Uyuni and
OpenStack run only on x86_64**, and the author's lab is a virtual machine on Apple silicon; so
provisioning through Foreman (phase 3), the product half of content management (phase 2), the
automation controller (phase 5 — AWX needs a Kubernetes cluster, ⛔ by cost on this tier) and the
platform (phase 6) are specified to the point where a reader with the mid tier can run them, and
the tier is named in docs/02. Buying a machine to close a marker is the wrong order of
operations. Phase 0 was ⛔ for a few hours on the day the repository was written — the
subscription and support workflow runs on aarch64 and needs only a free developer account, which
did not exist that morning and did that afternoon; it is 🔨 lab now. Phase 1's Image Builder
path and phase 4's OpenSCAP scan are ⛔ the same way: runnable here, not yet run, next.

## 🔨 lab — the difference from 🔨

The first playbook marked its one real run 🔨 with the words *"lab"* and *"no fleet"* in the
sentence. Here the 🔨 lab rows are the phase-2 run, and repeating the disclaimer in prose on every row
is how a disclaimer stops being read. So the qualifier is in the marker: **🔨 lab** means real
commands and real output on one machine in a named tier — and *nothing about production*. A reader
who sees 🔨 without the qualifier is being told the author has done this where it counted.

## Why it earns its own symbol

Because the two are read differently by the only audience that matters. *"I have not done that"*
and *"here is the environment I specified to do it, what each tier can and cannot verify, and why
the tier I have stops short"* are different answers to the same question, and the second is only
available if the distinction was made while writing.

A reader who wants to build this can act on a ⛔ section. They cannot act on a 🧭 one.
