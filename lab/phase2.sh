#!/bin/bash
# Phase 2 — content and lifecycle, the Satellite model by hand, on the minimum tier.
# One RHEL-family VM (Rocky Linux 9, aarch64). Nothing here needs a subscription or x86_64.
#
#   library  ← reposync from upstream + a custom product built from a spec file
#   content view version  = a snapshot of the library at publish time (hardlinks, own metadata)
#   lifecycle environment = a symlink that points at exactly one content view version
#   host                  = a .repo file whose baseurl is an environment, never the library
#   errata                = updateinfo.xml attached to a version's metadata
#
# Ran on 2026-09-15. Every command below ran in this order; the output is lab/phase2.log.
set -euo pipefail
C=/srv/content
step() { printf '\n===== %s =====\n' "$*"; }

step "0 · tools and layout"
rpm -q createrepo_c rpm-build rpmdevtools dnf-plugins-core | sed 's/^/  /'
sudo mkdir -p $C/library $C/cv $C/env $C/products
sudo chown -R "$USER" $C

step "1 · library: sync one upstream repository (extras — small on purpose)"
dnf reposync -q --repoid=extras --download-metadata --norepopath -p $C/library/extras
createrepo_c -q --update $C/library/extras
echo "  packages in library/extras: $(find $C/library/extras -name '*.rpm' | wc -l)"

step "2 · a custom product: lab-hello 1.0, from a spec file"
rpmdev-setuptree
cat > ~/rpmbuild/SPECS/lab-hello.spec <<'SPEC'
Name:           lab-hello
Version:        1.0
Release:        1%{?dist}
Summary:        A one-line tool that says which content view version it came from
License:        MIT
BuildArch:      noarch
%description
Prints a version string. Exists so a fleet can prove which content it was pinned to.
%install
mkdir -p %{buildroot}/usr/bin
printf '#!/bin/sh\necho "lab-hello %{version}"\n' > %{buildroot}/usr/bin/lab-hello
chmod 0755 %{buildroot}/usr/bin/lab-hello
%files
/usr/bin/lab-hello
%changelog
* Mon Sep 15 2026 lab <lab@localhost> - 1.0-1
- first build
SPEC
rpmbuild -bb ~/rpmbuild/SPECS/lab-hello.spec 2>&1 | grep -E 'Wrote|error' | sed 's/^/  /'
mkdir -p $C/library/lab-tools
cp ~/rpmbuild/RPMS/noarch/lab-hello-1.0-1.el9.noarch.rpm $C/library/lab-tools/
createrepo_c -q $C/library/lab-tools
rpm -qip $C/library/lab-tools/lab-hello-1.0-1.el9.noarch.rpm | grep -E '^(Name|Version|Release|Architecture)' | sed 's/^/  /'

step "3 · publish content view cv-base version 1.0 (snapshot of the library, hardlinked)"
publish() {  # publish <version>
  local v=$1 d=$C/cv/cv-base/$1
  mkdir -p "$d"
  for repo in extras lab-tools; do
    cp -al $C/library/$repo "$d/$repo"          # hardlinks: a snapshot that costs no space
    rm -rf "$d/$repo/repodata"
    createrepo_c -q "$d/$repo"                   # its own metadata, frozen at publish time
  done
  echo "  published cv-base $v: $(find "$d" -name '*.rpm' | wc -l) packages"
}
publish 1.0

step "4 · lifecycle environments: dev and prod both point at 1.0"
ln -sfn $C/cv/cv-base/1.0 $C/env/dev
ln -sfn $C/cv/cv-base/1.0 $C/env/prod
ls -l $C/env | sed 's/^/  /'

step "5 · serve the environments over HTTP; the host is pinned to an environment by its .repo"
(cd $C/env && nohup python3 -m http.server 8080 >/tmp/content-http.log 2>&1 &) ; sleep 1
curl -so /dev/null -w '  GET /dev/lab-tools/repodata/repomd.xml -> %{http_code}\n' http://localhost:8080/dev/lab-tools/repodata/repomd.xml
pin() {  # pin <env>  — the activation-key analogue: which environment this host draws from
  sudo tee /etc/yum.repos.d/lab.repo >/dev/null <<R
[lab-extras]
name=lab extras ($1)
baseurl=http://localhost:8080/$1/extras/
enabled=1
gpgcheck=0
[lab-tools]
name=lab tools ($1)
baseurl=http://localhost:8080/$1/lab-tools/
enabled=1
gpgcheck=0
R
  sudo dnf -q clean all; echo "  host pinned to: $1"
}
pin prod
sudo dnf -q -y install lab-hello >/dev/null && lab-hello | sed 's/^/  installed from prod: /'

step "6 · a new build, an erratum, content view version 2.0"
sed -i 's/^Version:.*/Version:        1.1/; s/^- first build/- second build, closes LAB-2026:0001/' ~/rpmbuild/SPECS/lab-hello.spec
sed -i 's/- 1.0-1$/- 1.1-1/' ~/rpmbuild/SPECS/lab-hello.spec
rpmbuild -bb ~/rpmbuild/SPECS/lab-hello.spec 2>&1 | grep -E 'Wrote|error' | sed 's/^/  /'
cp ~/rpmbuild/RPMS/noarch/lab-hello-1.1-1.el9.noarch.rpm $C/library/lab-tools/
createrepo_c -q --update $C/library/lab-tools
cat > /tmp/updateinfo.xml <<'X'
<?xml version="1.0" encoding="UTF-8"?>
<updates>
  <update from="lab" status="stable" type="security" version="1">
    <id>LAB-2026:0001</id>
    <title>lab-hello security update</title>
    <severity>Moderate</severity>
    <issued date="2026-09-15 00:00:00"/>
    <updated date="2026-09-15 00:00:00"/>
    <description>A made-up flaw in lab-hello 1.0, fixed in 1.1. Exists so the errata path can be verified end to end.</description>
    <pkglist>
      <collection short="lab-tools">
        <name>lab-tools</name>
        <package arch="noarch" name="lab-hello" release="1.el9" version="1.1" src="lab-hello-1.1-1.el9.src.rpm">
          <filename>lab-hello-1.1-1.el9.noarch.rpm</filename>
        </package>
      </collection>
    </pkglist>
  </update>
</updates>
X
publish 2.0
modifyrepo_c --mdtype=updateinfo /tmp/updateinfo.xml $C/cv/cv-base/2.0/lab-tools/repodata
echo "  erratum LAB-2026:0001 attached to cv-base 2.0"

step "7 · promote 2.0 to dev only; prod stays on 1.0"
ln -sfn $C/cv/cv-base/2.0 $C/env/dev
ls -l $C/env | sed 's/^/  /'
sudo dnf -q clean all
echo "  what a prod-pinned host sees:"; dnf -q --disablerepo='*' --enablerepo='lab-tools' repoquery lab-hello | sed 's/^/    /'
dnf -q --disablerepo='*' --enablerepo='lab-tools' updateinfo list 2>/dev/null | sed 's/^/    errata: /' || true
pin dev
echo "  what a dev-pinned host sees:"; dnf -q --disablerepo='*' --enablerepo='lab-tools' repoquery lab-hello | sed 's/^/    /'
dnf -q --disablerepo='*' --enablerepo='lab-tools' updateinfo list | sed 's/^/    errata: /'
sudo dnf -q -y update lab-hello >/dev/null && lab-hello | sed 's/^/  after dnf update on dev: /'

step "8 · promote 2.0 to prod, then roll prod back to 1.0"
ln -sfn $C/cv/cv-base/2.0 $C/env/prod
pin prod
dnf -q --disablerepo='*' --enablerepo='lab-tools' updateinfo list | sed 's/^/  prod now: errata: /'
ln -sfn $C/cv/cv-base/1.0 $C/env/prod
sudo dnf -q clean all
echo "  prod rolled back to 1.0 — one symlink:"; ls -l $C/env/prod | sed 's/^/    /'
dnf -q --disablerepo='*' --enablerepo='lab-tools' repoquery lab-hello | sed 's/^/    prod offers: /'
echo "  the installed host keeps 1.1 (a rollback changes what is offered, not what is installed):"; lab-hello | sed 's/^/    /'

step "9 · the audit question: why is this host on this version?"
echo "  environment -> content view version:"; readlink $C/env/prod | sed 's/^/    prod -> /'; readlink $C/env/dev | sed 's/^/    dev  -> /'
echo "  content view versions on disk:"; ls $C/cv/cv-base | sed 's/^/    /'
echo "  disk cost of two versions (hardlinks):"; du -sh $C/library $C/cv/cv-base/1.0 $C/cv/cv-base/2.0 | sed 's/^/    /'
