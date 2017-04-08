#!/bin/bash

cd `dirname $0`
ls *.tar.gz | grep tsar -v | xargs rm
