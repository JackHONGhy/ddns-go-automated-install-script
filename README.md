# ddns-go Automated Install Script

这个项目提供一个 ddns-go 自动安装脚本，用于在 Linux 服务器上自动识别系统架构，并安装 GitHub 最新发布版本的 ddns-go。

脚本会从 `jeessy2/ddns-go` 的 latest release 实时获取最新版本，不固定写死版本号。

## 支持系统和架构

- Linux amd64 / x86_64
- Linux arm64 / aarch64

## 一键安装

在目标服务器上使用 root 用户运行：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/JackHONGhy/ddns-go-automated-install-script/master/install.sh)
```

安装过程中脚本会询问 ddns-go Web 管理界面端口，例如：

```bash
Enter ddns-go web port, for example 50897: 50897
```

脚本最终会执行类似下面的服务安装命令：

```bash
./ddns-go -s install -l :50897
```

## 脚本会自动完成

- 检测当前系统是否为 Linux
- 检测 CPU 架构
- 根据架构选择 `linux_x86_64` 或 `linux_arm64`
- 查询 ddns-go GitHub 最新 release
- 下载对应架构的最新压缩包
- 解压并安装到 `/opt/ddns-go`
- 创建 `/usr/local/bin/ddns-go` 命令链接
- 询问 Web 管理端口
- 安装 systemd service
- 设置开机自启
- 启动或重启 `ddns-go` 服务

## 安装后管理

查看服务状态：

```bash
systemctl status ddns-go --no-pager -l
```

查看日志：

```bash
journalctl -u ddns-go.service -e --no-pager -f
```

重启服务：

```bash
systemctl restart ddns-go
```

停止服务：

```bash
systemctl stop ddns-go
```

## 自定义安装目录

默认安装到 `/opt/ddns-go`。如需修改：

```bash
INSTALL_DIR=/etc/ddns-go bash <(curl -Ls https://raw.githubusercontent.com/JackHONGhy/ddns-go-automated-install-script/master/install.sh)
```

## 文件说明

- `install.sh`：自动识别架构并安装最新 ddns-go 的脚本
- `README.md`：项目说明和安装方式
