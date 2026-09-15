# The same chain, with no jargon

*For the person who has to approve this, fund it, or explain it to someone who will.*

**What is being run.** A few hundred Linux servers that a company depends on, and the paid
relationship with the company that makes the operating system — Red Hat. The job is to keep
those servers correct, patched, provable and replaceable, and to know exactly what the paid
relationship is for.

**What "a version servers are pinned to" means.** Imagine the software updates for those
servers as a library that keeps receiving new books. You do not let every server read whatever
arrived last night. You take a photograph of the library — a numbered version — test it on a few
servers, then let the next group read *that photograph*, then the next. If a photograph turns
out to be bad, you point the group back at the previous one. Every server can say which
photograph it is reading. That is the whole idea behind the most expensive product in this
chain, and the middle of this repository rebuilds it with a folder, a snapshot and a shortcut,
on one machine, so that it is understood and not just described.

**What "a baseline servers are born from" means.** Every new server starts from the same
reviewed template — the settings, the security hardening, the monitoring agents — with a version
number on it. When the rules change, you make the next template, not a hundred hand edits. Two
servers born from the same template differ only by their names.

**What patching is, and what proving it is.** Patching is changing what is installed, in the
order the photographs allow. Proving it is a scan against a written policy, run by a tool, that
says pass or fail per rule. A company can be patched and unable to prove it; to an auditor that
is unpatched.

**What the paid relationship buys.** Almost never a feature. Three things, every time: a tested
combination of parts with a way to upgrade between them; an advisory or a certificate with a
name on it that an audit will accept; and a party obliged to answer when it breaks. The
open-source versions of every product here exist and work. What they do not come with is
someone else owning the upgrade. Whether that is worth paying for depends on the company, not
on the software — and that sentence is the honest answer to "Satellite or Foreman?".

**What the author has and has not done.** Built and run the server template and the packaging
for a fleet of hundreds of Ubuntu and, earlier, CentOS machines; run the patch cycles and the
automation from one control machine; never run Red Hat's own Satellite or Ansible Automation
Platform products. This repository says that on every page where it matters, and shows the
model rebuilt by hand where the product could not be run.

**The test of whether this page worked.** Give it to someone outside the domain. If they can
name one trade-off they would decide differently — *we would pay for the upgrade path* or *we
would not* — it worked. *"That was clear"* is a failure.
