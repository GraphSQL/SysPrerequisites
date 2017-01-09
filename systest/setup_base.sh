#!/bin/bash

cd `dirname $0`

if [[ $EUID -ne 0 ]]
then
  echo "Sudo or root rights are requqired to install test base."
  exit 1
fi

## install software
yum install -y wget

# install Jenkins
yum install -y java-1.8.0-openjdk.x86_64

wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo
rpm --import http://pkg.jenkins-ci.org/redhat-stable/jenkins-ci.org.key
yum install -y jenkins

systemctl start jenkins.service
systemctl enable jenkins.service

# need to setup ssh to localhost, such that jenkins can do sudo
cat /dev/zero | ssh-keygen -q -N ""
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys


systemctl start firewalld
systemctl enable firewalld

firewall-cmd --zone=public --permanent --add-port=8080/tcp
firewall-cmd --reload

# After first install, jenkins need to be configured

# Install Docker

# yum update

tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

yum install -y docker-engine

systemctl enable docker.service

systemctl start docker

# download images
docker_images=(centos:centos6.6 centos:centos7 ubuntu:12.04 ubuntu:14.04)

for img in ${docker_images[@]}
do
  docker pull $img
done
