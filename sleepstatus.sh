#!/bin/bash

# 检查是否是桌面环境
if [ "$(systemctl -q is-active graphical.target)" = "active" ]; then
    # 桌面环境下禁止休眠和屏幕熄灭
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    gsettings set org.gnome.desktop.session idle-delay 0
    echo "已设置桌面环境为永不休眠、永不熄屏，并关闭自动挂起。"
else
    # 无头服务器状态下禁止休眠和屏幕熄灭
    sudo sed -i 's/#HandleLidSwitch=ignore/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
    sudo sed -i 's/#HandleSuspendKey=ignore/HandleSuspendKey=ignore/' /etc/systemd/logind.conf
    sudo systemctl restart systemd-logind
    echo "已设置无头服务器状态为永不休眠、永不熄屏。"
fi
