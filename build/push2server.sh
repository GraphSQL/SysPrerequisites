#!/bin/bash

cd `dirname $0` 
source ../prettyprt
OS=$(get_os)
if [[ ( "$OS" == "RHEL" && ! -f ../rpm_online_repo.tar.gz ) || ( "$OS" == "UBUNTU" && ! -f ../deb_online_repo.tar.gz ) ]]; then
  warn "Online repo file does not exist"
  exit
fi
