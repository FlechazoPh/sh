#!/bin/bash

# 定义颜色函数
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
grey(){
    echo -e "\033[36m\033[01m$1\033[0m"
}
purple(){
    echo -e "\033[35m\033[01m$1\033[0m"
}
white(){
    echo -e "\033[37m\033[01m$1\033[0m"
}
greenbg(){
    echo -e "\033[43;42m\033[01m $1 \033[0m"
}
redbg(){
    echo -e "\033[37;41m\033[01m $1 \033[0m"
}
yellowbg(){
    echo -e "\033[33m\033[01m\033[05m[ $1 ]\033[0m"
}

# 检查命令是否可用
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装函数
install_packages() {
    local packages=("sudo" "lsb-release" "curl" "wget" "curl" "unzip" "jq" "gnupg" "net-tools" "lsof")

    for package in "${packages[@]}"; do
        if command_exists "$package"; then
            greenbg "$package 已安装."
        else
            yellowbg "正在安装 $package..."
            sudo apt-get update && sudo apt-get install -y "$package"
            if [ $? -eq 0 ]; then
                greenbg "$package 安装成功."
            else
                redbg "无法安装 $package."
            fi
        fi
    done
}

# 检测系统类型并安装软件
check_and_install() {
    if [ -e /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            debian|ubuntu|devuan|raspbian|kali)
                install_packages
                ;;
            *)
                red "不支持的系统类型."
                ;;
        esac
    else
        red "无法确定系统类型."
    fi
}

# 主函数
main() {
    check_and_install
}

# 执行主函数
main
