# Plexamp Cast [[中文说明](https://github.com/juneix/plexamp-cast/blob/main/README-CN.md)]

**Turn your Raspberry Pi, Mini PC, or TV Box into a powerful Home Music Hub.**

<img width="100%" alt="Plexamp-Cast" src="https://github.com/user-attachments/assets/67bd0832-7077-40dd-9304-1cabc22441bd" />

## 💡 Overview

This project provides a Docker solution to seamlessly integrate **Plexamp (Headless)** and **Snapserver**.

It transforms your device into a multi-room audio control center—similar to **AirPlay 2** or **Roon**—allowing you to play high-fidelity music via Plexamp and sync it across multiple rooms using Snapcast.

## 💻 Hardware Compatibility

### ✅ Supported Devices
This image is designed for **64-bit Linux systems** (`x86_64` and `arm64`). It works perfectly on:
* **Raspberry Pi:** Zero 2 W, 3B, 3B+, 4, 5.
* **Mini PCs:** Intel NUC, Dell OptiPlex Micro, Lenovo Tiny, etc.
* **TV Boxes:** Devices running **Armbian** (64-bit).

### ❌ Not Supported (armv7)
**armv7 is not supported** due to the high overhead of Docker on aging hardware.

> **Recommendation for armv7 Users:**
> I highly recommend using **DietPi OS** for a **native installation**.
> * You can install Snapcast via `dietpi-software` and set up Plexamp manually.
> * While this requires manual configuration, the final user experience is **nearly identical** to this Docker solution, but with much better performance.
>
> **Fun Fact:** I personally use an armv7 device (specs are identical to the ODROID-C1) running DietPi. I picked it up on China's second-hand market (similar to eBay) for just **$3 USD**... no joke!

## 🔥 Features

* **All-in-One:** One-click Docker deployment. Auto-detects architecture.
* **Multi-Room Sync:** Broadcast audio to any Snapcast client with perfect synchronization.
* **No Subscription Needed:** Plexamp Headless is free to use (**No Plex Pass required**).
* **Smart Control (Beta):** Integrated **PlexAPI** allows you to control Plexamp playback directly from Snapcast (currently in debugging).
* **Web Player:** Includes the Snapweb interface for browser-based playback.

## ⚙️ Usage

*(Video tutorial coming to YouTube soon)*

### 1. Prerequisites
You must have a **Plex Media Server** running (the free version works fine).

### 2. Deployment
Use the `docker-compose.yml` provided below to start the container.

### 3. Initialization
Once the container is running, open your browser and visit:
`http://<YOUR-DEVICE-IP>:32500`
Follow the on-screen instructions to sign in and link Plexamp to your server.
* *After setup, you can control it remotely via any Plexamp app (Phone/Desktop).*

### 4. Listening (Snapcast Clients)
You can listen to the audio on other devices by:
* Installing the **Snapcast** app (Android) or **Snap.Net** (Windows).
* Or simply visiting the Web Player at: `http://<YOUR-DEVICE-IP>:1780`

> **Tip:** Wired speakers are highly recommended. If you use Bluetooth speakers, you may need to manually adjust latency in the Snapcast app.

## 🧩 Docker Compose

```yaml
services:
  plexamp-cast:
    image: ghcr.io/juneix/plexamp-cast:latest
    container_name: plexamp-cast
    network_mode: host
    restart: unless-stopped
    privileged: true
    environment:
      - TZ=Asia/Shanghai
      # Get claim token: [https://www.plex.tv/claim/](https://www.plex.tv/claim/) (valid 4 mins)
      - PLEXAMP_CLAIM_TOKEN=claim-xxxxx
      # Player name for Plexamp & Snapcast
      - PLEX_PLAYER=Plexamp-Cast
      # Plex Server LAN IP (Required for PlexAPI control)
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
