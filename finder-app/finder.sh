#!/bin/sh

# full path to a file (including filename)
filesdir=$1

# text string which will be written within this file
searchstr=$2

# Check if input arguments are provided
if [ "$#" -lt 2 ];then
  echo "Needs at least two arguments!"
  exit 1
else
  if [ -d "$filesdir" ];then
    # X is the number of files in the directory and all subdirectories 
    # Y is the number of matching lines found in respective files, where a matching line refers to a line which contains searchstr
    lineCount=$(ls -1 "$filesdir" | wc -l)
    matchingLines=$(grep -R "$searchstr" "$filesdir" | wc -l)
    echo "The number of files are $lineCount and the number of matching lines are $matchingLines"
  else
    echo "$filesdir not a directory on the filesystem"
    exit 1
  fi
  exit 
fi


