#!/bin/bash 

exec 3>&1 # make stdout available as fd 3 for the result
exec &>> /var/log/bash-cni-plugin.log

