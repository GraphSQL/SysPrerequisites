#!/bin/bash

cd `dirname $0`
source ../prettyprt

create_rpm(){
  off_repo="/etc/yum.repos.d/syspreq_build.repo"

  progress "generating .rpm file"
  echo "%_topdir $build_dir" > ~/.rpmmacros
  rpmbuild -ba "${build_dir}/SPECS/GraphSQL-syspreq.spec" 1>>"$LOG" 2>&1  

  progress "generating the GraphSQL-syspreq package"
  mkdir -p "$on_dir"
  if ! rpm -q createrepo >/dev/null 2>&1; then
    yum -y install createrepo 1>>"$LOG" 2>&1
  fi
  echo "[graphsql-local]" > $off_repo
  echo "name=GraphSQL-syspreq Local" >> $off_repo
  echo "baseurl=file://${on_dir// /%20}" >> $off_repo
  echo "gpgcheck=0" >> $off_repo
  echo "enabled=1" >> $off_repo  
  cp "${build_dir}/RPMS/x86_64"/*.rpm "$on_dir" >/dev/null 2>&1
  createrepo "$on_dir" 1>>"$LOG" 2>&1

  progress "generating the GraphSQL-syspreq package with all dependencies"
  if ! rpm -q yum-utils >/dev/null 2>&1; then
    yum -y install yum-utils 1>>"$LOG" 2>&1
  fi
  repotrack -a x86_64 -p "$off_dir" GraphSQL-syspreq 
  rm -f "$off_dir"/*.i686.rpm 
  createrepo "$off_dir" 1>>"$LOG" 2>&1

  rm -f "$off_repo"
}

create_deb(){
  apt-get update

  progress "generating .deb file"
  mkdir -p "$on_dir"
  dpkg -b "${build_dir}" "${on_dir}/GraphSQL-syspreq.deb" 1>>"$LOG" 2>&1

  progress "generating the GraphSQL-syspreq package"  
  if ! dpkg -s dpkg-dev 2>&1 | grep -q 'install ok installed'; then
    apt-get -y install dpkg-dev 1>>"$LOG" 2>&1
  fi
  newsource="deb file://${on_dir// /%20}/ ./"
  if ! cat /etc/apt/sources.list | grep "$newsource"; then
    echo "$newsource" >> /etc/apt/sources.list
  fi
  cd "$on_dir"
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
  apt-get update 
 
  progress "generating the GraphSQL-syspreq package with all dependencies"
  mkdir -p "$off_dir"   
  cd "$off_dir"
  apt-get download $(./../build/deb_download.sh)
  cp "${on_dir}/GraphSQL-syspreq.deb" "$off_dir"
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz 
  apt-get update

  sed -i '$ d' /etc/apt/sources.list
}


if [[ $EUID -ne 0 ]]; then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi
LOG="${PWD}/build.log"
if [ -f "$LOG" ]; then
  echo '' > "$LOG"
fi 
OS=$(get_os)

on_dir="${PWD}/online_repo"
off_dir="${PWD}/../offline_repo"
if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
  build_dir="${PWD}/rpmbuild"
  create_rpm
else
  build_dir="${PWD}/dpkgbuild"
  create_deb
fi
cd "$off_dir/../"
tar czf "offline_repo.tar.gz" "offline_repo/"
rm -rf "$off_dir"
rm -rf "$on_dir"
progress "created deb repository successfully"
  
