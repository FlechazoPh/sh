#!/bin/bash

# 颜色定义
blue() { echo -e "\033[34m\033[01m$1\033[0m"; }
green() { echo -e "\033[32m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

# 日志文件路径
LOG_FILE="/var/log/cloudflare_ddns_update.log"

# 记录日志
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# 获取 API_KEY 和 EMAIL
API_KEY=$(grep -Po '(?<=API_KEY=")[^"]*' "$0")
EMAIL=$(grep -Po '(?<=EMAIL=")[^"]*' "$0")

# 检查 API_KEY 是否为空值
if [ -z "$API_KEY" ]; then
    read -p "请输入 Cloudflare Global API Key: " API_KEY
    sed -i "s/API_KEY=\"\"/API_KEY=\"$API_KEY\"/" "$0"
fi

# 检查 EMAIL 是否为空值
if [ -z "$EMAIL" ]; then
    read -p "请输入 Cloudflare 账户的邮箱地址: " EMAIL
    sed -i "s/EMAIL=\"\"/EMAIL=\"$EMAIL\"/" "$0"
fi

# 显示 API_KEY 和 EMAIL
green "Cloudflare Global API Key: $API_KEY"
green "Cloudflare 账户的邮箱地址: $EMAIL"

# 提示用户输入 DNS 记录数量
read -p "请输入要更新的 DNS 记录数量: " RECORD_COUNT

# 循环处理每个 DNS 记录
for ((i=1; i<=$RECORD_COUNT; i++)); do
    read -p "请输入第 $i 个 DNS 记录: " RECORD_NAME

    # 获取 Cloudflare Zone ID
    DOMAIN=$(echo "$RECORD_NAME" | rev | cut -d"." -f1-2 | rev)
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN&status=active" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)

    if [ -z "$ZONE_ID" ]; then
        red "未能找到与 $RECORD_NAME 对应的 Zone ID。"
        continue
    fi

    # 获取当前公网 IP 地址
    CURRENT_IP=$(curl -s http://ipv4.icanhazip.com)

    # 获取记录 ID
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$RECORD_NAME" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)

    # 更新 DNS 记录
    UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\"}")

    # 检查是否成功
    if [[ $UPDATE_RESULT == *"\"success\":true"* ]]; then
        log "DNS 更新成功: $RECORD_NAME -> $CURRENT_IP"
    else
        log "DNS 更新失败: $RECORD_NAME"
        log "错误信息: $UPDATE_RESULT"
    fi

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
done
