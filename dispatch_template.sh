i#!/bin/bash
#####################################################################
# dispatch_template.sh  -- all Atmos versions                       #
#                                                                   #
# Outputs pre-filled dispatch templates for Atmos.                  #
#                                                                   #
# Created by Claiton Weeks (claiton.weeks@emc.com)                  #
#                                                                   #
# Templates based off of Robert Schloss's dispatch templates.       #
#           --Thanks Robert!                                        #
#                                                                   #
# May be freely distributed and modified as needed,                 #
# as long as proper credit is given.                                #
#                                                                   #
  version=1.2.1                                                     #
#####################################################################

############################################################################################################
#########################################   Variables/Parameters   #########################################
############################################################################################################
  script_name=dispatch_template.sh 	
  cm_cfg="/etc/maui/cm_cfg.xml" 
  export RMG_MASTER=`awk -F, '/localDb/ {print $(NF-1)}' $cm_cfg`										# top_view.py -r local | sed -n '4p' | sed 's/.*"\(.*\)"[^"]*$/\1/'
  export INITIAL_MASTER=`awk -F"\"|," '/systemDb/ {print $(NF-2)}' $cm_cfg`				  # show_master.py |  awk '/System Master/ {print $NF}'
  xdr_disabled_flag=0																					                      # Initialize xdr disable flag.
  node_uuid=`dmidecode | grep -i uuid | awk {'print $2'}`                           # Find UUID of current node.
  cloudlet_name=`awk -F",|\"" '/localDb/ {print $(NF-3)}' $cm_cfg`
  atmos_ver=`awk -F\" '/version\" val/ {print $4}' /etc/maui/nodeconfig.xml`
  atmos_ver3=`awk -F\" '/version\" val/ {print substr($4,1,3)}' /etc/maui/nodeconfig.xml`
  atmos_ver5=`awk -F\" '/version\" val/ {print substr($4,1,5)}' /etc/maui/nodeconfig.xml`
  atmos_ver7=`awk -F\" '/version\" val/ {print substr($4,1,7)}' /etc/maui/nodeconfig.xml`
  site_id=`awk '/site/ {print ($3)}' /etc/maui/reporting/syr_reporting.conf`
  node_location="`echo $HOSTNAME | cut -c 1-4`_address";
  tla_number=`awk '/hardware/ {if (length($NF)!=14) print "Not found";else print $NF }' /etc/maui/reporting/tla_reporting.conf`
    

############################################################################################################
###########################################       Functions      ###########################################
############################################################################################################
display_usage() {               # Display usage table.
    cat <<EOF
Overview:
    Display pre-filled template to copy/paste into Service Manager for dispatch.

Synopsis:
  Disk templates:
    `basename $0` -d (<FSUUID>)	# Print MDS/SS/Mixed disk dispatch template, defaults to -k if no or invalid FSUUID specified.
    `basename $0` -e (<FSUUID>)	# Combines -d and -s to print dispatch template, and then update SR#.
    `basename $0` -k		# Runs Kollin's show_offline_disks script first, then asks for fsuuid for dispatch.
    `basename $0` -i		# Internal disk replacement template.

  Examples:
    `basename $0` -d 513b24f9-6af0-41c4-b1f4-d6d131bc50a2
    `basename $0` -e 513b24f9-6af0-41c4-b1f4-d6d131bc50a2
    `basename $0` -k
    `basename $0` -i
  
  Other:
    `basename $0` -h		# Display this usage info (help).
    `basename $0` -s		# Update SR# reported in Kollin's show_offline_disks script.
    `basename $0` -v		# Display script's current version.
    `basename $0` -x		# Distribute script to all nodes and set execute permissions.

  Planned additions:
    `basename $0` -c		# Switch/eth0 connectivity template.
    `basename $0` -f		# DAE fan repalcement template.
    `basename $0` -l		# LCC replacement template.
    `basename $0` -n		# Node replacement template.
    `basename $0` -o		# Reboot / Power On dispatch template.
    `basename $0` -p		# Power Supply replacment template.
    `basename $0` -r		# Reseat disk dispatch template.
    `basename $0` -w		# Private Switch replacement template.
  
EOF
  exit 1
}

cleanup() {                     # Clean-up if script fails or finishes.
  #restore files.. [ -f /usr/sbin/sgdisk.bak ] && /bin/mv /usr/sbin/sgdisk.bak /usr/sbin/sgdisk
  unset fsuuid
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
  disk_sn_uuid=$(psql -U postgres -d rmg.db -h ${RMG_MASTER} -t -c "select diskuuid from fsdisks where fsuuid='${fsuuid}';"| awk 'NR==1{print $1}')
  disk_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select status from disks where uuid='$disk_sn_uuid'"| awk 'NR==1{print $1}')
  disk_replaceable_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select replacable from disks where uuid='$disk_sn_uuid'"| awk 'NR==1{print $1}')
  recovery_status=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select status from recoverytasks where fsuuid='${fsuuid}'"| awk 'NR==1{print $1}')
  if [[ disk_replaceable_status -eq 0 ]]; then
    is_disk_replaceable ${disk_replaceable_status} ${disk_status} ${recovery_status} 
    echo -e "${boldwhite}" 
    read -p "# Are you sure you'd like to proceed? (y/n) " -t 60 -n 1 -s unreplaceable_continue 
    echo -e "${clear_color}" 
    [[ "$unreplaceable_continue" =~ [yY] ]] && echo -e "\n" || cleanup "Please try again once the disk is recovered." 99
  fi
  fail_count=0
  disk_size=`df --block-size=1T | awk '/mauiss/ {n=$2}; END {print n}'`
  set_customer_contact_info
  set_disk_part_info $hardware_gen $disk_size $atmos_ver3
  set_disk_type $hardware_gen $atmos_ver3
  [[ if_mixed ]] && replace_method="Admin GUI or CLI" || replace_method="CLI"
  [[ -a /var/service/fsuuid_SRs/${fsuuid}.txt ]] && sr_number=`awk -F, 'NR==1 {print $2}' /var/service/fsuuid_SRs/${fsuuid}.txt`
  disk_slot=$(psql -U postgres -d rmg.db -h $RMG_MASTER -t -c "select d.slot from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$fsuuid';" | tr -d ' |\n') 
  psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$fsuuid';" | egrep -v '^$|row'
  print_disk_template
  
  return 0
}

print_disk_template() {         # Prints disk template to screen.
  printf '%.0s=' {1..100}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nDispatch Reason: Disk Ready for Replacement\nDisk online (Y/N): no\n\nSystem Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDisk Model:\t${model_num}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\nDAE Slot#:\t$disk_slot\nCapacity:\t$disk_size TB\nFSUUID:\t\t${fsuuid}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} DAE Disk for Atmos ${atmos_ver5} using ${replace_method}.\n3- Notify ROCC when disk replacement is completed."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  # echo -e "\nPriority (NBD / ASAP): ASAP\n"		# We currently don't use the priority option - disks should be dispatched as Sev3.
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ROCC prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..100}
  echo -e ""
  
  return 0
}

is_disk_replaceable () { 			  # Checks the status of the recovery and replacement (rewritten from Kollin's show_offline_disks script)
  [[ $(echo ${#disk_sn_uuid}) -ne 8 ]] && return 1
  unrec_obj_num=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select unrecoverobj from recoverytasks where fsuuid='${fsuuid}'"| awk 'NR==1{print $1}')
  impacted_obj_num=$(psql -U postgres rmg.db -h ${RMG_MASTER} -t -c "select impactobj from recoverytasks where fsuuid='${fsuuid}'"| awk 'NR==1{print $1}')
  [[ ${#unrec_obj_num} -eq 0 ]] && percent_recovered=$(echo -e ${cyan}"Not found"${white}) || [[ ${unrec_obj_num} -eq 0 || ${impacted_obj_num} -eq 0 ]] && percent_tmp=0 || percent_tmp=$(echo "scale=6; 100-${unrec_obj_num}*100/${impacted_obj_num}"|bc|cut -c1-5)
  percent_recovered=$(echo -e ${light_yellow}${percent_tmp}"%"${lt_gray})
  clear; echo -e "\n\n"
  
  case "$1:$2:$3" in   	# echo "Replacement: ${disk_replaceable_status}  Disk status: ${disk_status}  RecoveryStatus: ${recovery_status}"
        0:*:1)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Cancelled/Paused${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
    0:*:2)  	echo -e "${green}# Recovery completed, however the replaceable bit needs to be changed to a 1 in the disks table.${lt_gray}"
            ;;        
    0:*:3)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${green}In Progress		${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
    0:*:[45])  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${red}FAILED/ABORTED		${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;    
    0:*:6)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Pending			${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
    0:*:*)  	echo -e "${red}# Disk is not currently marked replaceable. \n${lt_gray}# RecoveryStatus: ${yellow}Status not found${lt_gray}\n# Objects ${percent_recovered} recovered."
            ;;		
    1:6:*)  	touch /var/service/fsuuid_SRs/${fsuuid}.txt
            [[ $(grep -c "^" /var/service/fsuuid_SRs/${fsuuid}.txt) -eq 1 ]] && for log in $(ls -t /var/log/maui/cm.log*); do bzgrep -m1 "Successfully updated replacable bit for $disk_sn_uuid" ${log} | awk -F\" '{print $2}' >> /var/service/fsuuid_SRs/${fsuuid}.txt && break; done
            [[ $(cat /var/service/fsuuid_SRs/${fsuuid}.txt | wc -l) -eq 1 ]] && date >> /var/service/fsuuid_SRs/${fsuuid}.txt
          set_replaced=$(cat /var/service/fsuuid_SRs/${fsuuid}.txt | tail -1)
          date_replaceable=$(date +%s --date="$set_replaced")
          date_plus_seven=$((604800+${date_replaceable}))
          past_seven=''
          [[ $(date +%s) -ge ${date_plus_seven} ]] && past_seven=$(echo "Disk has been replaceable over 7 days, please check the SR")
          echo -e "Replaceable="${green}"Yes"${white} "DiskSize="${yellow}${fsuuid}size"TB"${white} ${past_seven} 
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

update_sr_num() {					      # Change the SR number in show_offline_disks script text file.
  echo -e "# ${red}You've selected to append a new SR to the show_offline_disks script.\nPlease ensure the new SR has been opened against Site ID: ${site_id} TLA: ${tla_number} Host: $HOSTNAME" 		# Subject: ${New_Subject}"
  read -p "# Enter new SR#: " -t 600 -n 8 new_sr_num
  
  ## Write new SR num to txt file.
  [[ -a /var/service/fsuuid_SRs/${fsuuid}.txt ]] && sed -i "s/,/,${new_sr_num}_origSR-/" /var/service/fsuuid_SRs/${fsuuid}.txt && echo -e "\n# SR# ${new_sr_num} has been added to the show_offline_disks file.${clear_color}" && return 0
  
  # To help SAMs meet MBO, it's proposed to open new SRs for dispatchments: // waiting for further info
  # echo -e "\n# Please close SR# ${sr_number} against the new SR# ${new_sr_num} ${clear_color}" 					#Include Site, tla_number, Node
  # If fail...
  return 1
}

append_dispatch_date() {			  # Appends dispatch date in show_offline_disks script text file.
  # Possibly ask if the following should happen first?
  # Append dispatched time to show_offline_disks text file. Need to revise logic to consider for no SR # or no #session.
  [[ -a /var/service/fsuuid_SRs/${fsuuid}.txt ]] && sed -i "s/\(,[0-9]*\)\([#_]\)/\1-Dispatched_$(date +%m-%d-%y)_\2/" /var/service/fsuuid_SRs/${fsuuid}.txt && echo -e "\n# Dispatch date has been appended to show_offline_disks text file. ${clear_color}" && return 0								#Include Site, tla_number, Node
    
  # If fail...
  return 1
}

set_customer_contact_info() {		# Set Customer contact info/location.
  ### Beatle addresses:
  alln_address="AT&T Solutions_Allen_IDC_Apple_SMS Managed Utility\n900 VENTURE DR\nALLEN, TX 75013"															                            # Allen
  amst_address="AT&T SOLUTIONS C/O REMOTE MANAGED SERVICES (RMS)\nGLOBAL SWITCH AMSTERDAM SLOTERVAAR\nJOHAN HUIZINGALAAN 759\nAMSTERDAM, NL 1066 VH"			    # Amsterdam
  DFW0_address="AT&T Internet Data Center\n11830 WEBB CHAPEL RD\nC/O Site ID 21611\nDALLAS, TX 75234"											                                    # Dallas - Fort Worth
  dfw1_address="AT&T Internet Data Center\n11830 WEBB CHAPEL RD\nC/O Site ID 21611\nDALLAS, TX 75234"												                                  # Dallas - Fort Worth
  hnkg_address="AT&T INFRASTRUCTURE STAAS:22061.HNK2\n28 PAK TIN PAR STREET\n10/F I TECH TOWER SITE ID[22061]\nTSUEN WAN\nNEW TERRITORIES\nHong Kong, China"	# Hong Kong - Phase 2
  LIS0_address="AT&T Internet Data Center\n4513 WESTERN AVE\nC/O Site ID 21609\nLISLE, IL  60532"																                              # Lisle
  lis1_address="AT&T Internet Data Center\n4513 WESTERN AVE\nC/O Site ID 21609\nLISLE, IL  60532"																                              # Lisle
  lond_address="AT&T SOLUTIONS C/O AT&T ENT. HOSTING LONDON UK\nUNIT 21 SENTRUM IV FACILITY\nGOLDSWORTH PARK TRADING ESTATE\nWOKING  SURREY  GB  GU21  3BA"	  # London
  rdcy_address="AT&T CORP\n3175 SPRING ST\nC/O AT&T Infrastructure StaaS: 22088.RWC\nREDWOOD CITY, CA 94063"  												                        # Redwood City - Phase 2.2
  RWC0_address="AT&T DATA CENTER\nC/O SITE ID 21610\n3175 SPRING ST\nREDWOOD CITY, CA 94063"																	                                # Redwood City - P1
  rwc1_address="AT&T DATA CENTER\nC/O SITE ID 21610\n3175 SPRING ST\nREDWOOD CITY, CA 94063"																	                                # Redwood City - P1
  stls_address="AT&T CORP\n801 CHESTNUT ST\nBEATLE PROJECT\nSAINT LOUIS, MO 63101"																			                                      # Saint Louis
  sndg_address="AT&T \n7337 TRADE ST\nRM 2181\nSAN DIEGO, CA  92121"																							                                            # San Diego
  SEC0_address="AT&T Internet Data Center\nC/O SITE ID 21614\n15 ENTERPRISE AVE N\nSECAUCUS, NJ  07094"														                            # Secaucus
  sec1_address="AT&T Internet Data Center\nC/O SITE ID 21614\n15 ENTERPRISE AVE N\nSECAUCUS, NJ  07094"														                            # Secaucus
  SYD0_address="AT&T - Please update location info in script."
  syd1_address="AT&T - Please update location info in script."
  tkyo_address="AT&T Japan K.K.\n2-3-10 FUKUZUMI\nASAHI COMPUTER BLDG 2ND FLOOR\nKOTO-KU\nTOKYO, JAPAN   135-0032"									                          # Tokyo - Phase 2
  TYO0_address="AT&T Solutions_Tokyo IDC_Apple_SMS Managed Utility\n6-5 KITA SHINAGAWA\nC/O AT&T ENTERPRISE HOSTING SERVICES\nTOKYO, JAPAN  141-0001"			    # Tokyo - Phase 1
  ########## CSTaaS addresses:
  lon0_address="AT&T SOLUTIONS_LONDON IDC_APPLE_SMS MANAGED UTILITY\nGOLDSWORTH PARK TRADING ESTATE\nKESTREL WAY\nWOKING  SURREY    GB     GU21 3BA"			    # London ?
  dfw0_address="AT&T Solutions_Dallas IDC_SMS Managed Utility - STaaS\n11830 WEBB CHAPEL RD\nSTE 200\nDALLAS, TX  75234"										                  # dfw cstaas
  iad0_address="AT&T Solutions_Ashburn IDC_SMS Managed Utility - STaaS\n21571 BEAUMEADE CIR\nASHBURN, VA  20147"												                      # iad cstaas
  
  eval is_att_rocc_system=\$$node_location
  if [[ ${#is_att_rocc_system} -gt 0 && "${is_att_rocc_system}" == "AT&T"[\ ]* ]] ; then
    cust_con_name="rocc@roccops.com"
    cust_con_numb="877-362-0253"
    cust_con_time="(7x24x356)"
    customer_contact_location="\nSite Location: \n${is_att_rocc_system}\n"
  else
    echo -e "${light_green}"
    read -p "# Enter customer's name: " -t 300 cust_con_name || cleanup "Timed out. Please get the information and try again." 111
    read -p "# Enter customer's number: " -t 300 cust_con_numb || cleanup "Timed out. Please get the information and try again." 112
    read -p "# Enter customer's available contact time: " -t 300 cust_con_time || cleanup "Timed out. Please get the information and try again." 113
    read -p "# Enter site's address: (Press \"Enter\" to skip..)" -t 300 cust_con_location || cleanup "Timed out. Please get the information and try again." 114
    echo -e "${clear_color}"
  fi
  
  customer_contact_info="Contact Name:\t${cust_con_name}\nContact Number:\t${cust_con_numb}\nContact Time:\t${cust_con_time}"
  [[ ${#cust_con_location} -gt 1 ]] && customer_contact_location="\nLocation: ${cust_con_location}\n" || customer_contact_location=""
  
  return 0
}

set_disk_type() {					      # Gets and sets disk type.
  if_mixed=`ssh $RMG_MASTER grep dmMixDriveMode /etc/maui/maui_cfg.xml | grep -c true`
  (( $if_mixed )) && disk_type="MIXED SS/MDS" && return 0
  
  disk_type_temp=`psql -tq -U postgres rmg.db -h $RMG_MASTER -c "select mnt from filesystems where uuid='$fsuuid'" | awk '{print substr($1,1,6)}'`
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

get_fsuuid() { 						      # Get fsuuid from user.
  if [[ $1 -eq 0 ]]
  then
    echo -e "\n## Please wait... running ${light_green}show_offline_disks.sh${clear_color}\n"
    offline_disks=$(/var/service/show_offline_disks.sh -l)
  else 
    echo "# Please choose a fsuuid from an offline disk: "
  fi
  echo -e "\n${offline_disks}\n\E[21m${clear_color}${light_green}"
  read -p "# Enter fsuuid for disk to dispatch: " -t 60 -n 36 fsuuid
  echo -e "${clear_color}\n"
  if [[ validate_fsuuid ]]
    then fail_count=$((fail_count+1))
      [[ "$fail_count" -gt 4 ]] && cleanup "Please try again with a valid fsuuid." 60
      clear
      echo -e "\n\n${red}# Invalid fsuuid attempt: $fail_count, please try again.${clear_color}"
      get_fsuuid $fail_count
    else dev_path=`blkid | grep ${fsuuid} | sed 's/1.*//'`
    return 0
  fi 
  return 1
}

validate_fsuuid() {					    # Validate fsuuid against regex pattern.
  valid_fsuuid='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' # Regex to confirm a valid UUID - only allows for hexidecimal characters.
  valid_fsuuid_on_host=$(psql -t -U postgres rmg.db -h $RMG_MASTER -c "select fs.fsuuid from disks d join fsdisks fs ON d.uuid=fs.diskuuid where d.nodeuuid='$node_uuid' and fs.fsuuid='$fsuuid'"| awk 'NR==1{print $1}')
  if [[ ! ${#valid_fsuuid_on_host} -eq 36 ]] ; then
    echo -e "${red}# FSUUID not found on host.\n# Please try again.${clear_color}"
    get_fsuuid $fail_count
  else
    [[ "$fsuuid" =~ $valid_fsuuid ]] && return 0 || echo -e "${red}# Invalid fsuuid.${clear_color}" && get_fsuuid
  fi
  return 1
  
  # valid_fsuuid='^[[:alnum:]]{8}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{4}-[[:alnum:]]{12}$' # Regex to confirm a valid UUID - allows for letters g-z, which aren't allowed 
  # valid_fsuuid='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' # Regex to confirm a valid UUID - allows for capital letters, which aren't allowed.

  # if [[ "$fsuuid" != [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f] ]]
    # then echo -e "${red}# Invalid fsuuid.${clear_color}"
    # get_fsuuid
    # else return 0
  # fi
}

get_abs_path() { 					      # Find absolute path of script.
case "$1" in /*)printf "%s\n" "$1";; *)printf "%s\n" "$PWD/$1";; esac; 
}

distribute_script() {				    # Distribute script across all nodes, and sets permissions.
  full_path=`get_abs_path $0`; this_script=`basename "$full_path"`; this_script_dir=`dirname "$full_path"`
  [[ "$script_name" == "$this_script" ]] || cleanup "Please rename script to $script_name and try again." 20
  echo -en "\n# Distributing script across all nodes.. "
  copy_script=`mauiscp ${full_path} ${full_path} | awk '/Output/{n=$NF}; !/Output|^$|Runnin/{print n": "$0}' | wc -l`
  [ $copy_script -eq 0 ] && echo -e "${light_green}Done!${clear_color} ($this_script copied to all nodes)" || cleanup "Failed to copy $this_script to all nodes" 21
  echo -en "# Setting script permissions across all nodes.. "
  set_permissions=`mauirexec "chmod +x ${full_path}" | awk '/Output/{n=$NF}; !/Output|^$|Runnin/{print n": "$0}' | wc -l`
  [ $set_permissions -eq 0 ] && echo -e "${light_green}Permissions set!${clear_color}\n\n" || cleanup "Failed to set permissions across all nodes" 22
  exit 0
}

update_script(){                # Allows for updating script with passcode.
  full_path=`get_abs_path $0`; this_script=`basename "$full_path"`; this_script_dir=`dirname "$full_path"`
  [[ "$script_name" == "$this_script" ]] || cleanup "Please rename script to $script_name and try again." 20
  read -p "Update script: please enter passcode: " -t 60 -s -n 4 update_passcode_ver
  echo
  [[ ${update_passcode_ver} == "7777" ]] && vim ${full_path}_tmp && /bin/mv -f ${full_path}_tmp ${full_path} && chmod +x ${full_path} && cleanup "Updated successfully!" 0 || cleanup "update failed..." 254
  cleanup "Wrong passcode entered. Exiting." 255
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

prep_int_disk_template() {      # Prepares input for use in print_disk_template function.
  # Check if disk is ready for replacement:
  echo -en "\n${light_green}# Enter internal disk's device path (sda/sdb): "
  read -t 60 -n 3 internal_disk_dev_path
  echo -e "\n${clear_color}"
  set_customer_contact_info
  int_dev_path="/dev/${internal_disk_dev_path}"
  
  #set_disk_part_info $hardware_gen $disk_size $atmos_ver3
  case "${hardware_gen}:${atmos_ver3}" in   						# hardware_gen:atmos_ver3
    1:*)  	                        # Gen 1 hardware
      part_num='105-000-160'				  
      int_disk_description='250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED'
      ;;		
    2:*)  	                        # Gen 2 Hardware 
      part_num='105-000-160'
      int_disk_description='250GB 7.2K RPM 3.5IN DELL SATA DRV/SLED'
      ;;
    3:*)                            # Gen 3 Hardware
      part_num='105-000-316-00'
      int_disk_description='300GB 2.5" 10K RPM SAS 512bps DDA ATMOS'
      ;;
    *) cleanup "Hardware Gen / Internal disk type detection failed." 130
      ;;
    esac

  internal_uuid=$(mdadm -D /dev/md126 | awk '/UUID/{print $3}')
  disk_type='Internal'
  [[ ${internal_disk_dev_path} =~ "sd"[ab] ]] || cleanup "Internal disk device path not recognized." 131
  [[ ${internal_disk_dev_path} == "sda" ]] && disk_sn_uuid=$(smartctl -i /dev/sg0 | awk '/Serial number/{print $3}')
  [[ ${internal_disk_dev_path} == "sdb" ]] && disk_sn_uuid=$(smartctl -i /dev/sg1 | awk '/Serial number/{print $3}')
  replace_method=" - FRU Replacement Procedure"
  [[ -a /var/service/fsuuid_SRs/${internal_uuid}.txt ]] && sr_number=`awk -F, 'NR==1 {print $2}' /var/service/fsuuid_SRs/${internal_uuid}.txt`
  [[ -a /var/service/fsuuid_SRs/${internal_serial}.txt ]] && sr_number=`awk -F, 'NR==1 {print $2}' /var/service/fsuuid_SRs/${internal_serial}.txt`
  
  # psql -U postgres -d rmg.db -h $RMG_MASTER -c "select d.devpath,d.slot,d.status,d.connected,d.slot_replaced,d.uuid,d.replacable from fsdisks fs RIGHT JOIN disks d ON fs.diskuuid=d.uuid where fsuuid='$internal_uuid';" | egrep -v '^$|row'
  # psql -U postgres -d rmg.db -h $RMG_MASTER -tx -c "select * from disks d where d.devpath='${int_dev_path}';"
  
  print_int_disk_template 
  
  return 0
}

print_int_disk_template() {     # Prints disk template to screen.
  printf '%.0s=' {1..100}
  echo -e "${lt_gray} \n\nAtmos ${atmos_ver3} Dispatch\t(Disp Notification - Generic)\n\nCST please create a Task for the field CE from the information below.\nReason for Dispatch: Internal* Disk Replacement\n*Note:\tINTERNAL DISK!!!\n\nSystem Serial#:\t${tla_number}\nHost Node:\t$HOSTNAME \nDisk Type:\t${disk_type}\nDescription:\t${int_disk_description}\nPart Number:\t${light_green}${part_num}${lt_gray}\nDisk Serial#:\t${disk_sn_uuid}\nRaid UUID:\t${internal_uuid}\nDev Path:\t${int_dev_path}"
  echo -e "\nCE Action Required:  On Site"
  printf '%.0s-' {1..30}
  echo -e "\n1- Contact ROCC and arrange for disk replacement prior to going on site.\n2- Follow procedure document for replacing GEN${hardware_gen} *Internal* Disk for Atmos ${atmos_ver5}${replace_method}."
  if [ $node_location != "lond" ] || [ $node_location != "amst" ]; then echo -e "*Note: If any assistance is needed, contact your FSS."; fi
  echo -e "\nIssue Description: Failed *internal* disk is ready for replacement."
  printf '%.0s-' {1..58}
  echo -e "\n${customer_contact_info}${customer_contact_location}"
  echo -e "Next Action:\tDispatch CE onsite\nPlease notify the CE to contact ROCC prior to going on site and to complete the above tasks in their entirety.\n ${clear_color}"
  printf '%.0s=' {1..100}
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

## Check if correct number of options were specified.
[[ $# -lt 1 || $# -gt 2 ]] && echo -e "\n${red}Invalid number of options, see usage:${clear_color}" && display_usage

## Check if option is blank.
[[ $1 == "" || $1 == $NULL || $1 == "-" || $1 == "?" ]] && echo -e "\n${red}Invalid option, see usage:${clear_color}" && display_usage

## Check for invalid options:
if ( ! getopts ":cd:e:fiklmnoprsuvwxyz" options ); then echo -e "\n${red}Invalid options, see usage:${clear_color}" && display_usage; fi

## Parse the options:
while getopts ":cd:e:fiklmnoprsuvwxyz" options
do
    case $options in
    c)  cleanup "Not supported yet, will print switch/eth0 connectivity dispatch template." 99
      ;;
    d)  fsuuid=$OPTARG
        validate_fsuuid 
        prepare_disk_template
        append_dispatch_date
      ;;
    e)  fsuuid=$OPTARG
        validate_fsuuid 
        prepare_disk_template
        update_sr_num
        append_dispatch_date
      ;;
    f)  cleanup "Not supported yet, will print DAE fan dispatch template." 99
            ;;
    i)  prep_int_disk_template
      ;;
    k)  get_fsuuid
        prepare_disk_template
      ;;
    l)  cleanup "Not supported yet, will print LCC dispatch template." 99
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
    v)	echo -e "# Current Version: $version\n"
        exit 0
      ;;
    w)	cleanup "Not supported yet, will print private switch replacement template." 99
      ;;
    x)  distribute_script
      ;;
    y)  update_script
        distribute_script
      ;;
    z)  update_sr_num
      ;;
    :)  
      [[ "$OPTARG" == "e" || "$OPTARG" == "d" ]] && validate_fsuuid
      [[ "$OPTARG" == "e" || "$OPTARG" == "d" ]] && prepare_disk_template
      [[ "$OPTARG" == "e" ]] && update_sr_num
      [[ "$OPTARG" != "e" && "$OPTARG" != "d" ]] && display_usage
      ;;	
    ?) display_usage
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

###########################################       Testing..       ##########################################
############################################################################################################
############################################################################################################
# Testing: 
# Gen1: 
# Gen2: iad01-is05-006
# Gen3: lis1d01-is5-001
# amst a,  rwc a, tkyo a, tyo1/syd1
# time for x in `cat /var/service/list`; do echo $x;scp /var/service/dispatch_template.sh $x:/var/service/;ssh $x "sh /var/service/dispatch_template.sh -x"; done

# TODO
# fsuuid valid on current node.
# customer contact info to text file?
# complete other dispatch templates.
# BZ standardized templates.
