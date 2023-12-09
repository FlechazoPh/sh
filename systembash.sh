#!/bin/bash

# 下载新的 .bashrc 文件
check_bash(){
  wget -q -O /tmp/new_bashrc https://raw.githubusercontent.com/jijunrong/sh/main/.bashrc

  # 比较两个文件是否相同
 if cmp -s ~/.bashrc /tmp/new_bashrc; then
    echo "文件相同，无需更新 .bashrc"
    source ~/.bashrc
 else
    echo "文件不同，将更新 .bashrc"
    cp /tmp/new_bashrc ~/.bashrc

 fi

 # 清理临时文件
 rm /tmp/new_bashrc
}

# 下载新的 .profile 文件
check_profile(){
  wget -q -O /tmp/new_profile https://raw.githubusercontent.com/jijunrong/sh/main/.profile

  # 比较两个文件是否相同
 if cmp -s ~/.profile /tmp/new_profile; then
    echo "文件相同，无需更新 .profile"

 else
    echo "文件不同，将更新 .profile"
    cp /tmp/new_profile ~/.profile

 fi
 # 清理临时文件
 rm /tmp/new_profile
}
# source刷新
source_new(){
source ~/.bashrc
source ~/.profile
}

check_bash
check_profile
source_new
