#!/bin/sh
# After a run: the pointers, the fingerprint of the versions (must be unchanged), the host's pin,
# and the TRUE offer (after clearing the querying user's cache) — for grading, not for the agent.
limactl shell rhel-lab -- bash -c '
echo "  env:"; ls -l /srv/content/env | awk "NR>1{print \"    \" \$9 \" -> \" \$11}"
echo "  cv fingerprint: $(find /srv/content/cv -type f | sort | xargs md5sum | md5sum | cut -c1-32)"
echo "  host pinned to: $(grep -m1 baseurl /etc/yum.repos.d/lab.repo | sed "s#.*8080/##; s#/.*##")"
echo "  installed: $(rpm -q lab-hello)"
dnf -q clean all >/dev/null 2>&1; echo "  true offer on the pinned env (user cache cleared): $(dnf -q --disablerepo="*" --enablerepo="lab-tools" repoquery lab-hello | tr "\n" " ")"'
