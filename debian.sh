#!/bin/sh
# shellcheck shell=dash

# 设置脚本在出现错误时终止执行，并且处理未定义变量的错误
set -eu

# 定义一个错误处理函数，输出错误信息并退出脚本
err() {
    printf "\n错误: %s.\n" "$1" 1>&2
    exit 1
}

# 定义一个警告处理函数，输出警告信息并继续执行
warn() {
    printf "\警告: %s.\n继续使用默认值...\n" "$1" 1>&2
    sleep 5
}

# 检查命令是否存在的函数
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# 设置变量：
in_target_script=
# 定义一个函数，用于将命令添加到目标脚本中
in_target() {
    local command=

    for argument in "$@"; do
        command="$command $argument"
    done

    if [ -n "$command" ]; then
        [ -z "$in_target_script" ] && in_target_script='true'
        in_target_script="$in_target_script;$command"
    fi
}

# 定义一个函数，用于备份目标文件
in_target_backup() {
    in_target "if [ ! -e \"$1.backup\" ]; then cp \"$1\" \"$1.backup\"; fi"
}

# 配置sshd服务
configure_sshd() {
    # 检查是否已经设置了sshd_config_backup变量
    [ -z "${sshd_config_backup+1s}" ] && in_target_backup /etc/ssh/sshd_config
    sshd_config_backup=
    in_target sed -Ei \""s/^#?$1 .+/$1 $2/"\" /etc/ssh/sshd_config
}

# 提示用户输入密码
prompt_password() {
    local prompt=

    if [ $# -gt 0 ]; then
        prompt=$1
    elif [ "$username" = root ]; then
        prompt="为root用户选择一个密码: "
    else
        prompt="为用户 $username 选择一个密码: "
    fi

    stty -echo
    trap 'stty echo' EXIT

    while [ -z "$password" ]; do
        echo -n "$prompt" > /dev/tty
        read -r password < /dev/tty
        echo > /dev/tty
    done

    stty echo
    trap - EXIT
}

# 下载文件的函数
download() {
    # 设置代理
    [ -n "$mirror_proxy" ] &&
    [ -z "${http_proxy+1s}" ] &&
    [ -z "${https_proxy+1s}" ] &&
    [ -z "${ftp_proxy+1s}" ] &&
    export http_proxy="$mirror_proxy" &&
    export https_proxy="$mirror_proxy" &&
    export ftp_proxy="$mirror_proxy"

    # 根据可用的命令下载文件
    if command_exists wget; then
        wget -O "$2" "$1"
    elif command_exists curl; then
        curl -fL "$1" -o "$2"
    elif command_exists busybox && busybox wget --help > /dev/null 2>&1; then
        busybox wget -O "$2" "$1"
    else
        err '无法找到"wget"、"curl"或"busybox wget"来下载文件'
    fi
}

# 设置镜像代理的函数
set_mirror_proxy() {
    [ -n "$mirror_proxy" ] && return

    case $mirror_protocol in
        http)
            if [ -n "${http_proxy+1s}" ]; then mirror_proxy="$http_proxy"; fi
            ;;
        https)
            if [ -n "${https_proxy+1s}" ]; then mirror_proxy="$https_proxy"; fi
            ;;
        ftp)
            if [ -n "${ftp_proxy+1s}" ]; then mirror_proxy="$ftp_proxy"; fi
            ;;
        *)
            err "不支持的协议: $mirror_protocol"
    esac
}

# 设置安全更新存档的函数
set_security_archive() {
    case $suite in
        buster|oldoldstable)
            security_archive="$suite/updates"
            ;;
        bullseye|oldstable|bookworm|stable|trixie|testing)
            security_archive="$suite-security"
            ;;
        sid|unstable)
            security_archive=''
            ;;
        *)
            err "不支持的版本: $suite"
    esac
}

# 设置是否使用每日安装程序的函数
set_daily_d_i() {
    case $suite in
        buster|oldoldstable|bullseye|oldstable|bookworm|stable)
            daily_d_i=false
            ;;
        trixie|testing|sid|unstable)
            daily_d_i=true
            ;;
        *)
            err "不支持的版本: $suite"
    esac
}

# 设置版本的函数
set_suite() {
    suite=$1
    set_daily_d_i
    set_security_archive
}

# 设置Debian版本的函数
set_debian_version() {
    case $1 in
        10|buster|oldoldstable)
            set_suite buster
            ;;
        11|bullseye|oldstable)
            set_suite bullseye
            ;;
        12|bookworm|stable)
            set_suite bookworm
            ;;
        13|trixie|testing)
            set_suite bookworm
            ;;
        sid|unstable)
            set_suite sid
            ;;
        *)
            err "不支持的版本: $1"
    esac
}

# 检查是否存在云内核的函数
has_cloud_kernel() {
    case $suite in
        buster|oldoldstable)
            [ "$architecture" = amd64 ] && return
            [ "$architecture" = arm64 ] && [ "$bpo_kernel" = true ] && return
            ;;
        bullseye|oldstable|bookworm|stable|trixie|testing|sid|unstable)
            [ "$architecture" = amd64 ] || [ "$architecture" = arm64 ] && return
    esac

    local tmp; tmp=''; [ "$bpo_kernel" = true ] && tmp='-backports'
    warn "没有可用于 $architecture/$suite$tmp 的云内核"

    return 1
}

# 检查是否有后端内核的函数
has_backports() {
    case $suite in
        buster|oldoldstable|bullseye|oldstable|bookworm|stable|trixie|testing) return
    esac

    warn "没有可用于 $suite 的后端内核"

    return 1
}

# 主要的配置变量初始化
interface=auto
ip=
netmask=
gateway=
dns='8.8.8.8 8.8.4.4'
dns6='2001:4860:4860::8888 2001:4860:4860::8844'
hostname=
network_console=false
set_debian_version 12
mirror_protocol=https
mirror_host=deb.debian.org
mirror_directory=/debian
mirror_proxy=
security_repository=mirror
account_setup=true
username=debian
password=
authorized_keys_url=
sudo_with_password=false
timezone=UTC
ntp=time.google.com
disk_partitioning=true
disk="/dev/$(lsblk -no PKNAME "$(df /boot | grep -Eo '/dev/[a-z0-9]+')")"
force_gpt=true
efi=
esp=106
filesystem=ext4
kernel=
cloud_kernel=false
bpo_kernel=false
install_recommends=true
install='sudo wget curl ntp lsb-release net-tools gnupg git socat cron jq'
upgrade=
kernel_params=
force_lowmem=
bbr=false
ssh_port=
hold=false
power_off=false
architecture=
firmware=false
force_efi_extra_removable=true
grub_timeout=5
dry_run=false
apt_non_free_firmware=true
apt_non_free=false
apt_contrib=false
apt_src=true
apt_backports=true
cidata=

# 解析脚本参数
while [ $# -gt 0 ]; do
    case $1 in
        --cdn)
            ;;
        --aws)
            mirror_host=cdn-aws.deb.debian.org
            ntp=time.aws.com
            ;;
        --cloudflare)
            dns='1.1.1.1 1.0.0.1'
            dns6='2606:4700:4700::1111 2606:4700:4700::1001'
            ntp=time.cloudflare.com
            ;;
        --aliyun)
            dns='223.5.5.5 223.6.6.6'
            dns6='2400:3200::1 2400:3200:baba::1'
            mirror_host=mirrors.aliyun.com
            ntp=time.amazonaws.cn
            ;;
        --ustc|--china)
            dns='119.29.29.29'
            dns6='2402:4e00::'
            mirror_host=mirrors.ustc.edu.cn
            ntp=time.amazonaws.cn
            ;;
        --tuna)
            dns='119.29.29.29'
            dns6='2402:4e00::'
            mirror_host=mirrors.tuna.tsinghua.edu.cn
            nt

p=time.amazonaws.cn
            ;;
        --interface)
            interface=$2
            shift
            ;;
        --ip)
            ip=$2
            shift
            ;;
        --netmask)
            netmask=$2
            shift
            ;;
        --gateway)
            gateway=$2
            shift
            ;;
        --dns)
            dns=$2
            shift
            ;;
        --dns6)
            dns6=$2
            shift
            ;;
        --hostname)
            hostname=$2
            shift
            ;;
        --network-console)
            network_console=true
            ;;
        --version)
            set_debian_version "$2"
            shift
            ;;
        --suite)
            set_suite "$2"
            shift
            ;;
        --release-d-i)
            daily_d_i=false
            ;;
        --daily-d-i)
            daily_d_i=true
            ;;
        --mirror-protocol)
            mirror_protocol=$2
            shift
            ;;
        --https)
            mirror_protocol=https
            ;;
        --mirror-host)
            mirror_host=$2
            shift
            ;;
        --mirror-directory)
            mirror_directory=${2%/}
            shift
            ;;
        --mirror-proxy|--proxy)
            mirror_proxy=$2
            shift
            ;;
        --reuse-proxy)
            set_mirror_proxy
            ;;
        --security-repository)
            security_repository=$2
            shift
            ;;
        --no-user|--no-account-setup)
            account_setup=false
            ;;
        --user|--username)
            username=$2
            shift
            ;;
        --password)
            password=$2
            shift
            ;;
        --authorized-keys-url)
            authorized_keys_url=$2
            shift
            ;;
        --sudo-with-password)
            sudo_with_password=true
            ;;
        --timezone)
            timezone=$2
            shift
            ;;
        --ntp)
            ntp=$2
            shift
            ;;
        --no-part|--no-disk-partitioning)
            disk_partitioning=false
            ;;
        --force-lowmem)
            [ "$2" != 0 ] && [ "$2" != 1 ] && [ "$2" != 2 ] && err '低内存级别只能是0、1或2'
            force_lowmem=$2
            shift
            ;;
        --disk)
            disk=$2
            shift
            ;;
        --no-force-gpt)
            force_gpt=false
            ;;
        --bios)
            efi=false
            ;;
        --efi)
            efi=true
            ;;
        --esp)
            esp=$2
            shift
            ;;
        --filesystem)
            filesystem=$2
            shift
            ;;
        --kernel)
            kernel=$2
            shift
            ;;
        --cloud-kernel)
            cloud_kernel=true
            ;;
        --bpo-kernel)
            bpo_kernel=true
            ;;
        --apt-non-free-firmware)
            apt_non_free_firmware=true
            ;;
        --apt-non-free)
            apt_non_free=true
            apt_contrib=true
            ;;
        --apt-contrib)
            apt_contrib=true
            ;;
        --apt-src)
            apt_src=true
            ;;
        --apt-backports)
            apt_backports=true
            ;;
        --no-apt-non-free-firmware)
            apt_non_free_firmware=false
            ;;
        --no-apt-non-free)
            apt_non_free=false
            ;;
        --no-apt-contrib)
            apt_contrib=false
            apt_non_free=false
            ;;
        --no-apt-src)
            apt_src=false
            ;;
        --no-apt-backports)
            apt_backports=false
            ;;
        --no-install-recommends)
            install_recommends=false
            ;;
        --install)
            install=$2
            shift
            ;;
        --no-upgrade)
            upgrade=none
            ;;
        --safe-upgrade)
            upgrade=safe-upgrade
            ;;
        --full-upgrade)
            upgrade=full-upgrade
            ;;
        --ethx)
            kernel_params="$kernel_params net.ifnames=0 biosdevname=0"
            ;;
        --bbr)
            bbr=true
            ;;
        --ssh-port)
            ssh_port=$2
            shift
            ;;
        --hold)
            hold=true
            ;;
        --power-off)
            power_off=true
            ;;
        --architecture)
            architecture=$2
            shift
            ;;
        --firmware)
            firmware=true
            ;;
        --no-force-efi-extra-removable)
            force_efi_extra_removable=false
            ;;
        --grub-timeout)
            grub_timeout=$2
            shift
            ;;
        --dry-run)
            dry_run=true
            ;;
        --cidata)
            cidata=$(realpath "$2")
            [ ! -f "$cidata/meta-data" ] && err '在cloud-init目录中找不到"meta-data"文件'
            [ ! -f "$cidata/user-data" ] && err '在cloud-init目录中找不到"user-data"文件'
            shift
            ;;
        *)
            err "未知选项: \"$1\""
    esac
    shift
done

# 如果未指定架构，则检测当前系统架构
[ -z "$architecture" ] && {
    architecture=$(dpkg --print-architecture 2> /dev/null) || {
        case $(uname -m) in
            x86_64)
                architecture=amd64
                ;;
            aarch64)
                architecture=arm64
                ;;
            i386)
                architecture=i386
                ;;
            *)
                err '未指定"--architecture"'
        esac
    }
}

# 如果未指定内核，则根据架构和云内核的可用性来设置
[ -z "$kernel" ] && {
    kernel="linux-image-$architecture"

    [ "$cloud_kernel" = true ] && has_cloud_kernel && kernel="linux-image-cloud-$architecture"
    [ "$bpo_kernel" = true ] && has_backports && install="$kernel/$suite-backports $install"
}

# 如果指定了authorized_keys_url，则下载公钥
[ -n "$authorized_keys_url" ] && ! download "$authorized_keys_url" /dev/null &&
err "无法从 \"$authorized_keys_url\" 下载SSH授权的公钥"

# 检查是否有可用的非自由固件
non_free_firmware_available=false
case $suite in
    bookworm|stable|trixie|testing|sid|unstable)
        non_free_firmware_available=true
        ;;
    *)
        apt_non_free_firmware=false
esac

# 设置APT组件和服务
apt_components=main
[ "$apt_contrib" = true ] && apt_components="$apt_components contrib"
[ "$apt_non_free" = true ] && apt_components="$apt_components non-free"
[ "$apt_non_free_firmware" = true ] && apt_components="$apt_components non-free-firmware"

apt_services=updates
[ "$apt_backports" = true ] && apt_services="$apt_services, backports"

installer_directory="/boot/debian-$suite"

# 保存预置文件的命令
save_preseed='cat'
[ "$dry_run" = false ] && {
    [ "$(id -u)" -ne 0 ] && err '需要root权限'
    rm -rf "$installer_directory"
    mkdir -p "$installer_directory"
    cd "$installer_directory"
    save_preseed='tee -a preseed.cfg'
}

# 如果需要账户设置，提示用户输入密码
if [ "$account_setup" = true ]; then
    prompt_password
elif [ "$network_console" = true ] && [ -z "$authorized_keys_url" ]; then
    prompt_password "为SSH网络控制台的安装程序用户选择一个密码: "
fi

# 输出本地化配置到预置文件
$save_preseed << EOF
# 本地化

d-i debian-installer/language string zh_CN:zh
d-i debian-installer/country string CN
d-i debian-installer/locale string zh_CN.UTF-8
d-i keyboard-configuration/xkb-keymap cn

# 网络配置

d-i netcfg/choose_interface select $interface
EOF

# 如果指定了IP地址，设置静态网络配置
[ -n "$ip" ] && {
    echo 'd-i netcfg/disable_autoconfig boolean true' | $save_preseed
    echo "d-i netcfg/get_ipaddress string $ip" | $save_preseed
    [ -n "$netmask" ] && echo "d-i netcfg/get_netmask string $netmask" | $save_preseed
    [ -n "$gateway" ] && echo "d-i netcfg/get_gateway string $gateway" | $save_preseed
    [ -z "${ip%%*:*}" ] && [ -n "${dns%%*:*}" ] && dns="$dns6"
    [ -n "$dns" ] && echo "d-i netcfg/get_nameservers string $dns" | $save_preseed
    echo 'd-i netcfg/confirm_static boolean true' | $save_preseed
}

# 设置主机名和域名
if [ -n "$hostname" ]; then
    echo "d-i netcfg/hostname string $hostname" | $save_preseed
    hostname=debian
    domain=
else
    hostname=$(cat /proc/sys/kernel/hostname)
    domain=$(cat /proc/sys/kernel/domainname)
    if [ "$domain" = '(none)' ]; then
        domain=
    else
        domain=" $domain"
    fi
fi

$save_preseed << EOF


d-i netcfg/get_hostname string $hostname
d-i netcfg/get_domain string$domain
EOF

# 启用固件加载
echo 'd-i hw-detect/load_firmware boolean true' | $save_preseed

# 如果启用了网络控制台，添加相关配置
[ "$network_console" = true ] && {
    $save_preseed << 'EOF'

# 网络控制台

d-i anna/choose_modules string network-console
d-i preseed/early_command string anna-install network-console
EOF
    if [ -n "$authorized_keys_url" ]; then
        echo "d-i network-console/authorized_keys_url string $authorized_keys_url" | $save_preseed
    else
        $save_preseed << EOF
d-i network-console/password password $password
d-i network-console/password-again password $password
EOF
    fi

    echo 'd-i network-console/start select Continue' | $save_preseed
}

$save_preseed << EOF

# 镜像设置

d-i mirror/country string manual
d-i mirror/protocol string $mirror_protocol
d-i mirror/$mirror_protocol/hostname string $mirror_host
d-i mirror/$mirror_protocol/directory string $mirror_directory
d-i mirror/$mirror_protocol/proxy string $mirror_proxy
d-i mirror/suite string $suite
EOF

# 如果需要账户设置，生成密码哈希并输出账户相关配置
[ "$account_setup" = true ] && {
    password_hash=$(mkpasswd -m sha-256 "$password" 2> /dev/null) ||
    password_hash=$(openssl passwd -5 "$password" 2> /dev/null) ||
    password_hash=$(busybox mkpasswd -m sha256 "$password" 2> /dev/null) || {
        for python in python3 python python2; do
            password_hash=$("$python" -c 'import crypt, sys; print(crypt.crypt(sys.argv[1], crypt.mksalt(crypt.METHOD_SHA256)))' "$password" 2> /dev/null) && break
        done
    }

    $save_preseed << 'EOF'

# 账户设置

EOF
    [ -n "$authorized_keys_url" ] && configure_sshd PasswordAuthentication no

    if [ "$username" = root ]; then
        if [ -z "$authorized_keys_url" ]; then
            configure_sshd PermitRootLogin yes
        else
            in_target "mkdir -m 0700 -p ~root/.ssh && busybox wget -O- \"$authorized_keys_url\" >> ~root/.ssh/authorized_keys"
        fi

        $save_preseed << 'EOF'
d-i passwd/root-login boolean true
d-i passwd/make-user boolean false
EOF

        if [ -z "$password_hash" ]; then
            $save_preseed << EOF
d-i passwd/root-password password $password
d-i passwd/root-password-again password $password
EOF
        else
            echo "d-i passwd/root-password-crypted password $password_hash" | $save_preseed
        fi
    else
        configure_sshd PermitRootLogin no

        [ -n "$authorized_keys_url" ] &&
        in_target "sudo -u $username mkdir -m 0700 -p ~$username/.ssh && busybox wget -O - \"$authorized_keys_url\" | sudo -u $username tee -a ~$username/.ssh/authorized_keys"

        [ "$sudo_with_password" = false ] &&
        in_target "echo \"$username ALL=(ALL:ALL) NOPASSWD:ALL\" > \"/etc/sudoers.d/90-user-$username\""

        $save_preseed << EOF
d-i passwd/root-login boolean false
d-i passwd/make-user boolean true
d-i passwd/user-fullname string
d-i passwd/username string $username
EOF

        if [ -z "$password_hash" ]; then
            $save_preseed << EOF
d-i passwd/user-password password $password
d-i passwd/user-password-again password $password
EOF
        else
            echo "d-i passwd/user-password-crypted password $password_hash" | $save_preseed
        fi
    fi
}

# 如果指定了SSH端口，则配置sshd服务
[ -n "$ssh_port" ] && configure_sshd Port "$ssh_port"

# 输出时区和时钟设置到预置文件
$save_preseed << EOF

# 时钟和时区设置

d-i time/zone string $timezone
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i clock-setup/ntp-server string $ntp

# 分区

EOF

# 如果启用了磁盘分区，设置分区相关配置
[ "$disk_partitioning" = true ] && {
    $save_preseed << 'EOF'
d-i partman-auto/method string regular
EOF
    if [ -n "$disk" ]; then
        echo "d-i partman-auto/disk string $disk" | $save_preseed
    else
        # shellcheck disable=SC2016
        echo 'd-i partman/early_command string debconf-set partman-auto/disk "$(list-devices disk | head -n 1)"' | $save_preseed
    fi
}

# 如果启用了GPT分区表，设置相关选项
[ "$force_gpt" = true ] && {
    $save_preseed << 'EOF'
d-i partman-partitioning/choose_label string gpt
d-i partman-partitioning/default_label string gpt
EOF
}

# 设置默认文件系统类型并配置分区
[ "$disk_partitioning" = true ] && {
    echo "d-i partman/default_filesystem string $filesystem" | $save_preseed

    [ -z "$efi" ] && {
        efi=false
        [ -d /sys/firmware/efi ] && efi=true
    }

    $save_preseed << 'EOF'
d-i partman-auto/expert_recipe string \
    naive :: \
EOF
    if [ "$efi" = true ]; then
        $save_preseed << EOF
        $esp $esp $esp free \\
EOF
        $save_preseed << 'EOF'
            $iflabel{ gpt } \
            $reusemethod{ } \
            method{ efi } \
            format{ } \
        . \
EOF
    else
        $save_preseed << 'EOF'
        1 1 1 free \
            $iflabel{ gpt } \
            $reusemethod{ } \
            method{ biosgrub } \
        . \
EOF
    fi

    $save_preseed << 'EOF'
        1075 1076 -1 $default_filesystem \
            method{ format } \
            format{ } \
            use_filesystem{ } \
            $default_filesystem{ } \
            mountpoint{ / } \
        .
EOF
    if [ "$efi" = true ]; then
        echo 'd-i partman-efi/non_efi_system boolean true' | $save_preseed
    fi

    $save_preseed << 'EOF'
d-i partman-auto/choose_recipe select naive
d-i partman-basicfilesystems/no_swap boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-lvm/device_remove_lvm boolean true
EOF
}

# 输出基础系统安装的配置
$save_preseed << EOF

# 基础系统安装

d-i base-installer/kernel/image string $kernel
EOF

# 如果不安装推荐的软件包，设置相关选项
[ "$install_recommends" = false ] && echo "d-i base-installer/install-recommends boolean $install_recommends" | $save_preseed

# 设置安全更新的存储库
[ "$security_repository" = mirror ] && security_repository=$mirror_protocol://$mirror_host${mirror_directory%/*}/debian-security

$save_preseed << EOF

# APT的设置

d-i apt-setup/contrib boolean $apt_contrib
d-i apt-setup/non-free boolean $apt_non_free
d-i apt-setup/enable-source-repositories boolean $apt_src
d-i apt-setup/services-select multiselect $apt_services
EOF

# 如果非自由固件可用，启用相关设置
[ "$non_free_firmware_available" = true ] && echo "d-i apt-setup/non-free-firmware boolean $apt_non_free_firmware" | $save_preseed

# 如果不是sid/unstable版本，设置安全更新的存储库
[ -n "$security_archive" ] && {
    $save_preseed << EOF
d-i apt-setup/local0/repository string $security_repository $security_archive $apt_components
d-i apt-setup/local0/source boolean $apt_src
EOF
}

# 输出软件包选择相关配置
$save_preseed << 'EOF'

# tasksel套餐选择 - 选择要安装的任务
tasksel tasksel/first multiselect ssh-server
EOF

# 定义要安装的软件包
install="$install ca-certificates libpam-systemd"
[ -n "$cidata" ] && install="$install cloud-init"

# 如果有安装包，则添加到预设文件中
[ -n "$install" ] && echo "d-i pkgsel/include string $install" | $save_preseed
# 如果有升级选项，则添加到预设文件中
[ -n "$upgrade" ] && echo "d-i pkgsel/upgrade select $upgrade" | $save_preseed

# 禁用流行度竞赛
$save_preseed << 'EOF'
popularity-contest popularity-contest/participate boolean false

# 引导加载程序安装
EOF

# 设置引导加载程序的安装设备
if [ -n "$disk" ]; then
    echo "d-i grub-installer/bootdev string $disk" | $save_preseed
else
    echo 'd-i grub-installer/bootdev string default' | $save_preseed
fi

# 如果需要强制安装EFI可移动设备支持
[ "$force_efi_extra_removable" = true ] && echo 'd-i grub-installer/force-efi-extra-removable boolean true' | $save_preseed

# 如果有内核参数，则添加到预设文件中
[ -n "$kernel_params" ] && echo "d-i debian-installer/add-kernel-opts string$kernel_params" | $save_preseed

$save_preseed << 'EOF'

# 完成安装
EOF

# 如果不需要暂停重新启动，则立即重新启动
[ "$hold" = false ] && echo 'd-i finish-install/reboot_in_progress note' | $save_preseed

# 如果需要启用BBR（拥塞控制算法），则添加配置
[ "$bbr" = true ] && in_target '{ echo "net.core.default_qdisc=fq"; echo "net.ipv4.tcp_congestion_control=bbr"; } > /etc/sysctl.d/bbr.conf'

# 如果有云数据源配置，则写入到配置文件中
[ -n "$cidata" ] && in_target 'echo "{ datasource_list: [ NoCloud ], datasource: { NoCloud: { fs_label: ~ } } }" > /etc/cloud/cloud.cfg.d/99_debi.cfg'

# 定义late_command命令
late_command='true'
[ -n "$in_target_script" ] && late_command="$late_command; in-target sh -c '$in_target_script'"
[ -n "$cidata" ] && late_command="$late_command; mkdir -p /target/var/lib/cloud/seed/nocloud; cp -r /cidata/. /target/var/lib/cloud/seed/nocloud/"

# 将late_command写入预设文件
echo "d-i preseed/late_command string $late_command" | $save_preseed

# 如果需要安装完成后关机，则写入关机选项
[ "$power_off" = true ] && echo 'd-i debian-installer/exit/poweroff boolean true' | $save_preseed

# 保存GRUB配置的命令，默认为cat
save_grub_cfg='cat'
# 如果不是dry_run模式，执行下载和配置GRUB
[ "$dry_run" = false ] && {
    base_url="$mirror_protocol://$mirror_host$mirror_directory/dists/$suite/main/installer-$architecture/current/images/netboot/debian-installer/$architecture"
    [ "$suite" = stretch ] && [ "$efi" = true ] && base_url="$mirror_protocol://$mirror_host$mirror_directory/dists/buster/main/installer-$architecture/current/images/netboot/debian-installer/$architecture"
    [ "$daily_d_i" = true ] && base_url="https://d-i.debian.org/daily-images/$architecture/daily/netboot/debian-installer/$architecture"
    firmware_url="https://cdimage.debian.org/cdimage/unofficial/non-free/firmware/$suite/current/firmware.cpio.gz"

    # 下载内核和初始ramdisk
    download "$base_url/linux" linux
    download "$base_url/initrd.gz" initrd.gz
    [ "$firmware" = true ] && download "$firmware_url" firmware.cpio.gz

    # 解压initrd.gz并追加预设文件
    gzip -d initrd.gz
    echo preseed.cfg | cpio -o -H newc -A -F initrd

    # 如果有云数据源，追加到initrd中
    if [ -n "$cidata" ]; then
        cp -r "$cidata" cidata
        find cidata | cpio -o -H newc -A -F initrd
    fi

    # 重新压缩initrd
    gzip -1 initrd

    # 配置GRUB引导菜单
    mkdir -p /etc/default/grub.d
    tee /etc/default/grub.d/zz-debi.cfg 1>&2 << EOF
GRUB_DEFAULT=debi
GRUB_TIMEOUT=$grub_timeout
GRUB_TIMEOUT_STYLE=menu
EOF

    # 更新GRUB配置
    if command_exists update-grub; then
        grub_cfg=/boot/grub/grub.cfg
        update-grub
    elif command_exists grub2-mkconfig; then
        tmp=$(mktemp)
        grep -vF zz_debi /etc/default/grub > "$tmp"
        cat "$tmp" > /etc/default/grub
        rm "$tmp"
        echo 'zz_debi=/etc/default/grub.d/zz-debi.cfg; if [ -f "$zz_debi" ]; then . "$zz_debi"; fi' >> /etc/default/grub
        grub_cfg=/boot/grub2/grub.cfg
        [ -d /sys/firmware/efi ] && grub_cfg=/boot/efi/EFI/*/grub.cfg
        grub2-mkconfig -o "$grub_cfg"
    elif command_exists grub-mkconfig; then
        tmp=$(mktemp)
        grep -vF zz_debi /etc/default/grub > "$tmp"
        cat "$tmp" > /etc/default/grub
        rm "$tmp"
        echo 'zz_debi=/etc/default/grub.d/zz-debi.cfg; if [ -f "$zz_debi" ]; then . "$zz_debi"; fi' >> /etc/default/grub
        grub_cfg=/boot/grub/grub.cfg
        grub-mkconfig -o "$grub_cfg"
    else
        err '无法找到 "update-grub" 或 "grub2-mkconfig" 或 "grub-mkconfig" 命令'
    fi

    save_grub_cfg="tee -a $grub_cfg"
}

# 处理安装程序目录路径
mkrelpath=$installer_directory
[ "$dry_run" = true ] && mkrelpath=/boot
installer_directory=$(grub-mkrelpath "$mkrelpath" 2> /dev/null) ||
installer_directory=$(grub2-mkrelpath "$mkrelpath" 2> /dev/null) || {
    err '无法找到 "grub-mkrelpath" 或 "grub2-mkrelpath" 命令'
}
[ "$dry_run" = true ] && installer_directory="$installer_directory/debian-$suite"

# 设置内核参数
kernel_params="$kernel_params lowmem/low=1"
[ -n "$force_lowmem" ] && kernel_params="$kernel_params lowmem=+$force_lowmem"

# 设置initrd路径
initrd="$installer_directory/initrd.gz"
[ "$firmware" = true ] && initrd="$initrd $installer_directory/firmware.cpio.gz"

# 写入GRUB菜单项
$save_grub_cfg 1>&2 << EOF
menuentry 'Debian Installer' --id debi {
    insmod part_msdos
    insmod part_gpt
    insmod ext2
    insmod xfs
    insmod btrfs
    linux $installer_directory/linux$kernel_params
    initrd $initrd
}
EOF
