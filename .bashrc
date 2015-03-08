#-------------------
# Personnal Aliases
#-------------------
alias update_cloud_op="/bin/cp /mnt/hgfs/MyScripts/Bash\ Scripts/Kollin/cloud_op.sh /usr/local/bin/cloud_op.sh"

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# -> Prevents accidentally clobbering files.
alias mkdir='mkdir -p'

alias h='history'
alias j='jobs -l'
alias which='type -a'
alias ..='cd ..'

# Pretty-print of some PATH variables:
alias path='echo -e ${PATH//:/\\n}'
alias libpath='echo -e ${LD_LIBRARY_PATH//:/\\n}'


alias du='du -kh'    # Makes a more readable output.
alias df='df -kTh'

export GREP_OPTIONS='--color=auto'  ## add color to all grep options

#-------------------------------------------------------------
# The 'ls' family (this assumes you use a recent GNU ls).
#-------------------------------------------------------------
# Add colors for filetype and  human-readable sizes by default on 'ls':
alias ls='ls -h --color'
alias lx='ls -lXB'         #  Sort by extension.
alias lk='ls -lSr'         #  Sort by size, biggest last.
alias lt='ls -ltr'         #  Sort by date, most recent last.
alias lc='ls -ltcr'        #  Sort by/show change time,most recent last.
alias lu='ls -ltur'        #  Sort by/show access time,most recent last.

# The ubiquitous 'll': directories first, with alphanumeric sorting:
alias ll="ls -lv --group-directories-first"
alias lm='ll |more'        #  Pipe through 'more'
alias lr='ll -R'           #  Recursive ls.
alias la='ll -A'           #  Show hidden files.
alias tree='tree -Csuh'    #  Nice alternative to 'recursive ls' ...


#-------------------------------------------------------------
# Tailoring 'less'
#-------------------------------------------------------------

alias more='less'
export PAGER=less
export LESSCHARSET='latin1'
export LESSOPEN='|/usr/bin/lesspipe.sh %s 2>&-'
                # Use this if lesspipe.sh exists.
export LESS='-i -N -w  -z-4 -g -e -M -X -F -R -P%t?f%f \
:stdin .?pb%pb\%:?lbLine %lb:?bbByte %bb:-...'

# LESS man page colors (makes Man pages more readable).
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


#-------------------------------------------------------------
# Spelling typos - highly personnal and keyboard-dependent :-)
#-------------------------------------------------------------

alias xs='cd'
alias vf='cd'
alias moer='more'
alias moew='more'
alias kk='ll'
alias duso="sudo"


#-------------------------------------------------------------
# A few fun ones
#-------------------------------------------------------------

# Adds some text in the terminal frame (if applicable).

function xtitle()
{
    case "$TERM" in
    *term* | rxvt)
        echo -en  "\e]0;$*\a" ;;
    *)  ;;
    esac
}


# Aliases that use xtitle
alias top='xtitle Processes on $HOST && top'
alias make='xtitle Making $(basename $PWD) ; make'

# .. and functions
function man()
{
    for i ; do
        xtitle The $(basename $1|tr -d .[:digit:]) manual
        command man -a "$i"
    done
}


#-------------------------------------------------------------
# Start screen
#-------------------------------------------------------------

# function to kill all screen sessions.
killscreen() {
    for session in $(screen -ls | grep -o '[0-9]\{4\}')
    do
        screen -S "${session}" -X quit;
    done
}

# fancy stuffs to start screen if none exists already.. http://serverfault.com/questions/1580/gnu-screen-and-bashrc
# set a fancy prompt (non-color, unless we know we "want" color)
if [[ $TERM =~ xterm-.*color || $TERM =~ screen.* ]]; then
   PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
   #if [[ $TERM =~ screen.* ]]; then
   export SCREEN_CMD=$(which screen 2>/dev/null)
   if [[ ( $TERM =~ screen.* ) || ${SCREEN_CMD-X} != X && ${SCREEN_CMD-X} != "" ]]; then
      # This is the escape sequence ESC k \w ESC \
      #Use path as title
      #SCREENTITLE='\[\ek\w\e\\\]'
      #Use program name as title
      SCREENTITLE='\[\ek\e\\\]'
   else
      #Soliton@freenode#screen suggested screen -xRRS primary
      echo ^[k$(hostname|sed "s/\..*//")^[\\
      export SCREEN_CMD=$(which screen 2>/dev/null)
      if [[ ${SCREEN_CMD-X} != X && ${SCREEN_CMD-X} != "" ]]; then
         screen -xRRS primary && unset SCREEN_CMD && [[ $(stat -c %Y .screen_do_not_disconnect 2>/dev/null || stat -f %m .screen_do_not_disconnect 2>/dev/null) -gt 0 ]] || exit
      fi
   fi
else
   PS1='\u@\h:\w# '
   SCREENTITLE=''
   #Soliton@freenode#screen suggested screen -xRRS primary
   echo ^[k$(hostname|sed "s/\..*//")^[\\
   export SCREEN_CMD=$(which screen 2>/dev/null)
   if [[ ${SCREEN_CMD-X} != X ]]; then
      screen -xRRS primary && unset SCREEN_CMD && [[ $(stat -c %Y .screen_do_not_disconnect 2>/dev/null || stat -f %m .screen_do_not_disconnect 2>/dev/null) -gt 0 ]] || exit
   fi
fi
PS1="${SCREENTITLE}${PS1}"
 
 
