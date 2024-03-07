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
# 作者: JIJUNRONG
# 博客: https://blog.jijunrong.com/
#==================================================================================================
######################################################################################################

function author_info() {
    blue " ========================================================"
    grey " ======================= ONE 集合 ======================="
    blue " ========================================================"
}

#一键DD脚本
function Debian(){
    curl -fLO https://raw.githubusercontent.com/jijunrong/sh/main/debian.sh && chmod a+rx debian.sh
    blue "DD脚本下载完成"
    blue "请选择安装方式："
    green " 1. 默认安装"
    green " 2. 本地静态IP及网关安装"
    green " 3. 自定义参数安装"
    green " 0. 返回上一层"

    read -n 1 -p "请输入数字 [默认为 1]: " choice

    case ${choice:-1} in
        1)
            sudo ./debian.sh --cdn --network-console --ethx --bbr --user root --password zxc1230. --version 13
            sudo shutdown -r now
            ;;
        2)
            read -p "请输入静态IP地址: " ip
            read -p "请输入  网关地址: " gateway
            sudo ./debian.sh --ip "$ip" --netmask 255.255.255.0 --gateway "$gateway" --dns '8.8.8.8 114.114.114.114' --cdn --network-console --ethx --bbr --user root --password zxc1230. --version 13
            sudo shutdown -r now
            ;;
        3)
            read -p "请输入自定义参数: " custom_params
            sudo ./debian.sh $custom_params
            sudo shutdown -r now
            ;;
        0)
            return
            ;;
        *)
            echo "请输入正确的选项！"
            ;;
    esac
}

#常用apt一键脚本
function app(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/apt.sh)" 
    blue "常用安装完成"
}

#卸载桌面环境自带游戏及软件
function removeapt(){
    sudo apt remove --purge -y gnome-2048 aisleriot gnome-chess five-or-more four-in-a-row gnome-nibbles hitori gnome-klotski libreoffice-* lightsoff gnome-mahjongg gnome-mines quadrapassel iagno gnome-robots gnome-sudoku swell-foop tali fcitx5-* gnome-taquin gnome-tetravex
}

# 科学代理协议安装及卸载管理
function proxy_management() {
    clear
    red "================科学代理协议安装 卸载管理================"
    green " 1. 安装 snell"
    green " 2. 卸载 snell" 
    green " 3. 安装 xray"
    green " 4. 卸载 xray"
    green " 0. 返回上一层"
    echo
    read -p "请输入数字:" proxyice

    case $proxyice in
        1)
            install_snell
            ;;
        2)
            uninstall_snell
            ;;
        3)
            install_xray
            ;;
        4)
            uninstall_xray
            ;;
        0)
            menu
            ;;
        *)
            echo "请输入正确的选项！"
            ;;
    esac
}


#安装snell
function install_snell() {
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/jijunrong/sh/main/snell.sh)"
blue "snell安装完成"
}

#卸载snell
function uninstall_snell() {
    sudo bash -c "$(curl -sL https://raw.githubusercontent.com/jijunrong/sh/main/rmsnell.sh)"
    blue "snell卸载完成"
}

#安装xray
function install_xray() {
    sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    blue "xray安装完成"
}

#卸载xray
function uninstall_xray() {
    sudo bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    blue "xray卸载完成"
}

#网络管理及网卡重命名
function eth0(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/eth0.sh)"
}

#Cloudflare CDN优选IP脚本
function CloudflareIP(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/CloudflareIP.sh)"
}

#桌面版root自动登录
function login(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/login.sh)"
}

#ssh一键root登录
function root(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/root.sh)"
}

#获取本地IP地址
function getip(){
    ip=$(curl -s ipinfo.io/ip)
    grey "本地IP地址： $ip "

    sleep 3
}


#设置时区为Asia/Shanghai
function timezone(){
    sudo timedatectl set-timezone Asia/Shanghai
}

#启动BBR FQ算法
function bbrfq(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/bbrfq.sh)"
}

#更改主机名称及登陆提示信息
function motd(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/motd.sh)"
}

#默认语言环境判定
function language(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/language.sh)"
}

#Bash个性化配置
function systembash(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/systembash.sh)"
}

#桌面环境系统禁止系统休眠
function sleepstatus(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/sleepstatus.sh)"
}

#备用TEST管理
function TEST(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/HOME.sh)"
}

#备用HOME管理
function HOME(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/HOME.sh)"
}

#流媒体一键脚本
function movie(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/movie.sh)"
}


#DDNS自动更新管理
function ddns(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/ddns.sh)"
}


#CloudFlare 域名管理
function CloudFlare(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/CloudFlare.sh)"
}


#自动化管理SSL证书
function ssl(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/ssl.sh)"
}

#SWAP一键安装/卸载管理
function swap(){
    sudo bash -c "$(curl -L https://raw.githubusercontent.com/jijunrong/sh/main/swap.sh)"
}




# 主菜单函数
function menu() {
    while true; do
        clear
        author_info
    
        white " 1. $(blue '一键DD脚本')\t\t\t6. $(grey 'Cloudflare CDN优选IP')"
        white " 2. $(blue '常用apt一键脚本')\t\t7. $(grey '桌面版root自动登录')"
        white " 3. $(blue '卸载桌面环境自带游戏及软件')\t8. $(grey 'ssh一键root登录')"
        white " 4. $(blue '科学代理协议安装及卸载管理')\t9. $(grey '获取本地IP地址')"
        white " 5. $(blue '网络管理及网卡重命名')\t10. $(grey '设置时区为Asia/Shanghai')"
        yellow " ========================================================"
        white " 11. $(purple '网络优化BBR FQ算法')\t\t16. $(green '备用TEST管理')"
        white " 12. $(purple '更改主机名称及登陆提示信息')\t17. $(green '备用HOME管理')"
        white " 13. $(purple '默认语言环境判定')\t\t18. $(green '流媒体一键脚本')"
        white " 14. $(purple 'Bash个性化配置')\t\t19. $(green 'DDNS自动更新管理')"
        white " 15. $(purple '桌面环境系统禁止系统休眠')\t20. $(green 'CloudFlare 域名管理') "
        yellow " ========================================================"
        white " 30. $(yellow '自动化管理SSL证书')\t\t31. $(yellow 'SWAP一键安装/卸载管理')"
        white " 0. $(red '退出脚本')"
        green " ========================================================"
        echo
        read -t 60 -p "$(green '请输入数字:') " choice

        case $choice in
            [1-9]|1[0-9]|2[0])
                case $choice in
                    1) Debian ;;
                    2) app ;;
                    3) removeapt ;;
                    4) proxy_management ;;
                    5) eth0 ;;
                    6) CloudflareIP ;;
                    7) login ;;
                    8) root ;;
                    9) getip ;;
                    10) timezone ;;
                    11) bbrfq ;;
                    12) motd ;;
                    13) language ;;
                    14) systembash ;;
                    15) sleepstatus ;;
                    16) TEST ;;
                    17) HOME ;;
                    18) movie ;;
                    19) ddns ;;
                    20) CloudFlare ;;
                    30) ssl ;;
                    31) swap ;;
                esac
                ;;
            0)
                exit 0
                ;;
            "")
                echo "未输入任何内容，即将退出脚本..."
                exit 1
                ;;
            *)
                echo "请输入正确的选项！"
 
                continue
                ;;
        esac
    done
}

menu
