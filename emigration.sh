#!/bin/bash

# Copyright (c)2010-2012 rbTechnologies, LLC
# By Rubin Bennett rbennett@rbtechvt.com>
# https://support.rbtechvt.com/Knowledgebase/Article/View/38/0/a-super-elegant-way-to-migrate-user-accounts-from-one-linux-server-to-another

# Released under the terms and conditions of the GNU Public License version 2.

# A simple script to assist in server migrations from Linux to Linux
# Intended to be run on the NEW server, and expecting that you have performed
# ssh key exchange for password-less login to the OLD server.

# IP address or hostname of source server (e.g. server your're migrating
# AWAY from
#

# Function prototypes
usage() {
    echo "USAGE: "
    echo "  $0 "
    echo "      -s <source-server IP address>"
    echo "      -u <root user on source server>"
    echo "      -b <enable backups of existing pwd files>"
    echo
    echo "  The process will migrate all users from source Server to current server"
    echo
    echo "Example:"
    echo "  $0 -s 192.168.1.134 -u root"
    exit 1
}


function syncusers() {
    echo 
    echo "Copying user accounts and passwords from /etc/passwd on $sourceServer to current host"

    echo -n "Do you have backups of your existing passwd files? [y|N] "
    read
    if [ "$REPLY" != "y" ]
    then
        echo "Please back your files up and run this script again."
        exit 1
    else
        scp $sourceUser@$sourceServer:/etc/passwd /tmp/passwd.$sourceServer
        scp $sourceUser@$sourceServer:/etc/group /tmp/group.$sourceServer
        scp $sourceUser@$sourceServer:/etc/shadow /tmp/shadow.$sourceServer

        # First, make a list of non-system users that need to be moved.

        export UGIDLIMIT=500
        awk -v LIMIT=$UGIDLIMIT -F: '($3 >= LIMIT) && ($3 != 65534)' /tmp/passwd.$sourceServer > /tmp/passwd.mig
        awk -v LIMIT=$UGIDLIMIT -F: '($3 >= LIMIT) && ($3 != 65534)' /tmp/group.$sourceServer >/tmp/group.mig
        awk -v LIMIT=$UGIDLIMIT -F: '($3 >= LIMIT) && ($3 != 65534) { print $1 }' /tmp/passwd.$sourceServer \
    | tee - |egrep -f - /tmp/shadow.$sourceServer > /tmp/shadow.mig

        # Now copy non-duplicate entries in to the new server files...
        while IFS=: read user pass uid gid full home shell
        do
            line="$user:$pass:$uid:$gid:$full:$home:$shell"
            exists=$(grep $user /etc/passwd)
            if [ -z "$exists" ]
            then
                echo "Copying entry for user $user to new system"
                echo $line >> /etc/passwd
            fi
        done </tmp/passwd.mig

        while IFS=: read group pass gid userlist
        do
            line="$group:$pass:$gid:$userlist"
            exists=$(grep $group /etc/group)
            if [ -z "$exists" ]
            then
                echo "Copying entry for group $group to new system"
                echo $line >> /etc/group
            fi
        done </tmp/group.mig

        while IFS=: read user pass lastchanged minimum maximum warn
        do
            line="$user:$pass:$lastchanged:$minimum:$maximum:$warn"
            exists=$(grep $user /etc/passwd)
            if [ -z "$exists" ]
            then
                echo "Copying entry for user $user to new system"
                echo $line >> /etc/shadow
            fi
        done </tmp/shadow.mig

    fi
}


#----- MAIN -----
# Set globals and defaults
now=$(date -u +%Y%m%d%H%M)

# Set command-line options, which might override the defdaults
options=':h:u'

while getopts $options option
do
    case $option in
        s  ) sourceServer=$OPTARG;;
        u  ) sourceUser=$OPTARG;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
        *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
    esac
done


if [ -z "$sourceServer" ];then
    echo -n "Source Server IP: "
    read sourceServer
    if [ -z "$sourceServer" ]
    then
        echo "A source server is necessary. Cannot proceed without it!"
        exit 1
    fi
fi

if [ -z "$sourceUser" ];then
    echo -n "Source Server username (ensure SSH keys are set up): "
    read sourceUser
    if [ -z "$sourceUser" ]
    then
        echo "You must specify the username on the remote host!"
        exit 1
    fi
fi

# Try ssh'ing to the remote host as this user
resp=$(ssh $sourceUser@$sourceServer 'uname -a')
if [ -z "$resp" ];then
    echo "Failed connection to $sourceUser@$sourceServer. Please check your configurations"
    exit 1
fi

echo "OK things look good. Proceeding with migration ..."

syncusers

exit 0
