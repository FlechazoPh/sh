# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
#
 # 追加到.bashrc文件底部即可
 # Append to end of .bashrc file
 #
 # 前景      背景         颜色
 # ---------------------------
 # 30        40           黑色
 # 31        41           紅色
 # 32        42           綠色
 # 33        43           黃色
 # 34        44           藍色
 # 35        45           紫紅色
 # 36        46           青藍色
 # 37        47           白色
 #
 # 代码     意义
 # -----------------
 # 0         OFF
 # 1         高亮显示
 # 4         underline
 # 5         闪烁
 # 7         反白显示
 # 8         不可见
_wjk_color_none='\[\033[00m\]'
_wjk_color_light_yellow='\[\033[1;33m\]'
_wjk_color_dark_yellow='\[\033[0;33m\]'
_wjk_color_light_blue='\[\033[1;34m\]'
_wjk_color_light_green='\[\033[1;32m\]'
_wjk_color_dark_green='\[\033[0;32m\]'
_wjk_color_light_purple='\[\033[1;35m\]'
_wjk_color_light_red='\[\033[1;31m\]'

_wjk_inner_color_none='\033[00m'
_wjk_inner_color_light_yellow='\033[1;33m'
_wjk_inner_color_dark_yellow='\033[0;33m'
_wjk_inner_color_light_blue='\033[1;34m'
_wjk_inner_color_light_green='\033[1;32m'
_wjk_inner_color_dark_green='\033[0;32m'
_wjk_inner_color_light_purple='\033[1;35m'
_wjk_inner_color_dark_purple='\033[0;35m'
_wjk_inner_color_light_red='\033[1;31m'
_wjk_inner_color_dark_red='\033[0;31m'

# ps1
_wjk_ps1() {

    local user_indicator='$'
    if [ $UID -eq "0" ] ; then
        user_indicator='#'
    fi

    local ps1_user_segment="${_wjk_color_light_yellow}${debian_chroot:+($debian_chroot)}\u${_wjk_color_none}"
    local ps1_host_segment="${_wjk_color_light_blue}\$(_wjk_custom_text)${_wjk_color_none}"
        local ps1_path_segment="${_wjk_color_light_green}\w${_wjk_color_none}"
        local ps1_git_segment="\$(_wjk_git_info)${_wjk_color_none}"

    echo "${ps1_user_segment}@${ps1_host_segment} ${ps1_path_segment} ${ps1_git_segment}${_wjk_color_light_red}${user_indicator}${_wjk_color_none} "
}

# 获取当前时间
_wjk_current_datetime() {
     echo $(date "+%Y-%m-%d %r")
}

# 主机或者自定义文字
_wjk_custom_text() {
    local hostnamestr=`hostname`

    if [[ -e '/etc/.wjk.bash.customtext' ]] ; then
        hostnamestr=`/etc/.wjk.bash.customtext`
    fi

    echo $hostnamestr
}

# git的仓库分支信息
function _wjk_git_info {
        if [[ "$(type -t git)" = "" ]] ; then
                return
        fi

        if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
                local ref bare
                if [[ "$(type -t git)" != "" ]] ; then
                        ref=$(git symbolic-ref --short -q HEAD 2> /dev/null)
                        bare=$(git config --bool core.bare)
                fi

                local repo_path=$(git rev-parse --git-dir 2>/dev/null)
                local current_mode=""
                local branch_color=$_wjk_inner_color_light_purple

                if [[ -e "${repo_path}/BISECT_LOG" ]]; then
                  current_mode=" <B>"
                  branch_color=$_wjk_inner_color_dark_purple
                elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
                  current_mode=" >M<"
                  branch_color=$_wjk_inner_color_dark_purple
                elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
                  current_mode=" >R>"
                  branch_color=$_wjk_inner_color_dark_purple
                else
                        if [[ "$(git status --porcelain -uno 2>/dev/null | head -n 1)" != "" ]] ; then
                                current_mode=" ✎"
                        fi
                fi

                local iscommitnode=""

                if [[ "$ref" = "" ]] ; then
                        ref=$(git log --oneline -1 2>/dev/null | cut -d " " -f 1)

                        if [ ${ref} ] ; then
                                iscommitnode="yes"
#                               ref="${_wjk_inner_color_dark_yellow} (($ref))"
                                ref=" (($ref))"
                        fi
                else
                        if $bare; then
                                branch_color=$_wjk_inner_color_dark_green
                        fi

#                       ref="${branch_color} (${ref}${_wjk_inner_color_dark_yellow}${current_mode}${branch_color})${_wjk_inner_color_none}"
                        ref="(${ref}${current_mode})"
                fi

#               echo -e $ref
                echo $ref
        fi
}

export PS1=$(_wjk_ps1)
