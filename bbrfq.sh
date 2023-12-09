#!/bin/bash

# 检查是否已开启 BBR
check_bbr_status() {
    bbr_status=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    
    if [[ "$bbr_status" == "bbr" ]]; then
        echo "BBR 已开启，无需更改。"
    else
        echo "BBR 未开启，开始开启 BBR..."
        enable_bbr
    fi
}

# 开启 BBR
enable_bbr() {
    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
    
    sudo sysctl -p

    echo "BBR 已成功开启。"
}

# 执行检查函数
check_bbr_status
