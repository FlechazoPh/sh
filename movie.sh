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

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#脚本主目录
BASH_FILE="/BOX"


# 设置证书路径和密码文件
certificatePath="/BOX/jellyfin.pfx"
certificatePasswordFile="/BOX/jellyfint.txt"

# Cloudflare 设置
CF_Email=""

CF_Key=""

# 配置 network.xml 文件
networkXml="/etc/jellyfin/network.xml"

# 函数：配置完成
start() {
    purple "===================================================="
    purple "==============jellyfin管理脚本开始运行=============="
    purple "===================================================="
}

# 验证输入是否是合法的域名
validate_domain() {
    local input=$1
    local domain_regex="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9])\\.([A-Za-z]{2,})(\\.[A-Za-z]{2,})?$"
    
    if [[ $input =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}


# 函数：停止Jellyfin服务
stop_jellyfin() {
    red "==================停止Jellyfin服务=================="
    sudo systemctl stop jellyfin
}

# 函数：启动Jellyfin服务
start_jellyfin() {
    green "==================开始Jellyfin服务=================="
    sudo systemctl start jellyfin
    sudo systemctl enable jellyfin
    blue "===================== 等待 3秒 ====================="
    sleep 3
}

# 函数：重启Jellyfin服务
restart_jellyfin() {
    grey "==================重启Jellyfin服务=================="
    sudo systemctl restart jellyfin
    blue "===================== 等待 3秒 ====================="
    sleep 3
}

# 检查/生成BOX文件夹
check_and_create_box_folder() {
    if [ ! -d "/BOX" ]; then
        green "=============BOX文件夹不存在，正在生成.============="
        sudo mkdir -p /BOX
        sudo chmod 777 /BOX  # 赋予用户可读、可写、可执行权限
        green "=================创建BOX文件夹成功.================="
    else
        grey "============BOX文件夹存在，跳过创建步骤.============"
    fi
}

# 检查acme.sh是否已下载和安装
check_acme(){
    if ! command -v acme.sh &> /dev/null; then
    red "==================acme.sh 尚未安装=================="
    curl https://get.acme.sh | sh
    # 为acme.sh创建一个符号链接，这样可以从任何地方运行它
    ln -s "/root/.acme.sh/acme.sh" /usr/local/bin/acme.sh
    # 设置Let's Encrypt为默认的证书颁发机构
    acme.sh --set-default-ca --server letsencrypt
else
    green "=========acme.sh 已安装，跳过下载和安装步骤========="
fi
}

# 安装或检查Jellyfin
check_jellyfin() {
if ! command -v jellyfin &> /dev/null; then
    red "==================Jellyfin尚未安装=================="

    # 安装Jellyfin
    yellow "==================正在安装Jellyfin=================="

    # 安装依赖
    sudo apt install -y curl gnupg lsof

    # 下载 GPG 签名密钥（由 Jellyfin 团队签名）并安装
    sudo mkdir -p /etc/apt/keyrings

    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg

    # 添加存储库配置
    export VERSION_OS="$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"
    export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"
    cat <<EOF | sudo tee /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/${VERSION_OS}
Suites: bookworm
Components: main
Architectures: ${DPKG_ARCHITECTURE}
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF


    # 更新您的 APT 存储库
    sudo apt update
    sudo apt install -y jellyfin
else
    grey "==========Jellyfin已经安装。跳过安装步骤。=========="
fi
}

# 检查证书是否存在并生成
check_and_generate_certificate() {
    if [ ! -f "$certificatePath" ]; then
        red "===================证书尚未配置。==================="
        generate_ssl_certificate
    else
        grey "===========证书已配置。跳过证书生成步骤。==========="
    fi
}


# 函数: 检查 CF_Key 和 CF_Email 是否为空值，如果为空则引导用户输入
check_api_CF_Email() {
    # 尝试从文件中读取已保存的 CF_Key 和 CF_Email
    if [[ -f "$BASH_FILE/api_config.txt" ]]; then
        source "$BASH_FILE/api_config.txt"
        if [[ -n "${CF_Key}" && -n "${CF_Email}" ]]; then
            # 如果已存在 CF_Key 和 CF_Email，则继续执行脚本
            green "CF_Key 和 CF_Email 已存在，跳过执行脚本。"
            return 0
        fi
    fi

    # 如果 CF_Key 或 CF_Email 为空，则引导用户输入
    while [[ -z "${CF_Key}" || -z "${CF_Email}" ]]; do
        echo -e "${RED}CF_Key 或 CF_Email 为空值，请输入 Cloudflare 邮箱和 API 密钥.${NC}"
        manage_api

        # 保存 CF_Key 和 CF_Email 到文件中
        echo "CF_Key=\"$CF_Key\"" > $BASH_FILE/api_config.txt
        echo "CF_Email=\"$CF_Email\"" >> $BASH_FILE/api_config.txt
    done

    # 如果输入了 CF_Key 和 CF_Email，则执行剩余的脚本
    return 1
}




# 管理 Cloudflare 邮箱和 API 密钥函数
manage_api() {
    echo -e "${BLUE}============管理 Cloudflare 邮箱和 API密钥============${NC}"

    # 提示用户输入新的 Cloudflare 邮箱和 API 密钥
    read -p "请输入新的 Cloudflare 邮箱地址: " new_CF_Email
    read -p "请输入新的 Cloudflare API 密钥: " new_CF_Key

    # 在这里添加设置新的 Cloudflare 邮箱和 API 密钥的逻辑
    # 示例：更新 CF_Key 和 CF_Email 变量
    CF_Key="$new_CF_Key"
    CF_Email="$new_CF_Email"
    echo -e "${YELLOW}Cloudflare     新邮箱为: $CF_Email ${NC}"
    echo -e "${YELLOW}Cloudflare API 新密钥为: $CF_Key ${NC}"
    # 如果需要将更新后的值保存到脚本本身，请使用 sed 或其他适当的命令
    sed -i "s/CF_Key=\"$CF_Key\"/CF_Key=\"$new_CF_Key\"/" "$0"
    sed -i "s/CF_Email=\"$CF_Email\"/CF_Email=\"$new_CF_Email\"/" "$0"
}

# 生成SSL证书
generate_ssl_certificate() {
    red "==========证书尚未配置，正在生成 SSL证书。=========="
    
    # 申请证书前，自动杀死占用80端口的进程
    sudo lsof -i :80 | grep LISTEN | awk '{print $2}' | xargs -r sudo kill -9

    attempts=3

    while [ $attempts -gt 0 ]; do

        # 引导用户输入域名
        read -p "请输入您的域名: " domain

        if validate_domain "$domain"; then
            echo "输入的域名 $domain 是有效的。"
            break
        else
            echo "输入的域名 $domain 不是有效的域名。"
            ((attempts--))
            if [ $attempts -gt 0 ]; then
                echo "您还有 $attempts 次尝试机会，请输入正确的域名。"
            else
                red "===========已超过尝试次数限制，退出脚本。==========="
                exit 1
            fi
        fi
    done

    # 使用 acme.sh 获取证书
    acme.sh --issue --dns dns_cf -d "$domain" --keylength ec-256

    if [ $? -eq 0 ]; then
        green "=================SSL 证书获取成功。================="
        generate_pfx_certificate "$domain"
    else
        red "=====SSL 证书获取失败，检查输入的信息是否正确。====="
        exit 1
    fi
}

# 生成.pfx格式证书
generate_pfx_certificate() {
    local domain=$1
    green "================正在生成.pfx格式证书================"

    # 生成.pfx格式证书
    Password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 8)
    acme.sh --toPkcs -d "$domain" --password "$Password"  > "$certificatePath"

    # 保存密码到文件
    echo "$Password" > "$certificatePasswordFile"

    blue "生成.pfx格式证书成功。密码为：$Password 已保存到文件：$certificatePasswordFile"
}





# 提取密码
extract_password() {
    if [ -f "$certificatePasswordFile" ]; then
        certificatePassword=$(cat "$certificatePasswordFile")
    else
        red "=====证书密码文件不存在，请检查路径或创建文件。====="
        exit 1
    fi
}

# 停止、启动和重启Jellyfin服务
manage_jellyfin() {
    stop_jellyfin
    start_jellyfin
    restart_jellyfin
}

# 配置SSL证书相关内容
configure_ssl_certificate() {
    #（配置SSL证书路径和密码的代码）...

    # 检查 network.xml 是否存在
if [ ! -f "$networkXml" ]; then
    red "network.xml 不存在，检查 Jellyfin 已安装并正确配置。"
    exit 1
fi


# 修改 RequireHttps 的值为 true，如果未修改，则修改
if ! grep -q "<RequireHttps>true</RequireHttps>" "$networkXml"; then
    sed -i 's|<RequireHttps>false</RequireHttps>|<RequireHttps>true</RequireHttps>|' "$networkXml"
    green "==================启用 公开HTTPS。=================="
else
    grey "============= 公开 HTTPS 已启用。跳过。============="
fi

# 修改 EnableHttps 的值为 true，如果未修改，则修改
if ! grep -q "<EnableHttps>true</EnableHttps>" "$networkXml"; then
    sed -i 's|<EnableHttps>false</EnableHttps>|<EnableHttps>true</EnableHttps>|' "$networkXml"
    green "==================启用 本地HTTPS。=================="
else
    grey "============= 本地 HTTPS 已启用。跳过。============="
fi


# 填写 SSL 证书路径
if ! grep -q "<CertificatePath>${certificatePath}</CertificatePath>" "$networkXml"; then
    if ! grep -q "<CertificatePath></CertificatePath>" "$networkXml"; then
        sed -i "s|<CertificatePath>.*</CertificatePath>|<CertificatePath>${certificatePath}</CertificatePath>|" "$networkXml"
    else
        sed -i "s|<CertificatePath></CertificatePath>|<CertificatePath>${certificatePath}</CertificatePath>|" "$networkXml"
    fi
    green "SSL 证书路径已填写为：${certificatePath}"
else
    grey "=======SSL 证书路径已经是所需路径。跳过填写。======="
fi

# 填写 SSL 证书密码
if ! grep -q "<CertificatePassword>${certificatePassword}</CertificatePassword>" "$networkXml"; then
    if ! grep -q "<CertificatePassword></CertificatePassword>" "$networkXml"; then
        sed -i "s|<CertificatePassword>.*</CertificatePassword>|<CertificatePassword>${certificatePassword}</CertificatePassword>|" "$networkXml"
    else
        sed -i "s|<CertificatePassword></CertificatePassword>|<CertificatePassword>${certificatePassword}</CertificatePassword>|" "$networkXml"
    fi
    green "SSL 证书密码已填写。密码：${certificatePassword}"
else
    grey "==========SSL 证书密码已经设置。跳过填写。=========="
fi
}

# 函数：配置完成
over() {
    purple "===================================================="
    purple "===============jellyfin已经配置完成。==============="
    purple "===================================================="
}

# 主函数：执行任务
main() {

    # 函数：配置完成
    start
    # 检查/生成BOX文件夹
    check_and_create_box_folder
    # 检查acme.sh是否已下载和安装
    check_acme
    # 安装或检查Jellyfin
    check_jellyfin
    # 函数: 检查 CF_Key 和 CF_Email 是否为空值，如果为空则引导用户输入
    check_api_CF_Email    
    # 调用检查证书是否存在并生成的函数
    check_and_generate_certificate
    # 提取密码
    extract_password
    # 停止、启动和重启Jellyfin服务
    manage_jellyfin
    # 配置SSL证书相关内容
    configure_ssl_certificate
    # 重启Jellyfin服务
    restart_jellyfin
    # 函数：配置完成
    over
}

# 执行主函数
main
