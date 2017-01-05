txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

warn(){
  echo "${bldred}Warning: $* $txtrst" | tee -a $LOG
}

notice(){
  echo "${bldblu}$* $txtrst" | tee -a $LOG
}

progress(){
  echo "${bldgre}*** $* ...$txtrst" | tee -a $LOG
}

has_internet(){
  ping -c2 -i0.5 -W1 -q www.github.com >/dev/null 2>&1
  return $?
}

get_os(){
  if which apt-get > /dev/null 2>&1
  then
    os_version=$(lsb_release  -r | awk '{print $2}' | cut -d. -f1)
    if [ "$os_version" -lt 12 ]
    then
      warn "Unsupported OS. Please upgrade to Ubuntu 12.x or above."
      exit 2
    else
      echo UBUNTU
    fi
  elif which yum >/dev/null 2>&1
  then
    os_version=$(rpm -qa | grep 'kernel-' | head -1 |grep -o .'el[0-9]'. | grep -o '[0-9]') 
    if [ "$os_version" -lt 6 ]
    then
      warn "Unsupported OS. Please upgrade to RHEL or CentOS 6.x or above."
      exit 2
    else
      echo RHEL
    fi
  else
    warn "Unknown OS. Please contact GraphSQL support."
    exit 2
  fi
}

create_rpm(){
  echo "%_topdir $rpm_build_dir" > ~/.rpmmacros
  rpmbuild -ba $rpm_build_dir/SPECS/GraphSQL-syspreq.spec 1>>$LOG 2>&1  
  
  if [ -d $rpm_off_repo_dir ]
  then rm -rf $rpm_off_repo_dir
  fi
  mkdir -p $rpm_off_repo_dir
  if ! rpm -q createrepo >/dev/null 2>&1
  then yum -y install createrepo 1>>$LOG 2>&1
  fi
  cp $rpm_build_dir/RPMS/x86_64/*.rpm $rpm_off_repo_dir >/dev/null 2>&1
  createrepo $rpm_off_repo_dir 1>>$LOG 2>&1
}

create_deb(){
  if [ -d $deb_off_repo_dir ]
  then rm -rf $deb_off_repo_dir
  fi
  mkdir -p $deb_off_repo_dir
  dpkg -b $deb_build_dir/syspreq_deb $deb_off_repo_dir/syspreq_deb.deb 1>>$LOG 2>&1
  
  if ! dpkg -s dpkg-dev 2>&1 | grep -q 'install ok installed'
  then apt-get -y install dpkg-dev 1>>$LOG 2>&1
  fi
  newsource="deb file://${deb_off_repo_dir}/ ./"
  if ! cat /etc/apt/sources.list | grep "$newsource"
  then echo $newsource >> /etc/apt/sources.list
  fi
  cd $deb_off_repo_dir
  dpkg-scanpackages . /dev/null 1>>$LOG 2>&1 | gzip -9c > Packages.gz 1>>$LOG 2>&1
  apt-get update 1>>$LOG 2>&1
}

LOG="${PWD}/build.log"
if [ -f $LOG ]
then echo '' > $LOG
fi 
OS=$(get_os)
if [ "Q$OS" = "QRHEL" ]  # Redhat or CentOS
then
  rpm_off_repo_dir="${PWD}/rpm_off_repo"
  rpm_build_dir="${PWD}/rpmbuild"
  create_rpm
  progress "created rpm repository successfully"
else
  deb_off_repo_dir="${PWD}/deb_off_repo"
  deb_build_dir="${PWD}/dpkgbuild"
  create_deb
  progress "created deb repository successfully"
fi
  
