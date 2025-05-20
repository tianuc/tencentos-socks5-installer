#!/bin/bash

# 颜色定义
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
NC="\033[0m" # 无颜色

# 配置文件和日志路径
CONFIG_FILE="/etc/v2ray/config.json"
V2RAY_LOG="/var/log/v2ray/access.log"
CREDENTIALS_FILE="/etc/v2ray/credentials.txt"
KEEPALIVE_SERVICE="/etc/systemd/system/v2ray-keepalive.service"

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误: 请使用root权限运行此脚本!${NC}"
        exit 1
    fi
}

# 安装必要的软件包
install_dependencies() {
    echo -e "${BLUE}正在检查并安装依赖项...${NC}"
    
    # 更新软件包索引
    if ! yum update -y; then
        echo -e "${RED}更新软件包索引失败${NC}"
        return 1
    fi
    
    # 安装基本工具
    echo -e "${BLUE}安装基础工具...${NC}"
    if ! yum install -y curl wget unzip jq; then
        echo -e "${RED}安装基础工具失败${NC}"
        return 1
    fi
    
    # 创建必要的目录
    mkdir -p /etc/v2ray
    mkdir -p /var/log/v2ray
    
    echo -e "${GREEN}依赖安装完成${NC}"
    return 0
}

# 下载并安装V2Ray
install_v2ray() {
    echo -e "${BLUE}正在下载并安装V2Ray...${NC}"
    
    # 下载V2Ray安装脚本
    if ! curl -L -o v2ray-install.sh https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh; then
        echo -e "${RED}下载V2Ray安装脚本失败${NC}"
        return 1
    fi
    
    # 执行安装脚本
    if ! bash v2ray-install.sh; then
        echo -e "${RED}V2Ray安装失败${NC}"
        return 1
    fi
    
    # 清理安装脚本
    rm -f v2ray-install.sh
    
    echo -e "${GREEN}V2Ray安装完成${NC}"
    return 0
}

# 生成随机端口(1024-65535)
generate_random_port() {
    echo $(( (RANDOM % 64511) + 1024 ))
}

# 生成随机用户名和密码
generate_random_credentials() {
    local username=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
    local password=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
    echo "$username:$password"
}

# 保存凭据到文件
save_credentials() {
    local port=$1
    local username=$2
    local password=$3
    
    echo "端口: $port" > "$CREDENTIALS_FILE"
    echo "用户名: $username" >> "$CREDENTIALS_FILE"
    echo "密码: $password" >> "$CREDENTIALS_FILE"
    
    chmod 600 "$CREDENTIALS_FILE"
    
    echo -e "${GREEN}凭据已保存到 $CREDENTIALS_FILE${NC}"
}

# 配置V2Ray
configure_v2ray() {
    local port=$1
    local username=$2
    local password=$3
    
    # 确保目录存在
    mkdir -p /etc/v2ray
    
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": $port,
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$username",
            "pass": "$password"
          }
        ],
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

    echo -e "${GREEN}V2Ray已配置为使用端口 $port 和用户名/密码认证${NC}"
    save_credentials "$port" "$username" "$password"
}

# 设置自动保活服务
setup_keepalive() {
    cat > "$KEEPALIVE_SERVICE" << 'EOF'
[Unit]
Description=V2Ray Keepalive Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do if ! pgrep -x v2ray > /dev/null; then systemctl restart v2ray; fi; sleep 60; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable v2ray-keepalive
    systemctl start v2ray-keepalive
    
    echo -e "${GREEN}V2Ray保活服务已设置并启动${NC}"
}

# 显示当前配置
show_current_config() {
    echo -e "${CYAN}╭───────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${WHITE}          当前V2Ray Socks5代理配置          ${CYAN}│${NC}"
    echo -e "${CYAN}╰───────────────────────────────────────────╯${NC}"
    
    if [ -f "$CREDENTIALS_FILE" ]; then
        # 读取配置信息
        local port=$(grep "端口:" "$CREDENTIALS_FILE" | cut -d' ' -f2)
        local username=$(grep "用户名:" "$CREDENTIALS_FILE" | cut -d' ' -f2)
        local password=$(grep "密码:" "$CREDENTIALS_FILE" | cut -d' ' -f2)
        
        echo -e "${BLUE}端口:    ${WHITE}$port${NC}"
        echo -e "${BLUE}用户名:  ${WHITE}$username${NC}"
        echo -e "${BLUE}密码:    ${WHITE}$password${NC}"
        
        # 显示运行状态
        if systemctl is-active --quiet v2ray; then
            echo -e "${BLUE}状态:    ${GREEN}运行中${NC}"
        else
            echo -e "${BLUE}状态:    ${RED}未运行${NC}"
        fi
        
        # 显示IP地址
        echo -e "${BLUE}服务器IP地址:${NC}"
        ip -4 addr show | grep -o "inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -v "127.0.0.1" | sed 's/inet //' | head -n 1
        
        # 显示连接信息
        echo -e "${CYAN}╭───────────────────────────────────────────╮${NC}"
        echo -e "${CYAN}│${WHITE}               连接信息                   ${CYAN}│${NC}"
        echo -e "${CYAN}╰───────────────────────────────────────────╯${NC}"
        echo -e "${YELLOW}协议:    ${WHITE}SOCKS5${NC}"
        echo -e "${YELLOW}地址:    ${WHITE}$(ip -4 addr show | grep -o "inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" | grep -v "127.0.0.1" | sed 's/inet //' | head -n 1)${NC}"
        echo -e "${YELLOW}端口:    ${WHITE}$port${NC}"
        echo -e "${YELLOW}用户名:  ${WHITE}$username${NC}"
        echo -e "${YELLOW}密码:    ${WHITE}$password${NC}"
    else
        echo -e "${YELLOW}未找到配置文件，请先配置代理${NC}"
    fi
}

# 主函数
main() {
    check_root
    install_dependencies
    install_v2ray
    
    # 生成随机端口和凭据
    local port=$(generate_random_port)
    local credentials=$(generate_random_credentials)
    local username=$(echo "$credentials" | cut -d: -f1)
    local password=$(echo "$credentials" | cut -d: -f2)
    
    # 配置V2Ray
    configure_v2ray "$port" "$username" "$password"
    
    # 启动V2Ray服务
    systemctl enable v2ray
    systemctl start v2ray
    
    # 设置保活服务
    setup_keepalive
    
    # 显示配置信息
    show_current_config
    
    echo -e "${GREEN}安装完成！${NC}"
}

# 启动脚本
main 