Name:           lab-hello
Version:        1.1
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
* Mon Sep 15 2026 lab <lab@localhost> - 1.1-1
- second build, closes LAB-2026:0001
