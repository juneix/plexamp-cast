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
      # 获取 Token: https://www.plex.tv/claim/ (有时效性)
      - PLEXAMP_CLAIM_TOKEN=claim-XXXXXXXXXX 
      # Plex 服务器中显示的播放器名称
      - PLEXAMP_PLAYER_NAME=Plexamp-Cast
      # Snapcast 客户端中显示的流名称
      - SNAPCAST_NAME=Plexamp-Cast
    volumes:
      # Plexamp 配置数据持久化（账户登录信息等）
      - ./config:/root/.local/share/Plexamp/Settings
      # Snapcast 配置数据持久化（分组、备注信息等）
      - ./config:/root/.local/share/Plexamp/Settings
      - ./data:/var/lib/snapserver
      # 如果想修改 Snapserver 配置，请先创建 snapserver.conf
      # - ./snapserver.conf:/etc/snapserver.conf
```
