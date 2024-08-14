#!/bin/bash
usage="Usage: $(basename $0) -g group -h host -r role"

while getopts "g:r:h:" opt; do
case $opt in
g)
    group="${OPTARG}"
    ;;
h)
    host="${OPTARG}"
    ;;
r)
    role="${OPTARG}"
    ;;
*)
    echo "${usage}" >&2
    exit 1
    ;;
esac
done

if [ -z "${group}" -o -z "${role}" -o -z "${host}" ]; then
    echo "${usage}" >&2
    exit 1
fi

list="
group_vars
host_vars
roles
roles/${role}
roles/${role}/tasks
roles/${role}/files
roles/${role}/vars
"

for item in ${list}
do
    if [ ! -e "${item}" ]; then
        mkdir "${item}"
    fi
    if [ ! -d "${item}" ]; then
        exit 1
    fi
done

list="
group_vars/all.sh
group_vars/${group}.sh
host_vars/${host}.sh
roles/${role}/vars/main.sh
"

for item in ${list}
do
    if [ ! -e "${item}" ]; then
        : > "${item}"
    fi
done

if [ ! -e inventory.conf ]; then
cat << EOF > inventory.conf
[${group}]
${host} shellsible_host=127.0.0.1 shellsible_user=root shellsible_password=vagrant
EOF
fi

if [ ! -e ${group}.conf ]; then
cat << EOF > ${group}.conf
${role}
EOF
fi

if [ ! -e roles/${role}/tasks/main.sh ]; then
cat << "EOF" > roles/${role}/tasks/main.sh
_debug \
    msg="hello, world!"
EOF
fi
