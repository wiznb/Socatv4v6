#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

Green="\033[32m"
Font="\033[0m"
Blue="\033[33m"

rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error:必须以 root 权限运行脚本！" 1>&2
       exit 1
    fi
}

checkos(){
    if [[ -f /etc/redhat-release ]];then
        OS=CentOS
    elif grep -q -E -i "debian" /etc/issue;then
        OS=Debian
    elif grep -q -E -i "ubuntu" /etc/issue;then
        OS=Ubuntu
    elif grep -q -E -i "centos|red hat|redhat" /etc/issue;then
        OS=CentOS
    elif grep -q -E -i "debian" /proc/version;then
        OS=Debian
    elif grep -q -E -i "ubuntu" /proc/version;then
        OS=Ubuntu
    elif grep -q -E -i "centos|red hat|redhat" /proc/version;then
        OS=CentOS
    else
        echo "不支持的操作系统，请更换系统后重试。"
        exit 1
    fi
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

disable_iptables(){
    systemctl stop firewalld.service >/dev/null 2>&1
    systemctl disable firewalld.service >/dev/null 2>&1
    service iptables stop >/dev/null 2>&1
    chkconfig iptables off >/dev/null 2>&1
}

get_ip(){
    ip=`curl -s http://whatismyip.akamai.com`
}

config_socat() {
    echo -e "${Green}请输入 Socat 配置信息！${Font}"
    read -p "请输入本地端口: " port1
    read -p "请输入远程端口: " port2
    read -p "请输入远程 IP (支持 IPv4 和 IPv6): " rawip

    # 正则判断 IPv4
    ipv4_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    # 简单的 IPv6 检查（匹配 : 并含至少两个段）
    ipv6_regex='^([0-9a-fA-F]{0,4}:){2,}'

    if [[ "$rawip" =~ $ipv4_regex ]]; then
        socatip="$rawip"
        iptype="IPv4"
    elif [[ "$rawip" =~ $ipv6_regex ]]; then
        socatip="[$rawip]"
        iptype="IPv6"
    else
        socatip="$rawip"
        iptype="域名"
    fi

    echo -e "${Yellow}识别为：$iptype，格式化后地址：$socatip${Font}"
}

start_socat(){
    echo -e "${Green}正在配置 Socat...${Font}"
    nohup socat TCP6-LISTEN:${port1},bind=[::],reuseaddr,fork TCP:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP4-LISTEN:${port1},reuseaddr,fork UDP4:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP6-LISTEN:${port1},bind=[::],reuseaddr,fork UDP6:[${socatip}]:${port2} >> /root/socat.log 2>&1 &

    # 加入开机启动
    if [ "${OS}" == 'CentOS' ];then
        sed -i '/exit/d' /etc/rc.d/rc.local
        echo " nohup socat TCP6-LISTEN:${port1},bind=[::],reuseaddr,fork TCP:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP4-LISTEN:${port1},reuseaddr,fork UDP4:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP6-LISTEN:${port1},bind=[::],reuseaddr,fork UDP6:[${socatip}]:${port2} >> /root/socat.log 2>&1 &

     " >> /etc/rc.d/rc.local
        chmod +x /etc/rc.d/rc.local
    elif [ -s /etc/rc.local ]; then
        sed -i '/exit/d' /etc/rc.local
        echo " nohup socat TCP6-LISTEN:${port1},bind=[::],reuseaddr,fork TCP:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP4-LISTEN:${port1},reuseaddr,fork UDP4:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP6-LISTEN:${port1},bind=[::],reuseaddr,fork UDP6:[${socatip}]:${port2} >> /root/socat.log 2>&1 &

     " >> /etc/rc.local
        chmod +x /etc/rc.local
    else
        echo -e "${Green}检测到系统无 rc.local，自启将进行配置...${Font}"
        cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

        cat > /etc/rc.local <<EOF
#!/bin/sh -e
    nohup socat TCP6-LISTEN:${port1},bind=[::],reuseaddr,fork TCP:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP4-LISTEN:${port1},reuseaddr,fork UDP4:${socatip}:${port2} >> /root/socat.log 2>&1 &
    nohup socat -T 600 UDP6-LISTEN:${port1},bind=[::],reuseaddr,fork UDP6:[${socatip}]:${port2} >> /root/socat.log 2>&1 &

EOF

        chmod +x /etc/rc.local
        systemctl enable rc-local >/dev/null 2>&1
        systemctl start rc-local >/dev/null 2>&1
    fi

    get_ip
    sleep 2
    echo
    echo -e "${Green}Socat 安装并配置成功!${Font}"
    echo -e "${Blue}本地端口: ${port1}${Font}"
    echo -e "${Blue}远程端口: ${port2}${Font}"
    echo -e "${Blue}远程 IP: ${socatip}${Font}"
    echo -e "${Blue}本地服务器公网 IP: ${ip}${Font}"
    exit 0
}

install_socat(){
    echo -e "${Green}正在安装 Socat...${Font}"
    if [ "${OS}" == 'CentOS' ]; then
        yum install -y socat
    else
        apt-get update -y
        apt-get install -y socat
    fi
    if [ -s /usr/bin/socat ]; then
        echo -e "${Green}Socat 安装完成！${Font}"
    fi
}

status_socat(){
    if [ -s /usr/bin/socat ]; then
        echo -e "${Green}检测到 Socat 已存在，跳过安装步骤！${Font}"
        main_x
    else
        main_y
    fi
}

main_x(){
checkos
rootness
disable_selinux
disable_iptables
config_socat
start_socat
}

main_y(){
checkos
rootness
disable_selinux
disable_iptables
install_socat
config_socat
start_socat
}

status_socat
