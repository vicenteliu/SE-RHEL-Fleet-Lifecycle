# Phase 2 — content and lifecycle: a version hosts are pinned to

**Hop:** upstream content → a version hosts are pinned to. **Mechanism:** sync → content view
version → promote through lifecycle environments → host pinned by activation key. **Product:**
Red Hat Satellite (Katello + Pulp). **Upstream:** Foreman + Katello. **State: 🔨 lab — the model
rebuilt by hand on the minimum tier, every command and its output on this page.**

The problem the phase exists for: a few hundred hosts must not each `dnf update` to *whatever
the CDN has today*. Production wants the content Test verified, byte for byte; a way back to the
previous version; and an answer, when an auditor asks why this host is on this version, that is
a version number and not a memory. Satellite's answer is the **content view version** —
a snapshot of synced content with its own metadata — promoted through **lifecycle
environments** (`Library → Dev → Test → Prod`), with each host **pinned** to one environment by
the activation key it registered with. A host is never "latest"; it is on a version.

This page rebuilds that model with `reposync`, `createrepo_c`, hardlinks and symlinks, because a
model you can rebuild in forty lines is a model you understand, and because the minimum tier
cannot run Katello ([docs/02](../../docs/02-lab-tiers.md)).

## Before you start

- **Host**: one RHEL-family machine. This run: Rocky Linux 9.8, aarch64, 2 vCPU, 4 GB, a Lima VM
  on an Apple-silicon workstation. `createrepo_c` 0.20, `rpm-build` 4.16, `dnf-plugins-core` 4.3.
- **Content**: one small upstream repository to sync (`extras`, 59 packages, 3.4 MB — chosen for
  size; `baseos` would be gigabytes and prove nothing more) and one custom product built here.
- **Layout**: `/srv/content/{library,cv,env}` — the library is what synced; `cv/<name>/<version>`
  is a published snapshot; `env/<name>` is a symlink to exactly one version.

## Permissions

- A user who can `sudo`: the layout under `/srv`, the `.repo` file under `/etc/yum.repos.d`,
  `dnf install`. Everything else — sync, build, publish, promote — runs as the user.
- Outbound HTTPS to the distribution's mirrors for the one sync. No inbound; the environments are
  served on `localhost:8080` by `python3 -m http.server`, which is a stand-in for the Capsule's
  web server and nothing more.
- No subscription. Nothing on this page touches the Red Hat CDN; the same model applies to it
  the day a manifest exists (phase 0).

## Minimum test

One package at two versions, one erratum, two environments, one host. If the host pinned to
`prod` is offered 1.0 while `dev` offers 1.1 and the advisory, and a rollback of `prod` is a
single symlink, the model is proved. Everything a real Satellite adds on top — Pulp's
deduplication, composite views, filters, the API — is scale and convenience over this exact
shape.

## Hops

### Hop 1 — the library: sync, and a custom product from a spec file

`dnf reposync --repoid=extras --download-metadata -p /srv/content/library/extras` is Pulp's
sync. The custom product is what Satellite calls a *custom repository*: a spec file, `rpmbuild -bb`,
the RPM into a directory, `createrepo_c`. The spec ([`lab/lab-hello.spec`](../../lab/lab-hello.spec))
is eleven lines and builds a `noarch` package whose only job is to print its own version — so a
host can prove which content it drew from.

### Hop 2 — 🥇 a content view version is a snapshot with its own metadata

```sh
cp -al /srv/content/library/extras /srv/content/cv/cv-base/1.0/extras   # hardlinks
rm -rf /srv/content/cv/cv-base/1.0/extras/repodata
createrepo_c /srv/content/cv/cv-base/1.0/extras                          # frozen metadata
```

Two things make it a version and not a copy. The **hardlinks** mean a version costs nothing
(the run shows 1.0 and 2.0 at 124 KB and 128 KB against a 3.4 MB library — the metadata is the
only new bytes; Pulp does the same with content-addressed storage). The **own `repodata`** means
the version's package list is frozen at publish time: syncing the library tomorrow changes
nothing a host can see until someone publishes 3.0. This is the property that lets "Test verified
it" mean anything.

### Hop 3 — a lifecycle environment is a pointer, and promotion is moving it

```sh
ln -sfn /srv/content/cv/cv-base/2.0 /srv/content/env/dev      # promote 2.0 to dev
# prod still -> 1.0
```

An environment is not a place content lives; it is a name that resolves to one version. Promotion
does not copy anything. Rollback is the same operation pointed the other way. The run shows all
three: both environments on 1.0, `dev` promoted to 2.0 while `prod` stays, `prod` promoted and
then rolled back — each one `ls -l /srv/content/env`.

### Hop 4 — a host is pinned by what its repository file resolves to

The activation key's job, reduced to its content half: the host's `.repo` has
`baseurl=http://localhost:8080/prod/lab-tools/`. It draws from `prod`, and `prod` is a version.
The host never sees the library. Re-pinning a host is rewriting that file (in Satellite, changing
the host's environment); the run pins to `prod`, then `dev`, then `prod`.

### Hop 5 — errata are metadata on a version

`modifyrepo_c --mdtype=updateinfo updateinfo.xml <version>/lab-tools/repodata` attaches
`LAB-2026:0001` to version 2.0. A host pinned to `dev` (on 2.0) lists it with `dnf updateinfo
list`; a host pinned to `prod` (on 1.0) cannot see it. That is how an errata filter in a content
view works: the advisory exists only in versions that include it, and a host only sees its
version.

## How the phase fails

Two of these came out of the run, not the documentation.

- **A rollback behind the same URL is invisible until the host's metadata cache expires.** After
  `prod` was rolled back from 2.0 to 1.0, the host still saw 1.1 offered: `dnf` as a non-root user
  keeps its own cache in `/var/tmp/dnf-<user>-*`, `sudo dnf clean all` had cleared root's only,
  and the environment's URL had not changed. Satellite hosts have the same property —
  `metadata_expire` governs when they notice a promotion or a rollback. A rollback that "did not
  take" is usually this.
- **`dnf updateinfo list` is relative to the host, not to the repository.** With 1.1 already
  installed, the advisory disappeared from the list even on an environment that carries it;
  `--all` shows it with an `i` flag. A compliance report built from `updateinfo list` on hosts
  counts *applicable* advisories, which is right for "what do we still owe" and wrong for "what
  did this environment publish".
- A version published from a library that synced mid-way is a version of a half-sync. Sync,
  verify the sync, then publish; never publish on a schedule that can overlap a sync.
- A custom product without `updateinfo` has no errata, so hosts on it patch by package version,
  not by advisory — which is what the author's prior estates did, and what an audit will notice.
- Serving environments from a web server that lists directories is fine; serving the *library* is
  the failure — a host pointed at the library is pinned to nothing.

## Verify

Per hop, the command and what the run produced ([`lab/phase2.log`](../../lab/phase2.log), unedited).

| | Command | Seen |
|---|---|---|
| 1 | `dnf reposync --repoid=extras --download-metadata -p …/library/extras` | 59 packages, 3.4 MB |
| 1 | `rpmbuild -bb lab-hello.spec` · `rpm -qip …/lab-hello-1.0-1.el9.noarch.rpm` | `Wrote: …/lab-hello-1.0-1.el9.noarch.rpm` · Name/Version/Release/Architecture as in the spec |
| 2 | publish 1.0 (`cp -al` + `createrepo_c`) | `published cv-base 1.0: 60 packages` |
| 3 | `ls -l /srv/content/env` after both links | `dev -> …/cv-base/1.0` · `prod -> …/cv-base/1.0` |
| 4 | `curl …/dev/lab-tools/repodata/repomd.xml` | `200` |
| 4 | pin `prod`, `dnf install lab-hello`, `lab-hello` | `lab-hello 1.0` |
| 5 | publish 2.0, `modifyrepo_c --mdtype=updateinfo` | `published cv-base 2.0: 61 packages` · erratum attached |
| 3 | promote `dev` → 2.0; `ls -l /srv/content/env` | `dev -> …/2.0` · `prod -> …/1.0` |
| 4 | `dnf repoquery lab-hello` on the `prod`-pinned host | `lab-hello-0:1.0-1.el9.noarch` only |
| 4+5 | pin `dev`; `dnf repoquery lab-hello`; `dnf updateinfo list` | `1.0` and `1.1` · `LAB-2026:0001 Moderate/Sec. lab-hello-1.1-1.el9.noarch` |
| 5 | `dnf update lab-hello` on `dev`; `lab-hello` | `lab-hello 1.1` |
| 3 | promote `prod` → 2.0, then `prod` → 1.0; `ls -l …/env/prod` | `prod -> …/1.0` |
| — | `dnf repoquery lab-hello` on `prod` **before** clearing the user cache | `1.0` **and** `1.1` — the stale cache |
| — | `dnf clean all` as the user; `dnf repoquery lab-hello` | `1.0` only |
| — | `dnf updateinfo list` with 1.1 installed, `prod` on 2.0 | nothing; `--all` → `i LAB-2026:0001 …` |
| — | `du -sh library cv-base/1.0 cv-base/2.0` | `3.4M · 124K · 128K` |

## Acceptance

🔴 **A host pinned to `prod` is offered exactly what `prod`'s version contains, and nothing
that `dev`'s does — and rolling `prod` back is one pointer.**

```
what a prod-pinned host sees:   lab-hello-0:1.0-1.el9.noarch
what a dev-pinned host sees:    lab-hello-0:1.0-1.el9.noarch
                                lab-hello-0:1.1-1.el9.noarch
                                errata: LAB-2026:0001 Moderate/Sec. lab-hello-1.1-1.el9.noarch
prod rolled back to 1.0 — one symlink:  prod -> /srv/content/cv/cv-base/1.0
```

✅ Met, on one machine, one afternoon, one package, two versions, two environments. ⛔ Not
claimed: Katello doing any of it, Pulp's storage, composite content views, filters other than
"which packages are in the version", a Capsule, a second host, GPG-signed content, the Red Hat
CDN as a source, any scale. Those remain 🧭 (Katello/Pulp: [docs/02](../../docs/02-lab-tiers.md)
mid tier) and none is claimed here.

## Rollback

`rm -rf /srv/content /etc/yum.repos.d/lab.repo`, kill the `http.server`, `dnf remove lab-hello`,
`rm -rf ~/rpmbuild`. The VM itself: `limactl delete rhel-lab`.

## Escape Hatch

A host that must have a package *now*, ahead of promotion — the security fix that cannot wait for
Test. The documented path: a **hotfix content view** (in Satellite, a version with an inclusion
filter for the one package), promoted to the environment the host is in, and recorded as such.
The undocumented path is a host with a second `.repo` pointing at the library, which is a host
pinned to nothing, which is the failure the phase exists to prevent — so the hatch is a named
version, never a URL.
