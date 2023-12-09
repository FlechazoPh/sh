#!/bin/bash

# 检查 Snell 是否已安装
function is_snell_installed() {
    systemctl is-active --quiet snell.service
}

# 安装 Snell
function install_snell() {
    # 确定安装命令
    local os_name=$(lsb_release -si)
    local installer_command
    case $os_name in
        Debian|Ubuntu|Armbian|Deepin|Mint)
            installer_command="apt-get install wget unzip dpkg -y"
            ;;
        CentOS|Fedora|RedHat|Redhat)
            installer_command="yum install wget unzip dpkg -y"
            ;;
        Arch|Manjaro)
            installer_command="yes | pacman -S wget dpkg unzip --needed --noconfirm"
            ;;
        *)
            echo "无法确定系统类型或找不到适用的包管理器。"
            exit 1
            ;;
    esac

    # 安装依赖
    $installer_command || { echo "安装依赖失败。"; exit 1; }

    # 下载 Snell
    ARCH=$(uname -m)
    case $ARCH in
        aarch64 | armv8)
            match="linux-aarch64"
            ;;
        armv7 | armv6l)
            match="linux-armv7l"
            ;;
        *)
            match="linux-amd64"
            ;;
    esac

    local snell_url="https://dl.nssurge.com/snell/snell-server-v4.0.1-$match.zip"
    wget --no-check-certificate -O snell.zip $snell_url || { echo "下载 Snell 失败。"; exit 1; }
    unzip -o snell.zip || { echo "解压 Snell 失败。"; exit 1; }
    chmod +x snell-server
    mv snell-server /usr/local/bin/

    # 创建配置文件
    local conf="/etc/snell/snell-server.conf"
    mkdir -p /etc/snell/
    if [ ! -f $conf ]; then
        local psk=$(openssl rand -hex 16)
        echo "生成新的 PSK: $psk"
        echo "[snell-server]" > $conf
        echo "listen = 0.0.0.0:8888" >> $conf
        echo "psk = $psk" >> $conf
        echo "obfs = tls" >> $conf
    fi

    # 创建 Snell 守护进程
    local systemd="/etc/systemd/system/snell.service"
    if [ ! -f $systemd ]; then
        echo "生成 Snell 守护进程..."
        cat <<EOF >$systemd
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
LimitNOFILE=8888
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable snell
        systemctl start snell
    fi

    echo "Snell 已成功安装！"
    #生成snell节点内容。
    echo "$(uname -n) = snell, $(curl -s ipinfo.io/ip), $(cat /etc/snell/snell-server.conf | grep -i listen | cut --delimiter=':' -f2), psk=$(grep 'psk' /etc/snell/snell-server.conf | cut -d= -f2 | tr -d ' '), version=4, tfo=true"
    
}

# 卸载 Snell
function uninstall_snell() {
    systemctl stop snell.service
    systemctl disable snell.service
    rm -rf /etc/systemd/system/snell.service
    rm -rf /usr/local/bin/snell-server
    rm -rf /etc/snell/
    echo "Snell 已成功卸载！"
}

# 检测 Snell 安装状态并执行相应操作
function check_and_manage_snell() {
    if is_snell_installed; then
        echo "Snell 已安装。是否需要卸载？(yes/no)"
        read choice
        if [ "$choice" == "yes" ]; then
            uninstall_snell
            echo "Snell 已成功卸载。"
        elif [ "$choice" == "no" ]; then
            echo "保持 Snell 安装状态。"
        else
            echo "无效输入，保持 Snell 安装状态。"
        fi
    else
        echo "Snell 未安装，正在进行安装..."
        install_snell
        echo "Snell 安装完成。"
    fi
}

check_and_manage_snell
