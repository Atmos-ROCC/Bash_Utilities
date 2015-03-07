#!/bin/bash
#####################################################################
# Proactive replace disk, 2.1.x    ( remove_disk.sh )               #
# -- created from KB15810v12 and KB15950v7                          #
#                                                                   #
# This script will proactively kick out disk from syustem.          #
#                                                                   #
# Created by Claiton Weeks (claiton.weeks@emc.com)                  #
#                                                                   #
# May be freely distributed and modified as needed,                 #
# as long as proper credit is given.                                #
#                                                                   #
version=1.5.1                                                       #
#####################################################################

############################################################################################################
#########################################   Variables/Parameters   #########################################
############################################################################################################
cm_cfg="/etc/maui/cm_cfg.xml"; 
export RMG_MASTER=`awk -F, '/localDb/ {print $(NF-1)}' $cm_cfg`                       # top_view.py -r local | sed -n '4p' | sed 's/.*"\(.*\)"[^"]*$/\1/'
export INITIAL_MASTER=`awk -F"\"|," '/systemDb/ {print $(NF-2)}' $cm_cfg`             # show_master.py |  awk '/System Master/ {print $NF}'
dev_path=0                                                                            # set after getting fsuuid
node_uuid=`dmidecode | grep -i uuid | awk {'print $2'}`                               # Find UUID of current node.
xdr_disabled_flag=0                                                                   # Initialize flag.

############################################################################################################
##########################################  Functions      ###########################################
############################################################################################################
disable_xdoctor() {
echo -e "${lt_gray}"
read -p "# Would you like to disable SYR Dialhomes (xDoctor method)? (y/n): " -t 60 -n 1 disable_xdr
echo -e "${clear_color}"
if [[ "$disable_xdr" =~ [yY] ]] 
then
	ssh $INITIAL_MASTER xdoctor --tool --exec=syr_maintenance --method=disable && xdr_disabled_flag=1
else 
	echo -e "${magenta}# --Skipping \"Disable xDoctor\" ${clear_color}"
	xdr_disabled_flag=0
fi

return
}

set_motd() {
## Need to get input of SR# and Agent email. Then ask if MOTD should be updated. If so, append echo to MOTD, but create backup for cleanup.
#Edit the Message of the Day (MOTD) on the entire Atmos to avoid other Atmos Support or Field personnel duplicating or interrupting this work. Add the below MOTD text (fill in the SR number and your email) and mauiscp it to all nodes.
echo -e "${lt_gray}"
read -p "# Would you like to set the MOTD across the system? (y/n) " -t 60 -n 1 set_motd_flag
echo -e "${clear_color}"
if [[ "$set_motd_flag" =~ [yY] ]]
then 
  echo -en "${lt_gray}"
	read -p "${clear_color}# Please enter the SR number: " -t 60 -n 8 sr_number
  echo
	read -p "# Please enter your email address: " -t 60 agent_email
  echo -e "${clear_color}"
	#MOTD text:
	/bin/cp -fp /etc/motd /etc/motd.bak
	echo -e "**********************************************\n*\n* All EMC, READ THIS!!!\n*\n* Do NOT start any proactive disk replacement,\n* fail out any new disk, or work on a disk\n* issue without consulting:\n*\n* SR $sr_number \n* Atmos Support $agent_email \n*\n**********************************************" >> /etc/motd
	mauiscp /etc/motd /etc/motd
else 
	echo -e "${magenta}# --Skipping \"Set MOTD\"${clear_color}"
fi

return
}

get_fsuuid() { 						      # Get fsuuid from user.
  spinner_time 1
  echo -en "\b${light_green}"
  read -p "# Enter FSUUID: " -t 180 -n 36 fsuuid_var
  echo -e "${clear_color}\n"
  if [[ ! validate_fsuuid ]]
    then fail_count=$((fail_count+1))
      [[ "$fail_count" -gt 4 ]] && cleanup "Please try again with a valid fsuuid." 60
      #clear
      echo -e "\n\n${red}# Invalid fsuuid attempt: $fail_count, please try again.${clear_color}"
      get_fsuuid $fail_count
    else return 0
  fi 
  return 1
}

validate_fsuuid() {					    # Validate fsuuid 
  echo -e "${lt_gray}# Validating fsuuid...${clear_color}";spinner_time 1
  valid_fsuuid='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' # Regex to confirm a valid UUID - only allows for hexidecimal characters.
  valid_fsuuid_on_host=$(psql -t -U postgres rmg.db -h $RMG_MASTER -c "select fs.fsuuid from disks d join fsdisks fs ON d.uuid=fs.diskuuid where d.nodeuuid='$node_uuid' and fs.fsuuid='$fsuuid_var'"| awk 'NR==1{print $1}')
  if [[ ! ${#valid_fsuuid_on_host} -eq 36 ]] ; then
    echo -e "${red}# FSUUID not found on host.\n# Please try again.${clear_color}"
    get_fsuuid $fail_count
  else
    [[ "$fsuuid_var" =~ $valid_fsuuid ]] && { echo -e "${light_green}# FSUUID validation passed.${clear_color}"; dev_path=`blkid | grep ${fsuuid_var} | sed 's/1.*//'`; return 0; }
    echo -e "${red}# Invalid fsuuid.${clear_color}" && get_fsuuid
  fi

  return 1
}

spinner_time() {
i=1
x=0
seconds="$(echo "$1*7.172" | bc | sed 's/[.].*//')"
sp="/-\|"
echo -n ' '
while [ $x -le $seconds ]
do
    x=$(( $x + 1 ))
    printf "\b${sp:i++%${#sp}:1}"
sleep .12
done
echo -en "\b"
}

cleanup() {
#Step 4: Restore tools
[ -f /sbin/mkfs.ext3.bak ] && /bin/mv /sbin/mkfs.ext3.bak /sbin/mkfs.ext3 
[ -f /sbin/fdisk.bak ] && /bin/mv /sbin/fdisk.bak /sbin/fdisk
#If the DAE disk is 3 TB or more in size, also restore the binary from Step 1.10:
[ -f /usr/sbin/sgdisk.bak ] && /bin/mv /usr/sbin/sgdisk.bak /usr/sbin/sgdisk

#echo -e "\n# On the Atmos inital master node (found with first command below), enable dial homes using xDoctor (second command below). Investigate any errors or warnings mentioned if they are not related to the proactive disk replacement."
if (( $xdr_disabled_flag )); then 
  echo -en "${lt_gray}"
  read -p "# Would you like to re-enable SYR Dialhomes (xDoctor method)? (y/n) " -t 60 -n 1 enable_xdr
  echo -e "${clear_color}"
  if [[ "$enable_xdr" =~ [yY] ]] ; then
    echo -e "${light_green}# Enabling SYR Dialhomes (xDoctor method) now.\n# Please investigate any errors or warnings mentioned if they are not related to the proactive disk replacement.${clear_color}" 
    ssh $INITIAL_MASTER xdoctor --tool --exec=syr_maintenance --method=enable && xdr_disabled_flag=0
  else 
    echo -e "${magenta}# --Skipping \"Re-enable SYR Dialhomes (xDoctor method)\"${clear_color}"
  fi
fi

echo -e "\n# ${1}\n"
exit $2
}

control_c() {													# run if user hits control-c
  echo -e "\n# Ouch! Keyboard interrupt detected.\n# Cleaning up..."
  cleanup "Done cleaning up, exiting..." 1
}

move_binaries_and_backup(){
#Move the mkfs.ext3 and fdisk binaries to avoid any manual mistakes that would format the disk unexpectedly: (This is not applicable for initial install 2.1 xfs system. If unsure, you can verify by running cat /etc/fstab |grep ${fsuuid_var} |awk '{print $3}'. If it returns xfs, skip to next Step 1.10)
filesystem_type=$(awk -v var=${fsuuid_var} '/var/{print $3}' /etc/fstab) || cleanup "xfs detection failed" 4
if [[ $filesystem_type != "xfs" ]]
then 
	/bin/mv /sbin/mkfs.ext3 /sbin/mkfs.ext3.bak
	/bin/mv /sbin/fdisk /sbin/fdisk.bak   
fi

#Check with df if the DAE disk capacity is 3 TB or more. If so, move the following:
sg_disk_flag=0
for i in `df --block-size=1T | awk '/mauiss/ {print $2}'`
	do (( `echo "$i > 3" | bc -l` )) && sg_disk_flag=1 
done
(( $sg_disk_flag )) && mv /usr/sbin/sgdisk /usr/sbin/sgdisk.bak

#Backup the following configuration files before continuing:
echo -en "\n${lt_gray}# Backing up config files:${clear_color}\t"
spinner_time 1
/bin/cp -fp /etc/maui/node.cfg /etc/maui/node.cfg.bak
/bin/cp -fp /etc/maui/ss_cfg.xml /etc/maui/ss_cfg.xml.bak
/bin/cp -fp /etc/fstab /etc/fstab.bak
echo -e "\b${light_green}Done.${clear_color}"
}
 
get_hardware_gen() {				    # Gets and sets HW Gen.
  hardware_product=`dmidecode | grep -4 -i "system info" | awk '/Product Name/ {print $NF}'`
    case "$hardware_product" in
        1950)                   # > Dell 1950 is the Gen 1 hardware
      hardware_gen=1
      return 0
            ;;
    R610)                       # > Dell r610 is the Gen 2 hardware.
      hardware_gen=2
      return 0
      ;;
    S2600JF)                    # > Product Name: S2600JF is Gen3 
      hardware_gen=3
      return 0
      ;;
        *)  cleanup "Invalid hardware information. Could not determine generation. Please email Claiton.Weeks@emc.com to get corrected. " 51
            ;;
    esac
}

init_colors() {						      # Initialize text color variables.
foreground='\E[39m'
black='\E[30m'
red='\E[31m'
green='\E[32m'
yellow='\E[33m'
blue='\E[34m'
magenta='\E[35m'
cyan='\E[36m'
lt_gray='\E[37m'
dark_gray='\E[90m'
light_red='\E[91m'
light_green='\E[92m'
light_yellow='\E[93m'
light_blue='\E[94m'
light_magenta='\E[95m'
light_cyan='\E[96m'
white='\E[97m'
green2='\E[0;32m'
blue2='\E[1;34m'
boldwhite='\E[1;97m'
orange='\E[0;33m'
default='\E[0m'
clear_color='\E[0m'
}

proactive_mds_replace() {
# # Goal	
# # How to perform a proactive Meta Data Service (MDS) DAE disk replacement.
# # How to manually fail a MDS DAE disk in preparation for replacement.
# # Issue	- xDoctor 4.0.28 and later reports RAP016 SMART Failure Detected.
# # MDS DAE disks in smartctl output have a raw value higher than 10 for attributes Reallocated_Sector_Ct or Offline_Uncorrectable.
# # There may or may not be any I/O errors in /var/log/messages for this DAE disk.
# # There may or may not be an amber fault light turned for this DAE disk.
# # EMC Software: EMC Atmos 1.4.2 and later
# # This statement does not apply: EMC Hardware: EMC Atmos Virtual Edition (VE)
# # This statement does not apply: EMC Software: EMC Atmos 1.4.1 and earlier

# # Resolution	
# # To proactively replace a MDS DAE disk:
# # Disable connect home functionality using the latest xdoctor.
### Step 1: Pre-Checks.
# # Only replace one MDS disk per MDS set.
# # Replacement of MDS disks in different MDS sets can be done in parallel.
# # Take note of any SS disks that may be running recovery, contact the SR owner for the disk recovery and make sure they are aware of the MDS disk issue.
# # Use the below command to see how many SS disks are currently recovering, it may take a couple minutes to receive output:
query_not_rec_disks.py --query

# # This procedure should be followed only for MDS disks that are still connected to an Atmos node. See the beginning of EMC Knowledgebase solution 13492 for how to check if the disk is removed (seen at OS level or not).

# # Determine the filesystem UUID (FSUUID) and device path for the disk you will be working on. 
# # Determine what the /dev/sd* path is based on /dev/sg*. grep that sd* from blkid's output to get the filesystem UUID (in the below we are considering sg3/sdb):
 
#;;# sg_map | grep <appropriate sg* device like sg3>
#;;# blkid | grep <appropriate sd* device like sdb>
  # # For example:
    # # [root@Atmos1-IS1-004 ~]# sg_map | grep sg3
    # # /dev/sg3  /dev/sdb
    # # [root@Atmos1-IS1-004 ~]# blkid | grep sdb
    # # /dev/sdb1: LABEL=" mds" UUID="4679dc68-68f1-4c02-825d-f8b98aab519f" SEC_TYPE="ext2" TYPE="ext3"

### Step 2:  Check the status of the MDS services running on the disk.
# # In this example, Atmos1-IS1-004 has the MDS disk with the issue and the filesystem UUID for the disk is c8199146-1a51-4139-af15-aaa8a29a82da
grep EnvRoot /etc/maui/mds/*/mds_cfg.xml | grep ${fsuuid_var}
  # # The result shows which MDS services are running on the suspect MDS disk.
    # # For Example:
    # # grep EnvRoot /etc/maui/mds/*/mds_cfg.xml | grep c8199146-1a51-4139-af15-aaa8a29a82da
    # # /etc/maui/mds/10401/mds_cfg.xml:  <entry key="bdbxmlEnvRoot" value="/mauimds-db/mds-c8199146-1a51-4139-af15-aaa8a29a82da/slave"/>
    # # /etc/maui/mds/10402/mds_cfg.xml:  <entry key="bdbxmlEnvRoot" value="/mauimds-db/mds-c8199146-1a51-4139-af15-aaa8a29a82da/master"/>
    # # /etc/maui/mds/10601/mds_cfg.xml:  <entry key="bdbxmlEnvRoot" value="/mauimds-db/mds-c8199146-1a51-4139-af15-aaa8a29a82da/remote"/>

# # Check the status of the MDS services above:
# # For local MDS 104xx:
#;;# service mauimds_104xx status 
#;;# mauisvcmgr -s mauimds -c mauimds_isNodeInitialized | grep 104xx
# # For remote MDS 106xx:
#;;# service mauimdsremt_106xx status 
#;;# mauisvcmgr -s mauimds -c mauimds_isNodeInitialized | grep 106xx
# # The MDS services status should be displayed. They can be stopped, running, or dead but sys sublock due to the disk issue.

# # Run rmsview -l mauimds | grep down
# # If there are any MDS services reported down that are not related to this disk, run the MDS Diagnostic tool as per the latest Atmos Procedure Generator.
# # If the output reports all MDS services outside of the MDS services using this disk are initialized and running, continue to Step 3.

### Step 3: Remove the disk.
# # Determine the node UUID for the node with the disk you are working on:
#;;# dmidecode | grep -i uuid

# # Determine the RMG database master node. This will be the first node listed in the following:
#;;# grep localDb /etc/maui/cm_cfg.xml
  # # For example:
    # # [root@Atmos1-IS1-004 ~]# grep localDb /etc/maui/cm_cfg.xml
      # # <entry key="localDb" value="RMG1,Atmos1-IS1-001,Atmos1-IS1-002" />

# # Determine the disk UUID for the disk you are working on using the information from Step 3.1, 3.2 and 1.2 above (single quotes are needed):
psql -U postgres rmg.db -h $RMG_MASTER -c "select uuid from disks where nodeuuid='${node_uuid}' and devpath='${dev_path}'"

# # Remove the disk you are working on with the following (will also trigger disk recovery automatically):
# # For 2.1.x+ code
  cmgenevent --event=disk --type=ioerror --fsuuid=${fsuuid_var}

# # For 2.0 code
  cmgenevent -E "disk" -T "remove" -U ${fsuuid_var}
 
# # NOTE: You may see the following error. This can be ignored if the next step verifies the disk has been removed.
# # Send event to CM failed:
# # Errcode: -3
# # Errmsg: communication failed

# # Check that the disk has been removed, which may take a few minutes.
# # The first command should return a status of 4, indicating the disk is removed at the Atmos level.

# # The second command should contain 'none' for the filesystem UUID of the disk you are working on (same filesystem UUID as Step 2).

# # psql -U postgres rmg.db -h <RMG master node from step 3.2> -c "select slot_id,devpath,status,connected,uuid from disks where nodeuuid='<node UUID from step 3.1>' and devpath='<device path from step 1.2>'"
# # cat /etc/fstab | grep <FSUUID from step 1.2>
# # Check the MDS services running on disk are no longer reported.

# # service mauimds status

# # The MDS services have been removed from chkconfig by CM service which is expected.

# # chkconfig --list | grep mds 

# # The disk is now ready for replacement. Dispatch the MDS disk for replacement as per the latest Atmos Procedure Generator.

# # In the dispatch text, include the following for the CE:

# # Disk Part Number.
# # Hostname of the node with the failed disk.
# # Disk slot-id and device name of the failed disk.
# # fsuuid of the failed disk.

# # Make sure to re-enable connect Home again as per APG.

# # Notes	
# # Atmos Hardware Engineering has determined that a SMART raw value higher than 10 for attributes Reallocated_Sector_Ct or Offline_Uncorrectable indicates that a proactive hardware replacement is needed. The disk may not show signs of failure yet.

# # This solution details how to proactively replace Storage Service DAE disks by failing them out first. See EMC Knowledgebase article [Link Error:UrlName "emc261852-Atmos-xDoctor-RAP016-SMART-Failure-Detected" not found] for the overall issue and also for information about MDS DAE disks and internal disks.
}

proactive_ss_disk_replace_sh() {
#!/bin/bash
#This script is used for proactively replacing SS disks in the field.

# Check if a disk recovery is already running.

echo "`date`: Checking if a disk recovery is already running. " >> diskreplace.log
count=`/usr/local/maui/bin/query_not_rec_disks.py --query|awk {'print $1'}`
if [ $count -ne 0 ];
then
echo "A disk recovery seems to be already running. Ensure /usr/local/maui/bin/query_not_rec_disks.py --query shows no disks are being recovered before running this script again."
exit
fi
/usr/local/maui/bin/query_not_rec_disks.py --query >> diskreplace.log

#Check if the FSUUID is given as an input parameter or not.
if [ $# != 1 ];
then
echo "No FSUUID given: Please run as -- ./Proactive_SS_disk_replace.sh <FSUUID>. Use ./Proactive_SS_disk_replace.sh -h for help."
exit
fi
echo "----------- `date`: Given  FSUUID is $1 ---------------" >> diskreplace.log

#Help on running this tool
if [ "$1" == "-h" ];
then
echo "Usage: ./Proactive_SS_disk_replace.sh <FSUUID of SS Disk>"
exit
fi

#Check if the FSUUID is valid
count=`grep -c $1 /etc/fstab`
if [ $count == 0 ];
then
echo "Invalid FSUUID or The script is not executed on the correct Node"
exit
fi

#Check if the given FSUUID is an SS disk
count=`grep -c "/mauiss-disks/ss-$1" /etc/fstab`
if [ $count == 0 ] ;
then
echo "Given disk is not an SS disk, pleaes verify and provide the correct SS disk FSUUID"
exit
fi


#Verify CC is running on all the nodes
downcc=`rmsview -l mauicc|grep -c down`
if [ $downcc -gt 0 ];
then
echo "CC is down on below node(s), Please start or Fix CC before running this script again."
rmsview -l mauicc|grep down
exit
fi


#Verify if the disk is already disconnected/Unconfigured
check1=`grep $1 /etc/fstab |grep -c none`
check2=`mount|grep -c $1`
if [[ $check1 == 1 || $check2 != 1 ]];
then
echo " The disk seems to be already unconfigured or disconnected"
exit
fi


#Backup /sbin/mkfs.ext3, /sbin/fdisk, /usr/sbin/sgdisk binaries
echo "The status is being written to diskreplace.log file, please read that file for progress status"
echo "`date`: Backing up mkfs.ext3, fdisk binaries " >> diskreplace.log
disksize=`df --block-size=1T| grep $1|awk {'print $2'}`
echo " `date`: Disk size is : $disksize TB" >> diskreplace.log

if [ $disksize -gt 3 ];
then
/bin/ls /sbin/mkfs.ext3 /sbin/fdisk /usr/sbin/sgdisk >> diskreplace.log 2>&1
   if [ $? != 0 ];
    then
    echo "one or more of the binaries from /sbin/mkfs.ext3 /sbin/fdisk /usr/sbin/sgdisk is missing. Restore the binary(s) and run the script again"
    exit
   fi

/bin/mv -f /sbin/mkfs.ext3 /sbin/mkfs.ext3.bak
/bin/mv -f /sbin/fdisk /sbin/fdisk.bak
/bin/mv -f /usr/sbin/sgdisk /usr/sbin/sgdisk.bak


fi

/bin/ls /sbin/mkfs.ext3 /sbin/fdisk >> diskreplace.log 2>&1

if [ $? != 0 ];
    then
    echo "one or more of the binaries from /sbin/mkfs.ext3 /sbin/fdisk is missing. Restore the binary(s) and run the script again"
    exit
   fi
/bin/mv -f /sbin/mkfs.ext3 /sbin/mkfs.ext3.bak
/bin/mv -f /sbin/fdisk /sbin/fdisk.bak

#Backup config files

echo "`date`: Backing up /etc/fstab, /etc/maui/ss_cfg.xml, /etc/maui/node.cfg files " >> diskreplace.log

/bin/cp -p /etc/fstab /etc/fstab.proactive
/bin/mv -f /etc/fstab.proactive /etc/fstab.bak

/bin/cp -p /etc/maui/ss_cfg.xml /etc/maui/ss_cfg.xml.proactive
/bin/mv -f /etc/maui/ss_cfg.xml.proactive /etc/maui/ss_cfg.xml.bak

/bin/cp -p /etc/maui/node.cfg /etc/maui/node.cfg.proactive
/bin/mv -f /etc/maui/node.cfg.proactive /etc/maui/node.cfg.bak

#Triggering Consistency Check for the disk that needs to be replaced

echo "`date`: Triggering Consistency Check for Disk with File System UUID: $1" >> diskreplace.log

diskidx=`grep mauiss /etc/fstab|nl|grep $1|awk '{print $1}'`

host_name=$HOSTNAME

echo "`date`: Executing : mauirexec mauisvcmgr -s mauicc -c trigger_cc_rcvrtask -a 'queryStr=\"DISKID-$host_name:$diskidx\",act=ConsCheck,taskId=$host_name:$diskidx'" >> diskreplace.log

mauirexec "mauisvcmgr -s mauicc -c trigger_cc_rcvrtask -a 'queryStr=\"DISKID-$host_name:$diskidx\",act=ConsCheck,taskId=$host_name:$diskidx'" >> diskreplace.log

CCStatus=Not_Finished
counter=0

echo "`date`: Checking the CC Status " >> diskreplace.log

while [ "$CCStatus" == "Not_Finished" ]
do
    norecordhosts=`mauirexec "mauisvcmgr -s mauicc -c query_cc_rcvrtask -a 'taskId=$host_name:$diskidx'"|grep -c NORECORD`
        if [ $norecordhosts != 0 ];
        then
             echo "`date`: Re-Triggering CC on nodes with NORECORD CC status " >> diskreplace.log

             mauirexec "mauisvcmgr -s mauicc -c query_cc_rcvrtask -a 'taskId=$host_name:$diskidx'"|grep NORECORD -B3|grep host|cut -d ':' -f2 > retriggercc
             for i in `cat retriggercc`;
             do
                ssh $i mauisvcmgr -s mauicc -c trigger_cc_rcvrtask -a 'queryStr=\"DISKID-$host_name:$diskidx\",act=ConsCheck,taskId=$host_name:$diskidx'
             done
             sleep 10
        fi

   inprogresshosts=`mauirexec "mauisvcmgr -s mauicc -c query_cc_rcvrtask -a 'taskId=$host_name:$diskidx'"|grep -c INPROGRESS`
        if [ $inprogresshosts != 0 ];
        then
             echo "`date`: Consistency Check for the disk is still running on some nodes, status will be verified again after Ten minutes" >> diskreplace.log
             sleep 600
             continue
        fi
#Retry triggering CC on hosts returning NORECORD 5 times

   norecordhosts=`mauirexec "mauisvcmgr -s mauicc -c query_cc_rcvrtask -a 'taskId=$host_name:$diskidx'"|grep -c NORECORD`
        if [ $norecordhosts != 0 ];
        then
            counter=$(($counter+1))
            if [ $counter -eq 5 ];
            then
                 echo " `date`: Unable to trigger CC on some nodes, maximum re-tries of 5 already done. Please escalate to L3 for investigation" >> diskreplace.log
                 exit
            fi
           continue
       fi
CCStatus=Finished
echo "`date`: Consistency Check for the disk is successfully completed." >> diskreplace.log
done

# Removing the disk from Atmos by using cmgenevent

rmgmaster=`grep localDb /etc/maui/cm_cfg.xml|cut -d ',' -f2`

diskuid=`psql -U postgres rmg.db -h $rmgmaster -c "select diskuuid from fsdisks where fsuuid='$1'" |awk 'NR==3'|cut -d ' ' -f2`

echo "`date`: DISKUUID of the disk being removed is : $diskuid" >> diskreplace.log
echo "`date`: Trying to remove the disk from configuration" >> diskreplace.log

echo "`date`: Executing : cmgenevent -E disk -T remove -U $diskuid" >> diskreplace.log

cmgenevent -E "disk" -T "remove" -U $diskuid >> diskreplace.log 2>&1

#wait for 5 minutes for the disk to be unconfigured before checking if it has been removed successfully
sleep 300

#Verifying if the disk is successfully unconfigured

Disk_Status=`psql -U postgres rmg.db -h $rmgmaster -c "select status from disks where uuid='$diskuid'"|awk 'NR==3'|awk '{print $1}'`

Check_Fstab=`grep $1 /etc/fstab|grep -c none`

SS_Disk_List=`mauisvcmgr -s mauiss -c disk_status_list | grep -c $1`

if [ $Disk_Status -ne 4 ] || [ $Check_Fstab -ne 1 ] || [ $SS_Disk_List -eq 1 ];
then

echo "`date`: Unable to successfully unconfigre the disk, Please escalate to L3 for further investigation" >> diskreplace.log

exit
fi

echo "`date`: Disk has been removed successfully" >> diskreplace.log

#Restoring the /sbin/fdisk, /sbin/mkfs.ext3 binaries
/bin/mv /sbin/fdisk.bak /sbin/fdisk
/bin/mv /sbin/mkfs.ext3.bak /sbin/mkfs.ext3

if [ $disksize -gt 3 ];
then
/bin/mv /usr/sbin/sgdisk.bak /usr/sbin/sgdisk 
fi
echo "`date`: All steps completed. Please proceed with triggering/monitoring disk recovery for this disk" >> diskreplace.log
echo "======================================================================================================================"
}

main() {
############################################################################################################
###########################################   Start main code..  ###########################################
############################################################################################################
trap control_c SIGINT           # trap keyboard interrupt (control-c)
init_colors                     # Initialize color variables
[[ -z "$1" ]] && cleanup "No option given, try -d to remove a disk by fsuuid." 255  # ## remove after changing to getopts.

#echo -e "\n# Disks already in recovery status: (ctrl+c to exit)"
spinner_time 1
#psql -U postgres -d rmg.db -h $RMG_MASTER -c "select * from recoverytasks where status not in ('1','2');"

# Dependant on input, can use commands below to get fsuuid from sg* or sd* input.
#sg_map | grep <appropriate sg* device like sg7>
#blkid | grep <appropriate sd* device like sdf>

#Check to make sure we are on the problem node.
echo -en "${lt_gray}"
read -p "# Enter node with issue (Leave blank to use current host): " -t 60 problem_node
echo -e "${clear_color}"
spinner_time 1
[[ -z "$problem_node" ]] && problem_node="$HOSTNAME"
[[ "$problem_node" == $HOSTNAME ]] || cleanup "Please run from the problematic node. Cleaning up..." 6

# need to replace with getopt
# Get fsuuid
fail_count=0
[[ "$1" == "-d" ]] && { [[ ! -z "$2" ]] && { fsuuid_var="$2"; validate_fsuuid; } || get_fsuuid; } || cleanup "Invalid option given" 255 

disable_xdoctor             # Disable xDoctor?
set_motd                    # Set MOTD?
move_binaries_and_backup    # Move binaries and backup config files.

## Step 2 only for 2.0.x code. Skipping. 
## Step 3: Remove the disk
echo -e "${lt_gray}"
read -p "# Proceed with removing the disk? (y/n) " -t 60 -n 1 proceed_pdr
echo -e "${clear_color}"
if [[ "$proceed_pdr" =~ [yY] ]]; then 
  echo -e "${light_green}"
	#cmgenevent --event=disk --type=ioerror --fsuuid=${fsuuid_var} || cleanup "cmgenevent failed. May need to restart mauicm." 5
  echo -e "${lt_gray}# Trying to remove disk, can take up to 20 minutes: ${clear_color}" && { while true; do echo -e "cmgenevent --event=disk --type=ioerror --fsuuid=${fsuuid_var}";cmgenevent --event=disk --type=ioerror --fsuuid=${fsuuid_var} && { while true; do echo -en "$(date)\t\t";df -h | grep ${fsuuid_var};((count2++));[[ count%5 -eq 0 ]]&&break||spinner_time 60;done; } || { service mauicm restart && spinner_time 300; }; ((count1++));[[ count%3 -eq 0 ]]&&break||spinner_time 5;done; echo; }
  #[[ -n disk_mounted ]] && echo "hi"
else
	echo -e "${red}# Proactive disk replacement aborted. \n# Performing cleanup.${clear_color}"
  spinner_time 1
	cleanup "Done cleaning up, exiting..." 2
fi

#Check that the disk has been removed, which may take a few minutes. The first command should return a status of 4 for 1.4.2 and 2.0.x and 6 for 2.1.x, indicating the disk is removed at the Atmos level. In 1.4.2 and 2.0.x, the second command should contain 'none' for the filesystem type of the disk you are working on (used to be ext3). In 2.1.x, the second command should not report anything since the old filesystem entry should be gone. The third command should not report anything, indicating that SS is not using the disk.
spinner_time 10
disk_status=$(psql -t -U postgres rmg.db -h $RMG_MASTER -c "select status from disks where nodeuuid='$node_uuid' and devpath='$dev_path';" | awk 'NR==1{print $1}')
echo -e "${lt_gray}# Getting disk status: (select status from disks where nodeuuid='$node_uuid' and devpath='$dev_path')${clear_color}"
spinner_time 1
echo -e "$disk_status"
[[ ! ${disk_status} =~ [46] ]] && echo -e "${red}# Error, disk status should be 6 (2.1+ code) or 4 (pre 2.1 code), indicating the disk is removed at the Atmos level.${clear_color}"

echo -e "${lt_gray}# Code 2.1.x+ - should be no output: (pre 2.1 code should show none for the filesystem type.)${red}"
spinner_time 20
cat /etc/fstab | grep ${fsuuid_var}

echo -e "${lt_gray}# Should be no output: (/etc/fstab and mauisvcmgr -s mauiss -c disk_status_list)${red}"
spinner_time 20
mauisvcmgr -s mauiss -c disk_status_list | grep ${fsuuid_var}
echo -en "${clear_color}"

# Step 4.
echo -e "${lt_gray}# See additional steps for monitoring in KB15810. (Step 5+)"
spinner_time 5
cleanup "Finished." 0

############################################################################################################
###########################################    End main code..   ###########################################
############################################################################################################
}

main $@

# TODO
# implement mds side
# run through old version, and make sure there isn't anything that needs to be incorporated into new.
# 

#Step 5: Monitor SS disk recovery and next steps
#
#Monitor the disk recovery process
# 
#Note: To monitor the disk reovvery process or should it become stuck, see KB article 15854 How to troubleshoot Storage Service (SS) disk recovery issues
#
#Once recovery successfully completed remove the MOTD text that was added previously in Step 1.7.
# 
#vi /etc/motd
#mauiscp /etc/motd /etc/motd
#
#Dispatch for the disk replacement like normal. Make sure to include as much information as possible to facilitate the dispatch (node hostname with disk to be replaced, disk slot number, disk serial number, disk model, correct part number mentioned in the DAE disk replacement procedure, etc). To avoid a requeue, make sure to mention that the disk may not have a fault light on it and the DAE disk replacement procedure should be followed to isolate the disk to be replaced.
