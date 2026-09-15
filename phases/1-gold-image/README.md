# Phase 1 — the gold image: a versioned, reviewed baseline every host is born from

**Hop:** nothing → a baseline every host is born from. **Mechanism:** Kickstart (`%packages`,
`%post`) for *install-it*; Image Builder blueprints for *build-it*. **Product:** RHEL Image
Builder (`osbuild-composer`, `composer-cli`, the hosted builder). **Upstream:** osbuild — the
same project; Packer; a repacked installer ISO with an answer file and a first-boot hook.
**State: ⛔ Specced-Not-Run on this tier for Image Builder (runnable on aarch64; next hop in
[TODO.md](../../TODO.md)) · Kickstart 🔨 at RHCE level, not a fleet · the author's Ubuntu
version of the method 🔨 in production for years — see the footing table.**

The problem: hosts installed by hand differ in ways nobody can list, and the differences turn
into faults six months later that nobody can explain. A gold image makes *how every host came to
be* a reviewed, versioned artifact: when the security baseline changes, the answer is the next
image version, not a hundred hand edits. The fleet's differences stop at the image.

## Before you start

- **Host**: a RHEL-family machine to build on — Image Builder runs on the OS it builds for (Rocky
  9 builds Rocky 9 images; RHEL builds RHEL with entitled content). This tier: the Rocky 9
  aarch64 VM, `osbuild-composer` and `composer-cli` from AppStream. Building x86_64 images needs
  an x86_64 builder.
- **Content**: the repositories the image will draw from — on a fleet, an environment from
  phase 2, never the library; the blueprint's package list resolves against them at build time.
- **A definition under version control**: the blueprint (TOML) or the Kickstart file. The image
  has a name and a version (`rhel9-base-2026.09`); its source is a commit.

## Permissions

- The `weldr` group for `composer-cli`; root for the `osbuild-composer` socket and for
  Kickstart-driven installs.
- Outbound to the repositories the blueprint names. Nothing else.
- Whoever can merge a change to the blueprint can change every future host. That is a review
  gate, not a permission bit.

## Minimum test

One blueprint that adds one package and one hardening setting, built to one `qcow2`, booted
once, and the two things checked from inside. If the booted image has the package and the
setting and reports its own version, the method is proved; the rest of a real baseline is more
lines in the same file.

## Hops

### Hop 1 — install-it: Kickstart

`%packages` chooses what is installed; `%post` is where hardening, agent installation and
registration happen — `subscription-manager register --activationkey`, which is how phase 0 and
phase 2 reach a host that has existed for ninety seconds. Kickstart is served by the provisioning
server (phase 3) or embedded in installer media. RHCE-level here: the syntax and the `%post`
pattern, not a Kickstart fleet.

### Hop 2 — build-it: Image Builder

```sh
composer-cli blueprints push rhel9-base.toml
composer-cli blueprints depsolve rhel9-base
composer-cli compose start rhel9-base qcow2
composer-cli compose status
composer-cli compose image <uuid>
```

The blueprint names packages, users, services, kernel arguments and — through customisations —
the files and firewall rules that a `%post` would have scripted. Output formats come from the
same osbuild: `qcow2`, `ami`, `vhd`, an installer `iso`, an `edge-commit` (ostree). The build
does not boot anything; the image is assembled from packages, which is why it is reproducible.

### Hop 3 — 🥇 the baseline is what goes in, and it is reviewed as a diff

Hardening that can be baked in (sshd settings, audit rules, SELinux enforcing, FIPS if the
policy says so, LUKS with a sealed key where the hardware allows), the monitoring and
management agents, the repository pointers (an activation key, or a `.repo` file to an
environment), the time and log forwarding. Each is a line in the blueprint or the Kickstart; a
change is a diff someone approved; the image version records which diff.

### Hop 4 — first boot hands the host to configuration management

`cloud-init` or a `%post`-installed first-boot unit registers the host, enrols it where it
belongs (phase 0, phase 2, identity if any) and calls the automation (phase 5) to converge. The
image stops at *born correctly*; *kept correct* is phase 4 and 5's job, and an image that tries
to do both becomes a snowflake factory with extra steps.

## How the phase fails

- An image with a repository URL hard-coded is a host pinned to nothing (phase 2) from birth.
- A baseline whose hardening lives in a script that runs at first boot rather than in the image
  drifts on the hosts where the script failed silently; bake what can be baked.
- Two images for two teams "temporarily" become two fleets permanently.
- An image built on a builder whose repositories were mid-sync is an image nobody can rebuild.
- `%post` with `--nochroot` and `%post` without it are different filesystems; a script that
  writes to the wrong one produces a host that looks right until reboot.

## Verify

| | Command | Expected · tier |
|---|---|---|
| 2 | `composer-cli compose status` | `FINISHED` with the blueprint name and version · minimum |
| 2 | `composer-cli compose image <uuid>` · boot it | a `qcow2` that boots to a login · minimum (Lima can boot a `qcow2`) |
| 3 | inside: `rpm -q <package>` · `sshd -T \| grep <setting>` · `getenforce` | the package, the setting, `Enforcing` · minimum |
| 3 | inside: `cat /etc/image-version` (a file the blueprint writes) | the image's name and version · minimum |
| 1 | a Kickstart install with `%post` registering to an environment; after boot `dnf repolist` | only the environment's repositories · mid (needs phase 3's provisioning server) |
| 4 | after first boot: the host appears in the automation inventory and has converged | the host's report in phase 5's job history · mid |

## Acceptance

🔴 **A host booted from the image can say which version it was born from, and two hosts born
from it differ only in hostname and keys.** ⛔ Not run on this tier yet; the blueprint path is
runnable here and is the next hop. Not claimed: any RHEL image with entitled content (needs
phase 0), any x86_64 image, an edge/ostree image, a fleet born from any of it.

## Rollback

`composer-cli compose delete <uuid>`, `blueprints delete`; the previous image version is the
rollback for the fleet, which is why versions are kept and why the hop above says *diff*.

## Escape Hatch

A host that must exist before the next image version — the vendor appliance, the one box with
the odd driver. The documented path is a **variant blueprint** that inherits the base and adds
the difference, versioned like the base; a host installed by hand with a note in a ticket is
the thing the phase exists to end, and the note is not an image.
