#!/bin/bash

# 定义颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 输出带颜色的信息
echo_color() {
    color="$1"
    text="$2"
    echo -e "${color}${text}${NC}"
}

# 确保脚本以 root 权限运行
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_color "$RED" "此脚本必须以 root 权限运行。"
        exit 1
    fi
}

# 检查 NetworkManager 服务是否正在运行
check_network_service() {
    if systemctl is-active NetworkManager; then
        echo_color "$GREEN" "系统正在使用 NetworkManager 进行网络管理。"
        main_menu
    elif systemctl is-active networking; then
        echo_color "$GREEN" "系统正在使用 systemd-networking 进行网络管理。"
        network_main_menu
    else
        echo_color "$RED" "系统未找到任何网络管理服务运行。可能使用其他网络管理方式或未配置网络。"
    fi
}

# 删除所有网络接口配置
delete_network_configs() {
    echo_color "$GREEN" "正在删除所有网络接口配置..."
    rm -f /etc/NetworkManager/system-connections/*
    if [ $? -ne 0 ]; then
        echo_color "$RED" "删除网络接口配置时出错。"
        exit 1
    fi
    echo_color "$GREEN" "所有网络接口配置已删除。"
}

# 重启 NetworkManager
restart_network_manager() {
    echo_color "$GREEN" "正在重启 NetworkManager..."
    systemctl restart NetworkManager
    if [ $? -ne 0 ]; then
        echo_color "$RED" "重启 NetworkManager 时出错。"
        exit 1
    fi
    echo_color "$GREEN" "NetworkManager 重启成功。"
}

# 创建新的以太网接口 eth0
create_eth0_interface() {
    echo_color "$GREEN" "正在创建新的网络接口 'eth0'..."
    nmcli con add type ethernet con-name eth0 ifname eth0
    if [ $? -ne 0 ]; then
        echo_color "$RED" "创建新网络接口 'eth0' 时出错。"
        exit 1
    fi

    # 启用新接口
    nmcli con up eth0
    if [ $? -ne 0 ]; then
        echo_color "$RED" "启动新网络接口 'eth0' 时出错。"
        exit 1
    fi
    echo_color "$GREEN" "网络接口 'eth0' 已成功创建并激活。"
}

# 切换到 DHCP 模式
set_dhcp() {
    CONNECTION_NAME=$1
    nmcli con mod "$CONNECTION_NAME" ipv4.method auto
    nmcli con mod "$CONNECTION_NAME" ipv4.dns ""
    nmcli con up "$CONNECTION_NAME"
    if [ $? -ne 0 ]; then
        echo_color "$RED" "切换到 DHCP 模式时出错。"
        exit 1
    fi
    echo_color "$GREEN" "已切换到 DHCP 模式。"
}

# 切换到静态 IP 模式
set_static() {
    CONNECTION_NAME=$1
    read -rp "请输入静态 IP 地址（例如，192.168.50.60/24）: " STATIC_IP
    read -rp "请输入网关地址（例如，192.168.50.100）: " GATEWAY
    read -rp "请输入DNS服务器地址（用逗号分隔，例如，8.8.8.8,114.114.114.114）: " DNS

    nmcli con mod "$CONNECTION_NAME" ipv4.addresses "$STATIC_IP"
    nmcli con mod "$CONNECTION_NAME" ipv4.gateway "$GATEWAY"
    nmcli con mod "$CONNECTION_NAME" ipv4.dns "$DNS"
    nmcli con mod "$CONNECTION_NAME" ipv4.method manual
    nmcli con up "$CONNECTION_NAME"
    if [ $? -ne 0 ]; then
        echo_color "$RED" "设置静态 IP 模式时出错。"
        exit 1
    fi
    echo_color "$GREEN" "已设置静态 IP。"
}

# 选择网络连接模式
select_network_mode() {
    echo_color "$GREEN" "请选择网络连接模式："
    echo "1. DHCP"
    echo "2. 静态 IP"
    read -rp "输入选项数字: " mode_choice

    case $mode_choice in
        1)
            set_dhcp "eth0"
            ;;
        2)
            set_static "eth0"
            ;;
        *)
            echo_color "$RED" "无效的选项。请重新选择。"
            select_network_mode
            ;;
    esac
}

# 切换到DHCP模式函数
switch_to_dhcp() {
    sudo tee /etc/network/interfaces > /dev/null <<EOL
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp
EOL


    # 重启网络服务
    sudo systemctl restart networking
    echo -e "${GREEN}已切换为DHCP模式${NC}"
}


# 静态IP配置菜单函数
switch_to_static_ip() {
    while :; do
        clear
        # 读取当前的网络配置
        current_ip=$(cat /etc/network/interfaces | awk '{print $2}' | cut -d/ -f1 | sed -n 13p)
        current_gateway=$(cat /etc/network/interfaces | awk '{print $2}' | cut -d/ -f1 | sed -n 15p)

        # 更新网络配置的函数
        function update_network_config() {
            # 使用sudo权限修改网络配置文件
            sudo tee /etc/network/interfaces > /dev/null <<EOL
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet static
    address $ip
    netmask 255.255.255.0
    gateway $gateway
EOL

            # 重启网络服务
            sudo systemctl restart networking
            echo -e "${GREEN}已更新网络配置${NC}"
        }

        # 修改静态IP地址的函数
        function modify_static_ip() {
            ip=$current_ip
            gateway=$current_gateway

            read -p "请输入新的IP地址 [$current_ip]: " new_ip
            ip=${new_ip:-$current_ip}

   
            update_network_config
        }


        # 修改网关地址的函数
        function modify_gateway() {
            ip=$current_ip
            gateway=$current_gateway

            read -p "请输入新的网关地址 [$current_gateway]: " new_gateway
            gateway=${new_gateway:-$current_gateway}
            
   
            update_network_config
        }

        # 提供用户选择修改项的菜单
        clear
        echo -e "${GREEN}选择修改项:${NC}"
        echo -e "${GREEN}1. 修改全部（IP地址、网关）${NC}"
        echo -e "${GREEN}2. 仅修改IP地址${NC}"
        echo -e "${GREEN}3. 仅修改网关地址${NC}"
        echo -e "${GREEN}4. 返回主菜单${NC}"

        # 根据用户的选择执行相应的操作
        read -p "请选择: " choices
        case $choices in
            1)
                modify_static_ip
                modify_gateway
                ;;
            2)
                modify_static_ip
                ;;
            3)
                modify_gateway
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                ;;
        esac

        # 显示当前网络配置信息
        clear
        echo -e "${GREEN}当前配置：${NC}"
        echo -e "${GREEN}IP地址：$current_ip ${NC}"
        echo -e "${GREEN}网关地址：$current_gateway ${NC}"
    done
}

# IP地址验证
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi

    return $stat
}

# 子网掩码验证
validate_subnet() {
    local subnet=$1
    local stat=1

    if validate_ip $subnet; then
        local binary_mask=$(printf "%d.%d.%d.%d\n" ${subnet//./ } | awk -F. '{ printf "%08d%08d%08d%08d\n", $1, $2, $3, $4 }')
        if [[ $binary_mask =~ ^(1+)(0*)$ ]]; then
            stat=0
        fi
    fi

    return $stat
}

# 网关地址验证
validate_gateway() {
    validate_ip $1
}

# 函数：更改网卡命名
function change_network_naming() {
    # 检测操作系统类型
    local os_type
    if [ -f /etc/os-release ]; then
        os_type=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    elif type lsb_release >/dev/null 2>&1; then
        os_type=$(lsb_release -is)
    else
        echo "无法确定操作系统类型。"
        return 1
    fi

    # 检测系统架构
    local arch=$(uname -m)

    # 不同发行版的特定处理
    case $os_type in
        ubuntu|debian)
            change_ubuntu_debian
            ;;
        fedora|centos|rhel)
            change_fedora_centos
            ;;
        *)
            echo "此脚本不支持 $os_type 发行版。"
            return 1
            ;;
    esac

    echo "网卡命名方式更改完成。"
}

# 针对 Ubuntu 和 Debian 的更改
function change_ubuntu_debian() {
    if grep -q "GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"" /etc/default/grub; then
        echo "网卡命名已更改，不需要再次操作。"
    else
        sudo sed -i "/^GRUB_CMDLINE_LINUX=/c\\GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"" /etc/default/grub
        sudo update-grub
    fi
}

# 针对 Fedora, CentOS, RHEL 的更改
function change_fedora_centos() {
    if grep -q "net.ifnames=0 biosdevname=0" /etc/default/grub; then
        echo "网卡命名已更改，不需要再次操作。"
    else
        sudo grubby --update-kernel=ALL --args="net.ifnames=0 biosdevname=0"
    fi
}

# 显示网络配置函数
function display_network_config() {
    clear
    echo -e "${GREEN}当前网络配置信息：${NC}"
    local current_ip=$(cat /etc/network/interfaces | awk '{print $2}' | cut -d/ -f1 | sed -n 13p)
    local current_gateway=$(cat /etc/network/interfaces | awk '{print $2}' | cut -d/ -f1 | sed -n 15p)
    
    echo -e "${GREEN}IP地址：$current_ip${NC}"
    echo -e "${GREEN}网关地址：$current_gateway${NC}"
}




# 无头服务器版菜单函数
function network_main_menu() {
    while :; do
        clear
        display_network_config
        echo_color "${GREEN}欢迎使用网络管理及网卡重命名配置脚本${NC}"
        echo_color "${GREEN}1. 网络管理静态IP模式${NC}"
        echo_color "${GREEN}2. 网络管理DHCP模式${NC}"
        echo_color "${GREEN}3. 网卡重命名${NC}"        
        echo_color "${GREEN}4. 退出脚本${NC}"

        read -p "请选择要进行的操作: " option
        case $option in
            1)
                switch_to_static_ip
                ;;
            2)
                switch_to_dhcp
                ;;
            3)
                change_network_naming
                ;;
            4)
                exit 1
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入${NC}"
                ;;
        esac
    done
}

# 网络管理服务器版菜单函数
function main_menu() {
    echo_color "${GREEN}======= 网络配置管理菜单 =======${NC}"
    echo_color "${GREEN}1. 删除所有网络接口配置${NC}"
    echo_color "${GREEN}2. 重启 NetworkManager${NC}"
    echo_color "${GREEN}3. 创建新的网络接口 'eth0'${NC}"
    echo_color "${GREEN}4. 设置网络连接模式${NC}"
    echo_color "${GREEN}5. 网卡重命名${NC}"
    echo_color "${GREEN}6. 退出${NC}"    
    echo_color "=============================="
    read -rp "请输入选项数字: " choice

    case $choice in
        1)
            delete_network_configs
            ;;
        2)
            restart_network_manager
            ;;
        3)
            create_eth0_interface
            ;;
        4)
            select_network_mode
            ;;
        5)
            change_network_naming
            ;;
        6)
            echo "退出网络配置管理菜单。"
            exit 0
            ;;
        *)
            echo "无效的选项。请重新选择。"
            main_menu
            ;;
    esac
}

# 运行 root 检查
ensure_root
check_network_service
