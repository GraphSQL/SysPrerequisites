#!/bin/bash

cd `dirname $0` 
source ../prettyprt
OSG=$(get_os)
OS=$(echo $OSG | cut -d' ' -f1)
OSV=$(echo $OSG | cut -d' ' -f2)
echo $OSG
echo $OS
echo $OSV
if [[ ( "$OS" == "RHEL" && ! -f ../rpm_online_repo.tar.gz ) || ( "$OS" == "UBUNTU" && ! -f ../deb_online_repo.tar.gz ) ]]; then
  warn "Online repo file does not exist"
  exit
fi
