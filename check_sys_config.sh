#!/bin/bash

if which dpkg > /dev/null 2>&1
then
  OS=UBUNTU
  PKGMGR=`which dpkg`
  PKGMGROPT='-S'
  CMDOPT='-S'
elif which rpm >/dev/null 2>&1 
then
  OS=RHEL
  PKGMGR=`which rpm`
  PKGMGROPT='-q'
  CMDOPT='-qf'
else
  echo "Unsupported OS."
  exit 1
fi

report="report4GraphSQL_`hostname`.txt"
(
#for cmd in gse_canonnical_loader gse_loader ids_worker redis-benchmark redis-check-aof redis-check-dump redis-cli redis-sentinel redis-server ; do  ldd $cmd ; done | sort | awk '{print $1}'|uniq | xargs locate| grep -v debug|sort | xargs rpm -qf |sort |uniq

  echo "=== Checking Prerequisites ==="
  echo "**checking required system libraries ..."
  LIBS="glibc libgcc libstdc++ zlib"
  LIBS_MISSING=''
  for lib in $LIBS
  do
    if $PKGMGR $PKGMGROPT $lib > /dev/null
    then
      echo "  $lib found"
    else
      echo "  $lib not found"
      LIBS_MISSING=$LIBS_MISSING $lib
    fi
  done

  echo
  echo "**checking required commands ..."
  CMDS="java lsof unzip scp"
  CMDS_MISSING=''
  for cmd in $CMDS
  do
    if which $cmd >/dev/null 2>&1
    then
      if [ "j$cmd" = 'jjava' ]
      then
        echo "  $(java -version 2>&1|head -1) found"
      else
        pkg=$( $PKGMGR $CMDOPT "$(which $cmd)")
        echo "  $cmd found in $pkg"
      fi
    else
      echo "  $cmd not found"
      CMDS_MISSING="$CMDS_MISSING $cmd"
    fi
  done  

  if [ "l$LIBS_MISSING" != 'l' -o "c$CMDS_MISSING" != 'c' ]
  then
    if [ "l$LIBS_MISSING" != 'l' ]
    then
      echo "The following system libaries are missing: $LIBS_MISSING"
    fi

    if [ "l$CMDS_MISSING" != 'l' ]
    then
      echo "The following comands are missing: $CMDS_MISSING"
    fi
    
    echo "Please install the missing items above and run test check again"
    exit 2
  fi

  # not required, but good to know  
  CMDS="python ip netstat make gcc g++"
  for cmd in $CMDS
  do
    if which $cmd >/dev/null 2>&1
    then
      if [ $cmd = 'python' ]
      then
        echo "  $(python -V 2>&1) found"
      else
        pkg=$( $PKGMGR $CMDOPT $(which $cmd))
        echo "  $cmd found in $pkg"
      fi
    else
      echo "  $cmd not found"
    fi
  done 

  /bin/echo -e "\n= Gathering System information ="
  /bin/echo -e "\n---Host name: " `hostname`
  /bin/echo -e "\n---Arch:" `uname -a`

  if [ $OS = 'RHEL' ]
  then
    /bin/echo -e "\n---OS Family: `cat /etc/redhat-release`"
  else
    /bin/echo -e "\n---OS Family: `grep VERSION= /etc/os-release`"
  fi

  /bin/echo -e "\n---CPU:" 
    lscpu
  /bin/echo -e "\n---Memory:" 
    grep Mem /proc/meminfo 

  /bin/echo -e "\n---Disk space:" 
    df -h

  /bin/echo -e "\n---NIC and IP" 
    if which ifconfig >/dev/null 2>&1
    then
      ifconfig -a|grep -v '127\|lo' | grep -B1 'inet '
    else 
      ip addr|grep -B1 'inet '
    fi

  /bin/echo -e "\n---Outside Connection"
    ping -c 3 -W 3 www.cisco.com
  /bin/echo 
  /bin/echo -e "Please review $report and send it to GraphSQL. Thank you!"
) 2>&1 | tee $report 
