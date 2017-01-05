#!/bin/bash

txtbld=$(tput bold)             # Bold
bldred=${txtbld}$(tput setaf 1) # red
bldgre=${txtbld}$(tput setaf 2) # green
bldblu=${txtbld}$(tput setaf 4) # blue
txtrst=$(tput sgr0)             # Reset

help()
{
  echo "`basename $0` [-h] [-d] [-r <graphsql_root_dir>] [-u <user>] [-o] [-n]"
  echo "  -h  --  show this message"
  echo "  -d  --  use default config, GraphSQL user: graphsql, GraphSQL root dir: /home/graphsql/graphsql"
  echo "  -r  --  GraphSQL.Root.Dir"
  echo "  -u  --  GraphSQL user"
  echo "  -o  --  Enforce offline install"
  echo "  -n  --  Enforce online install, if no internet access, it will fail"
  exit 0
}

warn()
{
  echo "${bldred}Warning: $* $txtrst" | tee -a $LOG
}

## Main ##
if [[ $EUID -ne 0 ]]
then
  warn "Sudo or root rights are requqired to install prerequsites for GraphSQL software."
  exit 1
fi

trap cancel INT

while getopts ":hdr:u:on" opt; do
  case $opt in
    h|H)
      help
      ;;
    v|V)
      LOG="`pwd`/gsql_syspre_install.log"
      ;;
    r|R)
      DATA_PATH=$OPTARG
      ;;
    u|U)
      GSQL_USER=$OPTARG
      ;;
    d|D)
      DEFAULT_INSTALL=true
      ;;
    o|O)
      OFFLINE=true
      ;;
    n|N)
      ONLINE=true
      ;;
  esac
done

# check os version, fail if not supported

# ask for input if not specify username, input path, retrieve path if default

# setup repo, online or offline according to options or internet connection

# install rpm
yum install GraphSQL-syspreq # or apt-get

# config system, this should be defined in a separate shell file for easy extensibility

