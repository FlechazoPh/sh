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

# 检查是否已经开启root登录
if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config; then
    red "root登录已开启，脚本退出"
    exit 1
fi

# 检查是否已经开启密码认证
if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
    red "密码认证已开启，脚本退出"
    exit 1
fi

#=======================================Debian 一键开启root登录===================================================

apt install sudo

sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;

sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;

sudo service sshd restart

# 检查配置是否成功
if grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config && grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
    green "root登录开启完成"
else
    red "无法成功开启root登录"
fi
