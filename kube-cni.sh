#!/bin/bash 

exec 3>&1 # make stdout available as fd 3 for the result
exec &>> /var/log/bash-cni-plugin.log

echo "CNI command: $CNI_COMMAND" 

stdin=`cat /dev/stdin`
echo "stdin: $stdin"

case $CNI_COMMAND in
ADD)

echo "{
  \"cniVersion\": \"0.3.0\",
  \"interfaces\": [                                            
      {
          \"name\": \"eth0\",
      }
  ],
  \"ips\": [
      {
          \"version\": \"4\",
          \"interface\": 0 
      }
  ]
}" >&3

;;

DEL)
  echo "DEL not supported"
  exit 1
;;

GET)
  echo "GET not supported"
  exit 1
;;

VERSION)
echo '{
  "cniVersion": "0.3.0", 
  "supportedVersions": [ "0.2.0", "0.3.0", "0.4.0" ] 
}' >&3
;;

*)
  echo "Unknown cni commandn: $CNI_COMMAND" 
  exit 1
;;

esac

