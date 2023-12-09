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

# 设置证书路径和密码文件
certificatePath="/BOX/jellyfin.pfx"
certificatePasswordFile="/BOX/jellyfint.txt"

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
    export VERSION_CODENAME="$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"
    export DPKG_ARCHITECTURE="$( dpkg --print-architecture )"
    cat <<EOF | sudo tee /etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/${VERSION_OS}
Suites: ${VERSION_CODENAME}
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
    # 安装或检查Jellyfin
    check_jellyfin
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
