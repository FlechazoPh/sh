#!/bin/bash
#########################################注意注意注意注意注意############################################

#蓝色
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
#绿色
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
#红色
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
#黄色
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
#天蓝
grey(){
    echo -e "\033[36m\033[01m$1\033[0m"
}
#紫色
purple(){
    echo -e "\033[35m\033[01m$1\033[0m"
}
#白色
white(){
    echo -e "\033[37m\033[01m$1\033[0m"
}
#绿色背景
greenbg(){
    echo -e "\033[43;42m\033[01m $1 \033[0m"
}
#红色背景
redbg(){
    echo -e "\033[37;41m\033[01m $1 \033[0m"
}
#黄色背景
yellowbg(){
    echo -e "\033[33m\033[01m\033[05m[ $1 ]\033[0m"
}


#==================================================================================================

#=======================================总是开启root登录===================================================
#===================================匹配特定符号下一行添加指定内容============================================
sed -i '/\[security\]/a\AllowRoot = true' /etc/gdm3/daemon.conf

AllowRoot=$(cat /etc/gdm3/daemon.conf|sed -n 19p)

if [ "$AllowRoot" = "AllowRoot = true" ]; then
    green "root登录开启"
else
    white "$AllowRoot"
    green "root登录开启"
fi

#=======================================开启自动登录======================================================
#=======================================删除开头的#注释===================================================
sudo sed -i -e 's/^#\?  AutomaticLoginEnable/AutomaticLoginEnable/g' /etc/gdm3/daemon.conf;

AutomaticLoginEnable=$(cat /etc/gdm3/daemon.conf|sed -n 10p)

if [ "$AutomaticLoginEnable" = "AutomaticLoginEnable = true" ]; then
    green "自动登录开启"
else
    white "$AutomaticLoginEnable"
    yellow "自动登录开启"
fi

#=======================================ROOT自动登录=====================================================
#=======================================删除开头的#注释===================================================
sudo sed -i -e 's/^#\?  AutomaticLogin = user1/AutomaticLogin = root/g' /etc/gdm3/daemon.conf;

AutomaticLogin=$(cat /etc/gdm3/daemon.conf|sed -n 11p)

if [ "$AutomaticLogin" = "AutomaticLogin = root" ]; then
    green "root自动登录开启"
else
    white "$AutomaticLogin"
    blue "root自动登录开启"
fi

#=======================================匹配某个值，在行前加#注释============================================
sudo sed -i "s/^[^#].*success$/#&/g" /etc/pam.d/gdm-autologin

autologin=$(cat /etc/pam.d/gdm-autologin|sed -n 3p)

if [ "$autologin" = "# auth required pam_succeed_if.so user != root quiet_success" ]; then
    green "root自动登录开启完成"
else
    white "$autologin"
fi

sudo sed -i "s/^[^#].*success$/#&/g" /etc/pam.d/gdm-password

password=$(cat /etc/pam.d/gdm-password|sed -n 3p)

if [ "$password" = "# auth required pam_succeed_if.so user != root quiet_success" ]; then
    green "root自动登录开启完成"
else
    white "$password"
fi

