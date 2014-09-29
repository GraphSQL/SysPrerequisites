#!/bin/bash
if which python; then
    printf "Python already installed.\n"
    exit 1
fi

apt-get update
apt-get -y install build-essential zlib1g-dev libbz2-dev libreadline-dev libreadline-gplv2-dev libncursesw5-dev tk-dev libgdbm-dev libc6-dev
apt-get -y install make
apt-get -y install sqlite3 libsqlite3-dev
apt-get -y install libssl-dev
cd Python-2.7.5
./configure
touch Include/Python-ast.h
touch Python/Python-ast.c
make
make install 
