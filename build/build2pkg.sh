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
  echo "%_topdir ${PWD}/rpmbuild" > ~/.rpmmacros
  rpmbuild -ba rpmbuild/SPECS/GraphSQL-syspreq.spec 1>>$LOG 2>&1  
  cp rpmbuild/RPMS/x86_64/*.rpm* /root/ >/dev/null 2>&1 
}

create_rpm_offline_repo(){
  if [ -d $rpm_off_repo_dir ]
  then 
    rm -rf $rpm_off_repo_dir
  fi
  mkdir -p $rpm_off_repo_dir 
  if ! rpm -q createrepo >/dev/null 2>&1
  then
    yum -y install createrepo 1>>$LOG 2>&1
  fi
  cp /root/*.rpm $rpm_off_repo_dir >/dev/null 2>&1 
  createrepo $rpm_off_repo_dir 1>>$LOG 2>&1  
}


LOG="${PWD}/build.log"
OS=$(get_os)
if [ "Q$OS" = "QRHEL" ]  # Redhat or CentOS
then
  rpm_off_repo_dir="${PWD}/rpm_off_repo"
  if has_internet
  then 
    create_rpm
    create_rpm_offline_repo
    progress "created rpm repository successfully"
  elif [ -d $rpm_off_repo_dir ]
  then 
    progress "offline local repository already existed and can be used to install"
  else 
    warn "No Internet access and offline local repository"
  fi
fi
  
