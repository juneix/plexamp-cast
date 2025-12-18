让你的 NAS、电视盒子（armbian）或任意 Linux 服务器变成家庭音乐系统的中控，可实现多房间同步播放（类似 AirPlay2 和 Roon）。
- 基于 Plexamp Headless➕Snapcast
- 使用 Docker 一键部署，开箱即用
- 自动识别 x86-64 和 arm64 架构
- 暂不支持 arm32 设备
  - 玩客云推荐刷 Dietpi 系统，然后在 Dietpi-Software 应用商店里安装 Snapcast，接着打开 [Plex 官网](https://www.plex.tv/media-server-downloads/?cat=headless&plat=raspberry-pi#plex-plexamp)下载并安装 *Plexamp for Raspberry Pi* 即可（需要 Node.js 20 环境）

docker-compose 配置文件
```
services:
  plexamp-cast:
    image: ghcr.io/juneix/plexamp-cast:latest
    container_name: plexamp-cast
    network_mode: host
    restart: unless-stopped
    privileged: true
    environment:
      - TZ=Asia/Shanghai
      # --- 统一播放器名称 ---
      # Plexamp 和 Snapcast 显示的设备名称
      - PLEX_PLAYER=Plexamp-Cast
      # --- Plex 服务器认领 ---
      # 首次运行时用于自动认领服务器 (有效期4分钟)
      # 获取 Claim Token: https://www.plex.tv/claim/
      - PLEXAMP_CLAIM_TOKEN=claim-xxxxx
      # --- Plex 控制设置 ---
      # 直接用 Snapcast 控制 Plexamp 播放音乐
      # Plex 服务器内网 IP
      - PLEX_HOST=10.1.1.x
      # 获取 API Token: 浏览器登录 Plex -> 任意媒体 -> 查看 XML -> 链接末尾的 X-Plex-Token
      - PLEX_TOKEN=xxxxx
    volumes:
      # Plexamp 数据 (保留登录凭证)
      - ./config:/root/.local/share/Plexamp
      # Snapcast 数据 (保留分组、备注、音量)
      - ./data:/var/lib/snapserver
      # 自定义 Snapserver 配置（老司机专用）
      # - ./snapserver.conf:/etc/snapserver.conf
```
