#!/bin/bash

# 设置颜色变量
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # 恢复默认颜色

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#脚本主目录
BASH_FILE="$SCRIPT_DIR/cloudflare"

# 初始化配置 -检查是否安装了所需工具或依赖项
check_apt() {
    # 检查是否安装了所需工具或依赖项
    # 检查系统是否为 Ubuntu 或 Debian
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ $ID == "ubuntu" || $ID == "debian" ]]; then
            echo -e "${BLUE} 当前系统为 $ID ${NC}"

            # 检查是否已安装 curl, unzip 和 jq，如果不存在则尝试安装
            packages=("curl" "unzip" "jq" "wget")
            for pkg in "${packages[@]}"; do
                if ! command -v "$pkg" &> /dev/null; then
                    echo -e "${RED} $pkg 未安装，尝试安装...${NC}"
                    sudo apt-get update
                    sudo apt-get install -y "$pkg"
                fi
            done
        else
            echo -e "${RED} 不支持的系统类型${NC}"
            exit 1
        fi
    else
        echo -e "${RED} 无法确定系统类型${NC}"
        exit 1
    fi
}

# 获取BASH_FILE所在的文件夹路径
get_info() {
    # 检查BASH_FILE是否存在，不存在则创建
    if [ ! -d "$BASH_FILE" ]; then
        echo -e "${RED} 文件夹不存在，开始创建...${NC}"
        mkdir -p "$BASH_FILE"
        chmod -R 777 "$BASH_FILE"  # 赋予写入、读取、执行的所有权限
        echo -e "${GREEN} 文件夹创建完成。"
    else
        echo -e "${RED} 文件夹已存在，跳过创建。${NC}"
    fi
}

# 函数: 检查 API_KEY 和 EMAIL 是否为空值，如果为空则引导用户输入
check_api_email() {
    # 尝试从文件中读取已保存的 API_KEY 和 EMAIL
    
    if [[ -f "$BASH_FILE/api_config.txt" ]]; then
        source "$BASH_FILE/api_config.txt"
        if [[ -n "${API_KEY}" && -n "${EMAIL}" ]]; then
            # 如果已存在 API_KEY 和 EMAIL，则继续执行脚本
            main_menu
        fi
    fi

    # 如果 API_KEY 或 EMAIL 为空，则引导用户输入
    while [[ -z "${API_KEY}" || -z "${EMAIL}" ]]; do
        echo -e "${RED}API_KEY 或 EMAIL 为空值，请输入 Cloudflare 邮箱和 API 密钥.${NC}"
        manage_api

        # 保存 API_KEY 和 EMAIL 到文件中
        echo "API_KEY=\"$API_KEY\"" > $BASH_FILE/api_config.txt
        echo "EMAIL=\"$EMAIL\"" >> $BASH_FILE/api_config.txt
    done

    # 如果 API_KEY 和 EMAIL 非空，则继续执行脚本
    main_menu
}



# 函数: 获取域名列表
fetch_domain_list() {
    DOMAINS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "X-Auth-Email: ${EMAIL}" \
        -H "X-Auth-Key: ${API_KEY}" \
        -H "Content-Type: application/json" | jq -r '.result[] | "\(.id) \(.name)"')
    echo "${DOMAINS}"
}

# 函数: 获取指定域名的DNS记录列表
fetch_dns_records() {
    local zone_id=$1
    RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
        -H "X-Auth-Email: ${EMAIL}" \
        -H "X-Auth-Key: ${API_KEY}" \
        -H "Content-Type: application/json" | jq -r '.result[] | "\(.id) \(.name)"')
    echo "${RECORDS}"
}

# 函数：添加DNS记录
add_dns_record() {

    # 显示域名列表并让用户选择
    echo -e "${BLUE}=====================可用 域 名 列表=====================${NC}"
    IFS=$'\n'
    DOMAIN_LIST=($(fetch_domain_list))
    for ((i = 0; i < ${#DOMAIN_LIST[@]}; i++)); do
        index=$((i + 1))
        echo "${index}. ${DOMAIN_LIST[i]#* }"
    done
    unset IFS

    read -p "请输入要选择的域名序号: " DOMAIN_INDEX

    # 将用户选择的序号减去1以获取实际在列表中的序号
    selected_index=$((DOMAIN_INDEX - 1))

    # 检查选择的域名序号是否在有效范围内
    if [[ $selected_index -ge 0 && $selected_index -lt ${#DOMAIN_LIST[@]} ]]; then
        SELECTED_DOMAIN=$(echo "${DOMAIN_LIST[selected_index]}" | cut -d ' ' -f2)
        echo -e "选择的域名: ${GREEN}${SELECTED_DOMAIN}${NC}"
    else
        echo -e "${RED}选择无效或无法获取域名.${NC}"
        return 1
    fi


    # 发送API请求来获取Zone ID
    ZONERESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$SELECTED_DOMAIN" \
    -H "X-Auth-Email: ${EMAIL}" \
    -H "X-Auth-Key: ${API_KEY}" \
    -H "Content-Type: application/json")

    if [[ -z "$ZONERESPONSE" ]]; then
        echo "API 未返回有效数据。"
        exit 1
    fi
    # 提取Zone ID
    ZONE_ID=$(echo "${ZONERESPONSE}" | jq -r '.result[0].id')
    if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
        echo "未能找到有效的 Zone ID。"
        exit 1
    fi

    if [[ -n "${ZONE_ID}" && "${ZONE_ID}" != "null" ]]; then
        echo -e "${BLUE}域名 ${SELECTED_DOMAIN} 的 Zone ID 是: ${ZONE_ID}  ${NC}"
    else
        echo -e "${RED}未能找到域名 ${SELECTED_DOMAIN} 的 Zone ID ${NC}"
    fi
    
    # 记录类型验证
    record_type_attempts=0
    while true; do
        read -p "请输入记录类型（例如：A，CNAME等，默认为 A）: " record_type
        record_type=${record_type:-A}  # 默认为 A
        if [[ $record_type != "A" && $record_type != "CNAME" ]]; then
            ((record_type_attempts++))
            if [ $record_type_attempts -eq 3 ]; then
                echo -e "${RED}已达到最大尝试次数，请返回主菜单.${NC}"
                return 1
            else
                echo -e "${RED}输入无效，请输入 A 或 CNAME.${NC}"
            fi
        else
            break
        fi
    done

    # 记录名称验证
    record_name_attempts=0
    while true; do
        read -p "请输入记录名称（例如：subdomain）: " record_name
        if ! [[ "$record_name" =~ ^[a-zA-Z0-9]+$ && ${#record_name} -le 8 ]]; then
            ((record_name_attempts++))
            if [ $record_name_attempts -eq 3 ]; then
                echo -e "${RED}已达到最大尝试次数，请返回主菜单.${NC}"
                return 1
            else
                echo -e "${RED}输入无效，请输入字母和数字的组合，且长度不超过8位.${NC}"
            fi
        else
            break
        fi
    done

    # 记录内容验证
    record_content_attempts=0
    while true; do
        echo "请选择记录内容的来源:"
        echo "1. 本地公网IP地址"
        echo "2. 手动输入"
        read -p "请输入选项 [1/2] (默认为 1): " content_option

    # 如果用户没有输入内容，则设置默认选项为 1
        content_option=${content_option:-1}
        
        case $content_option in
        1)
            record_content=$(curl -s https://api64.ipify.org)  # 获取本地公网IP地址
            echo -e "${BLUE} 公网IP ： $record_content ${NC}"
            break
            ;;
        2)
            read -p "请输入记录内容（例如：127.0.0.1）: " record_content
            if ! [[ "$record_content" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
                ((record_content_attempts++))
                if [ $record_content_attempts -eq 3 ]; then
                    echo -e "${RED}已达到最大尝试次数，请返回主菜单.${NC}"
                    return 1
                else
                    echo -e "${RED}输入无效，请输入合理的IP地址.${NC}"
                fi
            else
                break
            fi
            ;;
        *)
            echo -e "${RED}无效选项，请输入 1 或 2.${NC}"
            ;;
        esac
    done

    # TTL 值验证
    ttl_attempts=0
    while true; do
        read -p "请输入TTL值（例如：120）[默认为 120]: " ttl
        if ! [[ "$ttl" =~ ^[0-9]+$ ]]; then
            ttl=120
            break
        else
            ((ttl_attempts++))
            if [ $ttl_attempts -eq 3 ]; then
                echo -e "${RED}已达到最大尝试次数，请返回主菜单.${NC}"
                return 1
            else
                echo -e "${RED}输入无效，请输入数字.${NC}"
            fi
        fi
    done

    # 是否启用代理验证
    proxied_attempts=0
    while true; do
        read -p "是否启用代理（true/false）[默认为 false]: " proxied
        if [[ "$proxied" != "true" && "$proxied" != "false" ]]; then
            proxied=false
            break
        else
            ((proxied_attempts++))
            if [ $proxied_attempts -eq 3 ]; then
                echo -e "${RED}已达到最大尝试次数，请返回主菜单.${NC}"
                return 1
            else
                echo -e "${RED}输入无效，请输入 true 或 false.${NC}"
            fi
        fi
    done



    # 构建JSON数据用于API请求
    json_data=$(cat <<EOF
{
  "type": "${record_type}",
  "name": "${record_name}",
  "content": "${record_content}",
  "ttl": ${ttl},
  "proxied": ${proxied}
}
EOF
)

    # 发送API请求来添加DNS记录
    DNSRESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "X-Auth-Email: ${EMAIL}" \
    -H "X-Auth-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    --data "${json_data}")

    # 检查API响应并输出结果
    if [[ $(echo "${DNSRESPONSE}" | jq -r '.success') == "true" ]]; then
        echo -e "${GREEN}DNS记录已成功添加 ${NC}"
    else
        echo -e "${RED}添加DNS记录失败: $(echo "${DNSRESPONSE}" | jq -r '.errors[0].message') ${NC}"
    fi
}




# 函数: 删除DNS记录
delete_dns_record() {

    # 显示域名列表并让用户选择
    echo -e "${BLUE}=====================可用 域 名 列表=====================${NC}"
    IFS=$'\n'
    DOMAIN_LIST=($(fetch_domain_list))
    for ((i = 0; i < ${#DOMAIN_LIST[@]}; i++)); do
        index=$((i + 1))
        echo "${index}. ${DOMAIN_LIST[i]#* }"
    done
    unset IFS

    read -p "请输入要选择的域名序号: " DOMAIN_INDEX

    # 将用户选择的序号减去1以获取实际在列表中的序号
    selected_index=$((DOMAIN_INDEX - 1))

    # 检查选择的域名序号是否在有效范围内
    if [[ $selected_index -ge 0 && $selected_index -lt ${#DOMAIN_LIST[@]} ]]; then
        SELECTED_DOMAIN=$(echo "${DOMAIN_LIST[selected_index]}" | cut -d ' ' -f2)
        ZONE_ID=$(echo "${DOMAIN_LIST[selected_index]}" | cut -d ' ' -f1)
        echo -e "选择的域名: ${GREEN}${SELECTED_DOMAIN}${NC}"
    else
        echo -e "${RED}选择无效或无法获取域名.${NC}"
        return 1
    fi

    # 获取所选域名的DNS记录列表
    DNS_RECORDS=$(fetch_dns_records "$ZONE_ID")

    # 显示DNS记录列表并让用户选择要删除的记录
    echo -e "${BLUE}======================可用 DNS 列表======================${NC}"
    IFS=$'\n'
    RECORD_LIST=(${DNS_RECORDS})
    for ((i = 0; i < ${#RECORD_LIST[@]}; i++)); do
        index=$((i + 1))
        echo "${index}. ${RECORD_LIST[i]#* }"
    done
    unset IFS

    read -p "请输入要选择删除的DNS记录序号: " RECORD_INDEX

    # 将用户选择的序号减去1以获取实际在列表中的序号
    record_selected_index=$((RECORD_INDEX - 1))

    # 检查选择的DNS记录序号是否在有效范围内
    if [[ $record_selected_index -ge 0 && $record_selected_index -lt ${#RECORD_LIST[@]} ]]; then
        SELECTED_RECORD=$(echo "${RECORD_LIST[record_selected_index]}" | cut -d ' ' -f1)
        echo -e "选择要删除的DNS记录: ${GREEN}${SELECTED_RECORD}${NC}"

        # 根据选择的DNS记录ID执行删除操作
        DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${SELECTED_RECORD}" \
            -H "X-Auth-Email: ${EMAIL}" \
            -H "X-Auth-Key: ${API_KEY}" \
            -H "Content-Type: application/json")
        
        # 检查删除操作的响应
        if [[ $(echo "${DELETE_RESPONSE}" | jq -r '.success') == "true" ]]; then
            echo -e "${GREEN}DNS记录已成功删除.${NC}"
        else
            echo -e "${RED}删除DNS记录失败: $(echo "${DELETE_RESPONSE}" | jq -r '.errors[0].message')${NC}"
        fi
    else
        echo -e "${RED}选择无效或无法获取DNS记录.${NC}"
        return 1
    fi
}

# 展示域名和 DNS 记录函数
show_dns_record() {
    echo -e "${BLUE}===================展示域名和 DNS 记录===================${NC}"

    # 获取主域名列表并展示，使用阿拉伯数字编号
    echo -e "${YELLOW}=====================可用 域 名 列表=====================${NC}"
    IFS=$'\n'
    DOMAIN_LIST=($(fetch_domain_list))
    for ((i = 0; i < ${#DOMAIN_LIST[@]}; i++)); do
        index=$((i + 1))
        echo "${index}. ${DOMAIN_LIST[i]#* }"
    done
    unset IFS

    read -p "请输入要查看的主域名序号: " SELECTED_DOMAIN_INDEX

    selected_index=$((SELECTED_DOMAIN_INDEX - 1))

    # 检查选择的主域名序号是否在有效范围内
    if [[ $selected_index -ge 0 && $selected_index -lt ${#DOMAIN_LIST[@]} ]]; then
        SELECTED_DOMAIN=$(echo "${DOMAIN_LIST[selected_index]}" | cut -d ' ' -f2)
        
        # 获取所选域名的 DNS 记录列表并展示，使用罗马数字编号
        echo -e "${YELLOW}======================可用 DNS 列表======================${NC}"
        declare -a roman_numerals=(I II III IV V VI VI VII VIII IX X XI XII XIII XIV XV )  # 罗马数字序列
        IFS=$'\n'
        ZONE_ID=$(echo "${DOMAIN_LIST[selected_index]}" | cut -d ' ' -f1)
        RECORD_LIST=($(fetch_dns_records "$ZONE_ID"))
        for ((i = 0; i < ${#RECORD_LIST[@]}; i++)); do
            echo "${roman_numerals[i]}. ${RECORD_LIST[i]#* }"
        done
        unset IFS
    else
        echo -e "${RED}选择无效或无法获取主域名.${NC}"
        return 1
    fi
}

# 管理 Cloudflare 邮箱和 API 密钥函数
manage_api() {
    echo -e "${BLUE}============管理 Cloudflare 邮箱和 API密钥============${NC}"

    # 提示用户输入新的 Cloudflare 邮箱和 API 密钥
    read -p "请输入新的 Cloudflare 邮箱地址: " new_email
    read -p "请输入新的 Cloudflare API 密钥: " new_api_key

    # 在这里添加设置新的 Cloudflare 邮箱和 API 密钥的逻辑
    # 示例：更新 API_KEY 和 EMAIL 变量
    API_KEY="$new_api_key"
    EMAIL="$new_email"
    echo -e "${YELLOW}Cloudflare     新邮箱为: $EMAIL ${NC}"
    echo -e "${YELLOW}Cloudflare API 新密钥为: $API_KEY ${NC}"
    # 如果需要将更新后的值保存到脚本本身，请使用 sed 或其他适当的命令
    sed -i "s/API_KEY=\"$API_KEY\"/API_KEY=\"$new_api_key\"/" "$0"
    sed -i "s/EMAIL=\"$EMAIL\"/EMAIL=\"$new_email\"/" "$0"
}



# 主菜单
main_menu() {

    clear   
    
    while true; do
        echo -e "${YELLOW}======Cloudflare     邮箱为: $EMAIL ${NC}"
        echo -e "${YELLOW}======Cloudflare API 密钥为: $API_KEY ${NC}"
        echo -e "${BLUE}================ CloudFlare 域名管理脚本 ================${NC}"
        echo -e "${GREEN}1) =====================新增域名记录=====================${NC}"
        echo -e "${GREEN}2) =====================删除域名记录=====================${NC}"
        echo -e "${GREEN}3) ==================展示域名和DNS 记录==================${NC}"
        echo -e "${GREEN}4) ============管理 Cloudflare 邮箱和 API密钥============${NC}"
        echo -e "${RED}5) ======================== 退出 ========================${NC}"

        read -p "请输入选择: " choice

        case $choice in
        1) add_dns_record ;;
        2) delete_dns_record ;;
        3) show_dns_record ;;
        4) manage_api ;;
        5) echo -e "${RED}===================退出脚本，感谢使用.===================${NC}"; exit ;;
        *) echo -e "${RED}无效选项，请选择有效选项.${NC}" ;;
        esac

        # 输出空行和提示，等待用户按任意键继续
        if [[ $choice != 5 ]]; then
            echo -e "\n${BLUE}按任意键返回主菜单...${NC}"
            read -n 1 -s -r -p ""
            clear
        fi
    done
}


# 检查APT和获取信息
check_apt
get_info
check_api_email

# 这里添加退出循环的语句
echo -e "${BLUE}已检查APT并获取信息。${NC}"
echo -e "${BLUE}按任意键继续...${NC}"
read -n 1 -s -r -p ""
clear


# 运行主菜单
main_menu
