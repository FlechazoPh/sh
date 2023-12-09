#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 设置变量

#脚本主目录
BASH_FILE="$SCRIPT_DIR/cdn"
#日志位置
LOG_FILE="$SCRIPT_DIR/cdn/log.txt"
#cloudflareST主程序文件保存位置
RESULT_CSV="$SCRIPT_DIR/cdn/result.csv"
#cloudflareST主程序IP文件
CloudflareST_IP_FILE="$SCRIPT_DIR/cdn/ip.txt"
#cloudflareST主程序优选IP文件
OPTIMIZED_IP_FILE="$SCRIPT_DIR/cdn/优选IP.txt"
#科学配置文件
SURGE_CONFIG="$SCRIPT_DIR/cdn/ONE.conf"
#科学配置文件远程位置
SURGE_LINE=""
#上传目标文件
REMOTE_SERVER=""
#cloud flare优选工具位置
CloudflareST_FILE="$SCRIPT_DIR/cdn/CloudflareST"  # CloudflareST 的文件路径
#cloud flare优选工具下载链接
CloudflareST_LINE="https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.2.5/CloudflareST_linux_amd64.tar.gz"
# 记录下载的压缩包位置
downloaded_file="$SCRIPT_DIR/cdn/CloudflareST.tar.gz"
#获取 Cloudflare CDN IPv4 地址段列表
CloudflareST_IP_LINE="https://www.cloudflare.com/ips-v4"

# 函数：输出不同颜色的信息
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


# 检查SURGE_LINE 和 REMOTE_SERVER 是否已配置
check_configurations() {
    if [[ -z "$SURGE_LINE" || -z "$REMOTE_SERVER" ]]; then
        red "SURGE_LINE 或 REMOTE_SERVER 未配置，请设置以下内容："

        read -p "请输入 SURGE_LINE 的值: " input_surge_line
        read -p "请输入 REMOTE_SERVER 的值: " input_remote_server

        # 更新脚本中的配置
        if [[ -n "$input_surge_line" && -n "$input_remote_server" ]]; then
            sed -i "s#^SURGE_LINE=.*#SURGE_LINE=\"$input_surge_line\"#" "$0"
            sed -i "s#^REMOTE_SERVER=.*#REMOTE_SERVER=\"$input_remote_server\"#" "$0"
            green "已更新配置文件。"
        else
            red "未提供有效输入。配置文件未更改。"
        fi
    else
        green "SURGE_LINE 和 REMOTE_SERVER 已配置，可以正常运行脚本。"
    fi
}



# 检查是否已安装 curl、unzip、jq、wget，如果不存在则尝试安装
check_dependencies() {
    # 检查系统是否为 Ubuntu 或 Debian
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ $ID == "ubuntu" || $ID == "debian" ]]; then
            purple "当前系统为 $ID"

            # 检查是否已安装 curl, unzip 和 jq，如果不存在则尝试安装
            packages=("curl" "unzip" "jq" "wget")
            for pkg in "${packages[@]}"; do
                if ! command -v "$pkg" &> /dev/null; then
                    redbg "$pkg 未安装，尝试安装..."
                    sudo apt-get update
                    sudo apt-get install -y "$pkg"
                fi
            done
        else
            redbg "不支持的系统类型"
            exit 1
        fi
    else
        redbg "无法确定系统类型"
        exit 1
    fi
}


# 获取BASH_FILE所在的文件夹路径
get_BASH_FILE_info() {
    # 检查BASH_FILE是否存在，不存在则创建
    if [ ! -d "$BASH_FILE" ]; then
        blue "文件夹不存在，开始创建..."
        mkdir -p "$BASH_FILE"
        chmod -R 777 "$BASH_FILE"  # 赋予写入、读取、执行的所有权限
        green "文件夹创建完成。"
    else
        redbg "文件夹已存在，跳过创建。"
    fi
}

# 函数：获取公网IP和国家
get_public_ip_info() {
grey "=======================================获取公网IP和国家======================================="
    sleep 2
    ipinfo=$(curl -s ipinfo.io)
    
    publicip=$(echo "$ipinfo" | jq -r '.ip')
    
    country=$(echo "$ipinfo" | jq -r '.country')

    if [ "$country" = "CN" ]; then
        grey "网络国家: 中  国"
    else
        redbg "网络国家: 外  国"
    fi

    purple "公网  IP: $publicip"
}

# 函数：检查网络状态
check_network_status() {
    network_status=$(curl -s -o /dev/null --connect-timeout 2 -w "%{http_code}" https://www.google.com/)

    if [ "$network_status" = "200" ]; then
        green "网络状态: 科学冲浪"
    else
        red "网络状态: 闭关锁国"
    fi
}

# 函数：检查配置文件是否存在
CONFIG(){
    # 检查 CloudflareST 是否存在
    if [ ! -f "$SURGE_CONFIG" ]; then
        # 如果 CloudflareST 不存在，则下载
        green "配置文件 不存在，开始下载..."
        curl -o "$SURGE_CONFIG" "$SURGE_LINE"  # 替换为正确的下载链接


        grey "配置文件 下载完成。"
    else
        blue "配置文件 已存在，跳过下载。"
    fi
}



# 函数：cloudflareST主程序IP文件
CloudflareST_IP(){
    # 检查 CloudflareST ip.txt是否存在
    if [ ! -f "$CloudflareST_IP_FILE" ]; then
        # 如果 CloudflareST ip.txt不存在，则下载
        green "CloudflareST ip.txt 不存在，开始下载..."
        
        curl --connect-timeout 30 -o "$CloudflareST_IP_FILE" "$CloudflareST_IP_LINE"  > /dev/null # 替换为正确的下载链接


        grey "CloudflareST ip.txt 下载完成。"
    else
        blue "CloudflareST ip.txt 已存在，跳过下载。"
    fi

}


# 函数:检查CloudflareST主程序是否存在且给予权限
CloudflareST(){
    # 检查 CloudflareST 是否存在
    if [ ! -f "$CloudflareST_FILE" ]; then
        # 如果 CloudflareST 不存在，则下载压缩包
        green "CloudflareST 不存在，开始下载..."

        # 使用 wget 设置超时时间为 30 秒下载文件
        if wget --timeout=30 -O "$SCRIPT_DIR/cdn/CloudflareST.tar.gz" "$CloudflareST_LINE"; then
            grey "CloudflareST 下载完成。"
        else
            red "下载 CloudflareST 文件超时！请检查网络连接并重试。"
            exit 1
        fi
    else
        blue "CloudflareST 已存在，跳过下载。"
    fi

    # 检查是否下载成功
    if [ -f "$SCRIPT_DIR/cdn/CloudflareST.tar.gz" ]; then

        # 解压缩文件
        tar -xzf "$downloaded_file" -C "$SCRIPT_DIR/cdn" CloudflareST

        # 删除下载的压缩包
        rm "$downloaded_file"

        # 给予执行权限
        chmod +x "$CloudflareST_FILE"

        grey "CloudflareST 解压并赋予执行权限完成。"
    else
        blue "没有可用的 CloudflareST 压缩包。"
    fi

}




# 函数：运行CloudflareST工具进行IP优选
run_cloudflarest() {
white "======================================= 优选  IP ======================================="
#执行cloudflareST主程序
#2秒后启动
sleep 2
$CloudflareST_FILE -n 1000 -tll 30 -tl 180 -sl 12 -p 10 -url https://cdn.cloudflare.steamstatic.com/steam/apps/256870924/movie_max.mp4 -f "$CloudflareST_IP_FILE" -o "$RESULT_CSV" /dev/null
}

# 函数：提取优选IP信息
extract_optimized_ip_info() {
#提取优选ip地址
IP=$(cat $RESULT_CSV|sed -n '2p'|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}"|grep -wv 255)

red "优选IP $IP"

#提取优选IP网速
speed=$(cat $RESULT_CSV|cut -d , -f 6 |sed -n 2p)

white "实测带宽 $speed Mb/s"

#提取优选IP延时
time=$(cat $RESULT_CSV|cut -d , -f 5 |sed -n 2p)

yellow "网络延迟 $time ms"
}

# 函数：替换Surge配置文件中的IP
replace_ip_in_surge_config() {
Surge=$(cat $SURGE_CONFIG|sed -n '85p'|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}"|grep -wv 255)

green "Surge 原生IP $Surge"
sleep 1
sudo sed -i "s/${Surge}/${IP}/g" $SURGE_CONFIG
#替换Surge ip
sleep 1
clash=$(cat $SURGE_CONFIG|sed -n '85p'|egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}"|grep -wv 255)
#再次获取Surge ip
yellow "Surge 优选IP $clash"
}

# 函数：将修改后的配置文件发送到另一个服务器
send_config_to_remote_server() {
grey "======================================= 替换配置 ======================================="

scp $SURGE_CONFIG $REMOTE_SERVER
}

# 函数：记录日志
log_info() {
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$current_time] $1" >> "$LOG_FILE"
    # 自动添加到 Cron 任务
SCRIPT="$(readlink -f "$0")"
CRON_JOB="*/30 * * * * $SCRIPT >> $LOG_FILE 2>&1"
(crontab -l 2>/dev/null | grep -Fq "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

# 检查 Cron 任务
if crontab -l | grep -Fq "$SCRIPT"; then
    green "Cron 任务已存在并已更新。"
else
    red "Cron 任务不存在，尝试添加失败。"
fi
}


# 启用错误检查
# set -e

main(){
# 检查SURGE_LINE 和 REMOTE_SERVER 是否已配置
check_configurations
# 检查是否已安装 curl、unzip、jq、wget，如果不存在则尝试安装
check_dependencies
# 获取BASH_FILE所在的文件夹路径
get_BASH_FILE_info
# 记录开始时间
log_info "脚本开始执行"
# 函数：获取公网IP和国家
get_public_ip_info
# 函数：检查网络状态
check_network_status
# 函数：检查配置文件是否存在
CONFIG
# 函数：cloudflareST主程序IP文件
CloudflareST_IP
# 函数:检查CloudflareST主程序是否存在且给予权限
CloudflareS
# 函数：运行CloudflareST工具进行IP优选
run_cloudflarest
# 函数：提取优选IP信息
extract_optimized_ip_info
# 函数：替换Surge配置文件中的IP
replace_ip_in_surge_config
# 函数：将修改后的配置文件发送到另一个服务器
send_config_to_remote_server
# 记录结束时间
log_info "脚本执行结束"
}


main
