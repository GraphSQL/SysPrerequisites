#!/bin/bash
apt-get update
apt-get -y install make build-essential zlib1g-dev libbz2-dev libreadline-dev libreadline-gplv2-dev libncursesw5-dev tk-dev libgdbm-dev libc6-dev
apt-get -y install sqlite3 libsqlite3-dev
apt-get -y install libssl-dev
cd Python-2.7.5
./configure
make
make install 
