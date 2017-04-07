#!/bin/bash

# Copyright (c) 2016-2017, GraphSQL Inc.
# All rights reserved.
#
# Project: System Prerequisite
# Authors: Yun Peng, Justin Li
#

install_pkg(){
  pkg=$1
  if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
      yum -y install $pkg 1>>"$LOG" 2>&1
  else
      apt-get -y install $pkg 1>>"$LOG" 2>&1
  fi
}


create_rpm(){
  progress "generating .rpm file"
  install_pkg 'rpm-build'
  if [ "$os_version" -lt 7 ]; then
    install_pkg 'wget'
    wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
    wget https://dev.mysql.com/get/mysql57-community-release-el6-9.noarch.rpm
  else
    wget https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
  fi
  rpm -ivh mysql57-community-release*.rpm
  rm -rf mysql57-community-release*
  sed -i '27s/enabled=0/enabled=1/' /etc/yum.repos.d/mysql-community.repo
  sed -i '34s/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo

  echo "%_topdir $build_dir" > ~/.rpmmacros
  rpmbuild -ba "${build_dir}/SPECS/${pkg_name}_${os_version}.spec" 1>>"$LOG" 2>&1  

  progress "generating the ${pkg_name} package"
  mkdir -p "$on_dir"
  install_pkg 'createrepo'
  echo "[${pkg_name}-build]" > $off_repo
  echo "name=${pkg_name}-build" >> $off_repo
  echo "baseurl=file://${on_dir// /%20}" >> $off_repo
  echo "gpgcheck=0" >> $off_repo
  echo "enabled=1" >> $off_repo  
  cp "${build_dir}/RPMS/x86_64"/*.rpm "$on_dir" >/dev/null 2>&1
  createrepo "$on_dir" 1>>"$LOG" 2>&1

  progress "generating the ${pkg_name} package with all dependencies"
  install_pkg 'yum-utils'
  mkdir -p "$off_dir"
  cp "${build_dir}/RPMS/x86_64"/*.rpm "$off_dir" >/dev/null 2>&1
  repotrack -a x86_64 -p "$off_dir" "${pkg_name}"
  rm -f "$off_dir"/*.i686.rpm 
  createrepo "$off_dir" 1>>"$LOG" 2>&1

  rm -f "$off_repo"
}

download_deb(){
  install_pkg 'apt-rdepends'
  install_pkg 'aptitude'
  pkgs=$(apt-rdepends ${pkg_name} | grep -v "^ ")
  t_pkgs=""
  for pkg in $pkgs; do
    $(aptitude show $pkg 2>/dev/null | grep "not a real package"  >/dev/null 2>&1)
    if [[ "$pkg" != "$pkg_name" && $? -eq 1 ]]
    then t_pkgs="$t_pkgs $pkg"
    fi
  done
  echo $t_pkgs
}

prepare_repo_key_file(){
  key=$(sudo gpg --list-keys | grep "pub  " | cut -d '/' -f2 | cut -d ' ' -f1)
  sudo gpg --output ${key_file} --armor --export ${key}
}

create_deb(){
  apt-get  update

  progress "generating .deb file"
  mkdir -p "$on_dir"
  dpkg -b "${build_dir}" "${on_dir}/${pkg_name}.deb" 1>>"$LOG" 2>&1

  progress "generating the ${pkg_name} package"  
  install_pkg 'dpkg-dev'
  echo "$newsource" >> /etc/apt/sources.list
  cd "$on_dir"

  apt-get install -y dpkg-dev gzip
  if [ ${os_version} -ge 16 ]; then
    apt-ftparchive packages . > Packages
    gzip -c Packages > Packages.gz

    apt-ftparchive release . > Release
    gpg --clearsign -o InRelease Release
    gpg -abs -o Release.gpg Release

    # prepare the public_key file
    prepare_repo_key_file
    cat ${key_file} | sudo apt-key add -
  else
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
  fi
  apt-get  update 
 
  progress "generating the ${pkg_name} package with all dependencies"
  mkdir -p "$off_dir"   
  cd "$off_dir"

  if [ ${os_version} -ge 16 ]; then
    setfacl -m u:_apt:rwx "${off_dir}"
  fi
  apt-get download $(download_deb)
  cp "${on_dir}/${pkg_name}.deb" "$off_dir"
  if [ ${os_version} -ge 16 ]; then
    apt-ftparchive packages . > Packages
    gzip -c Packages > Packages.gz
  else
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz 
  fi
  apt-get update

  sed -i '$ d' /etc/apt/sources.list
}

cleanup(){
  rm -rf "$on_dir" "$off_dir" "$off_repo"
  if [[ $OS == "UBUNTU" ]] && cat /etc/apt/sources.list | grep "$newsource"; then
    sed -i '$ d' /etc/apt/sources.list
  fi
}


## Main ##
if [[ $EUID -ne 0 ]]; then
  warn "Sudo or root rights are requqired to install prerequsites for ${pkg_name} software."
  exit 1
fi

cd `dirname $0`
source ../prettyprt
trap cleanup INT EXIT TERM

LOG="${PWD}/build.log"
if [ -f "$LOG" ]; then
  echo '' > "$LOG"
fi 

OSG=$(get_os)
OS=$(echo $OSG | cut -d' ' -f1)
os_version=$(echo $OSG | cut -d' ' -f2)

if [ "Q$OS" = "QRHEL" ]; then
  name="centos"
else 
  name="ubuntu"
fi
install_pkg 'tar'

build_dir="${PWD}/${name}_build"
on_dir_name="${name}_${os_version}"
off_dir_name="${name}_${os_version}_offline"
on_dir="${PWD}/../${on_dir_name}"
off_dir="${PWD}/../${off_dir_name}"
key_file="${on_dir}/graphsql_ubuntu1604_key"

if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
  off_repo="/etc/yum.repos.d/${pkg_name}_build.repo"
  create_rpm
else
  newsource="deb file://${on_dir// /%20}/ ./"
  create_deb
fi

cp tsar.tar.gz "$off_dir/"
cd "$off_dir/../"
tar czf "${off_dir_name}.tar.gz" "${off_dir_name}/"
cd "$on_dir/../"
tar czf "${on_dir_name}.tar.gz" "${on_dir_name}/"
rm -rf "$off_dir" "$on_dir"
progress "created repository successfully"
  
