# 脚本大集合。

<br />
<br />
<br />

## Snell 一键脚本

<br />

### 安装snell。
```bash
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/jijunrong/sh/main/snell.sh)"
```
<br />

### 卸载snell。
```bash
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/jijunrong/sh/main/rmsnell.sh)"
```

<br />
<br />
<br />

## 一键DD脚本。

<br />

### 下载脚本并赋予权限。
```bash
curl -fLO https://raw.githubusercontent.com/jijunrong/sh/main/debian.sh && chmod a+rx debian.sh
```
<br />

### 运行脚本。
```bash
sudo ./debian.sh --cdn --network-console --ethx --bbr --user root --password zxc1230. --version 12
```
<br />

### 重启VPS。(无报错，重启进行全自动安装。)
```bash
sudo shutdown -r now
```
<br />
<br />
<br />

## PLEX一键安装。

<br />

### 安装PLEX
```bash
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/jijunrong/sh/main/plex.sh)"
```

<br />

### 运行PLEX,并设置开机自启。
```bash
sudo systemctl enable plexmediaserver
sudo systemctl start plexmediaserver
```
<br />

### 卸载PLEX,并取消开机自启。
```bash
sudo systemctl disable plexmediaserver
apt remove plexmediaserver
```

<br />
<br />
<br />

### 未完待续。。。
