#!/bin/bash
REMOTE_TMP_DIR=/tmp/shellsible
COMMAND_FILE="${REMOTE_TMP_DIR}/command.txt"
CONTROL_FILE="${REMOTE_TMP_DIR}/control.txt"
LOG_DIR=${REMOTE_TMP_DIR}
RE="${REMOTE_TMP_DIR}/rerror.txt"

function log(){
	echo "$(date +'%Y/%m/%d %H:%M:%S') $*" >> ${LOG_DIR}/remote.log
}

function info(){
	log "INFO " $*
}

function error(){
	log "ERROR" $*
    echo "${*}" > ${RE}
}

function wait_ctrl(){
	: > ${CONTROL_FILE}
	while true
	do
		if [ ! -f ${CONTROL_FILE} ]; then
			break
		fi
	done
}

function _copy(){
	while [ "$1" != "" ]
	do
		item="$1"
		key=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\1/')
		value=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\2/')
		case "${key}" in
		"src")
			src="${value}"
			;;
		"dest")
			dest="${value}"
			;;
		*)
			error "An unexpected argument: ${item}"
			exit 1
			;;
		esac
		shift
	done

	if [ -z "${src}" ]; then
		error "src is expected" 
		exit 1
	fi
	if [ -z "${dest}" ]; then
		error "dest is expected" 
		exit 1
	fi

	info 'copy '"${src}" "${dest}"
	echo "copy" > "${COMMAND_FILE}"
	echo "${src}" >> "${COMMAND_FILE}"
	echo "${dest}" >> "${COMMAND_FILE}"
	wait_ctrl
}

function _fetch(){
	while [ "$1" != "" ]
	do
		item="$1"
		key=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\1/')
		value=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\2/')
		case "${key}" in
		"src")
			src="${value}"
			;;
		"dest")
			dest="${value}"
			;;
		*)
			error "An unexpected argument: ${item}"
			exit 1
			;;
		esac
		shift
	done

	if [ -z "${src}" ]; then
		error "src is expected" 
		exit 1
	fi
	if [ -z "${dest}" ]; then
		error "dest is expected" 
		exit 1
	fi

	info 'fetch '"${src}" "${dest}"
	echo "fetch" > "${COMMAND_FILE}"
	echo "${src}" >> "${COMMAND_FILE}"
	echo "${dest}" >> "${COMMAND_FILE}"
	wait_ctrl
}

function _debug(){
	msg=""

	while [ "$1" != "" ]
	do
		item="$1"
		key=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\1/')
		value=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\2/')
		case "${key}" in
		"msg")
			msg="${value}"
			;;
		*)
			error "An unexpected argument: ${item}"
			exit 1
			;;
		esac
		shift
	done
	info 'debug '"${msg}"
	echo "debug" > "${COMMAND_FILE}"
	echo "${msg}" >> "${COMMAND_FILE}"
	wait_ctrl
}

function _file(){
	state="directory"

	while [ "$1" != "" ]
	do
		item="$1"
		key=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\1/')
		value=$(echo "${item}" | sed 's/^\([^=]*\)=\(.*\)$/\2/')
		case "${key}" in
		"owner")
			owner="${value}"
			;;
		"group")
			group="${value}"
			;;
		"mode")
			mode="${value}"
			;;
		"path")
			path="${value}"
			;;
		"state")
			state="${value}"
			;;
		*)
			error "An unexpected argument: ${item}"
            exit 1
			;;
		esac
		shift
	done
	
	if [ "${state}" != "directory" -a "${state}" != "absent" ]; then
		error "state must be directory or absent"
		exit 1
	fi

	if [ "${state}" = "directory" ]; then
        if [ -d "${path}" ]; then
            info "skip: ${path}"
        elif [ -e "${path}" ]; then
            error "${path} must be directory"
            exit 1
        else
            info mkdir -p "${path}"
            mkdir -p "${path}"
        fi

        if [ ! -z "${mode}" ]; then
            chmod "${mode}" "${path}"
        fi

        if [ ! -z "${owner}" ]; then
            chown "${owner}" "${path}"
        fi
        if [ ! -z "${group}" ]; then
            chown ":${group}" "${path}"
        fi
    else
        if [ -d "${path}" ]; then
            rm -fr "${path}" 
        fi
    fi
}

dir=$(dirname "$0")

list="
all_vars.sh
group_vars.sh
role_vars.sh
host_vars.sh
tasks.sh
"

for item in ${list}
do
	. "${dir}/${item}"
	RC=$?
	if [ $RC -ne 0 ]; then
        error "An unexpected argument: ${item}"
		exit 1
	fi
done

