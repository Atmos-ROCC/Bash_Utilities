i#!/bin/bash
#####################################################################
# dispatch_template.sh  -- all Atmos versions                       #
#                                                                   #
# Outputs pre-filled dispatch templates for Atmos.                  #
# Can troubleshoot some issues - see options list.                  #
#                                                                   #
# Created by Claiton Weeks (claiton.weeks<at>emc.com)               #
# Templates based off of CS ROCC team's dispatch templates.         #
#           --Thanks Robert, Kollin, Leo, and everyone else.        #
#                                                                   #
# May be freely distributed and modified as needed,                 #
# as long as proper credit is given.                                #
#                                                                   #
  version=1.2.5b                                                    #
#####################################################################

############################################################################################################
#########################################   Variables/Parameters   #########################################
############################################################################################################
  source_directory="${BASH_SOURCE%/*}"; [[ ! -d "$source_directory" ]] && source_directory="$PWD"
  #. "$source_directory/incl.sh"
  #. "$source_directory/main.sh"
  script_name=dispatch_template.sh 	
  cm_cfg="/etc/maui/cm_cfg.xml" 
  export RMG_MASTER=$(awk -F, '/localDb/ {print $(NF-1)}' $cm_cfg)										# top_view.py -r local | sed -n '4p' | sed 's/.*"\(.*\)"[^"]*$/\1/'
  export INITIAL_MASTER=$(awk -F"\"|," '/systemDb/ {print $(NF-2)}' $cm_cfg)				  # show_master.py |  awk '/System Master/ {print $NF}'
  xdr_disabled_flag=0																					                        # Initialize xdr disable flag.
  node_uuid=$(dmidecode | grep -i uuid | awk '{print $2}')                            # Find UUID of current node.
  cloudlet_name=$(awk -F",|\"" '/localDb/ {print $(NF-3)}' $cm_cfg)
  atmos_ver=$(awk -F\" '/version\" val/ {print $4}' /etc/maui/nodeconfig.xml)
  atmos_ver3=$(awk -F\" '/version\" val/ {print substr($4,1,3)}' /etc/maui/nodeconfig.xml)
  atmos_ver5=$(awk -F\" '/version\" val/ {print substr($4,1,5)}' /etc/maui/nodeconfig.xml)
  atmos_ver7=$(awk -F\" '/version\" val/ {print substr($4,1,7)}' /etc/maui/nodeconfig.xml)
  site_id=$(awk '/site/ {print ($3)}' /etc/maui/reporting/syr_reporting.conf)
  node_location="$(echo $HOSTNAME | cut -c 1-4)_address"
  tla_number=$(awk '/hardware/{if (length($NF)!=14) print "Not found";else print $NF}' /etc/maui/reporting/tla_reporting.conf)
  customer_site_info_file="/usr/local/bin/customer_site_info"
  print_test_switch=0
  
############################################################################################################
###########################################       Functions      ###########################################
############################################################################################################
display_usage() {               # Display usage table.
    cat <<EOF

${light_green}Overview:
    Display pre-filled template to copy/paste into Service Manager for dispatch. 
    Can also help troubleshoot some issues, like DAE fans.
    Send comments or suggestions to claiton.weeks@emc.com.
    
${light_cyan}Synopsis:
  Disk templates:
    `basename $0` -d (<FSUUID>)	# Print MDS/SS/Mixed disk dispatch template, defaults to -k if no or invalid FSUUID specified.
    `basename $0` -e (<FSUUID>)	# Combines -d and -s to print dispatch template, and then update SR#.
    `basename $0` -k		# Runs Kollin's show_offline_disks script first, then asks for fsuuid for dispatch.
    `basename $0` -f		# Troubleshoot DAE fan issues / Print DAE fan replacement template.
    `basename $0` -i		# Internal disk replacement template.
    
    Examples:
    `basename $0` -d        -or-        `basename $0` -d 513b24f9-6af0-41c4-b1f4-d6d131bc50a2
    `basename $0` -e        -or-        `basename $0` -e 513b24f9-6af0-41c4-b1f4-d6d131bc50a2
    
${lt_gray}  Other:
    `basename $0` -h		# Display this usage info (help).
    `basename $0` -b		# Set replacable bit to 1 in recoverytasks table.
    `basename $0` -s		# Update SR# reported in Kollin's show_offline_disks script.
    `basename $0` -v		# Display script's current version.
    `basename $0` -x		# Distribute script to all nodes and set execute permissions.

${dark_gray}  Planned additions:
    `basename $0` -c		# Switch/eth0 connectivity template.
    `basename $0` -l		# LCC replacement template.
    `basename $0` -L		# LCC reseat template.
    `basename $0` -m		# DAE power cycle template.
    `basename $0` -n		# Node replacement template.
    `basename $0` -o		# Reboot / Power On dispatch template.
    `basename $0` -p		# Power Supply replacement template.
    `basename $0` -r		# Reseat disk dispatch template.
    `basename $0` -w		# Private Switch replacement template.
${clear_color}  
EOF
  exit 1
}

cleanup() {                     # Clean-up if script fails or finishes.
  #restore files.. [ -f /usr/sbin/sgdisk.bak ] && /bin/mv /usr/sbin/sgdisk.bak /usr/sbin/sgdisk
  unset fsuuid
  unset sr_number
  unset new_sr_num
  (( $xdr_disabled_flag )) && echo -e "\n## Enabling Dialhomes (xDoctor/SYR) now.\n" && ssh $INITIAL_MASTER xdoctor --tool --exec=syr_maintenance --method=enable && xdr_disabled_flag=0
  
  [[ "$1" != "" && "$2" -ne 0 ]] && echo -e "\n${red}#${clear_color}#${red}# ${1}${clear_color}\n" || echo -e "${clear_color}"
  exit $2
}

control_c() {                   # Runs if user hits Ctrl-C.
  echo -e "\n${orange}## Ouch! Keyboard interrupt detected.\n${green}## Cleaning up..."
  cleanup "Done cleaning up, exiting..." 1
}

prepare_disk_template() {       # Prepares input for use in print_disk_template function.
  # Check if disk is ready for replacement:
  disk_sn_uuid=$(psql -U postgres -d rmg.db -h ${RMG_MASTER} -t -c "select diskuuid from fsdisks where fsuuid='${fsuuid_var}';"| awk 'NR==1{print $1}')
  disk_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select status from disks where uuid='$disk_sn_uuid'"| awk 'NR==1{print $1}')
  disk_replaceable_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select replacable from disks where uuid='$disk_sn_uuid'"| awk 'NR==1{print $1}')
  recovery_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select status from recoverytasks where fsuuid='${fsuuid_var}'"| awk 'NR==1{print $1}')
  if [[ disk_replaceable_status -eq 0 ]]; then
    is_disk_replaceable ${disk_replaceable_status} ${disk_status} ${recovery_status} 
    echo -e "${boldwhite}" 
    read -p "# Are you sure you'd like to proceed? (y/n) " -t 120 -n 1 -s unreplaceable_continue 
    echo -e "${clear_color}" 
    [[ "$unreplaceable_continue" =~ [yY] ]] && echo -e "\n" || cleanup "Please try again once the disk is recovered." 99
  fi
  fail_count=0
  disk_size=`df --block-size=1T | awk '/mauiss/ {n=$2}; END {print n}'`
  set_customer_contact_info
  set_disk_part_info $hardware_gen $disk_size $atmos_ver3
  set_disk_type $hardware_gen $atmos_ver3
  [[ if_mixed ]] && replace_method="Admin GUI or CLI" || replace_method="CLI"
  validate_fsuuid_text_file
  disk_slot=$(psql -U postgres -d rmg.db -h $RMG_MASTER -t -c "select d.slot from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='${fsuuid_var}';" | tr -d ' |\n') 
  psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='${fsuuid_var}';" | egrep -v '^$|row'
  print_disk_template
  
  return 0
}

print_disk_template() {         # Prints disk template to screen.
  printf '%.0s=' {1..80}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nDispatch Reason: Disk Ready for Replacement\nDisk online (Y/N): no\n\nSys. Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDisk Model:\t${model_num}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\nDAE Slot#:\t$disk_slot\nDisk Capacity:\t$disk_size TB\nDisk FSUUID:\t${fsuuid_var}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} DAE Disk for Atmos ${atmos_ver5} using ${replace_method}.\n3- Notify ROCC when disk replacement is completed."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  # echo -e "\nPriority (NBD / ASAP): ASAP\n"		# We currently don't use the priority option - disks should be dispatched as Sev3.
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ${customer_name} prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..80}
  echo -e ""
  
  return 0
}

is_disk_replaceable () { 			  # Checks the status of the recovery and replacement (rewritten from Kollin's show_offline_disks script)
  [[ $(echo ${#disk_sn_uuid}) -ne 8 ]] && return 1
  unrec_obj_num=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select unrecoverobj from recoverytasks where fsuuid='${fsuuid_var}'"| awk 'NR==1{print $1}')
  impacted_obj_num=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select impactobj from recoverytasks where fsuuid='${fsuuid_var}'"| awk 'NR==1{print $1}')
  [[ ${#unrec_obj_num} -eq 0 ]] && percent_recovered=$(echo -e ${light_cyan}"Not found"${white}) || [[ ${unrec_obj_num} -eq 0 || ${impacted_obj_num} -eq 0 ]] && percent_tmp=0 || percent_tmp=$(echo "scale=6; 100-${unrec_obj_num}*100/${impacted_obj_num}"|bc|cut -c1-5)
  percent_recovered=$(echo -e ${light_yellow}${percent_tmp}"%"${lt_gray})
  clear; echo -e "\n\n"
  
  case "$1:$2:$3" in   	# echo "Replacement: ${disk_replaceable_status}  Disk status: ${disk_status}  RecoveryStatus: ${recovery_status}"
        0:*:1)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Cancelled/Paused${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
        0:*:2)  	#echo -e "${green}# Recovery completed, however the replaceable bit needs to be changed to a 1 in the disks table.${lt_gray}"
                  mark_disk_replaceable
            ;;        
        0:*:3)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${green}In Progress		${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
        0:*:[45]) echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${red}FAILED/ABORTED		${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;    
        0:*:6)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Pending			${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
        0:*:*)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Status not found${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
        1:6:*)  	touch /var/service/fsuuid_SRs/${fsuuid_var}.txt
            [[ $(grep -c "^" /var/service/fsuuid_SRs/${fsuuid_var}.txt) -eq 1 ]] && for log in $(ls -t /var/log/maui/cm.log*); do bzgrep -m1 "Successfully updated replacable bit for $disk_sn_uuid" ${log} | awk -F\" '{print $2}' >> /var/service/fsuuid_SRs/${fsuuid_var}.txt && break; done
            [[ $(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | wc -l) -eq 1 ]] && date >> /var/service/fsuuid_SRs/${fsuuid_var}.txt
          set_replaced=$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | tail -1)
          date_replaceable=$(date +%s --date="$set_replaced")
          date_plus_seven=$((604800+${date_replaceable}))
          past_seven=''
          [[ $(date +%s) -ge ${date_plus_seven} ]] && past_seven=$(echo "Disk has been replaceable over 7 days, please check the SR")
          echo -e "Replaceable="${green}"Yes"${white} "DiskSize="${yellow}${fsuuid_var}size"TB"${white} ${past_seven} 
            ;;
    1:4:*)  	echo -e "The disk is set for replaceable, Disk status is set to 4. The disk may not been seen by the hardware" 
      ;;
    1:*:*)  	echo -e "Disk is set for replaceable, but disk status is incorrect. Please update disk status=6 in the disks table" 
      ;;
        *)  exit 1					# Cleanup "Something failed... " 144
            ;;
    esac
  
  return 0
}

validate_fsuuid_text_file(){
  # Append dispatched time to show_offline_disks text file. Need to revise logic to consider for no SR # or no #session.
  [[ -z $fsuuid_var ]] && get_fsuuid
  if [[ ! -e /var/service/fsuuid_SRs/${fsuuid_var}.txt ]]; then 
    echo -e "${red}# No show_offline_disks text file found for fsuuid: ${fsuuid_var}! ${clear_color}"
    read -p "# Would you like to create the file? (y/Y) " -n 1 -s -t 120 create_text_file_flag
    if [[ $create_text_file_flag ]]; then
      [[ -z $sr_number ]] && { read -p "# Enter new SR#: " -t 600 -n 8 new_sr_num && sr_number=${new_sr_num} || cleanup "Timeout: No SR# given." 181; }
      echo -en "${fsuuid_var},${sr_number}" > /var/service/fsuuid_SRs/${fsuuid_var}.txt
      validate_fsuuid_text_file
      return 0
    else cleanup "File not created." 191
    fi
  else
    [[ $print_test_switch -eq 1 ]] && echo "test validate_fsuuid_text_file 1"
    #Check that the file is valid.. fsuuid,sr#session..etc.
    #file_text=$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)
    [[ ! "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*${fsuuid_var}.* ]] && sed -i "1 s/^/${fsuuid_var}/;q" /var/service/fsuuid_SRs/${fsuuid_var}.txt
    [[ ! "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*,.* ]] && sed -i "1 s/${fsuuid_var}/&,/;q" /var/service/fsuuid_SRs/${fsuuid_var}.txt
    [[ "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*,[0-9]{8}.* ]] && sr_number=$(awk -F",|-D|_|#" 'NR==1 {print $2}' /var/service/fsuuid_SRs/${fsuuid_var}.txt) || update_sr_num 1 
    # validate sr number?
    [[ ! "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*${sr_number}.* ]] && update_sr_num 2
    [[ ! "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*session.* ]] && echo "No Session number found."
        [[ $print_test_switch -eq 1 ]] && echo "test validate_fsuuid_text_file 2"

    return 0
  fi
  return 2
}

update_sr_num() {					      # Change the SR number in show_offline_disks script text file.
  if [[ $1 -eq 1 ]]; then
    [[ -z "$sr_number" ]] && { echo -e "${red}# No SR# found in show_offline_disks text file. If new SR is needed, use -u option for site/tla info.${clear_color}";read -p "# Enter SR#: (ctrl-c to quit)" -t 600 -n 8 new_sr_num && { echo; sr_number=${new_sr_num}; } || cleanup "Timeout: No SR# given." 181; }
    sed -i "1 s/,/,${new_sr_num}/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
  elif [[ $1 -eq 2 ]]; then
    echo "# SR# given doesn't match number in show_offline_disks text file. Would you like to update the text file? (y/Y) "
    read -s -n 1 -t 120 update_sr_num_flag;
    [[ "${update_sr_num_flag}" =~ [yY] ]] || return 2
    sed -i "1 s/,/,${new_sr_num}_origSR-/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
  else
    echo -e "# ${red}You've selected to append a new SR to the show_offline_disks script.\nPlease ensure the new SR has been opened against Site ID: ${site_id} TLA: ${tla_number} Host: $HOSTNAME" 		               # Subject: ${New_Subject}"
    validate_fsuuid_text_file
    [[ -z "$new_sr_num" ]] && read -p "# Enter new SR#: " -t 600 -n 8 new_sr_num || cleanup "Timeout: No SR# given." 181
    # validate sr number?      
    ## Write new SR num to txt file.
    sed -i "1 s/,/,${new_sr_num}_origSR-/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
    echo -e "\n# SR# ${new_sr_num} has been added to the show_offline_disks text file.${clear_color}"
  fi
  return 0
}

append_dispatch_date() {			  # Appends dispatch date in show_offline_disks script text file.
  validate_fsuuid_text_file  
  if [[ "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*-Dispatched_[0-1][0-9]-[0-3][0-9]-[0-9][0-9]_.* ]]; then 
    echo -e "${red}# Dispatch date already appended to file. Please check to ensure this disk hasn't already been dispatched against.${clear_color} " 
    read -p "# Would you like to proceed anyways and update the dispatch date? (y/Y) " -s -n 1 -t 120 redispatch_flag
    [[ ${redispatch_flag} =~ [yY] ]] || cleanup "" 192
    sed -i "s/-Dispatched_[0-1][0-9]-[0-3][0-9]-[0-9][0-9]_/-Dispatched_$(date +%m-%d-%y)_/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
  elif
    [[ ! "$(cat /var/service/fsuuid_SRs/${fsuuid_var}.txt | head -1)" =~ .*#session.* ]]; then
    sed -i "1s/\(,[0-9]\{8\}\)\($\)/\1-Dispatched_$(date +%m-%d-%y)_\2/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
  else 
    sed -i "1s/\(,[0-9]\{8\}\)\([#_]\)/\1-Dispatched_$(date +%m-%d-%y)_\2/" /var/service/fsuuid_SRs/${fsuuid_var}.txt
  fi
  echo -e "\n${light_green}# Dispatch date has been appended to show_offline_disks text file: ${clear_color}"
  awk -F"," 'NR==1 {print $0}' /var/service/fsuuid_SRs/${fsuuid_var}.txt
  return 0
}

set_customer_contact_info() {		# Set Customer contact info/location.
  #source_directory="${BASH_SOURCE%/*}"; [[ ! -d "$source_directory" ]] && source_directory="$PWD"
  #. "$source_directory/incl.sh"
  #. "$source_directory/main.sh"
  [[ -f "${customer_site_info_file}" ]] && . "${customer_site_info_file}"
  
  eval is_att_rocc_system=\$$node_location
  if [[ ${#is_att_rocc_system} -gt 0 && "${is_att_rocc_system}" =~ "AT&T"[\ ]* ]] ; then
    customer_name="ROCC"
    cust_con_name="rocc@roccops.com"
    cust_con_numb="877-362-0253"
    cust_con_time="(7x24x356)"
    customer_contact_location="\nSite Location: \n${is_att_rocc_system}\n"
    customer_contact_info="Contact Name:\t${cust_con_name}\nContact Number:\t${cust_con_numb}\nContact Time:\t${cust_con_time}"
  else
    customer_name="customer"
    echo -e "${light_green}"
    read -p "# Enter customer's name: " -t 300 cust_con_name || cleanup "Timed out. Please get the information and try again." 111
    read -p "# Enter customer's number: " -t 300 cust_con_numb || cleanup "Timed out. Please get the information and try again." 112
    read -p "# Enter customer's available contact time: " -t 300 cust_con_time || cleanup "Timed out. Please get the information and try again." 113
    read -p "# Enter site's address: (Press \"Enter\" to skip..)" -t 300 cust_con_location || cleanup "Timed out. Please get the information and try again." 114
    echo -e "${clear_color}"
    customer_contact_info="Contact Name:\t${cust_con_name}\nContact Number:\t${cust_con_numb}\nContact Time:\t${cust_con_time}"
    [[ ${#cust_con_location} -gt 1 ]] && customer_contact_location="\nLocation: ${cust_con_location}\n" || customer_contact_location=""
  fi
  return 0
}

set_disk_type() {					      # Sets disk type.
  if_mixed=$(ssh $RMG_MASTER grep dmMixDriveMode /etc/maui/maui_cfg.xml | grep -c true)
  (( $if_mixed )) && disk_type="MIXED SS/MDS" && return 0
  
  disk_type_temp=$(psql -tq -U postgres rmg.db -h $RMG_MASTER -c "select mnt from filesystems where uuid='${fsuuid_var}'" | awk '{print substr($1,1,6)}')
  [[ "$disk_type_temp" == "/atmos" ]] && disk_type="MDS" || disk_type="SS"
  return 0
}

set_disk_part_info() {				  # Gets and sets disk part info.
  
    case "$1:$2:$3" in   						# hardware_gen:disk_size:atmos_ver3
        1:1:*)  	                  # Gen 1 hardware - 1TB disk
      part_num='005048818'				  # part: 005048818
      model_num='HUA721010KLA330'		# model: HUA721010KLA330
            ;;		
    1:[234]:*)  	                  # Gen 1 Hardware - 2TB,3TB, or 4TB disk
      cleanup "Error: Disk is showing as ${2}TB, but in Gen${1} hardware." 31
            ;;
    2:[14]:*)                     	# Gen 2 Hardware - 1TB or 4TB disk
      cleanup "Error: Disk is showing as ${2}TB, but in Gen${1} hardware." 32
      ;;
    2:2:*)  	                      # Gen 2 hardware - 2TB disk
      part_num='005049565'				  # part: 005049565
      model_num='HUA723020ALA640'		# model: HUA723020ALA640
      ;;
    2:3:*)  	                      # Gen 2 hardware - 3TB disk
      part_num='005049828'				  # part: 005049828
      model_num='HUA723030ALA640'		# model: HUA723030ALA640
      ;;
    3:[12]:*)  	                    # Gen 3 Hardware - 1TB or 2TB disk
      cleanup "Error: Disk is showing as ${2}TB, but in Gen${1} hardware." 31
            ;;
    3:3:*)  	                      # Gen 3 Hardware - 3TB disk
      part_num='005049828'			    # part: 005049828
      model_num='HUA723030ALA640'		# model: HUA723030ALA640
      ;;
    3:4:*)		                      # Gen 3 Hardware - 4TB disk
      part_num='005050062'				  # part: 005050062
      model_num='HUS724040ALA640'		# model: HUS724040ALA640
      ;;
        *)  cleanup "Gen${1} / ${2}TB Disk size combination not supported yet. \nPlease email Claiton.Weeks@emc.com to get corrected. " 4
            ;;
    esac
  return 0
}

get_hardware_gen() {				    # Gets and sets HW Gen.
  hardware_product=$(dmidecode | awk '/Product Name/{print $NF; exit}')
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

get_fsuuid() { 						      # Get fsuuid from user.
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 1"
  if [[ $1 -eq 0 ]]
  then
    [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 2"
    echo -e "\n# Please wait... running ${light_green}show_offline_disks.sh${clear_color}"
    offline_disks=$(/var/service/show_offline_disks.sh -l)
    [[ -z $offline_disks ]] && { echo -e "${light_green}# No offline disks found.\n# Exiting.${clear_color}"; cleanup "" 0; }
  else 
    [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 3"
    echo "# Please choose a fsuuid from an offline disk: "
  fi
  
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 4"
  echo -e "\n${offline_disks}\n\E[21m${clear_color}${light_green}"
  read -p "# Enter fsuuid for disk to dispatch: " -t 120 -n 36 fsuuid_var || cleanup "Timeout: FSUUID not given." 151
  echo -e "${clear_color}\n"
  if [[ ! validate_fsuuid ]]; then
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 6"
    fail_count=$((fail_count+1))
    [[ "$fail_count" -gt 4 ]] && cleanup "Please try again with a valid fsuuid." 60
    #clear
    echo -e "\n\n${red}# Invalid fsuuid attempt: $fail_count, please try again.${clear_color}"
    get_fsuuid $fail_count
    else [[ -n ${fsuuid_var} ]] && dev_path=$(blkid | grep ${fsuuid_var} | sed 's/1.*//')
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 7"
    return 0
  fi 
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 8"
  return 1
  [[ ${print_test_switch} -eq 1 ]] && echo "test get_fsuuid 9"

}

validate_fsuuid() {					    # Validate fsuuid against regex pattern.
  [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 10"
  if [[ -z ${fsuuid_var} ]]; then
    get_fsuuid $fail_count
  else
    valid_fsuuid='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' # Regex to confirm a valid UUID - only allows for hexidecimal characters.
    valid_fsuuid_on_host=$(psql -t -U postgres rmg.db -h $RMG_MASTER -c "select fs.fsuuid from disks d join fsdisks fs ON d.uuid=fs.diskuuid where d.nodeuuid='$node_uuid' and fs.fsuuid='${fsuuid_var}'"| awk 'NR==1{print $1}')
    if [[ ! ${#valid_fsuuid_on_host} -eq 36 ]] ; then
      [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 12"
      echo -e "${red}# FSUUID not found on host.\n# Please try again.${clear_color}"
      get_fsuuid $fail_count
    else
      [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 13"
      [[ "${fsuuid_var}" =~ $valid_fsuuid ]] && return 0 || echo -e "${red}# Invalid fsuuid.${clear_color}" && get_fsuuid
    fi
    [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 14"
    return 1
  fi
  
  [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 15"
  return 1
  # valid_fsuuid='^[[:alnum:]]{8}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{12}$' # Regex to confirm a valid UUID - allows for letters g-z, which aren't allowed 
  # valid_fsuuid='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' # Regex to confirm a valid UUID - allows for capital letters, which aren't allowed.
  # if [[ "${fsuuid_var}" != [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f] ]]
    # then echo -e "${red}# Invalid fsuuid.${clear_color}"
    # get_fsuuid
    # else return 0
  # fi
    [[ ${print_test_switch} -eq 1 ]] && echo "test validate_fsuuid 16"

}

get_abs_path() { 					      # Find absolute path of script.
case "$1" in /*)printf "%s\n" "$1";; *)printf "%s\n" "$PWD/$1";; esac; 
}

distribute_script() {				    # Distribute script across all nodes, and sets permissions.
  full_path=$(get_abs_path $0); this_script=$(basename "$full_path"); this_script_dir=$(dirname "$full_path")
  [[ "$script_name" == "$this_script" ]] || cleanup "Please rename script to $script_name and try again." 20
  echo -en "\n# Distributing script across all nodes.. "
  copy_script=$(mauiscp ${full_path} ${full_path} | awk '/Output/{n=$NF}; !/Output|^$|Runnin/{print n": "$0}' | wc -l)
  [ $copy_script -eq 0 ] && echo -e "${light_green}Done!${clear_color} ($this_script copied to all nodes)" || { echo -e "${red}Failed.${clear_color}";fail_flag=1; fail_text="Failed to copy $this_script to all nodes"; }
  if [[ -e "${customer_site_info_file}" ]]; then
    echo -en "# Detected customer site info file. Distributing file across all nodes.. "
    copy_cust_info_file=$(mauiscp ${customer_site_info_file} ${customer_site_info_file} | awk '/Output/{n=$NF}; !/Output|^$|Runnin/{print n": "$0}' | wc -l)
    [ $copy_cust_info_file -eq 0 ] && echo -e "${light_green}Done!${clear_color} (File copied to all nodes)" || { echo -e "${red}Failed.${clear_color}";fail_flag=1; fail_text="Failed to copy $this_script to all nodes"; }
  fi
  echo -en "# Setting script permissions across all nodes.. "
  set_permissions=$(mauirexec "chmod +x ${full_path}" | awk '/Output/{n=$NF}; !/Output|^$|Runnin/{print n": "$0}' | wc -l)
  [ $set_permissions -eq 0 ] && echo -e "${light_green}Permissions set!${clear_color}" || { echo -e "${red}Failed.${clear_color}";fail_flag=1; fail_text="Failed to set permissions across all nodes"; }
  echo -en "# Creating symlink in /var/service/ "
  [[ -e /var/service/$this_script ]] && /bin/rm -f /var/service/$this_script
  ln -s ${full_path} /var/service/${this_script} && echo -e "${light_green}  ..Done!${clear_color}" || echo -e "${red}  ..Failed.${clear_color}"
  [[ ${fail_flag} -eq 1 ]] && { full_path=$(get_abs_path $0); mauirexec -e "${full_path} -v" | awk '/Output/{n=$NF;m++}; !/Output|^$|Runnin|is 0|dispatch/{l++;print n": Error "}';cleanup "${fail_text}" 21; }
  echo -e "\n\n"
  exit 0
}

update_script(){                # Allows for updating script with passcode.
  full_path=$(get_abs_path $0); this_script=$(basename "$full_path"); this_script_dir=$(dirname "$full_path")
  [[ "$script_name" == "$this_script" ]] || cleanup "Please rename script to $script_name and try again." 20
  read -p "Update script: please enter passcode: " -t 30 -s -n 4 update_passcode_ver || cleanup "Timeout: No passcode given." 253
  echo
  [[ ${update_passcode_ver} == "7777" ]] && vim ${full_path}_tmp && /bin/mv -f ${full_path}_tmp ${full_path} && chmod +x ${full_path} && cleanup "Updated successfully!" 0 || cleanup "update failed..." 254
  cleanup "Wrong passcode entered. Exiting." 255
}

init_colors() {						      # Initialize text color variables.
foreground=$(echo -e "\E[39m")
black=$(echo -e "\E[30m")
red=$(echo -e "\E[31m")
green=$(echo -e "\E[32m")
yellow=$(echo -e "\E[33m")
blue=$(echo -e "\E[34m")
magenta=$(echo -e "\E[35m")
cyan=$(echo -e "\E[36m")
lt_gray=$(echo -e "\E[37m")
dark_gray=$(echo -e "\E[90m")
light_red=$(echo -e "\E[91m")
light_green=$(echo -e "\E[92m")
light_yellow=$(echo -e "\E[93m")
light_blue=$(echo -e "\E[94m")
light_magenta=$(echo -e "\E[95m")
light_cyan=$(echo -e "\E[96m")
white=$(echo -e "\E[97m")
green2=$(echo -e "\E[0;32m")
blue2=$(echo -e "\E[1;34m")
boldwhite=$(echo -e "\E[1;97m")
orange=$(echo -e "\E[0;33m")
default=$(echo -e "\E[0m")
clear_color=$(echo -e "\E[0m")
}

prep_int_disk_template() {      # Prepares input for use in print_int_disk_template function.
  case "${hardware_gen}:${atmos_ver3}" in   						# hardware_gen:atmos_ver3
    1:*)  	                        # Gen 1 hardware
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Gen1: Enter internal disk's device slot/ID ( 0:0:0 / 0:0:1 ) [0 or 1 is fine]: "
        read -t 120 -n 5 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      [[ ${internal_disk_dev_path} == "0" ]] && internal_disk_dev_path="0:0:0"
      [[ ${internal_disk_dev_path} == "1" ]] && internal_disk_dev_path="0:0:1"
      [[ ${internal_disk_dev_path} =~ "0:0:"[01] ]] || cleanup "Internal disk slot#/ID# not recognized." 131
      part_num='105-000-160'				  
      int_disk_description='250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED'
      [[ ${internal_disk_dev_path} == "0:0:0" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" && int_drive_loc_note="Drive ID 0:0:0 is the left drive"
      [[ ${internal_disk_dev_path} == "0:0:1" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" && int_drive_loc_note="Drive ID 0:0:1 is the right drive"
      omreport storage vdisk controller=0|grep "State"; omreport system alertlog | grep -B1 -A4 ": 2095"
      omreport system alertlog | grep -A5 ": Critical"; grep -B1 -A3 'Sense key: 3' /var/log/messages
      print_int_variable_line1="Dev ID/Slot:\t${internal_disk_dev_path}"
      print_int_variable_line2="Note: Each drive’s slot is labeled 0 or 1 at the node. ${int_drive_loc_note}."
      # Gen 1 (Dell 1950 III) Server Platform internal 3.5” SATA Drive: 105-000-160 (250GB)   "250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED"
      # Gen 1 (Dell 1950 III) Server Platform internal 3.5” SATA Drive: 105-000-153 (500GB)   "500GB 7.2K RPM 3.5IN DELL 10K SATA SLED"
      # Note: 105-000-160 and 105-000-153 are compatible. Refer to Product Compatibility Database for latest compatibility information. (https://alliance.emc.com/Pages/PcdHome.aspx)
      ;;		
    2:*)  	                        # Gen 2 Hardware 
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Gen2: Enter internal disk's device slot/ID ( 0:0:0 / 0:0:1 ) [0 or 1 is fine]: "
        read -t 120 -n 5 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      [[ ${internal_disk_dev_path} == "0" ]] && internal_disk_dev_path="0:0:0"
      [[ ${internal_disk_dev_path} == "1" ]] && internal_disk_dev_path="0:0:1"
      [[ ${internal_disk_dev_path} =~ "0:0:"[01] ]] || cleanup "Internal disk slot#/ID# not recognized." 131
      part_num='105-000-179'
      int_disk_description='DELL 250GB 7.2KRPM SATA2.5IN DK 11G SLED'
      [[ ${internal_disk_dev_path} == "0:0:0" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" && int_drive_loc_note="Drive ID 0:0:0 is the top drive"
      [[ ${internal_disk_dev_path} == "0:0:1" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" && int_drive_loc_note="Drive ID 0:0:1 is the bottom drive"
      omreport storage vdisk controller=0|grep "State"; omreport system alertlog | grep -B1 -A4 ": 2095"
      omreport system alertlog | grep -A5 ": Critical"; grep -B1 -A3 'Sense key: 3' /var/log/messages
      print_int_variable_line1="Dev ID/Slot:\t${internal_disk_dev_path}"
      print_int_variable_line2="Note: Each drive’s slot is labeled 0 or 1 at the node. ${int_drive_loc_note}."
      # Gen 2 (Dell R610) Server Platform internal 2.5” SATA Drive: 105-000-179   "DELL 250GB 7.2KRPM SATA2.5IN DK 11G SLED"
      ;;
    3:*)                            # Gen 3 Hardware
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Enter internal disk's device path (sda/sdb): "
        read -t 120 -n 3 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      int_dev_path="/dev/${internal_disk_dev_path}"
      [[ ${internal_disk_dev_path} == "a" ]] && internal_disk_dev_path="sda"
      [[ ${internal_disk_dev_path} == "b" ]] && internal_disk_dev_path="sdb"
      [[ ${internal_disk_dev_path} =~ "sd"[ab] ]] || cleanup "Internal disk device path not recognized." 131
      part_num='105-000-316-00'
      int_disk_description='300GB 2.5" 10K RPM SAS 512bps DDA ATMOS'
      internal_uuid=$(mdadm -D /dev/md126 | awk '/UUID/{print $3}')
      [[ ${internal_disk_dev_path} == "sda" ]] && disk_sn_uuid=$(smartctl -i /dev/sg0 | awk '/Serial number/{print $3}')
      [[ ${internal_disk_dev_path} == "sdb" ]] && disk_sn_uuid=$(smartctl -i /dev/sg1 | awk '/Serial number/{print $3}')
      print_int_variable_line1="Raid UUID:\t${internal_uuid}"
      print_int_variable_line2="Dev Path:\t${int_dev_path}"
      echo -e "\n${light_cyan}# Checking utilization of disks, please wait 30 seconds: (iostat -xk 10 3 /dev/sda /dev/sdb) ${clear_color}\n" && iostat -xk 10 3 /dev/sda /dev/sdb
      echo -e "\n${light_cyan}# Checking Raid status: (cat /proc/mdstat) ${clear_color}\n" && cat /proc/mdstat
      echo -e "\n${light_cyan}# Checking Raid status: (mdadm -D /dev/md126) ${clear_color}\n" && mdadm -D /dev/md126
      echo -e "\n${light_cyan}# Checking Disk status: (mdadm -E ${int_dev_path}) ${clear_color}\n" && mdadm -E ${int_dev_path}
      echo -e "\n${light_cyan}# Checking Disk health: (smartctl -x ${int_dev_path}) ${clear_color}\n" && smartctl -x ${int_dev_path}
      echo -e "\n${light_cyan}# Checking Disk health: (sg_inq ${int_dev_path}) ${clear_color}\n" && sg_inq ${int_dev_path}
      ;;
    *) cleanup "Hardware Gen / Internal disk type detection failed." 130
      ;;
    esac

  set_customer_contact_info
  disk_type='Internal'
  replace_method=" - FRU Replacement Procedure"
  [[ -a /var/service/fsuuid_SRs/${internal_uuid}.txt  ]]  && { fsuuid_var=${internal_uuid};validate_fsuuid_text_file; }
  [[ -a /var/service/fsuuid_SRs/${internal_serial}.txt  ]]  && { fsuuid_var=${internal_serial};validate_fsuuid_text_file; }
  # psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$internal_uuid';" | egrep -v '^$|row'
  # psql -U postgres -d rmg.db -h $RMG_MASTER -tx -c "select * from disks d where d.devpath='${int_dev_path}';"
  
  echo -en "\n${light_green}# Continue printing dispatch template? (y/Y) [Default = y]: ${clear_color}"
  read -t 120 -n 1 print_internal_disk_temp_flag || cleanup "Timeout: No internal disk given." 171
  [[ ${print_internal_disk_temp_flag} =~ [yY] ]] && print_int_disk_template 
  [[ -z ${print_internal_disk_temp_flag} ]] && print_int_disk_template
  return 0
}

print_int_disk_template() {     # Prints internal disk template to screen.
  printf '%.0s=' {1..80}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nReason for Dispatch: Internal* Disk Replacement\n*Note:\tINTERNAL DISK!!!\n\nSys. Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDescription:\t${int_disk_description}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\n${print_int_variable_line1}\n${print_int_variable_line2}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} *Internal* Disk for Atmos ${atmos_ver5}${replace_method}.\n3- Verify correct disk has been replaced by comparing disk serial# shown above, with SN shown on disk."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed *internal* disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ${customer_name} prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..80}
  echo -e ""
  
  return 0
}

prep_dae_fan_template() {       # Prepares input for use in print_dae_fan_template function.
  # Check if disk is ready for replacement:
  echo $cooling_fan_num
  
  if [ -z ${cooling_fan_num} ]; then
    echo -en "\n${light_green}# Enter DAE fan number ( A#0, B#0, C#0, \"Enter\" to troubleshoot ): "
    read -t 300 -n 3 cooling_fan_num
    echo -e "\n${clear_color}"
  fi
  
  [[ "${cooling_fan_num}" =~ [Aa] ]] && cooling_fan_num="A#0" 
  [[ "${cooling_fan_num}" =~ [Bb] ]] && cooling_fan_num="B#0"
  [[ "${cooling_fan_num}" =~ [Cc] ]] && cooling_fan_num="C#0"
  #[[ "${cooling_fan_num}" =~ [ABC] ]] && cooling_fan_num="${cooling_fan_num}#0"
  
  if [ -z "${cooling_fan_num}"  -a "${cooling_fan_num}" != " " ]; then
    enclosure_number=$(cs_hal list enclosures | awk -F"/dev/sg| " '/\/dev\//{print $2}')
    clear
    export GREP_COLORS="sl=37:cx=37"
    echo -e "\n\n\n${cyan}# Following KB# 86979"
    printf '%.0s=' {1..80}
    echo -e "\n# If not running script on node with issue, see KB above for instructions.\n${light_cyan}# Checking all fans: ( 0=A#0 | 1=B#0 | 2=C#0 )${lt_gray}"
    for i in `seq 0 2`; do 
      echo -en "$i: "
      sg_ses /dev/sg${enclosure_number} --index=coo$i 2>/dev/null | egrep "EMC|INVOP|Predicted|Ident" | egrep --color "^|Noncritical|Critical"; done
    echo -e "\n${light_cyan}# Checking DM log: ( /var/log/maui/dm.log )${lt_gray}"
    tac /var/log/maui/dm.log | grep -m3 "Cooling Fan" | tac | egrep --color "^|Cooling Fan [ABC]#0"
    echo -en "\n${light_cyan}# If no alerts after first line, probably false alert: ${clear_color}\n"
    ipmi_alerts=$(ipmitool sel elist)
    [[ $(echo ${ipmi_alerts} | wc -l) -gt 1 ]] && echo -en "${red}${ipmi_alerts}" || echo -en "${light_green}${ipmi_alerts}"
    echo -en "\n\n${light_cyan}# Checking disk temperature.\n${lt_gray}# Temperature Range of all SS disks: ${clear_color}"
    device_list=$(df -h | awk -F1 '/mauiss/{print $1}')
    for dev in $device_list; do smartctl -l scttempsts $dev | awk '/Current/{print $3}';done | sort | uniq | awk 'ORS="";function red(string) { printf ("%s%s%s%s", "\033[1;31m", string, "\033[0;37m", "C"); }; function green(string) { printf ("%s%s%s%s", "\033[1;32m", string, "\033[0;37m", "C"); };NR==1{n=$1};END { m=$1;if (n < 34){print green(n)" - "} else {print red(n)" - "};{if (m < 37){print green(m)} else {print red(m)}}}' 
    echo -e "\n${lt_gray}# *Note: The temperature of disks will vary based on the model and the activity and location.\n\n${light_cyan}# Either way, dispatch out to have the CE check the DAE for amber alert.\n${lt_gray}# For other DAE hardware errors, check the following logs: \ngrep DAE /var/log/maui/dm.log /var/log/messages\n\tError detected on DAE %s. Error details: %s.${clear_color}\n\n\n"
    sleep 6; echo -e "\n\n\n\n";prep_dae_fan_template 1; fi
  [[ "${cooling_fan_num}" =~ [ABCabc]"#0" ]] || cleanup "DAE Fan number not recognized." 131

  set_customer_contact_info
  
  # set cooling fan part number
  case "${hardware_gen}:${atmos_ver3}" in  # hardware_gen:atmos_ver3
    1:*)  	                        # Gen 1 hardware
      part_num='303-173-000B'				  
      fan_description='Front Fan control module'
      ;;		
    2:*)  	                        # Gen 2 Hardware 
      part_num='303-173-000B'
      fan_description='Front Fan control module'
      ;;
    3:*)                            # Gen 3 Hardware
      part_num='303-173-000B'
      fan_description='Front Fan control module'
      ;;
    *) cleanup "Hardware Gen / DAE Fan part number detection failed." 130
      ;;
  esac

  replace_method=" - FRU Replacement Procedure"
  
  # psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$internal_uuid';" | egrep -v '^$|row'
  # psql -U postgres -d rmg.db -h $RMG_MASTER -tx -c "select * from disks d where d.devpath='${int_dev_path}';"
  
  print_dae_fan_template 
  [[ $1 ]] && cleanup "" 0
  return 0
}

print_dae_fan_template() {      # Prints dae fan template to screen.
  printf '%.0s=' {1..80}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nReason for Dispatch: DAE Fan Replacement\n\nSys. Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nError details:\tCooling Fan ${cooling_fan_num}\nPart Number:\t${light_green}${part_num}${lt_gray} - ${fan_description}"
  echo -e "\nCE Action Required:  Please check cooling fan on DAE."
  printf '%.0s-' {1..48}
  echo -e "\n1- Contact ROCC and arrange for DAE cooling fan replacement prior to going on site.\n2- Attention: Possible false alert, please verify the DAE fan modules are all showing green and are functioning.\n - Note: Fans are located across the front of the DAE and numbered 0-2, left to right.\n - Note: If all green lights / no further DAE issues seen, then close task and SR.\n - Note: If any fan is showing amber alert, follow procedure document for replacing GEN${hardware_gen} DAE cooling fan for Atmos ${atmos_ver5}.\n3- Select the Gen${hardware_gen} Series FRU component you wish to replace: G${hardware_gen} Series - DAE7S Fan Module\n    a- Remove the failed fan.\n    b- Reseat to see if it returns to green.\n    c- If it stays green - wait 5 minutes and if no change, close out the task and close the SR.\n    d- If it stays amber or changes to amber, then replace fan.\n    e- After replacing the failed fan - verify the DAE amber fault LED transitions to OFF, and the replacement fan has no amber fault LEDs.\nNote: Please add a note to the SR if the fan with the amber alert is different than the fan specified above.\nNote: If you cannot locate the DAE - \"no amber fault light found\" - log onto the node specified above and use the following commands:\n# cs_hal list enclosures\t(Should return /dev/sg2 or /dev/sg3)\n# cs_hal led /dev/sg2 blink\t(Will blink the DAE led)\n# cs_hal led /dev/sg2 off\t(Will turn off the blinking led on the DAE)"
  [[ $node_location != "lond" || $node_location != "amst" ]] && echo -e "*Note: If any assistance is needed, contact your FSS."
  echo -e "\nIssue Description: Failed DAE fan check / replace."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ${customer_name} prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..80}
  echo -e ""
  
  return 0
}

mark_disk_replaceable(){
  # from KB 000088361 
  # https://emc--c.na5.visual.force.com/apex/KB_BreakFix_1?id=kA1700000000QPP

  # One-liner:
  echo -e "\n"
  [[ -z $fsuuid_var ]] && read -p "## Enter FSUUID: " -t 60 -n 36 fsuuid_var; echo
  psql -U postgres -d rmg.db -h $RMG_MASTER -tqxc "select d.uuid \"Disk Serial\",d.devpath,d.slot,d.connected,d.slot_replaced,d.status \"Disk status\",d.replacable,r.status \"Recovery status\",r.unrecoverobj from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid JOIN recoverytasks r ON fs.fsuuid=r.fsuuid where fs.fsuuid='$fsuuid_var';"
  is_replaceable=$(psql -U postgres -d rmg.db -h $RMG_MASTER -tq -c "select d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='${fsuuid_var}';" | tr -d ' |\n')
  disk_uuid=$(psql -U postgres -d rmg.db -h $RMG_MASTER -tq -c "select d.uuid from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='${fsuuid_var}';" | tr -d ' |\n') 
  echo -e "\n"
  [[ $is_replaceable ]] && { read -p "## The disk is not currently replaceable. Would you like to update replacable bit? (y/n) " -t 60 -n 1 update_replaceable_confirm; echo; }
  if [[ "$update_replaceable_confirm" =~ [yY] ]]; then echo -e "\n" ;\
    psql -U postgres -d rmg.db -h $RMG_MASTER -c "UPDATE disks SET replacable=1 WHERE uuid='${disk_uuid}';" ; echo; \
    psql -U postgres -d rmg.db -h $RMG_MASTER -tqxc "select d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='${fsuuid_var}';" ;\
    mauisvcmgr -s mauicm -c mauicm_cancel_recover_disk -a "host=$HOSTNAME,fsuuid=${fsuuid_var}" -m $HOSTNAME ;\
    psql -U postgres -d rmg.db -h $RMG_MASTER -c "UPDATE recoverytasks SET status=2 WHERE fsuuid='${fsuuid_var}';" ;\
    psql -U postgres -d rmg.db -h $RMG_MASTER -tqxc "select d.uuid \"Disk Serial\",d.devpath,d.slot,d.connected,d.slot_replaced,d.status \"Disk status\",d.replacable,r.status \"Recovery status\",r.unrecoverobj from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid JOIN recoverytasks r ON fs.fsuuid=r.fsuuid where fs.fsuuid='$fsuuid_var';"
  else \
    echo -e "\n## No updates performed. " ;\
  fi
  return 0
}

show_system_info(){
  echo -e "\n# `basename $0` version: $version\n"
  maui_ver=$(cat /etc/maui/maui_version)
  atmos_hotfixes=$(awk -F\" '/value=/ {if($2=="hotfixes") if($4=="")printf "None found"; else printf $4}' /etc/maui/nodeconfig.xml)
  echo -e "Site ID: \t${site_id}\t\tTLA:\t${tla_number}"
  echo -e "Hardware:\t${hardware_product} \tGen:\t${hardware_gen}"
  
  echo -e "\n\t\t\t(maui_version file)\t(nodeconfig.xml)\nAtmos Version:\t\t${maui_ver}\t\t${atmos_ver}\nInstalled Hotfixes:\t${atmos_hotfixes}\n"
  dmidecode | grep -i 'system information' -A4 && xdoctor -v | xargs -I{} echo 'xDoctor Version {}' && (ls -l /var/service/AET/workdir || ls -l /var/support/AET/workdir ) 2>/dev/null | awk '{print $11}'&& xdoctor -y | grep 'System Master:' | awk '{print $3,$4,$5}';echo -e "-------\n\n"
}

prep_lcc_templates() {      # Prepares input for use in print_int_disk_template function.

      # Parts
      # · 303-171-000B  – VOYAGER 6G SAS LCC ASSY - G3-DENSE Model ONLY
      # · 303-171-002C-00 - VOYAGER 6G SAS LCC ASSY W/ 8K EPROM - G3-FLEX Model ONLY
      # note: The above LCCs are not compatible and cannot be interchanged.
      # The following steps can be used to determine the defective LCC part number required for replacement.
      # 1. Establish a secure shell (SSH) session to any node within the Install Segment (IS) of the failing LCC.
      # 2. Type the following commands to assist in determining which LCC part number is being used in DAEs within the IS. If the Ext Disks = 30 or less, than order 303-171-002C-00, else order 303-171-000B .
        # # cs_hal list enclosures
        # Enclosure(s):
        # SCSI Device Ext Disks
        # ----------- ---------
        # /dev/sg2     30   < 30 disks = 303-172-002D-001
        #  
        # total: 1
      # note: G3-FLEX is supported on Atmos software release 2.1.4.0 and above, configured with 30 disks in each DAE.

  case "${hardware_gen}:${atmos_ver3}" in   						# hardware_gen:atmos_ver3
    1:*)  	                        # Gen 1 hardware
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Gen1: Enter internal disk's device slot/ID ( 0:0:0 / 0:0:1 ) [0 or 1 is fine]: "
        read -t 120 -n 5 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      [[ ${internal_disk_dev_path} == "0" ]] && internal_disk_dev_path="0:0:0"
      [[ ${internal_disk_dev_path} == "1" ]] && internal_disk_dev_path="0:0:1"
      [[ ${internal_disk_dev_path} =~ "0:0:"[01] ]] || cleanup "Internal disk slot#/ID# not recognized." 131
      part_num='105-000-160'				  
      int_disk_description='250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED'
      [[ ${internal_disk_dev_path} == "0:0:0" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" && int_drive_loc_note="Drive ID 0:0:0 is the left drive"
      [[ ${internal_disk_dev_path} == "0:0:1" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" && int_drive_loc_note="Drive ID 0:0:1 is the right drive"
      omreport storage vdisk controller=0|grep "State"; omreport system alertlog | grep -B1 -A4 ": 2095"
      omreport system alertlog | grep -A5 ": Critical"; grep -B1 -A3 'Sense key: 3' /var/log/messages
      print_int_variable_line1="Dev ID/Slot:\t${internal_disk_dev_path}"
      print_int_variable_line2="Note: Each drive’s slot is labeled 0 or 1 at the node. ${int_drive_loc_note}."
      # Gen 1 (Dell 1950 III) Server Platform internal 3.5” SATA Drive: 105-000-160 (250GB)   "250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED"
      # Gen 1 (Dell 1950 III) Server Platform internal 3.5” SATA Drive: 105-000-153 (500GB)   "500GB 7.2K RPM 3.5IN DELL 10K SATA SLED"
      # Note: 105-000-160 and 105-000-153 are compatible. Refer to Product Compatibility Database for latest compatibility information. (https://alliance.emc.com/Pages/PcdHome.aspx)
      ;;		
    2:*)  	                        # Gen 2 Hardware 
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Gen2: Enter internal disk's device slot/ID ( 0:0:0 / 0:0:1 ) [0 or 1 is fine]: "
        read -t 120 -n 5 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      [[ ${internal_disk_dev_path} == "0" ]] && internal_disk_dev_path="0:0:0"
      [[ ${internal_disk_dev_path} == "1" ]] && internal_disk_dev_path="0:0:1"
      [[ ${internal_disk_dev_path} =~ "0:0:"[01] ]] || cleanup "Internal disk slot#/ID# not recognized." 131
      part_num='105-000-179'
      int_disk_description='DELL 250GB 7.2KRPM SATA2.5IN DK 11G SLED'
      [[ ${internal_disk_dev_path} == "0:0:0" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:0" && int_drive_loc_note="Drive ID 0:0:0 is the top drive"
      [[ ${internal_disk_dev_path} == "0:0:1" ]] && disk_sn_uuid=$(omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" | awk '/Serial No./{print $4}') && omreport storage pdisk controller=0 | grep -A28 ": 0:0:1" && int_drive_loc_note="Drive ID 0:0:1 is the bottom drive"
      omreport storage vdisk controller=0|grep "State"; omreport system alertlog | grep -B1 -A4 ": 2095"
      omreport system alertlog | grep -A5 ": Critical"; grep -B1 -A3 'Sense key: 3' /var/log/messages
      print_int_variable_line1="Dev ID/Slot:\t${internal_disk_dev_path}"
      print_int_variable_line2="Note: Each drive’s slot is labeled 0 or 1 at the node. ${int_drive_loc_note}."
      # Gen 2 (Dell R610) Server Platform internal 2.5” SATA Drive: 105-000-179   "DELL 250GB 7.2KRPM SATA2.5IN DK 11G SLED"
      ;;
    3:*)                            # Gen 3 Hardware
      if [ -z ${internal_disk_dev_path} ] || [ -n ${internal_disk_dev_path} ]; then
        echo -en "\n${light_green}# Enter internal disk's device path (sda/sdb): "
        read -t 120 -n 3 internal_disk_dev_path || cleanup "Timeout: No internal disk given." 171
        echo -e "\n${clear_color}"
      fi
      int_dev_path="/dev/${internal_disk_dev_path}"
      [[ ${internal_disk_dev_path} == "a" ]] && internal_disk_dev_path="sda"
      [[ ${internal_disk_dev_path} == "b" ]] && internal_disk_dev_path="sdb"
      [[ ${internal_disk_dev_path} =~ "sd"[ab] ]] || cleanup "Internal disk device path not recognized." 131
      part_num='105-000-316-00'
      int_disk_description='300GB 2.5" 10K RPM SAS 512bps DDA ATMOS'
      internal_uuid=$(mdadm -D /dev/md126 | awk '/UUID/{print $3}')
      [[ ${internal_disk_dev_path} == "sda" ]] && disk_sn_uuid=$(smartctl -i /dev/sg0 | awk '/Serial number/{print $3}')
      [[ ${internal_disk_dev_path} == "sdb" ]] && disk_sn_uuid=$(smartctl -i /dev/sg1 | awk '/Serial number/{print $3}')
      print_int_variable_line1="Raid UUID:\t${internal_uuid}"
      print_int_variable_line2="Dev Path:\t${int_dev_path}"
      echo -e "\n${light_cyan}# Checking utilization of disks, please wait 30 seconds: (iostat -xk 10 3 /dev/sda /dev/sdb) ${clear_color}\n" && iostat -xk 10 3 /dev/sda /dev/sdb
      echo -e "\n${light_cyan}# Checking Raid status: (cat /proc/mdstat) ${clear_color}\n" && cat /proc/mdstat
      echo -e "\n${light_cyan}# Checking Raid status: (mdadm -D /dev/md126) ${clear_color}\n" && mdadm -D /dev/md126
      echo -e "\n${light_cyan}# Checking Disk status: (mdadm -E ${int_dev_path}) ${clear_color}\n" && mdadm -E ${int_dev_path}
      echo -e "\n${light_cyan}# Checking Disk health: (smartctl -x ${int_dev_path}) ${clear_color}\n" && smartctl -x ${int_dev_path}
      echo -e "\n${light_cyan}# Checking Disk health: (sg_inq ${int_dev_path}) ${clear_color}\n" && sg_inq ${int_dev_path}
      ;;
    *) cleanup "Hardware Gen / Internal disk type detection failed." 130
      ;;
    esac

  set_customer_contact_info
  disk_type='Internal'
  replace_method=" - FRU Replacement Procedure"
  [[ -a /var/service/fsuuid_SRs/${internal_uuid}.txt  ]]  && { fsuuid_var=${internal_uuid};validate_fsuuid_text_file; }
  [[ -a /var/service/fsuuid_SRs/${internal_serial}.txt  ]]  && { fsuuid_var=${internal_serial};validate_fsuuid_text_file; }
  # psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$internal_uuid';" | egrep -v '^$|row'
  # psql -U postgres -d rmg.db -h $RMG_MASTER -tx -c "select * from disks d where d.devpath='${int_dev_path}';"
  
  echo -en "\n${light_green}# Continue printing dispatch template? (y/Y) [Default = y]: ${clear_color}"
  read -t 120 -n 1 print_internal_disk_temp_flag || cleanup "Timeout: No internal disk given." 171
  [[ ${print_internal_disk_temp_flag} =~ [yY] ]] && print_int_disk_template 
  [[ -z ${print_internal_disk_temp_flag} ]] && print_int_disk_template
  return 0
}

print_lcc_replace_template() {     # Prints internal disk template to screen.
  cleanup "Function currently being developed." 1
      # CST please create a Task for the field CE from the information below.

      # Task Type: Corrective Maintenance
      # SN of Box:  <TLA Serial #> 

      # Reason for Dispatch: LCC Replacement
      # Online (Y/N):  < Yes  or No>

      # Node: <node name here>   
      # System Serial #: <system serial # if available> 
      # Part Number:  303-171-000B < All Beatle are this type - Check for others - See above>

      # Location: 
      # < Paste Address Here>

      # CE Action Required:  contact ROCC and arrange for LCC replacement

      # Replace LCC following Atmos Procedure Document - 
      # G3 Series - DAE7S Link Control Card (LCC)

      # Follow all steps in document.

      # Contact Name: rocc@roccops.surr
      # Contact Number and Time: 877-362-0253   7x24x356
      # Priority (NBD / ASAP): ASAP

      # Next Action: dispatch CE onsite

      # Please Dispatch the CE to contact ROCC and complete the above tasks in their entirety.






      # Disp Notification - Generic

      # CST please create a Task for the field CE from the information below.

      # Task Type: Corrective Maintenance
      # SN of Box:   APM00133861725

      # Reason for Dispatch: LCC Replacement
      # Online (Y/N): Yes

      # Node:  lond01a01-is5-008
      # System Serial #:  FC6AT133900072

      # Part Number:  303-171-000B 

      # Location: 
      # AT&T SOLUTIONS C/O AT&T ENTERPRISE HOSTING LONDON UK
      # UNIT 21 SENTRUM IV FACILITY
      # GOLDSWORTH PARK TRADING ESTATE
      # WOKING  SURREY    GB     GU21 3BA

      # CE Action Required:  contact ROCC and arrange for possible LCC replacement


      # Follow the steps in the Replace LCC following Atmos Procedure Document -  G3 Series - DAE7S Link Control Card (LCC

      # - up to step # 19 on page 17.  
      # After step 18, 

      # Power off DAE 

      # Then proceed following steps up to # 24 on page 19.   
      # Reseat all LCC units.

      # Power on DAE - wait at least 5 -10  minutes for drives to spin up.

      # Check for any amber fault light - If an amber fault light on DAE is found, proceed to replace the faulty LCC.

      # If no amber fault light is found - power back on node - and monitor boot process. 

      # Follow document steps # 27 - # 37  

      # When node is back up - ssh to node and check to see if all 48 SS disks are now seen using this command - 

      # # df -h | grep mauiss | wc -l

      # If count is not = 48, then restart LCC replacement - looking for amber fault light - use the following  document :

      # Replace LCC following Atmos Procedure Document - 
      # G3 Series - DAE7S Link Control Card (LCC)

      # Follow all steps in document.

      # Contact Name: rocc@roccops.com
      # Contact Number and Time: 877-362-0253   7x24x356
      # Priority (NBD / ASAP): ASAP

      # Next Action: dispatch CE onsite


      # Please Dispatch the CE to contact ROCC and complete the above tasks in their entirety.
  printf '%.0s=' {1..80}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nReason for Dispatch: Internal* Disk Replacement\n*Note:\tINTERNAL DISK!!!\n\nSys. Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDescription:\t${int_disk_description}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\n${print_int_variable_line1}\n${print_int_variable_line2}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} *Internal* Disk for Atmos ${atmos_ver5}${replace_method}.\n3- Verify correct disk has been replaced by comparing disk serial# shown above, with SN shown on disk."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed *internal* disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ${customer_name} prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..80}
  echo -e ""
  
  return 0
}

print_lcc_reseat_template() {     # Prints internal disk template to screen.
  printf '%.0s=' {1..80}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nReason for Dispatch: Internal* Disk Replacement\n*Note:\tINTERNAL DISK!!!\n\nSys. Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDescription:\t${int_disk_description}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\n${print_int_variable_line1}\n${print_int_variable_line2}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} *Internal* Disk for Atmos ${atmos_ver5}${replace_method}.\n3- Verify correct disk has been replaced by comparing disk serial# shown above, with SN shown on disk."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed *internal* disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ${customer_name} prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..80}
  echo -e ""
  
  return 0
}

###########################################   Start main code..  ###########################################
## Initialize color variables
############################################################################################################
main() {    ################################################################################################
init_colors
get_hardware_gen

## Trap keyboard interrupt (control-c)
trap control_c SIGINT

## If more than 2 options
## Check if correct number of options were specified.
[[ $# -lt 1 || $# -gt 2 ]] && echo -e "\n${red}Invalid number of options, see usage:${clear_color}" && display_usage

## Check if option is blank.
# [[ $1 ]] && echo -e "\n${red}Invalid option, see usage:${clear_color}" && display_usage
[[ $1 == "-\$" || $1 == "?" ]] && echo -e "\n${red}Invalid option, see usage:${clear_color}" && display_usage

## Check for invalid options:
if ( ! getopts ":bcdefiklmnoprsuvVwxyz" options ); then echo -e "\n${red}Invalid options, see usage:${clear_color}" && display_usage; fi

## Parse the options:
while getopts ":bcdefiklmnoprsuvVwxyz" options
do
    case $options in
    b)  mark_disk_replaceable
        ;;
    c)  cleanup "Not supported yet, will print switch/eth0 connectivity dispatch template." 99
        ;;
    d)  fsuuid_var="$2"
        validate_fsuuid 
        prepare_disk_template
        append_dispatch_date
        ;;
    e)  fsuuid_var="$2"
        validate_fsuuid 
        prepare_disk_template
        update_sr_num
        append_dispatch_date
        ;;
    f)  cooling_fan_num="$2"
        prep_dae_fan_template
        ;;
    i)  internal_disk_dev_path="$2"
        prep_int_disk_template
        ;;
    k)  get_fsuuid
        prepare_disk_template
        ;;
    l)  prep_lcc_templates
        ;;			
    m)  get_fsuuid 0
        prepare_disk_template
        append_dispatch_date
        ;;
    n)	cleanup "Not supported yet, will print node replacement template." 99
        ;;
    o)	cleanup "Not supported yet, will print node reboot/power on template." 99
        ;;
    p)	cleanup "Not supported yet, will print power supply replacement template." 99
        ;;
    r)	cleanup "Not supported yet, will print reseat disk template." 99
        ;;
    s)	update_sr_num
        ;;
    u)	update_sr_num
        ;;
    v)	echo -e "# `basename $0` version: $version\n"
        exit 0
        ;;
    V)  show_system_info
        ;;
    w)	cleanup "Not supported yet, will print private switch replacement template." 99
        ;;
    x)  distribute_script
        ;;
    y)  update_script
        distribute_script
        ;;
    z)  full_path=$(get_abs_path $0);
        [[ "${print_test_switch}" -eq 1 ]] && sed -i '30,40s/  print_test_switch=1/  print_test_switch=0/' ${full_path} || sed -i '30,40s/  print_test_switch=0/  print_test_switch=1/' ${full_path}
        ;;
    :)  # Multiple options..
        #echo "testing.. mult options."
        fsuuid_var="$2"
        [[ "$OPTARG" =~ [de] ]] && validate_fsuuid
        [[ "$OPTARG" =~ [de] ]] && prepare_disk_template
        [[ "$OPTARG" == "e" ]] && update_sr_num
        [[ ! "$OPTARG" =~ [de] ]] && display_usage
        ;;
    \?) echo -e "# Invalid option: -$OPTARG" >&2
        display_usage
        ;;
    *)  echo -e "# Invalid option: -$OPTARG" >&2
        display_usage
        ;;
    esac
done

##Exit successfully if script reaches this point.
cleanup "---" 0
}

# Call main function.
main "$@"

# TODO
# fsuuid valid on current node.                                             - done
# customer contact info to text file?                                       - done
# complete other dispatch templates.                                        - 0/7
    # # `basename $0` -c		# Switch/eth0 connectivity template.            - pending
    # # `basename $0` -l		# LCC replacement template.                     - in progress
    # # `basename $0` -n		# Node replacement template.                    - pending
    # # `basename $0` -o		# Reboot / Power On dispatch template.          - pending
    # # `basename $0` -p		# Power Supply replacement template.            - pending      #66679408  sndg01k01-is4-004  'Power Supply Redundancy' 'SENSOR_NON_RECOVERABLE'
    # # `basename $0` -r		# Reseat disk dispatch template.                - pending
    # # `basename $0` -w		# Private Switch replacement template.          - pending
# BZ standardized templates.                                                - pending

###########################################       Testing..       ##########################################
############################################################################################################
############################################################################################################
# Testing: 
# Gen1: dfw01-is01-003
# Gen2: iad01-is05-006
# Gen3: lis1d01-is5-001
# amst a,  rwc a, tkyo a, tyo1/syd1
# script_loc="/usr/local/bin";time for x in `cat /var/service/list`; do echo -n "$x  -  ";ssh $x 'echo "$HOSTNAME"'; echo -n "# Copying script: ";scp $script_loc/dispatch_template.sh $x:$script_loc/ ; [[ -e /usr/local/bin/customer_site_info ]] && scp /usr/local/bin/customer_site_info $x:/usr/local/bin/;ssh $x "sh $script_loc/dispatch_template.sh -x"; done
