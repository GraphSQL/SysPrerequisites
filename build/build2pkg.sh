#!/bin/bash

cd `dirname $0`

source ../prettyprt

create_rpm(){
  progress "generating .rpm file"
  echo "%_topdir $rpm_build_dir" > ~/.rpmmacros
  rpmbuild -ba "${rpm_build_dir}/SPECS/GraphSQL-syspreq.spec" 1>>"$LOG" 2>&1  

  progress "generating the GraphSQL-syspreq package"
  mkdir -p "$rpm_repo_dir"
  off_repo="/etc/yum.repos.d/syspreq_build.repo" 
  if ! rpm -q createrepo >/dev/null 2>&1; then
    yum -y install createrepo 1>>"$LOG" 2>&1
  fi
  echo "[graphsql-local]" > $off_repo
  echo "name=GraphSQL-syspreq Local" >> $off_repo
  echo "baseurl=file://${rpm_repo_dir// /%20}" >> $off_repo
  echo "gpgcheck=0" >> $off_repo
  echo "enabled=1" >> $off_repo  
  cp "${rpm_build_dir}/RPMS/x86_64"/*.rpm "$rpm_repo_dir" >/dev/null 2>&1
  createrepo "$rpm_repo_dir" 1>>"$LOG" 2>&1

  progress "generating the GraphSQL-syspreq package with all dependencies"
  if ! rpm -q yum-utils >/dev/null 2>&1; then
    yum -y install yum-utils 1>>"$LOG" 2>&1
  fi
  total_dir="${rpm_repo_dir}/../rpm_offline_repo"
  if [ -d "$total_dir" ]; then
    rm -rf "$total_dir" 
  fi
  repotrack -a x86_64 -p "$total_dir" GraphSQL-syspreq 
  rm -f "$total_dir"/*.i686.rpm 
  createrepo "$total_dir" 1>>"$LOG" 2>&1

  rm -rf "$rpm_repo_dir"
  rm -f "$off_repo"
}

create_deb(){
  progress "generating .deb file"
  mkdir -p "$deb_repo_dir"
  dpkg -b "${deb_build_dir}" "${deb_repo_dir}/GraphSQL-syspreq.deb" 1>>"$LOG" 2>&1

  progress "generating the GraphSQL-syspreq package"  
  if ! dpkg -s dpkg-dev 2>&1 | grep -q 'install ok installed'; then
    apt-get -y install dpkg-dev 1>>"$LOG" 2>&1
  fi
  newsource="deb file://${deb_repo_dir// /%20}/ ./"
  if ! cat /etc/apt/sources.list | grep "$newsource"; then
    echo "$newsource" >> /etc/apt/sources.list
  fi
  cd "$deb_repo_dir"
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
  apt-get update 
 
  progress "generating the GraphSQL-syspreq package with all dependencies"
  total_dir="${deb_repo_dir}/../deb_offline_repo"
  if [ -d "$total_dir" ]; then
    rm -rf "$total_dir"
  fi  
  mkdir "$total_dir"   
  cd "$total_dir"
  apt-get download $(./../deb_download.sh)
  cp "${deb_repo_dir}/GraphSQL-syspreq.deb" "$total_dir"
  dpkg-scanpackages . /dev/null 1>>"$LOG" 2>&1 | gzip -9c > Packages.gz 1>>"$LOG" 2>&1
  apt-get update
  rm -rf "$deb_repo_dir"
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
if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
  rpm_repo_dir="${PWD}/rpm_online_repo"
  rpm_build_dir="${PWD}/rpmbuild"
  create_rpm
  progress "created rpm repository successfully"
else
  deb_repo_dir="${PWD}/deb_online_repo"
  deb_build_dir="${PWD}/dpkgbuild"
  create_deb
  progress "created deb repository successfully"
fi
  
