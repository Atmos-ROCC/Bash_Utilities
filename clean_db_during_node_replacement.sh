#!/bin/bash
# Claiton.Weeks@emc.com | Claiton.Weeks@gmail.com
version=1.3.4

  red=$(echo -e "\E[31m");magenta=$(echo -e "\E[35m");cyan=$(echo -e "\E[36m");lt_gray=$(echo -e "\E[37m");lt_green=$(echo -e "\E[92m");clear_color=$(echo -e "\E[0m");
  clean_db_verify1="n"
  clean_db_verify2="n"
  cleandb_hostname_flag="false"
  cleandb_nodeuuid_flag="false"
  
cleanup_db_hostname(){
  # Remove entries based on hostname
  cleandb_hostname_flag="false"
  read -p "${lt_green}# Would you like to proceed with cleaning the database by hostname? (y/Y/n/N) ${clear_color}" -n 1 clean_db_verify1;
  echo
  [[ $clean_db_verify1 =~ [yY] ]] || return 1
  read -p "${red}# Are you positive? Please only proceed if doing node replacement. Type 'YES' to proceed: ${clear_color}" -n 3 clean_db_verify2;
  echo
  [[ $clean_db_verify2 == "YES" ]] || return 2

	echo -e "${magenta}System DB:${cyan} delete from nodes where hostname='$new_node_hostname'${clear_color}"; 
	psql -U postgres -d system.db -h $INITIAL_MASTER -c "delete from nodes where hostname='$new_node_hostname';"; 
	echo -e "${magenta}System DB:${cyan} update nodecfgs set nodeuuid='' where hostname='$new_node_hostname'${clear_color}"; 
	psql -U postgres -d system.db -h $INITIAL_MASTER -c "update nodecfgs set nodeuuid='' where hostname='$new_node_hostname';"; 
	echo -e "${magenta}RMG DB:${cyan} delete from nodes where hostname='$new_node_hostname'${clear_color}"; 
	psql -U postgres -d rmg.db -h $RMG_MASTER -c "delete from nodes where hostname='$new_node_hostname';"; 
  unset clean_db_verify1
  unset clean_db_verify2
  return 0
}

cleanup_db_nodeuuid(){
  # Remove entries based on nodeuuid
  cleandb_nodeuuid_flag="false"
  echo -e "${red}# WARNING: Only proceed if you are positive the node is not able to obtain network configurations during a node replacement. Otherwise exit now with ctrl+c${clear_color}"
  read -p "${lt_green}# Would you like to proceed with cleaning the database by nodeuuid? (y/Y/n/N) ${clear_color}" -n 1 clean_db_verify1;
  echo
  [[ $clean_db_verify1 =~ [yY] ]] || return 1
  read -p "${red}# Are you positive? Please only proceed if doing node replacement. Type 'YES' to proceed: ${clear_color}" -n 3 clean_db_verify2;
  echo
  [[ $clean_db_verify2 == "YES" ]] || return 2
  
	echo -e "${magenta}System DB:${cyan} delete from nodes where uuid='$new_node_uuid'${clear_color}"; 
	psql -U postgres -d system.db -h $INITIAL_MASTER -c "delete from nodes where uuid='$new_node_uuid';"; 
	echo -e "${magenta}System DB:${cyan} update nodecfgs set nodeuuid='' where hostname='$new_node_hostname'${clear_color}"; 
	psql -U postgres -d system.db -h $INITIAL_MASTER -c "update nodecfgs set nodeuuid='' where hostname='$new_node_hostname';"; 
	echo -e "${magenta}RMG DB:${cyan} delete from nodes where hostname='$new_node_hostname'${clear_color}"; 
	psql -U postgres -d rmg.db -h $RMG_MASTER -c "delete from nodes where hostname='$new_node_hostname';"; 
  unset clean_db_verify1
  unset clean_db_verify2
  return 0
}

check_db_nodes_nodecfgs(){  
  #clear;\
  echo -e "\n\n${lt_green}";unset new_node_hostname;unset new_node_uuid;read -p "# Enter hostname of problem node: ${clear_color}" new_node_hostname; echo -e "${lt_gray}# Run 'dmidecode | grep -i uuid' on new node to get nodeuuid.";read -p "${lt_green}# Enter nodeuuid of new replacement node : ${clear_color}" new_node_uuid;echo; \
	cm_cfg="/etc/maui/cm_cfg.xml";export RMG_MASTER=$(awk -F, '/localDb/ {print $(NF-1)}' $cm_cfg);export INITIAL_MASTER=$(awk -F"\"|," '/systemDb/ {print $(NF-2)}' $cm_cfg); \
  dboutput_system_nodes_hostname=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select * from nodes where hostname='$new_node_hostname';") ;\
	dboutput_system_nodecfgs_hostname=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select id,hostname,nodeuuid,clusteruuid from nodecfgs where hostname='$new_node_hostname';") ;\
	dboutput_system_nodecfgs_hn_nf=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select nodeuuid from nodecfgs where hostname='$new_node_hostname';") ;\
  dboutput_rmg_nodes_hostname=$(psql -txU postgres -d rmg.db -h $RMG_MASTER -c "select id,uuid,hostname,clusteruuid,status from nodes where hostname='$new_node_hostname';") ;\
	dboutput_system_nodes_nodeuuid=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select * from nodes where uuid='$new_node_uuid';");\
  dboutput_system_nodecfgs_nodeuuid=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select id,hostname,nodeuuid,clusteruuid from nodecfgs where nodeuuid='$new_node_uuid';");\
  dboutput_system_nodecfgs_nu_nf=$(psql -txU postgres -d system.db -h $INITIAL_MASTER -c "select nodeuuid from nodecfgs where nodeuuid='$new_node_uuid';");\
  dboutput_rmg_nodes_nodeuuid=$(psql -txU postgres -d rmg.db -h $RMG_MASTER -c "select id,uuid,hostname,clusteruuid,status from nodes where uuid='$new_node_uuid';");\
  #clear;
  echo -e "\n\n\n${lt_gray}# Search by hostname: ${clear_color}"
  echo -e "${magenta}System DB:${cyan} select * from nodes where hostname='$new_node_hostname'${clear_color}\n$dboutput_system_nodes_hostname"; \
	echo -e "${magenta}System DB:${cyan} select id,hostname,nodeuuid,clusteruuid from nodecfgs where hostname='$new_node_hostname'${clear_color}\n$dboutput_system_nodecfgs_hostname"; \
	echo -e "${magenta}RMG DB:${cyan}    select id,uuid,hostname,clusteruuid,status from nodes where hostname='$new_node_hostname'${clear_color}\n$dboutput_rmg_nodes_hostname"; \
	echo -e "\n\n${lt_gray}# Search by nodeuuid: ${clear_color}"
  echo -e "${magenta}System DB:${cyan} select * from nodes where uuid='$new_node_uuid'${clear_color}\n$dboutput_system_nodes_nodeuuid"; \
	echo -e "${magenta}System DB:${cyan} select id,hostname,nodeuuid,clusteruuid from nodecfgs where nodeuuid='$new_node_uuid'${clear_color}\n$dboutput_system_nodecfgs_nodeuuid"; \
	echo -e "${magenta}RMG DB:${cyan}    select id,uuid,hostname,clusteruuid,status from nodes where uuid='$new_node_uuid'${clear_color}\n$dboutput_rmg_nodes_nodeuuid"; \
  echo;
  
  return 0
}

check_db_nodes_nodecfgs
[[ ${#dboutput_system_nodes_hostname} -le 12 ]] || cleandb_hostname_flag="true"
[[ ${#dboutput_system_nodecfgs_hn_nf} -le 12 ]] || cleandb_hostname_flag="true"
[[ ${#dboutput_rmg_nodes_hostname} -le 12    ]] || cleandb_hostname_flag="true"
[[ ${#dboutput_system_nodes_nodeuuid} -le 12 ]] || cleandb_nodeuuid_flag="true"
[[ ${#dboutput_system_nodecfgs_nu_nf} -le 12 ]] || cleandb_nodeuuid_flag="true"
[[ ${#dboutput_rmg_nodes_nodeuuid} -le 12    ]] || cleandb_nodeuuid_flag="true"

[[ "${cleandb_hostname_flag}" = "true" ]] && { cleanup_db_hostname; [[ "${cleandb_nodeuuid_flag}" = "true" ]] && { cleanup_db_nodeuuid;\
    cleandb_nodeuuid_flag="false"; }; } || { [[ "${cleandb_nodeuuid_flag}" = "true" ]] && cleanup_db_nodeuuid; }

echo -e "${lt_green}# Finished."

# Testing ...
# rm -f /var/tmp/clean_db_during_node_replacement.sh;vi /var/tmp/clean_db_during_node_replacement.sh
#
# stls01k01-is1-008
