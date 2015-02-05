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
  echo "=== Checking Prerequisites ==="
  echo "**checking required system libraries ..."
  LIBS="glibc libgcc libstdc++ zlib"
  LIBS_MISSING=''
  for lib in $LIBS
  do
    if $PKGMGR $PKGMGROPT $lib > /dev/null 2>&1
    then
      pkglib=$( $PKGMGR $PKGMGROPT $lib)
      echo "  \"$lib\" found in $pkglib"
    else
      echo "  \"$lib\" not found"
      LIBS_MISSING="$LIBS_MISSING $lib"
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
        JV=$(java -version 2>&1|head -1 | grep -oP "[12]\.\d\d*")
        if [ "$JV" = "1.5" -o "$JV" = "1.6" ]
        then
          CMDS_MISSING="$CMDS_MISSING ${cmd}>=1.7"
          echo "  Java >= 1.7 required"
        fi
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
      echo
      echo "!! Missing system libaries: $LIBS_MISSING"
    fi

    if [ "l$CMDS_MISSING" != 'l' ]
    then
      echo
      echo "!! Missing comand(s): $CMDS_MISSING"
    fi
    
    echo "Please install all missing items and run the check again."
    exit 2
  fi

  # not required, but good to know  
  echo
  echo "**checking optional commands ..."
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

  /bin/echo -e "\n---NIC and IP:" 
    if which ifconfig >/dev/null 2>&1
    then
      ifconfig -a|grep -v '127\|lo' | grep -B1 'inet '
    else 
      ip addr|grep -B1 'inet '
    fi

  /bin/echo -e "\n---Outside Connection:"
    ping -c 3 -W 3 www.cisco.com
  /bin/echo 
  /bin/echo -e "Please review $report and send it to GraphSQL. Thank you!"
) 2>&1 | tee $report 
