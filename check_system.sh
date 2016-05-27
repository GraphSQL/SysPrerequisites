#!/bin/bash

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

help()
{
  echo "`basename $0` [-h] [-u <user>] [-r]" 
  echo "  -h  --  show this message"
  echo "  -r  --  generate system report"
  echo "  -u  --  GraphSQL user"
  exit 0
}

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
  echo "== $* == "
}

found()
{
  echo "${bldgre}$* found $txtrst"
}

check_os()
{
  if which dpkg > /dev/null 2>&1
  then
	  OS=UBUNTU
	  PKGMGR=`which dpkg`
	  PKGMGROPT='-l'
	  CMDOPT='-S'
    if [ -f /etc/os-release ]
    then
      cat /etc/os-release
    else
      lsb_release -a
    fi
	elif which rpm >/dev/null 2>&1 
	then
	  OS=RHEL
	  PKGMGR=`which rpm`
	  PKGMGROPT='-q'
	  CMDOPT='-qf'
    cat /etc/redhat-release
	else
	  warn "Unsupported OS."
	  exit 1
	fi
}


##### System check functions #####

  check_system_library()
  {
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
  }

  check_required_commands()
  {
	  CMDS="java unzip scp python lsof make gcc g++"
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
        elif [ "p$cmd" = 'ppython' ]
        then
          found "$(python -V 2>&1)"
	      else
	        if [ "$OS" = 'RHEL' ]
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
  }

  check_python_modules()
  {
	  PyMod="Crypto ecdsa paramiko nose yaml setuptools fabric psutil kazoo elasticsearch requests flask zmq"
	  for pymod in $PyMod
	  do
	    if [ "$pymod" = "Crypto" ]
	    then
	      testCmd="from $pymod import Random"
	    else
	      testCmd="import $pymod"
	    fi
	
	    if python -c "$testCmd" >/dev/null 2>&1
	    then
	      found "$pymod"
	    else
	      warn "$pymod: NOT FOUND"
	    fi
	  done
  }

  check_system_locale()
  {
	  allowedLocale='en_US.UTF-8'
	  if ! locale | grep -q "$allowedLocale"
	  then
	    warn "Locale $allowedLocale is required."
	    exit 3
	  else
	    found "en_US.UTF-8"
	  fi
  }

  check_ntp_service()
  {
    if pgrep ntpd >/dev/null 2>&1
    then
      echo "${bldgre}NTP service is running. $txtrst"
    else 
      warn  "NTP service is NOT running."
    fi
  }

  check_redis_service()
  {
    if pgrep redis >/dev/null 2>&1
    then
      echo "${bldgre}Redis service is running. $txtrst"
    else 
      warn  "Redis service is NOT running."
    fi
  }

  check_ulimit()
  {
    declare -a service
    declare -a arg
    declare -a expect

    users=''
    if [ "$GSQL_USER" = "root" ]
    then
      for IUM in `find /home -maxdepth 2 -type d -name .gium`
      do
        homePath=`dirname $IUM`
        usr=${homePath##*/}
        users="$users $usr"
      done
    else
      users=$GSQL_USER
    fi
  
    #service=("max user processes" "open files" "core file size")
    #arg=('-u' '-n' '-c')
    #expect=(102400 1000000 2000000)

    service=("max user processes" "open files" )
    arg=('-u' '-n' )
    expect=(102400 1000000 )

    for usr in $users
    do
      echo "User $usr":
      for i in $(seq 0 $((${#service[@]} - 1)))
      do
        size=$(su - $usr -c "ulimit ${arg[$i]}")
        if [ "$size" -ge ${expect[$i]} ]
        then
          echo "${bldgre} ${service[$i]}(ulimit ${arg[$i]}) = $size -- OK $txtrst"
        else
          warn "${service[$i]}(ulimit ${arg[$i]})  = $size. Expected ${expect[$i]}."
        fi
      done
    done
	}

  check_internet_connection()
  {
    #ping -c 2 -W 3 www.github.com | grep 'of data\|transmitted\|avg'
    if ping -c 1 -W 2 www.github.com > /dev/null 2>&1
    then
      echo "${bldgre}Internet connection -- OK $txtrst"
    else
      warn "No Internet connection"
    fi
  }

  check_cron_service()
  {
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
  }

  check_firewall()
  {
	  if [ "$OS" = 'RHEL' ]
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
	
	    if [ "$OS" = 'UBUNTU' ]
	    then
	        ufw status verbose
	        egrep -v '^#' /lib/ufw/user.rules
	    fi
	}

  check_tcpwrapper()
  {
	  if grep -v '^#' /etc/hosts.deny|grep -v '^ *$' > /dev/null 2>&1
	  then
	    egrep -v '^#' /etc/hosts.allow
	  fi
	
  }

  check_sshd(){
	  grep 'Port ' /etc/ssh/sshd_config
    if which netstat >/dev/null 2>&1
    then
      netstat -tlnp|grep sshd
    else
      netstat -tlnp|grep sshd
    fi
  }

  check_selinux(){
    if which getenforce >/dev/null 2>&1
    then
      getenforce
    fi
  }

  check_diskfree(){
    df -Ph | grep '^/dev\|^File'
  }

  check_disk_speed()
  {
	  if which hdparm >/dev/null 2>&1
	  then
	    disks=$(dmesg | grep -Po '\[.d.\]' | sed -e 's/\[//' -e 's/\]//'|sort|uniq)
	    if [ "D$disks" != "D" ]
	    then
	      for disk in $disks
	      do
	        hdparm -ITt /dev/$disk
	        hdparm -Tt --direct /dev/$disk | sed -e '1,2d'
	      done
	    fi
	  fi
  }
	
  ## assemble checks
	check_system()
  {
    declare -a checkNames
    declare -a checkFunctions
    checkNames=("OS" "Required system libraries" "Required commands" "Required python modules" \
                "System Locale" "NTP service" "Redis service" "Ulimit" \
                "Firewall" "Internet Connection" "TCP Wrapper" "SSHD" \
                "SeLinux" "Free Disk Space" "Disk Performance" "CRON service"
               )

    checkFunctions=("check_os" "check_system_library" "check_required_commands" "check_python_modules" \
                    "check_system_locale" "check_ntp_service" "check_redis_service" "check_ulimit" \
	                  "check_firewall" "check_internet_connection" "check_tcpwrapper" "check_sshd" \
	                  "check_selinux" "check_diskfree" "check_disk_speed" "check_cron_service"
                  )

	  echo "==== Checking System Configuration ===="
    for i in $(seq 0 $((${#checkNames[@]} - 1)))
    do
	    checkList  "${checkNames[$i]}"
      eval ${checkFunctions[$i]}
    done
  }

generate_report()
{
  echo -e "\n==== System information ===="

  collectList "Host name"
    hostname

  collectList "OS family"
  if which dpkg > /dev/null 2>&1
  then
    OS=UBUNTU
    #lsb_release -a
    grep VERSION= /etc/os-release
  elif which rpm >/dev/null 2>&1
  then
    OS=RHEL
    cat /etc/redhat-release
  else
    warn "Unsupported OS."
  fi

  collectList "Supported locale"
    locale
  collectList "Architecture"
    uname -a

  collectList "Motherboard"
    if which dmidecode >/dev/null 2>&1
    then
      dmidecode -s system-product-name
      dmidecode -t 2|tail -n +5
    fi

    echo
    if which lspci >/dev/null 2>&1
    then
      lspci  
    fi

  collectList "CPU"
    lscpu
    grep flags /proc/cpuinfo|head -1

  collectList "Memory"
    grep Mem /proc/meminfo

  collectList "Disk partitions and free space"
    [ -f /proc/partitions ] && cat /proc/partitions
    echo
    df -h

  if [ -f /etc/mtab ]
  then
    collectList "File Systems"
    if which tune2fs >/dev/null 2>&1
    then
      extFS=$(grep ext /etc/mtab | awk '{print $1}' | grep dev)
      for fs in `echo $extFS`
      do
        tune2fs -l $fs
        echo
      done

      xFS=$(grep xfs /etc/mtab | awk '{print $1}' | grep dev)
      for fs in `echo $xFS`
      do
        xfs_info $fs
        echo
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
}


## Main ##
GSQL_USER="root"
run_report='n'
while getopts ":hru:" opt; do
  case $opt in
    h|H)
      help
      ;;
    r|R)
      run_report='y'
      ;;
    u|U)
      GSQL_USER=$OPTARG
      ;;
  esac
done

if [[ $EUID -ne 0 ]]
then
  warn "Please log in as root, or 'sudo' to run the command if you have sudo privileges."
  exit 1
fi


if [ "$run_report" = 'y' ]
then
  report="./report-`hostname`-`date "+%Y%m%d"`.txt"
  generate_report  | tee $report 
  echo
  echo -e "Report \"$report\" is generated."
else
  check_system
fi
