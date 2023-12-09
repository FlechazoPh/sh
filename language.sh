#!/bin/bash

#定义颜色输出函数
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

# 安装和配置 locales
setup_locales() {
    # 安装 locales 包
    sudo apt-get update
    sudo apt-get install -y locales

    # 生成 en_US.UTF-8 和 zh_CN.UTF-8 两种 locales
    sudo locale-gen en_US.UTF-8 zh_CN.UTF-8

    # 将默认 locale 设置为 zh_CN.UTF-8
    sudo update-locale LANG=zh_CN.UTF-8

    # 提供给用户选择的选项
    echo "请选择默认语言:"
    blue "1. =====================英文 (en_US.UTF-8)======================="
    blue "2. =====================中文 (zh_CN.UTF-8)======================="
    read -p "输入您的选择 (1 或 2): " choice

    case $choice in
        1)
            sudo update-locale LANG=en_US.UTF-8
            green "默认语言已设置为英文 (en_US.UTF-8)"
            ;;
        2)
            sudo update-locale LANG=zh_CN.UTF-8
            green "默认语言已设置为中文 (zh_CN.UTF-8)"
            ;;
        *)
            yellow "无效选择。默认语言保持为中文 (zh_CN.UTF-8)."
            ;;
    esac

    # 重新配置 locales 以应用更改
    sudo dpkg-reconfigure --frontend=noninteractive locales
}

# 执行设置 locales 的函数
setup_locales


# 检查当前语言环境是否已经是指定的环境
check_locale() {
    current_locale=$(locale | grep "LC_ALL" | awk -F'=' '{print $2}')
    if [ -z "$current_locale" ]; then
        redbg "=====================语言环境 LC_ALL 未设置====================="
        select_language
    elif [ "$current_locale" = "$1" ]; then
        greenbg "======================语言环境已设置为 $1======================"
    else
        yellowbg "======================语言环境非 $1======================"
        select_language
    fi
}

# 修改语言环境为指定的环境
change_to_locale() {
    blue "=================修改语言环境为 $1================="
    sudo update-locale LANG=$1 LC_ALL=$1
}

# 选择语言环境
select_language() {
    purple "======================= 语言环境 管理脚本 ======================="

    grey "1. ====================英文环境 (en_US.UTF-8)===================="
    blue "2. ====================中文环境 (zh_CN.UTF-8)===================="
    read -p "请输入数字 [1/2]: " choice

    case $choice in
        1)
            change_to_locale "en_US.UTF-8"
            ;;
        2)
            change_to_locale "zh_CN.UTF-8"
            ;;
        *)
            redbg "无效的选择，使用默认英文环境 (en_US.UTF-8)"
            change_to_locale "en_US.UTF-8"
            ;;
    esac
}

main() {
    check_locale "en_US.UTF-8" # 默认英文环境
}

main
