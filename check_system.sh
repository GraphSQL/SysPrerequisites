#!/bin/bash

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

warn()
{
  echo "${bldred}Warning: $* $txtrst"
}

checkList()
{
  echo
  echo ${bldblu}** checking "$*" ... $txtrst
}

collectList()
{
  echo
  echo "${txtbld}--$*-- $txtrst"
}

found()
{
  echo "${bldgre}$* found $txtrst"
}

if [[ $EUID -ne 0 ]]
then
  warn "Please log in as root, or 'sudo' to run the command if you have sudo privileges."
  exit 1
fi

if which dpkg > /dev/null 2>&1
then
  OS=UBUNTU
  PKGMGR=`which dpkg`
  PKGMGROPT='-l'
  CMDOPT='-S'
elif which rpm >/dev/null 2>&1 
then
  OS=RHEL
  PKGMGR=`which rpm`
  PKGMGROPT='-q'
  CMDOPT='-qf'
else
  warn "Unsupported OS."
  exit 1
fi

GSQL_USER=${1:-root}

report="./report_`hostname`.txt"
(
  echo "==== Checking System Configuration ===="
  checkList "required system libraries"
  LIBS="glibc libgcc libstdc++ zlib"
  LIBS_MISSING=''
  for lib in $LIBS
  do
    if [ $OS = 'RHEL' ]
    then
      if $PKGMGR $PKGMGROPT $lib > /dev/null 2>&1
      then
        pkglib=$( $PKGMGR $PKGMGROPT $lib)
        echo "${bldgre}\"$lib\" found in $pkglib $txtrst"
      else
        warn "\"$lib\" NOT FOUND"
        LIBS_MISSING="$LIBS_MISSING $lib"
      fi
    else 
      if $PKGMGR $PKGMGROPT ${lib}*|grep $lib > /dev/null 2>&1
      then
        pkglib=$( $PKGMGR $PKGMGROPT ${lib}*|grep $lib |head -1|awk '{print $2}')
        echo "${bldgre}\"$lib\" found in $pkglib $txtrst"
      else
        warn "\"$lib\" NOT FOUND"
        LIBS_MISSING="$LIBS_MISSING $lib"
      fi
    fi
  done

  checkList "required commands"
  CMDS="java unzip scp"
  CMDS_MISSING=''
  for cmd in $CMDS
  do
    if which $cmd >/dev/null 2>&1
    then
      if [ "j$cmd" = 'jjava' ]
      then
        found "$(java -version 2>&1|head -1)"
        JV=$(java -version 2>&1|head -1 | grep -oP "[12]\.\d\d*")
        if [ "$JV" = "1.5" -o "$JV" = "1.6" ]
        then
          CMDS_MISSING="$CMDS_MISSING ${cmd}>=1.7"
          warn "Java >= 1.7 required"
        fi
      else
        if [ $OS = 'RHEL' ]
        then 
          pkg=$( $PKGMGR $CMDOPT "$(which $cmd)")
          echo "${bldgre}$cmd found in $pkg $txtrst"
        else
          pkg=$( $PKGMGR $CMDOPT "$(which $cmd)" |awk 'BEGIN { FS = ":" } ; { print $1 }') 
          pkgVer=$( $PKGMGR $PKGMGROPT $pkg|grep $pkg |head -1|awk '{print $3}')
          echo "${bldgre}\"$cmd\" version $pkgVer $txtrst"
        fi
      fi
    else
      warn "$cmd NOT FOUND"
      CMDS_MISSING="$CMDS_MISSING $cmd"
    fi
  done  

  if [ "l$LIBS_MISSING" != 'l' -o "c$CMDS_MISSING" != 'c' ]
  then
    if [ "l$LIBS_MISSING" != 'l' ]
    then
      echo
      warn " Missing system libaries: $LIBS_MISSING"
    fi

    if [ "l$CMDS_MISSING" != 'l' ]
    then
      echo
      warn " Missing comand(s): $CMDS_MISSING"
    fi
    
    warn "Please install all missing items and run the check again."
    exit 2
  fi

  # not required, but good to know  
  checkList  "optional commands"
  CMDS="python lsof make gcc g++"
  for cmd in $CMDS
  do
    if which $cmd >/dev/null 2>&1
    then
      if [ $cmd = 'python' ]
      then
        found "$(python -V 2>&1)"
      else
        if [ $OS = 'RHEL' ]
        then 
          pkg=$( $PKGMGR $CMDOPT "$(which $cmd)")
          echo "${bldgre}$cmd found in $pkg $txtrst"
        else
          pkg=$( $PKGMGR $CMDOPT "$(which $cmd)" |awk 'BEGIN { FS = ":" } ; { print $1 }') 
          pkgVer=$( $PKGMGR $PKGMGROPT $pkg|grep $pkg |head -1|awk '{print $3}')
          echo "${bldgre}\"$cmd\" version $pkgVer $txtrst"
        fi
      fi
    else
      warn "$cmd: NOT FOUND"
    fi
  done 

  checkList  "required python modules"
  PyMod="Crypto ecdsa paramiko nose yaml setuptools fabric psutil kazoo elasticsearch requests"
  for pymod in $PyMod
  do
    if python -c "import $pymod" >/dev/null 2>&1
    then
      found "$pymod"
    else
      warn "$pymod: NOT FOUND"
    fi
  done

  checkList  "System Locale"
  allowedLocale='en_US.UTF-8'
  if ! locale | grep -q "$allowedLocale"
  then
    warn "Locale $allowedLocale is required."
    exit 3
  else
    found "en_US.UTF-8"
  fi

  checkList "NTP service"
    if pgrep ntpd >/dev/null 2>&1
    then
      echo "${bldgre}NTP service is running. $txtrst"
    else 
      warn  "NTP service is NOT running."
    fi

  checkList "Redis service"
    if pgrep redis >/dev/null 2>&1
    then
      echo "${bldgre}Redis service is running. $txtrst"
    else 
      warn  "Redis service is NOT running."
    fi

  checkList  "Internet Connection"
    #ping -c 2 -W 3 www.github.com | grep 'of data\|transmitted\|avg'
    if ping -c 1 -W 2 www.github.com > /dev/null 2>&1
    then
      echo "${bldgre}Internet connection -- OK $txtrst"
    else
      warn "No Internet connection"
    fi

  checkList "CRON service"
  /bin/echo "This may take up to one minute"
    if [ $OS = 'UBUNTU' ]
    then
      cronFile="/var/spool/cron/crontabs/$GSQL_USER" 
    else
      cronFile="/var/spool/cron/$GSQL_USER" 
    fi

    cronFileExists='N'
    if [ -f $cronFile ]
    then
      cronFileExists='Y'
    fi

    TMPFILE="/tmp/cront-test.$$"
    echo "* * * * * echo graphsql_testing > $TMPFILE" >> $cronFile

    if [ $cronFileExists = 'N' ]
    then
      chown $GSQL_USER $cronFile
      chmod 600 $cronFile
    fi

    counter=60
    while [ $counter -gt 0 ]
    do 
      [ -f $TMPFILE ] && break
      sleep 2
      let "counter -= 2"
    done

    if [ $cronFileExists = 'Y' ]
      then
      sed -i -e '/graphsql_testing/d' $cronFile
    else
      rm -f $cronFile
    fi

    if [ -f $TMPFILE ]
    then
      echo "${bldgre}CRON service is running. $txtrst"
      rm -f $TMPFILE
    else 
      warn "CRON service is NOT working."
    fi

  /bin/echo -e "\n==== Collecting System information ===="
  collectList "Host name"
    hostname
  collectList "Supported locale"
    locale
  collectList "Architecture"
    uname -a
  collectList "OS family"

  if [ $OS = 'RHEL' ]
  then
    cat /etc/redhat-release
  else
    grep VERSION= /etc/os-release
  fi


  collectList "Firewall"
  if [ $OS = 'RHEL' ]
  then
      if which firewall-cmd >/dev/null 2>&1
      then
        echo -n Status: 
        firewall-cmd --state
        if [ -f /etc/sysconfig/iptables ]
        then
          echo Rules:
          egrep -v '^#' /etc/sysconfig/iptables
        fi
      else
        iptables -L
      fi
  fi

    if [ $OS = 'UBUNTU' ]
    then
        ufw status verbose
        egrep -v '^#' /lib/ufw/user.rules
    fi

  if grep -v '^#' /etc/hosts.deny|grep -v '^ *$' > /dev/null 2>&1
  then
    collectList "TCP wrapper"
    egrep -v '^#' /etc/hosts.allow
  fi

  collectList "SSH port"
    grep 'Port ' /etc/ssh/sshd_config

  collectList "CPU"
    lscpu
    grep flags /proc/cpuinfo|head -1
  collectList "Memory"
    grep Mem /proc/meminfo

  collectList "Disk space"
    df -h

  if which hdparm >/dev/null 2>&1
  then
    disks=$(dmesg | grep -Po '\[.d.\]' | sed -e 's/\[//' -e 's/\]//'|sort|uniq)
    if [ "D$disks" != "D" ]
    then
      collectList "Disk speed"
      for disk in $disks
      do
        hdparm -ITt /dev/$disk
        hdparm -Tt --direct /dev/$disk | sed -e '1,2d'
      done
    fi
  fi

  collectList "Network adapter and IP address"
    if which ifconfig >/dev/null 2>&1
    then
      ifconfig -a|grep -v '127\|lo' | grep -B1 'inet '
    else
      ip addr|grep -B1 'inet '
    fi


) 2>&1 | tee $report 
  /bin/echo
  /bin/echo -e "Report \"$report\" is generated."
