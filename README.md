# Socatv4v6
Socat一键转发，支持IPv4和IPv6
```
wget https://raw.githubusercontent.com/wiznb/Socatv4v6/main/socatv4v6.sh && bash socatv4v6.sh
```
查看系统IPv6 socket是否支持 dual-stack（IPv6 + IPv4）
```
cat /proc/sys/net/ipv6/bindv6only
```
返回为0支持，返回为1不支持
编辑配置文件：
```
vi /etc/sysctl.conf
```
添加一行
```
net.ipv6.bindv6only = 0
```
使配置生效
```
sysctl -p
```
改自https://github.com/lzw981731/socat
