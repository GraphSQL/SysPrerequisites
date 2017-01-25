#!/bin/bash

cd `dirname $0` 
source ../prettyprt
OSG=$(get_os)
OS=$(echo $OSG | cut -d' ' -f1)
os_version=$(echo $OSG | cut -d' ' -f2)
if [ "$OS" = "RHEL" ]; then
  name="centos"
else 
  name="ubuntu"
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
scp -i "../gsql_east.pem" "${name}_${os_version}.tar.gz"  ubuntu@54.83.18.80:/var/www/html/repo
ssh -i "../gsql_east.pem" ubuntu@54.83.18.80 << EOF
  cd /var/www/html/repo;
  rm -rf ${name}_${os_version}
  tar xzf ${name}_${os_version}.tar.gz
  rm -f ${name}_${os_version}.tar.gz
EOF
scp -i "../gsql_east.pem" "install.sh" ubuntu@54.83.18.80:/var/www/html/download
fn="GraphSQL-${name}-${os_version}-syspreq.tar.gz"
tar czf "$fn"  "install.sh" "${name}_${os_version}_offline.tar.gz"
scp -i "../gsql_east.pem" "$fn" ubuntu@54.83.18.80:/var/www/html/download
