
# Plexamp-Cast  [[中文说明](https://github.com/juneix/plexamp-cast/blob/main/README-CN.md)]

**Turn your Raspberry Pi, Mini PC, or old TV box into a powerful Home Music Hub.**

<img width="2642" height="1004" alt="Plexamp-Cast" src="https://github.com/user-attachments/assets/67bd0832-7077-40dd-9304-1cabc22441bd" />

## Overview

This project is a Docker solution that seamlessly integrates **Plexamp (Headless)** and **Snapserver**. 

It is designed to run on **any Linux device** (x86_64 or ARM64/armv7), making it perfect for:
* **Raspberry Pi** (Zero 2 W, 3B, 4, 5)
* **Mini PCs** (Intel NUC, Dell OptiPlex Micro, etc.)
* **Repurposed Android TV Boxes** (running Armbian)

It plays music via Plexamp and acts as a sync source for your multi-room audio system via Snapcast.

## Features

* **Universal Compatibility:** Works on almost any device capable of running Docker.
* **All-in-One:** Runs Plexamp and Snapserver in a single, lightweight container.
* **Multi-Room Audio:** Broadcasts high-fidelity audio to any Snapcast client in your house.
* **Persistence:** Simple volume mapping for Plexamp login data and Snapserver configuration.

## docker-compose
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
