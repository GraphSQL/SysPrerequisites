#!/bin/bash

#yum -y install libtool autoconf zlib-devel

#yum -y install unzip python-devel gmp-devel lsof

# Now we need to install fabric
echo "----- Install Fabric ------"
cd pycrypto-2.6
python setup.py install
cd ../ecdsa-0.11
python setup.py install
cd ../paramiko-1.14.0
python setup.py install
cd ../nose-1.3.4
python setup.py install
cd ../PyYAML-3.10
python setup.py install
cd ../setuptools-5.4.1
python setup.py install
cd ../Fabric-1.8.2 
python setup.py install


echo "---- Install psutil ------"
cd ../psutil-2.1.3
python setup.py install


# change open file limit
#echo "* hard nofile 1000000" >> /etc/security/limits.conf
#echo "* soft nofile 1000000" >> /etc/security/limits.conf




