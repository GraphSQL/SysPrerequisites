#!/bin/bash

# Copyright (c) 2016-2017, GraphSQL Inc.
# All rights reserved.
#
# Project: System Prerequisite
# Authors: Yun Peng, Justin Li
#

cd `dirname $0` 
test_dir="test"
release_dir="repo"
IF_TEST=true
PUBLISH=false
while getopts ":rp" opt; do
  case $opt in
    r|R)
      IF_TEST=false
      ;;
    p|P)
      PUBLISH=true
      ;;
  esac
done

source ../prettyprt
OSG=$(get_os)
OS=$(echo $OSG | cut -d' ' -f1)
os_version=$(echo $OSG | cut -d' ' -f2)
if [ "$OS" = "RHEL" ]; then
  name="centos"
  if ! rpm -q openssh-clients >/dev/null 2>&1; then
    yum -y install openssh-clients 
  fi
else 
  name="ubuntu"
  if ! dpkg -s openssh-client >/dev/null 2>&1; then
    apt-get -y install openssh-client
  fi
fi

cd ../
if [ ! -f "${name}_${os_version}.tar.gz" ]; then
  warn "Online repo file does not exist"
  exit 3
fi
if [ ! -f "${name}_${os_version}_offline.tar.gz" ]; then
  warn "Offline repo file does not exist"
  exit 3
fi

key="../gsql_east.pem"
server_addr="ubuntu@54.83.18.80"
html_dir="/var/www/html"
if [ "$IF_TEST" = true ]; then
  repo_dir="${html_dir}/${test_dir}"
else
  repo_dir="${html_dir}/${release_dir}"
fi
server_dir="${server_addr}:${repo_dir}"

if [ "$PUBLISH" = true ]; then
  ssh -o "StrictHostKeyChecking no" -i "$key" "$server_addr" >/dev/null <<< "
    cd ${html_dir}/${test_dir}
    cp -rf * ../${release_dir}
  "  
  progress 'already publish'
  exit 0
fi

tarf="${name}_${os_version}"
scp -o "StrictHostKeyChecking no" -i "$key" "${tarf}.tar.gz"  "$server_dir"
ssh -o "StrictHostKeyChecking no" -i "$key" "$server_addr" >/dev/null << EOF
  cd $repo_dir
  rm -rf $tarf
  tar xzf ${tarf}.tar.gz
  rm -f ${tarf}.tar.gz
EOF
if [ $? -ne 0 ]; then
  warn 'remote operation error'
  exit 3
fi 

scp -o "StrictHostKeyChecking no" -i "$key" "install.sh" "$server_dir"
fn="GraphSQL-${name}-${os_version}-syspreq"
mkdir "$fn"
cp "install.sh" "${fn}/"
cp "${tarf}_offline.tar.gz" "${fn}/"
tar czf "${fn}.tar.gz" "$fn"
rm -rf "$fn"
scp -o "StrictHostKeyChecking no" -i "$key" "${fn}.tar.gz" "$server_dir"
if [ $? -ne 0 ]; then
  warn 'scp error'
  exit 3
fi
