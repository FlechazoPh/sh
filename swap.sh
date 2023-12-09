#!/bin/bash

# 设置颜色变量
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # 恢复默认颜色


# 设置 swap 文件的路径
SWAP_FILE="/swapfile"

# 检查是否存在 swap 文件
check_swap_exists() {
    if swapon -s | grep -q "$SWAP_FILE"; then
        return 0
    else
        return 1
    fi
}


# 检查所需的 swap 大小是否合理
check_swap_size() {
    local size=$1
    local size_in_bytes=$(echo "$size" | awk '{
        size = $0 + 0   # 将字符串转换为数字，解决科学计数法格式的问题
        if(index($0, "G") != 0) size *= 1024*1024*1024
        else if(index($0, "M") != 0) size *= 1024*1024
        else if(index($0, "K") != 0) size *= 1024
        printf "%.0f", size  # 输出整数
    }')
    local available_disk_space=$(df --output=avail -B1 / | tail -n 1)  # 以字节为单位显示可用空间

    # 检查是否超过硬盘大小或100G
    if (( size_in_bytes > available_disk_space )) || (( size_in_bytes > 100*1024*1024*1024 )); then
        echo -e "${RED}指定的 swap 大小超过了硬盘的可用空间或超过了100G的最大限制。${NC}"
        return 1
    else
        return 0
    fi
}


# 创建 swap 文件
create_swap() {
    local size=$1

    if check_swap_size "$size"; then
        echo -e "${BLUE}====================正在创建 swap 文件====================${NC}"
        sudo fallocate -l "$size" "$SWAP_FILE"
        sudo chmod 600 "$SWAP_FILE"
        sudo mkswap "$SWAP_FILE"
        sudo swapon "$SWAP_FILE"
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}================== Swap 文件已创建并启用==================${NC}"
        else
            echo -e "${RED}====================创建 swap 文件失败====================${NC}"
            exit 1
        fi
    else
        main_menu
    fi
}

# 删除 swap 文件
remove_swap() {
    echo -e "${YELLOW}====================正在删除 swap 文件====================${NC}"
    sudo swapoff "$SWAP_FILE"
    sudo sed -i "\%$SWAP_FILE%d" /etc/fstab
    sudo rm -f "$SWAP_FILE"


    if [ $? -eq 0 ]; then
        echo -e "${RED}=====================已删除 Swap 文件=====================${NC}"
    else
        echo -e "${RED}====================删除 swap 文件失败====================${NC}"
        exit 1
    fi
}

# 显示主菜单
main_menu() {

    echo -e "${BLUE} ======================SWAP 管理脚本======================${NC}"
    echo -e "${GREEN} 1) =========自定义 swap 大小(请输入及单位的大小)=========${NC}"
    echo -e "${GREEN} 2) =================设置 swap 大小为 1G ================= ${NC}"
    echo -e "${GREEN} 3) =================设置 swap 大小为 2G ================= ${NC}"
    echo -e "${GREEN} 4) =================设置 swap 大小为 5G ================= ${NC}"
    echo -e "${RED} 5) ======================== 退出 ========================${NC}"

    read -p "请输入选项（1-5）或按回车键选择默认： " option

    case $option in
        1)
            read -p "请输入 swap 大小（例如：1G、512M）: " custom_size
            create_swap "$custom_size"
            ;;
        2)
            create_swap "1G"
            ;;
        3)
            create_swap "2G"
            ;;
        4)
            create_swap "5G"
            ;;
        5)
            echo -e "${RED} ===================退出脚本，感谢使用.===================${NC}"
            exit 0
            ;;
        "")
            echo "未选择，选择默认大小 2G。"
            create_swap "2G"
            ;;
        *)
            echo -e "${RED} ===================无效选项，重新输入.===================${NC}"
            main_menu
            ;;
    esac
}

# 执行主菜单
if check_swap_exists; then
    echo -e "${RED}====================已检测到 swap 文件====================${NC}"
    read -p "是否删除现有 swap 文件？(y/n): " choice
    if [[ "$choice" = "y" ]]; then
        remove_swap
    fi
fi

main_menu
