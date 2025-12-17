
让电视盒子（armbian）变成家庭音乐系统的中控，基于 plexamp➕snapcast。

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
      # Plexamp 的数据配置持久化
      - ./plexamp-data:/root/.local/share/Plexamp
      # 如果你想自定义 snapserver 配置，也可以挂载，但通常 run.sh 自动生成的够用了
      # - ./snapserver.conf:/etc/snapserver/snapserver.conf
```
