#! /bin/bash

pkgs=$(apt-rdepends GraphSQL-syspreq|grep -v "^ ")
t_pkgs=""
for pkg in $pkgs; do
  $(aptitude show $pkg 2>/dev/null | grep "not a real package"  >/dev/null 2>&1)
  if [[ $pkg != "GraphSQL-syspreq" && $? -eq 1 ]]
  then t_pkgs="$t_pkgs $pkg"
  fi
done

echo $t_pkgs
