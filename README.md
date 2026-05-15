## S-UI
基于 `SagerNet/Sing-Box` 构建的高级 Web 面板。

**提示：原 `alireza0/s-ui` 项目被 Github 官方封禁，本仓库是基于原版最后版本 `v1.4.1` 的完整备份，包含完整前端和后端源码。**

**本仓库仅修改了默认语言和时区为中文，其他都对标原版无改动。你可以直接使用本仓库的脚本，也可以自行 fork 编译。**

> **免责声明：** 本项目仅供个人学习与交流使用，请勿用于非法用途。

## 快速概览

| 功能 | 是否支持 |
| -------------------------------------- | :----------------: |
| 多协议 | :heavy_check_mark: |
| 多语言 | :heavy_check_mark: |
| 多客户端/入站 | :heavy_check_mark: |
| 高级流量路由界面 | :heavy_check_mark: |
| 客户端、流量与系统状态 | :heavy_check_mark: |
| 订阅链接（link/json/clash + info） | :heavy_check_mark: |
| 深色/浅色主题 | :heavy_check_mark: |
| API 接口 | :heavy_check_mark: |

## 支持平台

| 平台 | 架构 | 状态 |
|----------|--------------|---------|
| Linux | amd64, arm64, armv7, armv6, armv5, 386, s390x | 支持 |
| Windows | amd64, 386, arm64 | 支持 |
| macOS | amd64, arm64 | 实验性支持 |

## 默认安装信息

- 面板端口：2095
- 面板路径：/app/
- 订阅端口：2096
- 订阅路径：/sub/
- 用户名/密码：admin

## 安装或升级到最新版本

### Linux/macOS

```sh
bash <(curl -Ls https://raw.githubusercontent.com/chihiroecho-eng/s-ui/main/install.sh)
```

安装脚本会从 GitHub Releases 下载当前架构对应的资产，例如 `s-ui-linux-amd64.tar.gz`。发布新版本前，请先运行仓库的 `发布 S-UI` 工作流，确保 Release 中存在对应架构的安装包。

### 安装指定版本

```sh
bash <(curl -Ls https://raw.githubusercontent.com/chihiroecho-eng/s-ui/main/install.sh) v1.4.1
```

版本号可以带 `v`，也可以不带 `v`。

## 手动安装

### Linux/macOS

1. 根据系统和架构，从 [GitHub Releases](https://github.com/chihiroecho-eng/s-ui/releases/latest) 下载对应安装包。
2. 可选：获取最新管理脚本 [s-ui.sh](https://raw.githubusercontent.com/chihiroecho-eng/s-ui/main/s-ui.sh)。
3. 解压 `s-ui-linux-*.tar.gz`。
4. 将 `s-ui/s-ui.sh` 复制到 `/usr/bin/s-ui`，并执行 `chmod +x /usr/bin/s-ui`。
5. 将 `s-ui` 目录复制到 `/usr/local/s-ui`。
6. 将 `s-ui/s-ui.service` 复制到 `/etc/systemd/system/s-ui.service`。
7. 执行 `systemctl daemon-reload`。
8. 使用 `systemctl enable s-ui --now` 启用开机自启并启动 S-UI 服务。

### Windows

Windows 安装包需要在 Release 中单独发布。下载对应 ZIP 后，以管理员身份运行安装脚本或手动启动二进制文件。

## 卸载 S-UI

```sh
sudo -i
systemctl disable s-ui --now
rm -f /etc/systemd/system/s-ui.service
systemctl daemon-reload
rm -fr /usr/local/s-ui
rm -f /usr/bin/s-ui
```

## 使用 Docker 安装

<details>
   <summary>点击查看详情</summary>

### 安装 Docker

```shell
curl -fsSL https://get.docker.com | sh
```

### Docker Compose

```yaml
services:
  s-ui:
    image: ghcr.io/chihiroecho-eng/s-ui:latest
    container_name: s-ui
    hostname: "s-ui"
    network_mode: host
    volumes:
      - "./db:/app/db"
      - "./cert:/root/cert"
    tty: true
    restart: unless-stopped
```

```shell
docker compose up -d
```

### Docker CLI

```shell
mkdir s-ui && cd s-ui

docker run -itd \
    --network host \
    -v "$PWD/db/:/app/db/" \
    -v "$PWD/cert/:/root/cert/" \
    --name s-ui \
    --restart=unless-stopped \
    ghcr.io/chihiroecho-eng/s-ui:latest
```

### 自行构建镜像

普通本机构建默认构建 `linux/amd64`：

```shell
git clone https://github.com/chihiroecho-eng/s-ui
cd s-ui
docker build -t s-ui .
```

多架构构建建议使用 buildx：

```shell
docker buildx build --platform linux/amd64,linux/arm64 -t s-ui .
```

</details>

## 手动运行（贡献开发）

<details>
   <summary>点击查看详情</summary>

### 构建并运行完整项目

```shell
./runSUI.sh
```

### 前端

前端代码请查看 [frontend](frontend)。

### 后端

请先至少构建一次前端。

```shell
cd frontend
npm ci
npm run build

cd ..
rm -fr web/html/*
cp -R frontend/dist/. web/html/
go build -o sui main.go
./sui
```

</details>

## 环境变量

<details>
  <summary>点击查看详情</summary>

| 变量 | 类型 | 默认值 |
| -------------- | :--------------------------------------------: | :------------ |
| SUI_LOG_LEVEL | `"debug"` \| `"info"` \| `"warn"` \| `"error"` | `"info"` |
| SUI_DEBUG | `boolean` | `false` |
| SUI_BIN_FOLDER | `string` | `"bin"` |
| SUI_DB_FOLDER | `string` | `"db"` |
| SINGBOX_API | `string` | - |

</details>

## SSL 证书

Docker 部署时，证书目录建议挂载到容器内 `/root/cert`，以便与管理脚本默认生成路径保持一致。

### Certbot 示例

```bash
snap install core; snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

certbot certonly --standalone --register-unsafely-without-email --non-interactive --agree-tos -d <你的域名>
```

#### 鸣谢原作者：alireza0
