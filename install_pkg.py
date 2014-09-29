#! /usr/bin/env python
import os
import sys

def check_os_ver_from_file(keyword, fname):
    f = open(fname, 'r')
    lines = f.readlines()
    f.close()
    tag = False
    release = ''
    for l in lines:
        if keyword in l:
            tag = True
        if 'Release' in l or 'release' in l:
            release = l
    if tag:
        print '\nOS detected: ' + keyword
        print 'Release: ' + release

    return tag

def check_python_version_from_file(fname):
    f = open(fname, 'r')
    content = f.read()
    f.close()
    if '2.7' in content:
        return '2.7'
    elif '2.6' in content:
        return '2.6'
    else:
        return 'NA'
 
def repo_install_ubuntu():
    print "installing from ubuntu pkg repo..."
    os.system('apt-get update')
    os.system('apt-get -y install zlib1g-dev')
    os.system('apt-get -y install libssl-dev')
    os.system('apt-get -y install texinfo')
    os.system('apt-get -y install build-essential')
    os.system('apt-get -y install python-setuptools')
    os.system('easy_install pip')
    os.system('pip install fabric')      
    os.system('pip install pyyaml')
    os.system('apt-get -y install libgoogle-perftools-dev')

def repo_install_centos():
    print "installing from centos pkg repo..."
    os.system('yum -y install zlib-devel')
    os.system('yum -y install openssl-devel')
    os.system('yum -y install texinfo')
    os.system('yum -y groupinstall "Development Tools"')




# first we need to check OS
# since at this stage we may not have subprocess,
# we just use os.system() 

print '-------- Detect OS Family ---------'
tmp_file = 'install.dump'
os_family = "NA"
check_os_ubuntu = 'lsb_release -a > ' + tmp_file
check_os_centos = 'cat /etc/redhat-release > ' + tmp_file

os.system(check_os_ubuntu)
if check_os_ver_from_file('Ubuntu', tmp_file):
    os_family = 'ubuntu'
else:
    os.system(check_os_centos)
    if check_os_ver_from_file('CentOS', tmp_file):
        os_family = 'centos'

print os_family

print '-------- Check Python Version --------'
check_python_ver = 'python --version > ' + tmp_file + ' 2>&1'
os.system(check_python_ver)
p_ver = check_python_version_from_file(tmp_file)
print 'Python version: ' + p_ver
if p_ver != '2.7':
    print 'We need to install Python 2.7' 



print '-------- Select Installation Mode ---------'
print "1) install pkgs from public repo or private repo if you are sure the rpms are available there"
print "2) source install"
mode = raw_input('Your choice (1/2):')

if mode == '1':
    if os_family == 'ubuntu':
        repo_install_ubuntu()
    elif os_family == 'centos':
        # we have to src install python2.7
        src_install_python27()
        repo_install_centos()



