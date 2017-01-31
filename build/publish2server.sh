#!/bin/bash

cd `dirname $0` 
REPO_NAME="test"
PUBLISH=false
while getopts ":r" opt; do
  case $opt in
    r|R)
      REPO_NAME="repo"
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
repo_dir="/var/www/html/${REPO_NAME}"
server_dir="${server_addr}:${repo_dir}"

scp -i "$key" "${name}_${os_version}.tar.gz"  "$server_dir"
ssh -i "$key" "$server_addr" >/dev/null << EOF
  cd $repo_dir
  rm -rf ${name}_${os_version}
  tar xzf ${name}_${os_version}.tar.gz
  rm -f ${name}_${os_version}.tar.gz
EOF
if [ $? -ne 0 ]; then
  warn 'remote operation error'
  exit 3
fi 

scp -i "$key" "install.sh" "$server_dir"
fn="GraphSQL-${name}-${os_version}-syspreq.tar.gz"
tar czf "$fn"  "install.sh" "${name}_${os_version}_offline.tar.gz"
scp -i "$key" "$fn" "$server_dir"
if [ $? -ne 0 ]; then
  warn 'scp error'
  exit 3
fi
