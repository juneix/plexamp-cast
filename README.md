
# Plexamp-Cast  [[中文说明](https://github.com/juneix/plexamp-cast/blob/main/README-CN.md)]

**Turn your Raspberry Pi, Mini PC, or old TV box into a powerful Home Music Hub.**

<img width="2642" height="1004" alt="Plexamp-Cast" src="https://github.com/user-attachments/assets/67bd0832-7077-40dd-9304-1cabc22441bd" />

## 💡 Overview

This project is a Docker solution that seamlessly integrates **Plexamp (Headless)** and **Snapserver**. 

It is designed to run on **any Linux device** (x86_64 or arm64), making it perfect for:
* **Raspberry Pi** (Zero 2 W, 3B, 4, 5)
* **Mini PCs** (Intel NUC, Dell OptiPlex Micro, etc.)
* **Android TV Boxes** (running Armbian)

It plays music via Plexamp and acts as a sync source for your multi-room audio system via Snapcast.

### ⚠️ Note for armv7 Users

**armv7 is not supported** due to the high overhead of Docker on aging hardware.
Instead, I highly recommend using **DietPi OS** for a **native installation**. 
* You can install Snapcast via `dietpi-software` and set up Plexamp manually.
* While this requires manual configuration, the final user experience is **nearly identical** to this Docker solution, but with much better performance on older devices.

> **Fun Fact:** I personally use an armv7 device (specs are identical to the ODROID-C1) running DietPi. I picked it up on China's second-hand market (similar to eBay) for just **$3 USD**... no joke!


## 🔥 Features

* **Universal Compatibility:** Works on almost any device capable of running Docker.
* **All-in-One:** Runs Plexamp and Snapserver in a single, lightweight container.
* **Multi-Room Audio:** Broadcasts high-fidelity audio to any Snapcast client in your house.
* **Persistence:** Simple volume mapping for Plexamp login data and Snapserver configuration.

## 🧩 docker-compose
```
services:
  plexamp-cast:
    image: ghcr.io/juneix/plexamp-cast
    container_name: plexamp-cast
    network_mode: host
    restart: unless-stopped
    privileged: true
    environment:
      - TZ=Asia/Shanghai
      # Get claim token: https://www.plex.tv/claim/ (valid 4 mins)
      - PLEXAMP_CLAIM_TOKEN=claim-xxxxx
      # Player name for Plexamp & Snapcast
      - PLEX_PLAYER=Plexamp-Cast
      # Plex Server LAN IP
      - PLEX_HOST=10.1.1.x
      # Get X-Plex-Token: Plex Web -> View XML -> End of URL
      - PLEX_TOKEN=xxxxx
    volumes:
      # Plexamp data (persists login)
      - ./config:/root/.local/share/Plexamp
      # Snapcast data (persists groups/meta)
      - ./data:/var/lib/snapserver
      # Custom config (Advanced users)
      # - ./snapserver.conf:/etc/snapserver.conf
```
