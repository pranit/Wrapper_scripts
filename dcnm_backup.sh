#!/bin/bash
#Script to backup running config of switches managed by DCNM 

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/cisco/dcm/db/bin:/root/bin
cd /opt/custom_script
dcnm_host=$(cat dcnm_get_run_configs_fabric.yaml | grep dcnm_host | sed -n -e 's/^.*: //p')

ip addr | grep $dcnm_host
run_status=$?

if [ $run_status -ne 0 ]; then
	echo "Not on DCNM active host - not taking the backup"
else
cd /opt/custom_script
python dcnm_get_run_configs_fabric.py

zip -rm switch_config_backup.zip Switch-SN-*
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
filename=switch_config_backup-$current_time.zip
mv switch_config_backup.zip $filename

fpath=$(realpath $filename) 

#This will update local_file_path property  to newly generated backup file in dcnm_get_run_configs_fabric.yaml
sed -i '/local_file_path/c\    local_file_path : '$fpath'' dcnm_get_run_configs_fabric.yaml

dcnm_sftp_base64_encodedpassword=$(cat dcnm_get_run_configs_fabric.yaml | grep sftp_password | sed -n -e 's/^.*: //p')
dcnm_sftp_user=$(cat dcnm_get_run_configs_fabric.yaml | grep sftp_user | sed -n -e 's/^.*: //p')
dcnm_sftp_host=$(cat dcnm_get_run_configs_fabric.yaml | grep sftp_host | sed -n -e 's/^.*: //p')
dcnm_sftp_path=$(cat dcnm_get_run_configs_fabric.yaml | grep sftp_path | sed -n -e 's/^.*: //p')
dcnm_local_file_path=$(cat dcnm_get_run_configs_fabric.yaml | grep local_file_path | sed -n -e 's/^.*: //p')

#decoding base64 password
dcnm_sftp_password=$(echo $dcnm_sftp_base64_encodedpassword | base64 --decode)

#SFTP to remote sfp directory 
export SSHPASS=$dcnm_sftp_password
sshpass -v -e sftp -oBatchMode=no -oStrictHostKeyChecking=no -b - $dcnm_sftp_user@$dcnm_sftp_host << !
  cd $dcnm_sftp_path
  put $dcnm_local_file_path
   bye
!

status=$?

if [ $status -ne 0 ]; then
    echo "Error copying file to SFTP server. Not deleting local backup file $filename"
else 
   echo "File copying to sftp server successful. Deleting local backup file."
   rm -f $fpath

fi
exit $status

fi 
exit $run_status
