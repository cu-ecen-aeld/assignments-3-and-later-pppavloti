#!/bin/sh

writefile=$1
writestr=$2
dirpath=$(dirname -- "$1")

updateFile()
{
  touch $1
  if [ "$2" ]; then
    echo "$2" > $1
    exit 0
  else
    echo "No valid string to write"
    exit 1  
  fi  
}

# Check if input arguments are provided
if [ "$#" -lt 2 ];
then
  echo "Needs at least two arguments!"
  exit 1
else
  # check if dirpath exists
  if [ -d "$dirpath" ]; then
    updateFile "${writefile}" "$2"
    echo "$writestr" > ${writefile}
  else
    echo "No valid directory path. Creating missing directories"
    mkdir -p "$dirpath"
    updateFile "${writefile}" "$2"
    exit 1
  fi
fi

