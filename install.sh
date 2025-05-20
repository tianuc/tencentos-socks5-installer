#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置文件路径
CONFIG_FILE="/etc/v2ray/config.json"
SERVICE_FILE="/etc/systemd/system/v2ray.service"

# 生成随机字符串
generate_random_string() {
    local length=$1
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c $length
}

# 生成随机凭据
generate_random_credentials() {
    local username=$(generate_random_string 8)
    local password=$(generate_random_string 12)
    echo "$username:$password"
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 请使用root权限运行此脚本!${NC}"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装依赖...${NC}"
    yum update -y
    yum install -y wget unzip curl
}

# 安装V2Ray
install_v2ray() {
    echo -e "${BLUE}正在安装V2Ray...${NC}"
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
}

# 配置V2Ray
configure_v2ray() {
    local port=$1
    local username=$2
    local password=$3
    
    echo -e "${BLUE}正在配置V2Ray...${NC}"
    mkdir -p /etc/v2ray
    
    cat > $CONFIG_FILE << EOF
{
  "inbounds": [{
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
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF

    # 创建服务文件
    cat > $SERVICE_FILE << EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/v2ray run -config $CONFIG_FILE
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # 重载systemd
    systemctl daemon-reload
    
    # 保存配置到文件
    echo "端口: $port" > /etc/v2ray/credentials.txt
    echo "用户名: $username" >> /etc/v2ray/credentials.txt
    echo "密码: $password" >> /etc/v2ray/credentials.txt
    chmod 600 /etc/v2ray/credentials.txt
}

# 启动V2Ray
start_v2ray() {
    echo -e "${BLUE}正在启动V2Ray...${NC}"
    systemctl enable v2ray
    systemctl start v2ray
}

# 检查状态
check_status() {
    echo -e "${BLUE}V2Ray 状态信息:${NC}"
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status v2ray
    echo -e "\n${YELLOW}配置信息:${NC}"
    if [ -f /etc/v2ray/credentials.txt ]; then
        cat /etc/v2ray/credentials.txt
    else
        echo "未找到配置文件"
    fi
    echo -e "\n${YELLOW}连接信息:${NC}"
    echo "服务器IP: $(curl -s ifconfig.me)"
    echo "协议: SOCKS5"
}

# 修改配置
modify_config() {
    echo -e "${BLUE}修改配置${NC}"
    echo -e "${YELLOW}1. 修改端口${NC}"
    echo -e "${YELLOW}2. 修改用户名和密码${NC}"
    echo -e "${YELLOW}3. 返回主菜单${NC}"
    read -p "请选择操作 [1-3]: " choice

    case $choice in
        1)
            read -p "请输入新端口: " new_port
            if [ -f /etc/v2ray/credentials.txt ]; then
                username=$(grep "用户名:" /etc/v2ray/credentials.txt | cut -d' ' -f2)
                password=$(grep "密码:" /etc/v2ray/credentials.txt | cut -d' ' -f2)
                configure_v2ray "$new_port" "$username" "$password"
                systemctl restart v2ray
                echo -e "${GREEN}端口已修改为: $new_port${NC}"
            else
                echo -e "${RED}未找到现有配置${NC}"
            fi
            ;;
        2)
            echo -e "${YELLOW}是否生成随机用户名和密码? (y/n)${NC}"
            read -p "请选择 [y/n]: " gen_choice
            if [ "$gen_choice" = "y" ] || [ "$gen_choice" = "Y" ]; then
                credentials=$(generate_random_credentials)
                username=$(echo $credentials | cut -d: -f1)
                password=$(echo $credentials | cut -d: -f2)
                echo -e "${GREEN}已生成随机用户名: $username${NC}"
                echo -e "${GREEN}已生成随机密码: $password${NC}"
            else
                read -p "请输入新用户名: " username
                read -p "请输入新密码: " password
            fi
            if [ -f /etc/v2ray/credentials.txt ]; then
                port=$(grep "端口:" /etc/v2ray/credentials.txt | cut -d' ' -f2)
                configure_v2ray "$port" "$username" "$password"
                systemctl restart v2ray
                echo -e "${GREEN}用户名和密码已修改${NC}"
            else
                echo -e "${RED}未找到现有配置${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            ;;
    esac
}

# 卸载V2Ray
uninstall_v2ray() {
    echo -e "${RED}警告: 此操作将完全卸载V2Ray${NC}"
    read -p "是否继续? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        systemctl stop v2ray
        systemctl disable v2ray
        rm -rf /usr/local/bin/v2ray
        rm -rf /etc/v2ray
        rm -f $SERVICE_FILE
        systemctl daemon-reload
        echo -e "${GREEN}V2Ray已完全卸载${NC}"
    fi
}

# 安装/配置V2Ray
install_and_configure() {
    install_dependencies
    install_v2ray
    
    echo -e "${YELLOW}请选择配置方式:${NC}"
    echo -e "1. 手动输入配置"
    echo -e "2. 使用随机配置"
    read -p "请选择 [1-2]: " config_choice
    
    case $config_choice in
        1)
            read -p "请输入端口 (默认: 23000): " port
            port=${port:-23000}
            read -p "请输入用户名: " username
            read -p "请输入密码: " password
            ;;
        2)
            port=23000
            credentials=$(generate_random_credentials)
            username=$(echo $credentials | cut -d: -f1)
            password=$(echo $credentials | cut -d: -f2)
            echo -e "${GREEN}已生成随机用户名: $username${NC}"
            echo -e "${GREEN}已生成随机密码: $password${NC}"
            ;;
        *)
            echo -e "${RED}无效选项，使用默认配置${NC}"
            port=23000
            credentials=$(generate_random_credentials)
            username=$(echo $credentials | cut -d: -f1)
            password=$(echo $credentials | cut -d: -f2)
            ;;
    esac
    
    configure_v2ray "$port" "$username" "$password"
    start_v2ray
    
    echo -e "${GREEN}安装完成！${NC}"
    echo -e "${YELLOW}配置信息:${NC}"
    echo "端口: $port"
    echo "用户名: $username"
    echo "密码: $password"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${BLUE}=== V2Ray SOCKS5 代理管理 ===${NC}"
    echo -e "${GREEN}1.${NC} 安装/重装 V2Ray"
    echo -e "${GREEN}2.${NC} 启动 V2Ray"
    echo -e "${GREEN}3.${NC} 停止 V2Ray"
    echo -e "${GREEN}4.${NC} 重启 V2Ray"
    echo -e "${GREEN}5.${NC} 查看状态"
    echo -e "${GREEN}6.${NC} 修改配置"
    echo -e "${GREEN}7.${NC} 卸载 V2Ray"
    echo -e "${GREEN}0.${NC} 退出"
    echo
    read -p "请选择操作 [0-7]: " choice

    case $choice in
        1)
            install_and_configure
            ;;
        2)
            systemctl start v2ray
            echo -e "${GREEN}V2Ray已启动${NC}"
            ;;
        3)
            systemctl stop v2ray
            echo -e "${GREEN}V2Ray已停止${NC}"
            ;;
        4)
            systemctl restart v2ray
            echo -e "${GREEN}V2Ray已重启${NC}"
            ;;
        5)
            check_status
            ;;
        6)
            modify_config
            ;;
        7)
            uninstall_v2ray
            ;;
        0)
            echo -e "${GREEN}再见!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项${NC}"
            ;;
    esac

    read -p "按回车键继续..."
    show_menu
}

# 主函数
main() {
    check_root
    show_menu
}

# 运行主函数
main