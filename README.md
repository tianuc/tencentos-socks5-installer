# TencentOS Socks5 一键安装脚本

这是一个用于在TencentOS Server 4上快速部署Socks5代理服务器的脚本。

## 功能特点

- 自动安装V2Ray
- 自动配置Socks5代理
- 随机生成安全的端口和认证信息
- 自动设置服务保活
- 支持系统服务管理

## 使用方法

1. 下载安装脚本：
```bash
curl -L -o install_socks5.sh https://raw.githubusercontent.com/你的用户名/仓库名/main/install_socks5.sh
```

2. 添加执行权限：
```bash
chmod +x install_socks5.sh
```

3. 运行安装脚本：
```bash
sudo ./install_socks5.sh
```

## 安装完成后

安装完成后，脚本会显示以下信息：
- 代理服务器地址
- 端口号
- 用户名
- 密码

请妥善保存这些信息，它们将用于配置客户端。

## 系统要求

- TencentOS Server 4
- Root权限
- 网络连接

## 注意事项

- 请确保服务器防火墙已开放相应端口
- 建议定期更换端口和认证信息以提高安全性
- 如遇到问题，请查看日志文件：`/var/log/v2ray/error.log` 