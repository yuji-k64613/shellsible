# Shellsible
Shellsible is a simple IT automation system inspired by [Ansible](https://www.ansible.com/).

## Design Principles
* Configured mainly with shell scripts.
* No additional software installation required.
* Emphasize "[Convention over configuration](https://en.wikipedia.org/wiki/Convention_over_configuration)".

## Advantages over Ansible
* No need to install additional software.
* Shell scripts can be used as configuration files.
* Control statements like "if" and "while" are easily expressed using shell scripts.

## Install Shellsible

See Tutorial.

## Tutorial

### Directory Tree
This tutorial uses the following directories.

```
/tmp
├── playbook
├── repo
├── target
```
* playbook: Configuration files.
* repo: Source code for Shellsible.
* target: Remote host's directories.

### Make Directories
Type out the following.
```
mkdir /tmp/playbook
mkdir /tmp/repo
mkdir /tmp/target
```

### Install Shellsible
Type out the following.
```
cd /tmp/repo
git clone https://github.com/yuji-k64613/shellsible
PATH="${PATH}:/tmp/repo/shellsible/bin"
```

### Test SSH Login
Confirm whether you can log in to the local host as the root user.
```
ssh root@127.0.0.1
```

### Make Initial Playbook
Type out the following.
```
cd /tmp/playbook
shellsible-init.sh -g mygroup -r sample -h host1
```

* -g: group
* -r: role
* -h: target host

As a result of running "shellsible-init.sh", you can see the following output.

```
.
├── group_vars
│     ├── all.sh
│     ├── mygroup.sh
├── host_vars
│     ├── host1.sh
├── roles
│     ├── sample
│           ├── tasks
│           │     ├── main.sh
│           ├── files
│           ├── vars
│                 ├── main.sh
├── inventory.conf
├── mygroup.conf
```

### Confirm Inventory
Type out the following.
```
cat inventory.conf
```

You can see which host you will connect to, as well as the user and password.
You should change the values of variables according to your environment.
```
[mygroup]
host1 shellsible_host=127.0.0.1 shellsible_user=root shellsible_password=vagrant
```

### Confirm Group
Type out the following.
```
cat mygroup.conf
```

You can see which roles the group executes.
```
sample
```

### Confirm Tasks
Type out the following.
```
cat roles/sample/tasks/main.sh
```

You can see which tasks the "sample" roles execute and how to use the "debug" module.
```
_debug \
    msg="hello, world!"
```

### Execute Playbook
Type out the following.
```
shellsible-playbook.sh mygroup
```

You can confirm the result of the playbook.
```
2024/08/14 01:38:35 INFO  [mygroup,host1,sample,debug] hello, world!
```

### Define Variable
Type out the following to define the variable "MESSAGE".
```
cat << EOF > group_vars/all.sh 
MESSAGE="hello, world!"
EOF
```

Type out the following to use the variable "MESSAGE".
```
cat << "EOF" > roles/sample/tasks/main.sh
_debug \
    msg="${MESSAGE}"
EOF
```

Type out the following to execute the playbook.
```
shellsible-playbook.sh mygroup
```

You can confirm the result of the playbook just like the previous one.
```
2024/08/14 01:47:00 INFO  [mygroup,host1,sample,debug] hello, world!
```

You can define variables according to scopes.
* group_vars/all.sh
* group_vars/mygroup.sh
* host_vars/host1.sh
* roles/sample/vars/main.sh

### File Module
"File" module can create or delete a directory.

Type out the following to define the variable "MESSAGE" for "File" module.
```
cat << EOF > group_vars/all.sh 
DIRS="
/tmp/target/foo
/tmp/target/bar
"
EOF
```

Type out the following to use "File" module.
```
cat << "EOF" > roles/sample/tasks/main.sh
_debug \
    msg="File Module"
for dir in ${DIRS}
do
    _file \
        path=${dir} \
        state=directory
done
EOF
```

Type out the following.
```
shellsible-playbook.sh mygroup
```

You can confirm the result of the playbook.
```
2024/08/14 02:03:12 INFO  [mygroup,host1,sample,debug] File Module
```

Type out the following.
```
ls -l /tmp/target/
```

You can also confirm the result of "File" module.
```
total 0
drwxr-xr-x 2 root root 6 Aug 14 02:02 bar
drwxr-xr-x 2 root root 6 Aug 14 02:02 foo
```

### Copy Module
The "Copy" module can send a file from the local host to the target host.

Type out the following to define the variable "MESSAGE" for "File" module.
```
cat << EOF > roles/sample/files/input.txt
INPUT
EOF
```

Type out the following to use "Copy" module.
```
cat << "EOF" > roles/sample/tasks/main.sh
_copy \
    src=input.txt \
    dest=/tmp/target/foo
EOF
```

Type out the following.
```
shellsible-playbook.sh mygroup
```

You can confirm the result of the playbook.
```
2024/08/14 02:14:30 INFO  [mygroup,host1,sample,copy] scp /tmp/playbook/roles/sample/files/input.txt root@127.0.0.1:/tmp/target/foo
```

Type out the following.
```
cat /tmp/target/foo/input.txt
```

You can also confirm the result of "Copy" module.
```
INPUT
```

### Fetch Module
The "Fetch" module can send a file from the target host to the local host.

Type out the following to use "Fetch" module.
```
cat << "EOF" > roles/sample/tasks/main.sh
_fetch \
    src=/tmp/target/foo/input.txt \
    dest=/tmp
EOF
```

Type out the following.
```
shellsible-playbook.sh mygroup
```

You can confirm the result of the playbook.
```
2024/08/14 02:18:53 INFO  [mygroup,host1,sample,fetch] scp root@127.0.0.1:/tmp/target/foo/input.txt /tmp
```

Type out the following.
```
cat /tmp/input.txt
```

You can also confirm the result of "Fetch" module.
```
INPUT
```

### Modules

#### Copy

* The "Copy" module can send a file from the local host to the target host.

Parameters

| Parameter | Choices | Comments |
|:----------|:----------|:----------|
| dest | | Remote absolute path where the file should be copied to |
| src | | Local path to a file to copy to the remote host |

#### Debug

* The "Debug" module can output a message.

Parameters

| Parameter | Choices | Comments |
|:----------|:----------|:----------|
| msg | | Message |

#### Fetch

* The "Fetch" module can send a file from the target host to the local host.

Parameters

| Parameter | Choices | Comments |
|:----------|:----------|:----------|
| dest | | A directory to save the file into |
| src | | The file on the remote system to fetch |

#### File

* "File" module can create or delete a directory.

Parameters

| Parameter | Choices | Comments |
|:----------|:----------|:----------|
| owner* | | Name of the user that should own the directory |
| group* | | Name of the group that should own the directory |
| mode* | | Used for /usr/bin/chmod |
| path | | Path to the file being managed |
| state* | directory(default) or absent    | Create or delete a directory |

