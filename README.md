# emigrate

Migrate users and home directories from one linux box to another

## Usage

    $ emigrate -s <source-server> -u <source-user>

Will migrate all users from the source server (logged in via SSH using
source-user, who must have root access and keys or the remote host) to 
the current host.

This script must be run from the host to which you are migrating users.
In other words, users and data will be migrated from the source-server to
the machine on which the script runs.

