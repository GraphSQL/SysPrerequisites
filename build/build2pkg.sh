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
  if [ ! -f ~/.rpmmacros ]
  then 
    echo "%_topdir /root/SysPrerequisites/rpmbuild" > ~/.rpmmacros
  fi
  cd rpmbuild
  rpmbuild -ba SPECS/GraphSQL-syspreq.spec
  
}

create_deb(){

}

OS=$(get_os)
if [ "Q$OS" = "QRHEL" ]  # Redhat or CentOS
then
  create_rpm
else
  create_deb
fi
  
