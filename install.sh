#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
color='\033[0m'

shadowsocks_config='/var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json'

methods=(
    aes-256-gcm
    aes-192-gcm
    aes-128-gcm
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    camellia-128-cfb
    camellia-192-cfb
    camellia-256-cfb
    xchacha20-ietf-poly1305
    chacha20-ietf-poly1305
    chacha20-ietf
    chacha20
    salsa20
    rc4-md5
)

show_error() {
    echo -e "[${red}Error${color}] $1"
    exit 1
}

check_if_run_as_root() {
    [[ $EUID -ne 0 ]] && show_error "Please run as root"
}

is_ipv6() {
    local ipv6
    ipv6=$(wget -qO- -t1 -T2 ipv6.icanhazip.com)
    [ -z "${ipv6}" ] && return 1 || return 0
}

get_ip() {
    local IP
    IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v '^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\.' | head -n 1)
    [ -z "${IP}" ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    [ -z "${IP}" ] && IP=$(wget -qO- -t1 -T2 ipinfo.io/ip)
    [ -z "${IP}" ] && IP=$(curl ipinfo.io/ip)
    echo "${IP}"
}

print_result() {
    tmp=$(echo -n "${shadowsocks_method}:${shadowsocks_pwd}@$(get_ip):${shadowsocks_port}" | base64)
    # clear
    echo
    echo -e "Your server ip         : $(get_ip)"
    echo -e "Your server port       : ${shadowsocks_port}"
    echo -e "Your password          : ${shadowsocks_pwd}"
    echo -e "Your encryption method : ${shadowsocks_method}"
    echo -e "Your shadowsocks link  : ss://${tmp}"
}

config_shadowsocks_ip() {
    server_listen="\"0.0.0.0\""
    if is_ipv6; then
        server_listen="[\"[::0]\",\"0.0.0.0\"]"
    fi
}

config_shadowsocks_port() {
    while true; do
        dport=$(shuf -i 1024-65535 -n 1)
        echo -e "Please enter the port [1-65535]"
        read -p "(Default port: ${dport}):" shadowsocks_port
        [ -z "${shadowsocks_port}" ] && shadowsocks_port=${dport}
        expr "${shadowsocks_port}" + 1 &>/dev/null
        if [ $? -eq 0 ]; then
            if [ "${shadowsocks_port}" -ge 1 ] && [ "${shadowsocks_port}" -le 65535 ] && [ "${shadowsocks_port:0:1}" != 0 ]; then
                echo
                echo "port = ${shadowsocks_port}"
                echo
                break
            fi
        fi
        echo -e "[${red}Error${color}] Please enter a valid number [1-65535]"
    done
}

config_shadowsocks_method() {
    while true; do
        echo -e "Please select the method"

        for ((i = 1; i <= ${#methods[@]}; i++)); do
            hint="${methods[$i - 1]}"
            echo -e "${green}${i}${color}: ${hint}"
        done
        read -p "(Default method: ${methods[13]}):" pick
        [ -z "$pick" ] && pick=14
        expr ${pick} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${color}] Please enter a number"
            continue
        fi
        if [[ "$pick" -lt 1 || "$pick" -gt ${#methods[@]} ]]; then
            echo -e "[${red}Error${color}] Please enter a number between 1 and ${#methods[@]}"
            continue
        fi
        shadowsocks_method=${methods[$pick - 1]}

        echo
        echo "method = ${shadowsocks_method}"
        echo
        break
    done
}

config_shadowsocks_password() {
    echo "Please enter password"
    read -p '(Default password: pwd2022):' shadowsocks_pwd
    [ -z "${shadowsocks_pwd}" ] && shadowsocks_pwd='pwd2022'
    echo
    echo "password = ${shadowsocks_pwd}"
    echo
}

config_shadowsocks() {
    config_shadowsocks_ip
    config_shadowsocks_port
    config_shadowsocks_method
    config_shadowsocks_password
    if [ ! -d "$(dirname ${shadowsocks_config})" ]; then
        mkdir -p $(dirname ${shadowsocks_config})
    fi

    cat >${shadowsocks_config} <<-EOF
{
    "server":${server_listen},
    "server_port":${shadowsocks_port},
    "password":"${shadowsocks_pwd}",
    "timeout":300,
    "user":"nobody",
    "method":"${shadowsocks_method}",
    "fast_open":false,
    "mode":"tcp_and_udp"
}
EOF
}

download_shadowsocks() {
    # todo
    echo "assuming that I am downloading ss-server..."
    apt install snap
    snap install shadowsocks-libev --edge
}

run_shadowsocks() {
    # todo
    echo "assuming that I am running ss-server..."
    systemctl start snap.shadowsocks-libev.ss-server-daemon.service
    systemctl enable snap.shadowsocks-libev.ss-server-daemon.service
}

install_shadowsocks() {
    check_if_run_as_root
    config_shadowsocks
    download_shadowsocks
    run_shadowsocks
    print_result
}

install_shadowsocks
