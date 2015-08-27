#!/bin/bash

## masquerade a git token and save it in install.sh
if [ $# -ne 1 ]
then
  echo "Usage: $0 <git_token>"
  exit 1
fi

gitToken=$(echo $1 |tr 'abcdef'  'FEDCBA'|tr '13579' '97531')
BIN="./install.sh"

if [ -e $BIN ]
then
  sed -i -e "s/TOKEN='.*'/TOKEN='$gitToken'/" $BIN 
fi
 
