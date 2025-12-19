
# Plexamp-Cast 多房间播放

<img width="2642" height="1004" alt="Plexamp-Cast" src="https://github.com/user-attachments/assets/67bd0832-7077-40dd-9304-1cabc22441bd" />

## 1. 功能介绍
让你的 NAS、电视盒子（armbian）或任意 Linux 服务器变成 Plexamp 家庭音乐系统的中控，可实现多房间同步播放（类似 AirPlay2 和 Roon）。
- 基于 Plexamp Headless➕Snapcast  
~~借助 PlexAPI，可直接从 Snapcast 控制 Plexamp~~(调试中）
- 使用 Docker 一键部署，开箱即用
- 自动识别 x86-64 和 arm64 架构
- 暂不支持 arm32 设备
  - 玩客云推荐刷 Dietpi 系统，然后在 Dietpi-Software 应用商店里安装 Snapcast，接着打开 [Plex 官网](https://www.plex.tv/media-server-downloads/?cat=headless&plat=raspberry-pi#plex-plexamp)下载并安装 *Plexamp for Raspberry Pi* 即可（需要 Node.js 20 环境）

## 2. 使用说明（后续会出视频教程）
1️⃣ 你必须先拥有一个 Plex 服务器，Plexamp 是 Plex 推出的专业音乐播放器。
> 它们都是`免费`的，无需  Plex Pass 会员订阅！

2️⃣ 浏览器打开 `http://NAS-IP:32500` 初始化 Plexamp Headless，后续可直接通过其他 Plexamp 电脑/手机客户端远程控制。  
2️⃣ 作为多房间播放的设备（音箱），安装 Snapcast/Snap.Net 客户端，或者直接打开网页`http://NAS-IP:1780`即可。  
3️⃣ 推荐连接有线音箱，如果是蓝牙音箱，需手动调节延迟。  

## 3. docker-compose 配置文件

⚡️ 已配置毫秒镜像加速
```
services:
  plexamp-cast:
    image: ghcr.1ms.run/ghcr.io/juneix/plexamp-cast
    container_name: plexamp-cast
    network_mode: host
    restart: unless-stopped
    privileged: true
    environment:
      - TZ=Asia/Shanghai
      # 获取 Claim Token: https://www.plex.tv/claim/ (有效期约 4 分钟)
      - PLEXAMP_CLAIM_TOKEN=claim-xxxxx
      # Plexamp 和 Snapcast 显示的播放器名称
      - PLEX_PLAYER=Plexamp-Cast
      # Plex 局域网 IP
      - PLEX_HOST=10.1.1.x
      # 获取 X-Plex-Token: 浏览器登录 Plex -> 任意媒体 -> 查看 XML -> 链接末尾
      - PLEX_TOKEN=xxxxx
    volumes:
      # Plexamp 数据 (保留登录凭证)
      - ./config:/root/.local/share/Plexamp
      # Snapcast 数据 (保留分组、备注等)
      - ./data:/var/lib/snapserver
      # 自定义 Snapserver 配置（老司机专用）
      # - ./snapserver.conf:/etc/snapserver.conf
```
