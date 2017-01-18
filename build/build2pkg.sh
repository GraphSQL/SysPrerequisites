#!/bin/bash

cleanup(){
  rm -rf "$on_dir"
  rm -rf "$off_dir"
  rm -f "$off_repo"
  if [[ $OS == "UBUNTU" ]] && cat /etc/apt/sources.list | grep "$newsource"; then
    sed -i '$ d' /etc/apt/sources.list      
  fi
}

cd `dirname $0`
source ../prettyprt
trap cleanup INT EXIT TERM

create_rpm(){
  wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo

  progress "generating .rpm file"
  if ! rpm -q rpm-build >/dev/null 2>&1; then
    yum -y install rpm-build 1>>"$LOG" 2>&1
  fi
  echo "%_topdir $build_dir" > ~/.rpmmacros
  rpmbuild -ba "${build_dir}/SPECS/${pkg_name}.spec" 1>>"$LOG" 2>&1  

  progress "generating the ${pkg_name} package"
  mkdir -p "$on_dir"
  if ! rpm -q createrepo >/dev/null 2>&1; then
    yum -y install createrepo 1>>"$LOG" 2>&1
  fi
  echo "[${pkg_name}-build]" > $off_repo
  echo "name=${pkg_name}-build" >> $off_repo
  echo "baseurl=file://${on_dir// /%20}" >> $off_repo
  echo "gpgcheck=0" >> $off_repo
  echo "enabled=1" >> $off_repo  
  cp "${build_dir}/RPMS/x86_64"/*.rpm "$on_dir" >/dev/null 2>&1
  createrepo "$on_dir" 1>>"$LOG" 2>&1

  progress "generating the ${pkg_name} package with all dependencies"
  if ! rpm -q yum-utils >/dev/null 2>&1; then
    yum -y install yum-utils 1>>"$LOG" 2>&1
  fi
  repotrack -a x86_64 -p "$off_dir" "${pkg_name}"
  rm -f "$off_dir"/*.i686.rpm 
  createrepo "$off_dir" 1>>"$LOG" 2>&1

  rm -f "$off_repo"
}

download_deb(){
  if ! dpkg -s apt-rdepends 2>&1 | grep -q 'install ok installed'; then
    apt-get -y install apt-rdepends 1>>"$LOG" 2>&1
  fi
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


create_deb(){
  apt-get update

  progress "generating .deb file"
  mkdir -p "$on_dir"
  dpkg -b "${build_dir}" "${on_dir}/${pkg_name}.deb" 1>>"$LOG" 2>&1

  progress "generating the ${pkg_name} package"  
  if ! dpkg -s dpkg-dev 2>&1 | grep -q 'install ok installed'; then
    apt-get -y install dpkg-dev 1>>"$LOG" 2>&1
  fi
  echo "$newsource" >> /etc/apt/sources.list
  cd "$on_dir"
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
  apt-get update 
 
  progress "generating the ${pkg_name} package with all dependencies"
  mkdir -p "$off_dir"   
  cd "$off_dir"
  apt-get download $(download_deb)
  cp "${on_dir}/${pkg_name}.deb" "$off_dir"
  dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz 
  apt-get update

  sed -i '$ d' /etc/apt/sources.list
}


if [[ $EUID -ne 0 ]]; then
  warn "Sudo or root rights are requqired to install prerequsites for ${pkg_name} software."
  exit 1
fi
LOG="${PWD}/build.log"
if [ -f "$LOG" ]; then
  echo '' > "$LOG"
fi 
OS=$(get_os)

if [ "Q$OS" = "QRHEL" ]; then
  if ! rpm -q tar >/dev/null 2>&1; then
    yum -y install tar 1>>"$LOG" 2>&1
  fi
  name="rpm"
else 
  if ! dpkg -s tar 2>&1 | grep -q 'install ok installed'; then
    apt-get -y install tar 1>>"$LOG" 2>&1
  fi
  name="deb"
fi
build_dir="${PWD}/${name}_build"
on_dir="${PWD}/../${name}_online_repo"
off_dir="${PWD}/../${name}_offline_repo"
if [ "Q$OS" = "QRHEL" ]; then  # Redhat or CentOS
  off_repo="/etc/yum.repos.d/${pkg_name}_build.repo"
  create_rpm
else
  newsource="deb file://${on_dir// /%20}/ ./"
  create_deb
fi

cd "$off_dir/../"
tar czf "${name}_offline_repo.tar.gz" "${name}_offline_repo/"
cd "$on_dir/../"
tar czf "${name}_online_repo.tar.gz" "${name}_online_repo/"
rm -rf "$off_dir"
rm -rf "$on_dir"
progress "created repository successfully"
  
