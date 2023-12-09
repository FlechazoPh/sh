#!/bin/bash

# 设置颜色变量
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # 恢复默认颜色

# 设置Cloudflare的邮箱和API密钥，用于DNS验证
export CF_Email=""
export CF_Key=""

# 输出信息的函数
print_info() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_note() { echo -e "${BLUE}$1${NC}"; }

# 检查软件包是否已安装的函数
check_package() {
    local package=$1
    if ! dpkg -l | grep -q "^ii\s*$package"; then
        print_warning "$package 未安装，正在尝试安装..."
        sudo apt-get install -y "$package" || {
            print_error "安装 $package 失败！"
            exit 1
        }
    else
        print_note "$package 已安装，跳过..."
    fi
}

# 更新软件包列表并安装必要的软件包
print_info "=====================更新软件包列表====================="
sudo apt update || {
    print_error "====================更新软件包列表失败===================="
    exit 1
}

# 检查并安装必要的软件包
required_packages=("curl" "cron" "socat" "sudo" "git" "wget" "nginx" "jq")
for package in "${required_packages[@]}"; do
    check_package "$package"
done

# 检查 Cloudflare 凭据是否已设置
check_cloudflare_credentials() {
    if [[ -z "$CF_Email" || -z "$CF_Key" ]]; then
        print_warning "Cloudflare 邮箱或 API 密钥为空！请输入以下信息："
        read -p "Cloudflare     邮箱: " email
        read -p "Cloudflare API 密钥: " api_key

        export CF_Email="$email"
        export CF_Key="$api_key"
        
        # 使用 sed 直接更新脚本文件内的变量值
        sed -i "s/export CF_Email=\"\"/export CF_Email=\"$email\"/" "$0"
        sed -i "s/export CF_Key=\"\"/export CF_Key=\"$api_key\"/" "$0"
        
    else
        print_note "Cloudflare     邮箱：$CF_Email"
        print_note "Cloudflare API 密钥：$CF_Key"
    fi
}

# 检查 Cloudflare 凭据是否已设置
check_cloudflare_credentials

# 获取所有区域列表（主域名列表）
get_all_zones() {
    ZONES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
        -H "X-Auth-Email: ${CF_Email}" \
        -H "X-Auth-Key: ${CF_Key}" \
        -H "Content-Type: application/json" | jq -r '.result[] | .name')
    echo "${ZONES}"
}

ZONES=$(get_all_zones)

# 输出所有主域名
print_note "=====================可用域名列表====================="
echo "$ZONES"

# 提取顶级域名后缀
print_note "=====================可用域名后缀====================="
for tlddomain in $ZONES; do
    tld=$(echo "$tlddomain" | awk -F'.' '{print $NF}')
    echo "$tld"
done

# 获取用户输入的子域名记录
read -p "请输入您的 DNS 记录名称（例如：blog）: " subdomain

# 为每个域名生成证书的函数
generate_certificates() {
    local domain=$1
    print_info "为 $domain 生成 SSL 证书"
    acme.sh --issue --dns dns_cf -d "$domain" --keylength ec-256 || {
        print_error "为 $domain 生成 SSL 证书失败！"
        return 1
    }
    sleep 1
    cp "/root/.acme.sh/${domain}_ecc/$domain.cer" "/BOX/${HOSTNAME}/${folder}/server.crt"
    cp "/root/.acme.sh/${domain}_ecc/$domain.key" "/BOX/${HOSTNAME}/${folder}/server.key"
}

# 获取主机名并创建目录
HOSTNAME=$(hostname)
for tld in $ZONES; do
    folder=$(echo "$tld" | awk -F'.' '{print $NF}')
    mkdir -p "/BOX/${HOSTNAME}/${folder}"
    domain="${subdomain}.${tld}"
    generate_certificates "$domain"
done
