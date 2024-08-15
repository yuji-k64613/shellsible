#!/bin/bash
if [ -n "$PASSWORD" ]; then
    cat <<< "$PASSWORD"
    exit 0
fi
export SSH_ASKPASS=$0
export DISPLAY=dummy:0

function exit_parent(){
    msg="$1"
    if [ -z "${msg}" ]; then
        error "An unexpected error occurred: $(cat ${PE})"	
    else
        error ${msg}
    fi
	if [ ! -z "${CPID}" ]; then
		kill -9 ${CPID}
	fi
	exit 1
}

function exit_child(){
	error "An unexpected error occurred in the child process: $(cat ${CE})"
	kill -9 ${PID}
	exit 1
}

function log(){
	echo "$(date +'%Y/%m/%d %H:%M:%S') $*"
	echo "$(date +'%Y/%m/%d %H:%M:%S') $*" >> ${LOG_DIR}/shellsible.log
}

function debug(){
    if [ -z "${DEBUG}" ]; then
        return
    fi
    msg=
    if [ ! -z "${name}${role}${module}" ]; then
        msg="[${GROUP},${name},${role},${module}]"
    fi
	log "DEBUG" "${msg}" $*
}

function info(){
    msg=
    if [ ! -z "${name}${role}${module}" ]; then
        msg="[${GROUP},${name},${role},${module}]"
    fi
	log "INFO " "${msg}" $*
}

function error(){
    msg=
    if [ ! -z "${name}${role}${module}" ]; then
        msg="[${GROUP},${name},${role},${module}]"
    fi
	log "ERROR" "${msg}" $*
}

function control(){
	while true
	do
		REMOTE_CMD=${REMOTE_TMP_DIR}/control.sh
		debug ssh $SSH_USER@$SSH_HOST $REMOTE_CMD
		setsid ssh $SSH_USER@$SSH_HOST $REMOTE_CMD 2> ${CE} || exit_child

		debug scp $SSH_USER@$SSH_HOST:/$REMOTE_TMP_DIR/command.txt $TMP_DIR/command.txt
		setsid scp $SSH_USER@$SSH_HOST:/$REMOTE_TMP_DIR/command.txt $TMP_DIR/command.txt 2> ${CE} || exit_child

		REMOTE_CMD="rm ${REMOTE_TMP_DIR}/command.txt"
		debug ssh $SSH_USER@$SSH_HOST $REMOTE_CMD
		setsid ssh $SSH_USER@$SSH_HOST $REMOTE_CMD 2> ${CE} || exit_child

		cmd="$(awk 'NR==1{ print $0 }' $TMP_DIR/command.txt)"
		arg1="$(awk 'NR==2{ print $0 }' $TMP_DIR/command.txt)"
		arg2="$(awk 'NR==3{ print $0 }' $TMP_DIR/command.txt)"
		arg3="$(awk 'NR==4{ print $0 }' $TMP_DIR/command.txt)"

		rm $TMP_DIR/command.txt 2> ${CE} || exit_child

        module="${cmd}"
		if [ "${cmd}" = "fetch" ]; then
			rmt="${arg1}"
			lcl="${arg2}"
			info scp $SSH_USER@$SSH_HOST:"${rmt}" "${lcl}"
			setsid scp $SSH_USER@$SSH_HOST:"${rmt}" "${lcl}" 2> ${CE} || exit_child
		elif [ "${cmd}" = "copy" ]; then
			lcl="${arg1}"
			rmt="${arg2}"
            ch=$(echo "${lcl}" | grep -o "^.")
            if [ "${ch}" != "/" ]; then
                lcl="./roles/${role}/files/${lcl}"
                if [ -f "${lcl}" ]; then
                    lcl=$(realpath "${lcl}")
                fi
            fi
			info scp "${lcl}" $SSH_USER@$SSH_HOST:"${rmt}"
			setsid scp "${lcl}" $SSH_USER@$SSH_HOST:"${rmt}" || exit_child
		elif [ "${cmd}" = "debug" ]; then
			msg="${arg1}"
			info "${msg}"
		fi
        module=
	done
}

function execute_role(){
    export SSH_USER="${user}"
    export SSH_PASS="${password}"
    export SSH_HOST="${host}"
    export PASSWORD="${password}"

    REMOTE_CMD="rm -fr ${REMOTE_TMP_DIR:-/ERROR} && mkdir -p ${REMOTE_TMP_DIR}"
    debug ssh $SSH_USER@$SSH_HOST "$REMOTE_CMD"
    setsid ssh $SSH_USER@$SSH_HOST "$REMOTE_CMD" 2> ${CE} || exit_child

	list="
${BIN_DIR}/control.sh,
${BIN_DIR}/remote.sh,
"

	all_vars="./group_vars/all.sh"
	if [ ! -f "${all_vars}" ]; then
		all_vars="${BIN_DIR}/empty.sh"
	fi
	list="${list} ${all_vars},all_vars.sh"

	group_vars="./group_vars/${GROUP}.sh"
	if [ ! -f "${group_vars}" ]; then
		group_vars="${BIN_DIR}/empty.sh"
	fi
	list="${list} ${group_vars},group_vars.sh"

	host_vars="./host_vars/${name}.sh"
	if [ ! -f "${host_vars}" ]; then
		host_vars="${BIN_DIR}/empty.sh"
	fi
	list="${list} ${host_vars},host_vars.sh"

	role_vars="./roles/${role}/vars/main.sh"
	if [ ! -f "${role_vars}" ]; then
		role_vars="${BIN_DIR}/empty.sh"
	fi
	list="${list} ${role_vars},role_vars.sh"

	tasks="./roles/${role}/tasks/main.sh"
	if [ ! -f "${tasks}" ]; then
		tasks="${BIN_DIR}/empty.sh"
	fi
	list="${list} ${tasks},tasks.sh"
    
	for line in ${list}
	do
		src=$(echo "${line}" | awk -F, '{ print $1 }')
		dst=$(echo "${line}" | awk -F, '{ print $2 }')

		debug scp "${src}" "$SSH_USER@$SSH_HOST:${REMOTE_TMP_DIR}/${dst}"
		setsid scp "${src}" "$SSH_USER@$SSH_HOST:${REMOTE_TMP_DIR}/${dst}" 2> ${PE} || exit_parent
	done

	control&
	CPID=$!

	REMOTE_CMD=${REMOTE_TMP_DIR}/remote.sh
	debug ssh $SSH_USER@$SSH_HOST $REMOTE_CMD
	setsid ssh $SSH_USER@$SSH_HOST $REMOTE_CMD 2> ${PE}
    RS=$?
    if [ ${RS} -eq 1 ]; then
        rmt="${REMOTE_TMP_DIR}/rerror.txt"
        setsid scp $SSH_USER@$SSH_HOST:"${rmt}" "${PE}"
        if [ -f "${PE}" ]; then
            exit_parent "$(cat ${PE})"
        else
            exit_parent
        fi
    elif [ ${RS} -ne 0 ]; then
        exit_parent
    fi

	kill -9 ${CPID}
    wait ${CPID} > /dev/null 2>&1
    CPID=""

    if [ -z "${DEBUG}" ]; then
        REMOTE_CMD="rm -fr ${REMOTE_TMP_DIR:-/ERROR}"
        #info ssh $SSH_USER@$SSH_HOST "$REMOTE_CMD"
        setsid ssh $SSH_USER@$SSH_HOST "$REMOTE_CMD" 2> ${CE} || exit_child
    fi
}

function execute_host(){
	for role in ${roles}
	do
		execute_role
	done
}

export PID=$$
BIN_DIR=$(realpath $(dirname "$0"))
BASE_DIR=$(realpath "${BIN_DIR}/..")
TMP_DIR=./tmp
LOG_DIR=./log
REMOTE_TMP_DIR=/tmp/shellsible
INVENTORY_FILE=./inventory.conf
PE="${TMP_DIR}/perror.txt"
CE="${TMP_DIR}/cerror.txt"
PREFIX="shellsible_"
export DEBUG=

usage="Usage: $(basename $0) [ -d ] group"
while getopts "d" opt; do
case $opt in
d)
    DEBUG=on 
    ;;
*)
    exit_parent "${usage}"
    ;;
esac
done

shift $(expr ${OPTIND} - 1)
GROUP="$1"
if [ -z "${GROUP}" ]; then
    exit_parent "${usage}"
fi
GROUP_FILE="./${GROUP}.conf"

if [ ! -f "${INVENTORY_FILE}" ]; then
    exit_parent "No such file: ${INVENTORY_FILE}"
fi
if [ ! -f "${GROUP_FILE}" ]; then
    exit_parent "No such file: ${GROUP_FILE}"
fi
mkdir -p "${TMP_DIR}"
rm -fr "${TMP_DIR}/"*
mkdir -p "${LOG_DIR}" 2> ${PE} || exit_parent
roles=$(grep '^\s*[A-Za-z][A-Za-z0-9_]*' "${GROUP_FILE}")

flag=
while read line
do
	group=$(echo "${line}" | grep -o '^[\s]*\[.*\]')
	if [ $? -eq 0 ]; then
		group=$(echo "${group}" | sed 's/^\s*\[\(.*\)\].*$/\1/')
		if [ "${GROUP}" = "${group}" ]; then
			flag=ON
		else
			flag=
		fi
	elif [ ! -z "${flag}" ]; then
		name=
		for item in ${line}
		do
			if [ -z "${name}" ]; then
				name="${item}"
			else
				key=$(echo "${item}" | sed 's/^\s*\([^=]*\)=\(.*\)$/\1/')
				value=$(echo "${item}" | sed 's/^\s*\([^=]*\)=\(.*\)$/\2/')
				case "${key}" in
				"${PREFIX}host")
					host="${value}"
					;;
				"${PREFIX}user")
					user="${value}"
					;;
				"${PREFIX}password")
					password="${value}"
					;;
				*)
					;;
				esac
			fi
		done
		execute_host
	fi
done < <(grep '^[\s]*[^#]' "${INVENTORY_FILE}")
exit 0
