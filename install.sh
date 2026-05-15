#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}致命错误：${plain}请使用 root 权限运行此脚本" && exit 1

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "检测系统失败，请联系作者！" >&2
    exit 1
fi

echo "当前系统发行版为：$release"

arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${red}不支持的 CPU 架构！${plain}" && exit 1 ;;
    esac
}

echo "架构：$(arch)"

install_base() {
    case "${release}" in
    centos | almalinux | rocky | oracle)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    arch | manjaro | parch)
        pacman -Syu --noconfirm wget curl tar tzdata
        ;;
    opensuse-tumbleweed)
        zypper refresh && zypper -q install -y wget curl tar timezone
        ;;
    *)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    esac
}

config_after_install() {
    echo -e "${yellow}正在迁移... ${plain}"
    /usr/local/s-ui/sui migrate

    echo -e "${yellow}安装/更新完成！出于安全考虑，建议修改面板设置 ${plain}"
    read -p "是否继续修改设置 [y/n]？" config_confirm
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        echo -e "请输入${yellow}面板端口${plain}（留空则使用现有/默认值）："
        read config_port
        echo -e "请输入${yellow}面板路径${plain}（留空则使用现有/默认值）："
        read config_path
        echo -e "请输入${yellow}订阅端口${plain}（留空则使用现有/默认值）："
        read config_subPort
        echo -e "请输入${yellow}订阅路径${plain}（留空则使用现有/默认值）："
        read config_subPath

        echo -e "${yellow}正在初始化，请稍候...${plain}"
        params=""
        [ -z "$config_port" ] || params="$params -port $config_port"
        [ -z "$config_path" ] || params="$params -path $config_path"
        [ -z "$config_subPort" ] || params="$params -subPort $config_subPort"
        [ -z "$config_subPath" ] || params="$params -subPath $config_subPath"
        /usr/local/s-ui/sui setting ${params}

        read -p "是否修改管理员账号密码 [y/n]？" admin_confirm
        if [[ "${admin_confirm}" == "y" || "${admin_confirm}" == "Y" ]]; then
            read -p "请设置用户名：" config_account
            read -p "请设置密码：" config_password
            echo -e "${yellow}正在初始化，请稍候...${plain}"
            /usr/local/s-ui/sui admin -username "${config_account}" -password "${config_password}"
        else
            echo -e "${yellow}当前管理员账号密码：${plain}"
            /usr/local/s-ui/sui admin -show
        fi
    else
        echo -e "${red}已取消修改设置...${plain}"
        if [[ ! -f "/usr/local/s-ui/db/s-ui.db" ]]; then
            local usernameTemp
            local passwordTemp
            usernameTemp=$(head -c 6 /dev/urandom | base64)
            passwordTemp=$(head -c 6 /dev/urandom | base64)
            echo -e "这是全新安装，出于安全考虑将生成随机登录信息："
            echo -e "###############################################"
            echo -e "${green}用户名：${usernameTemp}${plain}"
            echo -e "${green}密码：${passwordTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}如果忘记登录信息，可以输入 ${green}s-ui${red} 打开配置菜单${plain}"
            /usr/local/s-ui/sui admin -username "${usernameTemp}" -password "${passwordTemp}"
        else
            echo -e "${red}这是升级安装，将保留旧设置；如果忘记登录信息，可以输入 ${green}s-ui${red} 打开配置菜单${plain}"
        fi
    fi
}

prepare_services() {
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        echo -e "${yellow}检测到旧版 sing-box systemd 服务，正在停止... ${plain}"
        systemctl stop sing-box || true
        systemctl disable sing-box || true
        rm -f /etc/systemd/system/sing-box.service
        rm -f /usr/local/s-ui/bin/sing-box /usr/local/s-ui/bin/runSingbox.sh /usr/local/s-ui/bin/signal
    fi

    if [[ -e "/usr/local/s-ui/bin" ]]; then
        echo -e "###############################################################"
        echo -e "${green}/usr/local/s-ui/bin${red} 目录已存在！"
        echo -e "请检查其中内容，并在迁移后手动删除 ${plain}"
        echo -e "###############################################################"
    fi

    systemctl daemon-reload
}

download_release() {
    local version="$1"
    local platform="$(arch)"
    local asset="s-ui-linux-${platform}.tar.gz"
    local url

    if [[ -z "$version" ]]; then
        url="https://github.com/chihiroecho-eng/s-ui/releases/latest/download/${asset}"
        echo -e "开始安装 s-ui 最新版本（${asset}）..."
    else
        [[ "$version" != v* ]] && version="v${version}"
        url="https://github.com/chihiroecho-eng/s-ui/releases/download/${version}/${asset}"
        echo -e "开始安装 s-ui ${version}（${asset}）..."
    fi

    wget -O "/tmp/${asset}" --no-check-certificate "$url"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载 ${asset} 失败，请确认 Release 已发布且包含该架构资产：${url}${plain}"
        exit 1
    fi

    if ! tar -tzf "/tmp/${asset}" >/dev/null 2>&1; then
        echo -e "${red}下载的 ${asset} 不是有效的 tar.gz 文件，请检查 Release 资产是否正确。${plain}"
        rm -f "/tmp/${asset}"
        exit 1
    fi

    echo "/tmp/${asset}"
}

install_s_ui() {
    cd /tmp/ || exit 1

    local package_path
    package_path=$(download_release "$1")

    if [[ -e /usr/local/s-ui/ ]]; then
        systemctl stop s-ui || true
    fi

    tar zxvf "$package_path"
    rm -f "$package_path"

    if [[ ! -x s-ui/sui ]]; then
        echo -e "${red}安装包缺少可执行文件 s-ui/sui。${plain}"
        rm -rf s-ui
        exit 1
    fi

    chmod +x s-ui/sui s-ui/s-ui.sh
    cp s-ui/s-ui.sh /usr/bin/s-ui
    chmod +x /usr/bin/s-ui
    cp -rf s-ui /usr/local/

    if [[ -f s-ui/s-ui.service ]]; then
        cp -f s-ui/s-ui.service /etc/systemd/system/s-ui.service
    else
        echo -e "${red}安装包缺少 s-ui.service。${plain}"
        rm -rf s-ui
        exit 1
    fi

    rm -rf s-ui

    config_after_install
    prepare_services

    systemctl enable s-ui --now

    echo -e "${green}s-ui 安装完成，现已启动并运行...${plain}"
    echo -e "你可以通过以下 URL 访问面板：${green}"
    /usr/local/s-ui/sui uri
    echo -e "${plain}"
    s-ui help
}

echo -e "${green}正在执行...${plain}"
install_base
install_s_ui "$1"
