#!/bin/bash
REMOTE_TMP_DIR=/tmp/shellsible
CONTROL_FILE=${REMOTE_TMP_DIR}/control.txt

rm -f ${CONTROL_FILE}
while true
do
	if [ -f ${CONTROL_FILE} ]; then
		break
	fi
	sleep 1
done
exit 0
