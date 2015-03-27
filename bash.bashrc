emc_nt_username=""
beatle_curr_pass=""
beatle_mon_curr_pass=""
gouda_ecs_curr_pass=""
gouda_vipr_curr_pass=""
cstaas_node_curr_pass=""
cstaas_jumpbox_curr_pass=""
cstaas_jumpbox_old_pass=""

version=2.3

## names of conf files for each site, WITHOUT the .conf extension.
## names of conf files for each site, WITHOUT the .conf extension.
## names of conf files for each site, WITHOUT the .conf extension.
vpnc_conf_beatle_alln01="beatle-alln01"
vpnc_conf_beatle_amst01="beatle-amst01"
vpnc_conf_beatle_dfw1="beatle-dfw1"
vpnc_conf_beatle_hnkg01="beatle-hnkg01"
vpnc_conf_beatle_lis1="beatle-lis1"
vpnc_conf_beatle_lond01="beatle-lond01"
vpnc_conf_beatle_rdcy01="beatle-rdcy01"
vpnc_conf_beatle_rwc1="beatle-rwc1"
vpnc_conf_beatle_sec1="beatle-sec1"
vpnc_conf_beatle_sndg01="beatle-sndg01"
vpnc_conf_beatle_stls01="beatle-stls01"
vpnc_conf_beatle_syd1="beatle-syd1"
vpnc_conf_beatle_tkyo01="beatle-tkyo01"
vpnc_conf_beatle_tyo1="beatle-tyo1"
vpnc_conf_cstaas_ams="cstaas-ams"
vpnc_conf_cstaas_dfw="cstaas-dfw"
vpnc_conf_cstaas_iad="cstaas-iad"
vpnc_conf_cstaas_lon="cstaas-lon"
vpnc_conf_gouda_lsvg01="gouda-lsvg01"
vpnc_conf_gouda_stng01="gouda-stng01"
vpnc_conf_govcst_dfw="govcst-dfw"
vpnc_conf_govcst_iad="govcst-iad"
vpnc_conf_mozy_ext="mozy-ext"
vpnc_conf_mozy_int="mozy-int"
## names of conf files for each site, WITHOUT the .conf extension.
## names of conf files for each site, WITHOUT the .conf extension.
## names of conf files for each site, WITHOUT the .conf extension.


#####################################################################################################################
# System-wide .bashrc file for interactive bash(1) shells.
setup_defaults() {

# To enable the settings / commands in this file for login shells as well,
# this file has to be sourced in /etc/profile.
alias vi='/usr/bin/vim'

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

use_color=false

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
        && type -P dircolors >/dev/null \
        && match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

if ${use_color} ; then
        # Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
        if type -P dircolors >/dev/null ; then
                if [[ -f ~/.dir_colors ]] ; then
                        eval $(dircolors -b ~/.dir_colors)
                elif [[ -f /etc/DIR_COLORS ]] ; then
                        eval $(dircolors -b /etc/DIR_COLORS)
                fi
        fi

        if [[ ${EUID} == 0 ]] ; then
                PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\h\[\033[01;34m\] \W \$\[\033[00m\] '
        else
                PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[01;34m\] \w \$\[\033[00m\] '
        fi

        alias ls='ls --color=auto'
        alias grep='grep --colour=auto'
else
        if [[ ${EUID} == 0 ]] ; then
                # show root@ when we don't have colors
                PS1='\u@\h \W \$ '
        else
                PS1='\u@\h \w \$ '
        fi
fi

# Try to keep environment pollution down, EPA loves us.
unset use_color safe_term match_lhs

# Commented out, don't overwrite xterm -T "title" -n "icontitle" by default.
# If this is an xterm set the title to user@host:dir
#case "$TERM" in
#xterm*|rxvt*)
#    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
#    ;;
#*)
#    ;;
#esac

# enable bash completion in interactive shells
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found ]; then
                function command_not_found_handle {
                        # check because c-n-f could've been removed in the meantime
                if [ -x /usr/lib/command-not-found ]; then
                                   /usr/bin/python /usr/lib/command-not-found -- $1
                   return $?
                                else
                                   return 127
                                fi
                }
fi

/usr/bin/mint-fortune

export HISTTIMEFORMAT="%y/%m/%d %T "

#init_colors() {	}					      # Initialize text color variables.
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

#####################################################################################################################
}
setup_defaults

###Mozy VPN
connect_mozy_vpn() {
v1=$vpnc_conf_mozy_ext
v2=$vpnc_conf_mozy_int
echo -en "${light_cyan}Checking for Mozy VPN: ${clear_color}"
[[ $(ps aux | egrep -c "[v]pnc $v1.conf") -eq 1 ]] && echo "Detected Mozy-EXT VPN" || { [[ $(ps aux | egrep -c "[v]pnc $v2.conf") -eq 1 ]] && echo "Detected Mozy-INT VPN" || { { echo -e "${light_green}# Opening VPN connection to $1${clear_color}"; sudo vpnc $v1.conf; } || { echo -e "${red}# Opening connection to $v1 failed.\n${light_green}# Opening VPN connection to $v2${clear_color}";sudo vpnc $v2.conf; }; }; }
}

###BEATLE ALIASES###
#Phase 2 #####################################################################################################################################
#Phase 2 #####################################################################################################################################
connect_phase1(){
#connect_mozy_vpn
echo -e "${light_cyan}# Detecting VPN connection for $1${clear_color}"
[[ $(ps aux | egrep -c "[v]pnc $1") -eq 1 ]] || { echo -e "${red}# VPN for $1 not found.\n${light_cyan}# Detecting VPN connection for $2${clear_color}";[[ $(ps aux | egrep -c "[v]pnc $2") -eq 1 ]] || { { echo -e "${light_green}# Opening VPN connection to $1${clear_color}"; sudo vpnc $1.conf; } || { echo -e "${red}# Opening connection to $1 failed.\n${light_green}# Opening VPN connection to $2${clear_color}";sudo vpnc $2.conf; }; }; }
[[ -z "$4" ]] && rubi_pass="${beatle_curr_pass}" || rubi_pass="$4"
echo -e "\n\n${light_cyan}# ssh $3${clear_color}"
[[ -n "$3" ]] && { [[ -n "$5" ]] && sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$3" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$5"; } || sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$3"
}

#Phase 1 West
connect_dfw() {
connect_phase1 "${vpnc_conf_beatle_dfw1}" "${vpnc_conf_beatle_rwc1}" "$1" "$2" "$3"
}
alias dfw="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval dfw\${cloudlet}"
alias dfwmon="connect_dfw 172.16.34.41 ${beatle_mon_curr_pass}"
alias dfw1="connect_dfw 172.16.22.11"
alias dfwa="connect_dfw 172.16.22.11 ${beatle_curr_pass} 172.16.30.11"
alias dfwb="connect_dfw 172.16.22.11 ${beatle_curr_pass} 172.16.30.75"
alias dfwc="connect_dfw 172.16.22.11 ${beatle_curr_pass} 172.16.30.139"
alias dfwd="connect_dfw 172.16.22.11 ${beatle_curr_pass} 172.16.30.203"

connect_rwc() {
connect_phase1 "${vpnc_conf_beatle_rwc1}" "${vpnc_conf_beatle_dfw1}" "$1" "$2" "$3"
}
alias rwc="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval rwc\${cloudlet}"
alias rwcmon="connect_rwc 172.17.34.41 ${beatle_mon_curr_pass}"
alias rwc1="connect_rwc 172.17.22.11"
alias rwca="connect_rwc 172.17.22.11 ${beatle_curr_pass} 172.17.30.11"
alias rwcb="connect_rwc 172.17.22.11 ${beatle_curr_pass} 172.17.30.75"
alias rwcc="connect_rwc 172.17.22.11 ${beatle_curr_pass} 172.17.30.139"
alias rwcd="connect_rwc 172.17.22.11 ${beatle_curr_pass} 172.17.30.203"

#Phase 1 East
connect_lis() {
connect_phase1 "${vpnc_conf_beatle_lis1}" "${vpnc_conf_beatle_sec1}" "$1" "$2" "$3"

}
alias lis="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval lis\${cloudlet}"
alias lismon="connect_lis 172.18.34.41 ${beatle_mon_curr_pass}"
alias lis1="connect_lis 172.18.22.11"
alias lisa="connect_lis 172.18.22.11 ${beatle_curr_pass} 172.18.30.11"
alias lisb="connect_lis 172.18.22.11 ${beatle_curr_pass} 172.18.30.75"
alias lisc="connect_lis 172.18.22.11 ${beatle_curr_pass} 172.18.30.139"
alias lisd="connect_lis 172.18.22.11 ${beatle_curr_pass} 172.18.30.203"

connect_sec() {
connect_phase1 "${vpnc_conf_beatle_sec1}" "${vpnc_conf_beatle_lis1}" "$1" "$2" "$3"

}
alias sec="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval sec\${cloudlet}"
alias secmon="connect_sec 172.19.34.41 ${beatle_mon_curr_pass}"
alias sec1="connect_sec 172.19.22.11"
alias seca="connect_sec 172.19.22.11 ${beatle_curr_pass} 172.19.30.11"
alias secb="connect_sec 172.19.22.11 ${beatle_curr_pass} 172.19.30.75"
alias secc="connect_sec 172.19.22.11 ${beatle_curr_pass} 172.19.30.139"
alias secd="connect_sec 172.19.22.11 ${beatle_curr_pass} 172.19.30.203"

#Phase 1 APJ
connect_syd() {
connect_phase1 "${vpnc_conf_beatle_syd1}" "${vpnc_conf_beatle_tyo1}" "$1" "$2" "$3"
}
alias syd="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval syd\${cloudlet}"
alias sydmon="connect_syd ${beatle_mon_curr_pass} 172.30.34.41"
alias syd1="connect_syd 172.30.22.11"
alias syda="connect_syd 172.30.22.11 ${beatle_curr_pass} 172.30.30.11"
alias sydb="connect_syd 172.30.22.11 ${beatle_curr_pass} 172.30.30.75"
alias sydc="connect_syd 172.30.22.11 ${beatle_curr_pass} 172.30.30.139"
alias sydd="connect_syd 172.30.22.11 ${beatle_curr_pass} 172.30.30.203"

connect_tyo() {
connect_mozy_vpn
connect_phase1 "${vpnc_conf_beatle_tyo1}" "${vpnc_conf_beatle_syd1}" "$1" "$2" "$3"

}
alias tyo="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval tyo\${cloudlet}"
alias tyomon="connect_tyo 172.31.34.41 ${beatle_mon_curr_pass}"
alias tyo1="connect_tyo 172.31.22.11"
alias tyoa="connect_tyo 172.31.22.11 ${beatle_curr_pass} 172.31.30.11"
alias tyob="connect_tyo 172.31.22.11 ${beatle_curr_pass} 172.31.30.75"
alias tyoc="connect_tyo 172.31.22.11 ${beatle_curr_pass} 172.31.30.139"
alias tyod="connect_tyo 172.31.22.11 ${beatle_curr_pass} 172.31.30.203"

#Phase 2 #####################################################################################################################################
#Phase 2 #####################################################################################################################################
connect_phase2(){
#connect_mozy_vpn
echo -e "${light_cyan}# Detecting VPN connection for $1${clear_color}"
[[ $(ps aux | egrep -c "[v]pnc $1") -eq 1 ]] || { echo -e "${red}# VPN for $1 not found.\n${light_cyan}# Detecting VPN connection for $2${clear_color}";[[ $(ps aux | egrep -c "[v]pnc $2") -eq 1 ]] || { { echo -e "${light_green}# Opening VPN connection to $1${clear_color}"; sudo vpnc $1.conf; } || { echo -e "${red}# Opening connection to $1 failed.\n${light_green}# Opening VPN connection to $2${clear_color}";sudo vpnc $2.conf; }; }; }
[[ -z "$4" ]] && rubi_pass="${beatle_curr_pass}" || rubi_pass="$4"
echo -e "\n\n${light_cyan}# ssh $3${clear_color}"
[[ -n "$3" ]] && sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$3"
}


connect_alln() {
connect_phase2 ${vpnc_conf_beatle_alln01} "${vpnc_conf_beatle_rdcy01}" "$1" "$2"
}
alias alln="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval alln\${cloudlet}"
alias allnmon="connect_alln 172.20.32.141 ${beatle_mon_curr_pass}"
alias allna="connect_alln 172.20.48.11"
alias allnb="connect_alln 172.20.48.75"
alias allnc="connect_alln 172.20.48.139"
alias allnd="connect_alln 172.20.48.203"
alias allne="connect_alln 172.20.49.11"
alias allnf="connect_alln 172.20.49.75"
alias allng="connect_alln 172.20.49.139"
alias allnh="connect_alln 172.20.49.203"
alias allni="connect_alln 172.20.50.11"
alias allnj="connect_alln 172.20.50.75"
alias allnk="connect_alln 172.20.50.139"
alias allnl="connect_alln 172.20.50.203"
alias allnm="connect_alln 172.20.51.11"
alias allnn="connect_alln 172.20.51.75"
alias allno="connect_alln 172.20.51.139"
alias allnp="connect_alln 172.20.51.203"
alias allnq="connect_alln 172.20.52.11"
alias allnr="connect_alln 172.20.52.75"
alias allns="connect_alln 172.20.52.139"
alias allnt="connect_alln 172.20.52.203"

connect_rdcy() {
connect_phase2 "${vpnc_conf_beatle_rdcy01}" ${vpnc_conf_beatle_alln01} "$1" "$2"
}
alias rdcy="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval rdcy\${cloudlet}"
alias rdcymon="connect_rdcy 172.20.0.141 ${beatle_mon_curr_pass}"
alias rdcya="connect_rdcy 172.20.16.11"
alias rdcyb="connect_rdcy 172.20.16.75"
alias rdcyc="connect_rdcy 172.20.16.139"
alias rdcyd="connect_rdcy 172.20.16.203"
alias rdcye="connect_rdcy 172.20.17.11"
alias rdcyf="connect_rdcy 172.20.17.75"
alias rdcyg="connect_rdcy 172.20.17.139"
alias rdcyh="connect_rdcy 172.20.17.203"
alias rdcyi="connect_rdcy 172.20.18.11"
alias rdcyj="connect_rdcy 172.20.18.75"
alias rdcyk="connect_rdcy 172.20.18.139"
alias rdcyl="connect_rdcy 172.20.18.203"
alias rdcym="connect_rdcy 172.20.19.11"
alias rdcyn="connect_rdcy 172.20.19.75"
alias rdcyo="connect_rdcy 172.20.19.139"
alias rdcyp="connect_rdcy 172.20.19.203"
alias rdcyq="connect_rdcy 172.20.20.11"
alias rdcyr="connect_rdcy 172.20.20.75"
alias rdcys="connect_rdcy 172.20.20.139"
alias rdcyt="connect_rdcy 172.20.20.203"

connect_sndg() {
connect_phase2 "${vpnc_conf_beatle_sndg01}" "${vpnc_conf_beatle_stls01}" "$1" "$2"
}
alias sndg="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval sndg\${cloudlet}"
alias sndgmon="connect_sndg 172.21.0.141 ${beatle_mon_curr_pass}"
alias sndga="connect_sndg 172.21.16.11"
alias sndgb="connect_sndg 172.21.16.75"
alias sndgc="connect_sndg 172.21.16.139"
alias sndgd="connect_sndg 172.21.16.203"
alias sndge="connect_sndg 172.21.17.11"
alias sndgf="connect_sndg 172.21.17.75"
alias sndgg="connect_sndg 172.21.17.139"
alias sndgh="connect_sndg 172.21.17.203"
alias sndgi="connect_sndg 172.21.18.11"
alias sndgj="connect_sndg 172.21.18.75"
alias sndgk="connect_sndg 172.21.18.139"
alias sndgl="connect_sndg 172.21.18.203"
alias sndgm="connect_sndg 172.21.19.11"
alias sndgn="connect_sndg 172.21.19.75"
alias sndgo="connect_sndg 172.21.19.139"
alias sndgp="connect_sndg 172.21.19.203"
alias sndgq="connect_sndg 172.21.20.11"
alias sndgr="connect_sndg 172.21.20.75"
alias sndgs="connect_sndg 172.21.20.139"
alias sndgt="connect_sndg 172.21.20.203"

connect_stls() {
connect_phase2 "${vpnc_conf_beatle_stls01}" "${vpnc_conf_beatle_sndg01}" "$1" "$2"
}
alias stls="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval stls\${cloudlet}"
alias stlsmon="connect_stls 172.21.32.141 ${beatle_mon_curr_pass}"
alias stlsa="connect_stls 172.21.48.11"
alias stlsb="connect_stls 172.21.48.75"
alias stlsc="connect_stls 172.21.48.139"
alias stlsd="connect_stls 172.21.48.203"
alias stlse="connect_stls 172.21.49.11"
alias stlsf="connect_stls 172.21.49.75"
alias stlsg="connect_stls 172.21.49.139"
alias stlsh="connect_stls 172.21.49.203"
alias stlsi="connect_stls 172.21.50.11"
alias stlsj="connect_stls 172.21.50.75"
alias stlsk="connect_stls 172.21.50.139"
alias stlsi="connect_stls 172.21.50.11"
alias stlsj="connect_stls 172.21.50.75"
alias stlsk="connect_stls 172.21.50.139"
alias stlsl="connect_stls 172.21.50.203"
alias stlsm="connect_stls 172.21.51.11"
alias stlsn="connect_stls 172.21.51.75"
alias stlso="connect_stls 172.21.51.139"
alias stlsp="connect_stls 172.21.51.203"
alias stlsq="connect_stls 172.21.52.11"
alias stlsr="connect_stls 172.21.52.75"
alias stlss="connect_stls 172.21.52.139"
alias stlst="connect_stls 172.21.52.203"

#Phase 2 EMEA
connect_amst() {
connect_phase2 "${vpnc_conf_beatle_amst01}" "${vpnc_conf_beatle_lond01}" "$1" "$2"
}
alias amst="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval amst\${cloudlet}"
alias amstmon="connect_amst 172.22.32.142 ${beatle_mon_curr_pass}"
alias amsta="connect_amst 172.22.48.11"
alias amstb="connect_amst 172.22.48.75"
alias amstc="connect_amst 172.22.48.139"
alias amstd="connect_amst 172.22.48.203"
alias amste="connect_amst 172.22.49.11"
alias amstf="connect_amst 172.22.49.75"
alias amstg="connect_amst 172.22.49.139"
alias amsth="connect_amst 172.22.49.203"
alias amsti="connect_amst 172.22.50.11"
alias amstj="connect_amst 172.22.50.75"
alias amstk="connect_amst 172.22.50.139"
alias amstl="connect_amst 172.22.50.203"
alias amstm="connect_amst 172.22.51.11"
alias amstn="connect_amst 172.22.51.75"
alias amsto="connect_amst 172.22.51.139"
alias amstp="connect_amst 172.22.51.203"
alias amstq="connect_amst 172.22.52.11"
alias amstr="connect_amst 172.22.52.75"
alias amsts="connect_amst 172.22.52.139"
alias amstt="connect_amst 172.22.52.203"

connect_lond() {
connect_phase2 "${vpnc_conf_beatle_lond01}" "${vpnc_conf_beatle_amst01}" "$1" "$2"
}
alias lond="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval lond\${cloudlet}"
alias londmon="connect_lond 172.22.0.141 ${beatle_mon_curr_pass}"
alias londa="connect_lond 172.22.16.11"
alias londb="connect_lond 172.22.16.75"
alias londc="connect_lond 172.22.16.139"
alias londd="connect_lond 172.22.16.203"
alias londe="connect_lond 172.22.17.11"
alias londf="connect_lond 172.22.17.75"
alias londg="connect_lond 172.22.17.139"
alias londh="connect_lond 172.22.17.203"
alias londi="connect_lond 172.22.18.11"
alias londj="connect_lond 172.22.18.75"
alias londk="connect_lond 172.22.18.139"
alias londl="connect_lond 172.22.18.203"
alias londm="connect_lond 172.22.19.11"
alias londn="connect_lond 172.22.19.75"
alias londo="connect_lond 172.22.19.139"
alias londp="connect_lond 172.22.19.203"
alias londq="connect_lond 172.22.20.11"
alias londr="connect_lond 172.22.20.75"
alias londs="connect_lond 172.22.20.139"
alias londt="connect_lond 172.22.20.203"

#Phase 2 APAC
connect_tkyo() {
connect_phase2 "${vpnc_conf_beatle_tkyo01}" "${vpnc_conf_beatle_hnkg01}" "$1" "$2"
}
alias tkyo="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo; eval tkyo\${cloudlet}"
alias tkyomon="connect_tkyo 172.23.0.141 ${beatle_mon_curr_pass}"
alias tkyoa="connect_tkyo 172.23.16.11"
alias tkyob="connect_tkyo 172.23.16.75"
alias tkyoc="connect_tkyo 172.23.16.139"
alias tkyod="connect_tkyo 172.23.16.203"
alias tkyoe="connect_tkyo 172.23.17.11"
alias tkyof="connect_tkyo 172.23.17.75"
alias tkyog="connect_tkyo 172.23.17.139"
alias tkyoh="connect_tkyo 172.23.17.203"
alias tkyoi="connect_tkyo 172.23.18.11"
alias tkyoj="connect_tkyo 172.23.18.75"
alias tkyok="connect_tkyo 172.23.18.139"
alias tkyol="connect_tkyo 172.23.18.203"
alias tkyom="connect_tkyo 172.23.19.11"
alias tkyon="connect_tkyo 172.23.19.75"
alias tkyoo="connect_tkyo 172.23.19.139"
alias tkyop="connect_tkyo 172.23.19.203"
alias tkyoq="connect_tkyo 172.23.20.11"
alias tkyor="connect_tkyo 172.23.20.75"
alias tkyor="connect_tkyo 172.23.20.75"
alias tkyor="connect_tkyo 172.23.20.75"
alias tkyor="connect_tkyo 172.23.20.75"
alias tkyor="connect_tkyo 172.23.20.75"
alias tkyos="connect_tkyo 172.23.20.139"
alias tkyot="connect_tkyo 172.23.20.203"

connect_hnkg() {
connect_phase2 "${vpnc_conf_beatle_hnkg01}" "${vpnc_conf_beatle_tkyo01}" "$1" "$2"
}
alias hnkg="clear;echo -en \"${light_cyan}Which site would you like to connect to? (a,b,c,d...etc.):${clear_color} \"; read -n 1 cloudlet; echo;eval hnkg\${cloudlet}"
alias hnkgmon="connect_hnkg 172.23.32.141 ${beatle_mon_curr_pass}"
alias hnkga="connect_hnkg 172.23.48.11"
alias hnkgb="connect_hnkg 172.23.48.75"
alias hnkgc="connect_hnkg 172.23.48.139"
alias hnkgd="connect_hnkg 172.23.48.203"
alias hnkge="connect_hnkg 172.23.49.11"
alias hnkgf="connect_hnkg 172.23.49.75"
alias hnkgg="connect_hnkg 172.23.49.139"
alias hnkgh="connect_hnkg 172.23.49.203"
alias hnkgi="connect_hnkg 172.23.50.11"
alias hnkgj="connect_hnkg 172.23.50.75"
alias hnkgk="connect_hnkg 172.23.50.139"
alias hnkgl="connect_hnkg 172.23.50.203"
alias hnkgm="connect_hnkg 172.23.51.11"
alias hnkgn="connect_hnkg 172.23.51.75"
alias hnkgo="connect_hnkg 172.23.51.139"
alias hnkgp="connect_hnkg 172.23.51.203"
alias hnkgq="connect_hnkg 172.23.52.11"
alias hnkgr="connect_hnkg 172.23.52.75"
alias hnkgs="connect_hnkg 172.23.52.139"
alias hnkgt="connect_hnkg 172.23.52.203"

##BEATLE WINDOWS JUMPBOXES##
alias dfw-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.16.34.44 &'
alias rwc-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.17.34.44 &'
alias lis-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.18.34.44 &'
alias sec-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.19.34.44 &'
alias syd-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.30.34.44 &'
alias tyo-win='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.31.34.44 &'
alias rdcywin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.20.0.44 &'
alias allnwin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.20.32.44 &'
alias sndgwin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.21.0.44 &'
alias stlswin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.21.32.44 &'
alias londwin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.22.0.44 &'
alias amstwin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.22.32.44 &'
alias tkyowin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.23.0.44 &'
alias hnkgwin='rdesktop -u administrator -g 1152x864 -a16 -rclipboard:PRIMARYCLIPBOARD 172.23.32.44 &'

##############################################################################################################################################
# Gouda  #####################################################################################################################################
# Gouda  #####################################################################################################################################
connect_gouda(){
#connect_mozy_vpn
echo -e "${light_cyan}# Detecting VPN connection for $1${clear_color}"
[[ $(ps aux | egrep -c "[v]pnc $1") -eq 1 ]] || { echo -e "${red}# VPN for $1 not found.\n${light_cyan}# Detecting VPN connection for $2${clear_color}";[[ $(ps aux | egrep -c "[v]pnc $2") -eq 1 ]] || { { echo -en "${light_green}# Opening VPN connection to $1:  ${clear_color}"; sudo vpnc $1.conf; } || { echo -en "${red}# Opening connection to $1 failed.\n${light_green}# Opening VPN connection to $2:  ${clear_color}";sudo vpnc $2.conf; }; }; }
[[ -z "$5" ]] && rubi_pass="${personal_gouda_pass}" || rubi_pass="$5"
echo -e "\n\n${light_cyan}# ssh $3${clear_color}"
[[ -n "$3" ]] && sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no ${emc_nt_username}@"$3" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no ${emc_nt_username}@"$4"
}
## ECS/ViPR in Las Vegas (lsvg)
connect_lsvg() {
connect_gouda "${vpnc_conf_gouda_lsvg01}" "${vpnc_conf_gouda_stng01}" ljb01.lsvg01.osaas.rcsops.com "$1" "$2"
# [[ $(ps aux | egrep -c "[v]pnc "${vpnc_conf_gouda_lsvg01}"") -eq 1 ]] || { [[ $(ps aux | egrep -c "[v]pnc "${vpnc_conf_gouda_stng01}"") -eq 1 ]] || { sudo vpnc "${vpnc_conf_gouda_lsvg01}".conf || sudo vpnc "${vpnc_conf_gouda_stng01}".conf; }; }
# [[ -z "$2" ]] && rubi_pass="${gouda_vipr_curr_pass}" || rubi_pass="$2"
# [[ -n "$1" ]] && sshpass -p "${rubi_pass}" ssh -vo StrictHostKeyChecking=no root@"$1"
# # ljb01.lsvg01.osaas.rcsops.com
}
#172.29.112.31 - .38 will be the nodes for beta that we'll be testing against. 
alias lsvg="clear;echo -en \"${light_cyan}Which site would you like to connect to? ( ViPR 1, 2, or 3 = v1, v2, v3 ECS 1-8 = e1, e2, e3, etc. ):${clear_color} \"; read -n 2 cloudlet; echo; eval lsvg\${cloudlet}"
alias lsvgv1="connect_lsvg 172.29.120.147"
alias lsvgv2="connect_lsvg 172.29.120.148"
alias lsvgv3="connect_lsvg 172.29.120.149"
alias lsvge1="connect_lsvg 172.29.112.31 ${gouda_ecs_curr_pass}"
alias lsvge2="connect_lsvg 172.29.112.32 ${gouda_ecs_curr_pass}"
alias lsvge3="connect_lsvg 172.29.112.33 ${gouda_ecs_curr_pass}"
alias lsvge4="connect_lsvg 172.29.112.34 ${gouda_ecs_curr_pass}"
alias lsvge5="connect_lsvg 172.29.112.35 ${gouda_ecs_curr_pass}"
alias lsvge6="connect_lsvg 172.29.112.36 ${gouda_ecs_curr_pass}"
alias lsvge7="connect_lsvg 172.29.112.37 ${gouda_ecs_curr_pass}"
alias lsvge8="connect_lsvg 172.29.112.38 ${gouda_ecs_curr_pass}"
alias lsvg_jb='sshpass -p ${personal_gouda_pass} ssh ${emc_nt_username}@ljb01.lsvg01.osaas.rcsops.com'

## ECS/ViPR in Sterling (stng)
connect_stng() {
connect_gouda "${vpnc_conf_gouda_stng01}" "${vpnc_conf_gouda_lsvg01}" ljb01.stng01.osaas.rcsops.com "$1" "$2"
# [[ $(ps aux | egrep -c "[v]pnc "${vpnc_conf_gouda_stng01}"") -eq 1 ]] || { [[ $(ps aux | egrep -c "[v]pnc "${vpnc_conf_gouda_lsvg01}"") -eq 1 ]] || { sudo vpnc "${vpnc_conf_gouda_stng01}".conf || sudo vpnc "${vpnc_conf_gouda_lsvg01}".conf; }; }
# #[[ -z "$2" ]] && rubi_pass="${gouda_vipr_curr_pass}" || rubi_pass="$2"
# [[ -n "$1" ]] && sshpass -p "${personal_gouda_pass}" ssh -vo StrictHostKeyChecking=no ${emc_nt_username}@ljb01.stng01.osaas.rcsops.com ssh -vo StrictHostKeyChecking=no ${emc_nt_username}@"$1"
}
#172.29.112.31 - .38 will be the nodes for beta that we'll be testing against. 
alias stng="clear;echo -en \"${light_cyan}Which site would you like to connect to? ( ViPR 1, 2, or 3 = v1, v2, v3 ECS 1-8 = e1, e2, e3, etc. ):${clear_color} \"; read -n 2 cloudlet; echo; eval stng\${cloudlet}"
alias stngv1="connect_stng 172.29.104.147"
alias stngv2="connect_stng 172.29.104.148"
alias stngv3="connect_stng 172.29.104.149"
alias stnge1="connect_stng 172.29.96.31 ${gouda_ecs_curr_pass}"
alias stnge2="connect_stng 172.29.96.32 ${gouda_ecs_curr_pass}"
alias stnge3="connect_stng 172.29.96.33 ${gouda_ecs_curr_pass}"
alias stnge4="connect_stng 172.29.96.34 ${gouda_ecs_curr_pass}"
alias stnge5="connect_stng 172.29.96.35 ${gouda_ecs_curr_pass}"
alias stnge6="connect_stng 172.29.96.36 ${gouda_ecs_curr_pass}"
alias stnge7="connect_stng 172.29.96.37 ${gouda_ecs_curr_pass}"
alias stnge8="connect_stng 172.29.96.38 ${gouda_ecs_curr_pass}"
alias stng_jb='sshpass -p ${personal_gouda_pass} ssh ${emc_nt_username}@ljb01.stng01.osaas.rcsops.com'


##############################################################################################################################################
# CSTaaS #####################################################################################################################################
# CSTaaS #####################################################################################################################################
connect_cstaas() {
#connect_mozy_vpn
echo -e "${light_cyan}# Detecting VPN connection for $1: ${clear_color}"
[[ $(ps aux | egrep -c "[v]pnc $1") -eq 1 ]] || { echo -e "${red}VPN for $1 not found.\n${light_cyan}# Detecting VPN connection for $2: ${clear_color}";[[ $(ps aux | egrep -c "[v]pnc $2") -eq 1 ]] || { { echo -en "${red}VPN for $2 not found.\n${light_green}# Opening VPN connection to $1:  ${clear_color}"; sudo vpnc $1.conf; } || { echo -en "${red}# Opening connection to $1 failed.\n${light_green}# Opening VPN connection to $2:  ${clear_color}";sudo vpnc $2.conf; }; }; }
[[ -z "$5" ]] && rubi_pass="${cstaas_jumpbox_curr_pass}" || rubi_pass="$5"
echo -e "\n\n${light_cyan}# ssh $3${clear_color}"
[[ -n "$3" ]] && { [[ -n "$4" ]] && sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$3" sshpass -p "${cstaas_node_curr_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$4"; } || sshpass -p "${rubi_pass}" ssh -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@"$3"
}

alias cstdfwjb=" connect_cstaas ${vpnc_conf_cstaas_dfw} ${vpnc_conf_cstaas_iad} 172.21.224.45"
alias cstiadjb=" connect_cstaas ${vpnc_conf_cstaas_iad} ${vpnc_conf_cstaas_dfw} 172.20.224.45" 
alias cstdfw="   connect_cstaas ${vpnc_conf_cstaas_dfw} ${vpnc_conf_cstaas_iad} 172.21.224.45 172.31.30.11"
alias cstiad="   connect_cstaas ${vpnc_conf_cstaas_iad} ${vpnc_conf_cstaas_dfw} 172.20.224.45 172.31.46.11" 
alias cstlonjb=" connect_cstaas ${vpnc_conf_cstaas_lon} ${vpnc_conf_cstaas_ams} 172.31.1.45"
alias cstamsjb=" connect_cstaas ${vpnc_conf_cstaas_ams} ${vpnc_conf_cstaas_lon} 172.31.1.45"
alias cstlon="   connect_cstaas ${vpnc_conf_cstaas_lon} ${vpnc_conf_cstaas_ams} 172.31.1.45"
alias cstams="   connect_cstaas ${vpnc_conf_cstaas_ams} ${vpnc_conf_cstaas_lon} 172.31.1.45"
alias govdfw="   connect_cstaas ${vpnc_conf_govcst_dfw} ${vpnc_conf_govcst_iad} 10.200.144.11"
alias goviad="   connect_cstaas ${vpnc_conf_govcst_iad} ${vpnc_conf_govcst_dfw} 10.202.144.11"
alias govdfwmon="connect_cstaas ${vpnc_conf_govcst_dfw} ${vpnc_conf_govcst_iad} 10.200.128.141"
alias goviadmon="connect_cstaas ${vpnc_conf_govcst_iad} ${vpnc_conf_govcst_dfw} 10.202.128.141"

# CSTaaS Jumpboxes
# alias iad='ssh -qtAC simisb@172.20.224.51 "$@"'
# alias dfws='ssh -qtAC simisb@172.21.224.51 "$@"'

##############################################################################################################################################
#        #####################################################################################################################################
#        #####################################################################################################################################

alias refreship="echo -e \"\n\"; getnew(){ echo -e \"# Refreshing connection.\"; sudo killall vpnc; sudo dhclient eth0 -r && ifconfig eth0; sudo dhclient eth0 && ifconfig eth0; return 0; }; while true; do sleep .3; if [[ \$(ping -w2 4.2.2.2 &>/dev/null;echo \$?) -eq 0 ]]; then echo -e \"# Internet connection established.\n\"; break; else getnew; fi; done"

alias refreshwireless="echo -e \"\n\"; getnew(){ echo -e \"# Refreshing connection.\"; sudo killall vpnc; sudo dhclient eth1 -r && ifconfig eth1; sudo dhclient eth1 && ifconfig eth1; sudo route add default gw 10.0.0.1 metric 0 dev eth1; return 0; }; while true; do sleep .3; if [[ \$(ping -w2 -Ieth1 4.2.2.2 &>/dev/null;echo \$?) -eq 0 ]]; then echo -e \"# Internet connection established.\n\"; break; else getnew; fi; done"

show_vpn_shortcuts() {
echo -e "\n\n\tOpen VPN connections: \n$(ps aux|egrep [v]pnc)\n\n\tAvailable VPN connections: "
egrep "[b]eatle-[a-z]*1" /etc/bash.bashrc | awk 'BEGIN {FS="\"beatle-|1\"";   printf "\n\t     Beatle Phase 1: \n\n"};/beatle-/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s\n",a[5],a[0],a[1],a[2],a[3]} END{printf "\n"}' 
egrep "[b]eatle-[a-z]*01" /etc/bash.bashrc | awk 'BEGIN {FS="\"beatle-|01\""; printf "\n\t     Beatle Phase 2: \n\n"};/beatle-/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s\n",a[5],a[0],a[1],a[2],a[3]} END{printf "\n"}'
egrep "connect_cstaas " /etc/bash.bashrc | awk 'BEGIN {FS="alias |=|\"|connect_cstaas"; printf "\t     CSTaaS: (add jb to connect to the jumpbox) \n\n"};!/jb/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s",a[5],a[0],a[1],a[2],a[3]} END{printf ""}'
egrep "[g]ouda-[a-z]*01" /etc/bash.bashrc | awk 'BEGIN {FS="\"gouda-|01\""; printf "\n\t     Gouda (ECS): \n\n"};/gouda/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s\n",a[5],a[0],a[1],a[2],a[3]} END{printf "\n"}'
# | awk '\''function red(string) { printf ("%s%s%s", "\033[1;31m", string, "\033[0m "); }; function green(string) { printf ("%s%s%s", "\033[1;32m", string, "\033[0m "); };BEGIN {FS="sudo vpnc beatle-|sudo vpnc cstaas-|sudo vpnc gouda-|01.conf|1.conf"; printf "\n\n"};/vpnc/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s\n",a[5],a[0],a[1],a[2],a[3]} END{printf "\n\n\n\n\n\n\n"}'\'' '
#'echo -e "\n\n";ps aux|egrep [v]pnc; egrep "[c]onf" /etc/bash.bashrc | egrep -v "[s]sh|vpn=|refreship=" | awk '\''function red(string) { printf ("%s%s%s", "\033[1;31m", string, "\033[0m "); }; function green(string) { printf ("%s%s%s", "\033[1;32m", string, "\033[0m "); };BEGIN {FS="sudo vpnc beatle-|sudo vpnc cstaas-|sudo vpnc gouda-|01.conf|1.conf"; printf "\n\n"};/vpnc/{a[i++]=$2;if (i==4){printf "%-14s %-14s %-14s %-14s %-14s \n\n",a[5], a[0], a[1], a[2], a[3] ;i=0;delete a}}END{if (i>0) printf "%-14s %-14s %-14s %-14s %-14s\n",a[5],a[0],a[1],a[2],a[3]} END{printf "\n\n\n\n\n\n\n"}'\'' '
}

alias vpn='show_vpn_shortcuts'
alias clear="clear;show_vpn_shortcuts"
