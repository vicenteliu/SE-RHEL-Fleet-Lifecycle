# Disclosure

What this repository deliberately does not contain, and why. Published as an artifact rather
than kept as a checklist, because a checklist is skipped under deadline and a missing file is
not.

## Not here, on purpose

**No employer, no client, no end client is named.** Not the organisations whose estates taught
the author the 🔨 rows, and not the parties whose role specification prompted this chain. Where
scale matters to an argument it appears as scale — *"a couple of hundred hosts"* — never as a
place or a party.

**No specification text.** The role that prompted this repository had a written specification.
None of its sentences are here. The chain is derived from what the work *is*; a distinctive
phrase from a job description reproduced in a public repository identifies the description.

**No claim of having run Satellite, AAP, Foreman, Katello, Uyuni or OpenStack.** The author has
not. The footing table in the README says exactly what was run where; the ⛔ pages say what
would be needed to run the rest and why it was not. Phase 2 rebuilds Satellite's content model
by hand on one machine so that the model is verified rather than recited, and says so on every
line where a reader might otherwise infer the product.

**No claim of scale for anything run here.** Every run happened on one virtual machine on one
afternoon. *Production* appears in the footing table only for the author's prior operating
work under a 🔨 marker, never for a run made here.

**No subscription content and no entitlement material.** Nothing from the Red Hat CDN, no
manifest, no certificate, no `sos report` from any real host. The lab tier is Rocky Linux for
that reason, and the day a developer subscription is registered, what it produces stays on the
lab VM except the command output the runbook quotes.

**No prices.** Product comparison is functional; a price is wrong within a quarter and a
functional difference is not.

**No secrets, no hostnames that are not the lab's.** Every published output has the lab VM's
user as `lab-user` and the host as `lab-host`; `lab/check_secrets.sh` refuses a transcript with
a key in it.

## Why publish the boundaries at all

Because an interviewer who reads this page and then asks *"have you run Satellite?"* already
knows the answer, and is scoring whether the candidate draws the line themselves. This page
draws it first.
