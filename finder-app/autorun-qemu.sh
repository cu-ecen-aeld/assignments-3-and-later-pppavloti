#!/bin/sh
cd $(dirname $0)

mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/ttAMA0 c 5 1 
mknod -m 666 /dev/console c 5 1 
mknod -m 666 /dev/tty c 5 0

echo "Running test script"
./finder-test.sh
rc=$?
if [ ${rc} -eq 0 ]; then
    echo "Completed with success!!"
else
    echo "Completed with failure, failed with rc=${rc}"
fi
echo "finder-app execution complete, dropping to terminal"
/bin/sh
