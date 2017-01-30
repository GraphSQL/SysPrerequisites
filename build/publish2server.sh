#!/bin/bash

cd `dirname $0` 
REPO_DIR="test"
while getopts ":r" opt; do
  case $opt in
    r|R)
      REPO_DIR="repo"
      ;;
  esac
done

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
scp -i "../gsql_east.pem" "${name}_${os_version}.tar.gz"  ubuntu@54.83.18.80:/var/www/html/${REPO_DIR}
ssh -i "../gsql_east.pem" ubuntu@54.83.18.80 1>/dev/null << EOF
  cd /var/www/html/${REPO_DIR}
  rm -rf ${name}_${os_version}
  tar xzf ${name}_${os_version}.tar.gz
  rm -f ${name}_${os_version}.tar.gz
EOF
if [ $? -ne 0 ]; then
  warn 'remote operation error'
  exit 3
fi 
scp -i "../gsql_east.pem" "install.sh" ubuntu@54.83.18.80:/var/www/html/${REPO_DIR}
fn="GraphSQL-${name}-${os_version}-syspreq.tar.gz"
tar czf "$fn"  "install.sh" "${name}_${os_version}_offline.tar.gz"
scp -i "../gsql_east.pem" "$fn" ubuntu@54.83.18.80:/var/www/html/${REPO_DIR}
if [ $? -ne 0 ]; then
  warn 'scp error'
  exit 3
fi
