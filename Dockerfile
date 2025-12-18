FROM node:20-bookworm-slim

# --- 版本定义 ---
ENV PLEXAMP_VERSION="4.12.4"
ENV SNAPCAST_VERSION="0.34.0"
ENV SNAPWEB_VERSION="0.9.3"
ENV DEBIAN_FRONTEND=noninteractive

# --- 合并执行 ---
RUN set -ex && \
    apt-get update && \
    # 1. 安装基础依赖 + Python 环境
    apt-get install -y --no-install-recommends \
        pulseaudio \
        pulseaudio-utils \
        ca-certificates \
        libasound2 \
        wget \
        bzip2 \
        python3 \
        python3-pip \
    && \
    # 2. 安装 PlexAPI (最小化安装)
    # --break-system-packages 允许在非 venv 环境安装，容器内为了省空间这是推荐做法
    pip3 install plexapi --no-cache-dir --break-system-packages && \
    # 3. 安装 Snapserver
    ARCH=$(dpkg --print-architecture) && \
    SNAP_DEB="snapserver_${SNAPCAST_VERSION}-1_${ARCH}_bookworm.deb" && \
    SNAP_URL="https://github.com/snapcast/snapcast/releases/download/v${SNAPCAST_VERSION}/${SNAP_DEB}" && \
    wget -O snapserver.deb "$SNAP_URL" && \
    apt-get install -y --no-install-recommends ./snapserver.deb && \
    rm snapserver.deb && \
    rm -f /etc/snapserver.conf && \
    # 4. 安装 Snapweb
    WEB_DEB="snapweb_${SNAPWEB_VERSION}-1_all.deb" && \
    WEB_URL="https://github.com/snapcast/snapweb/releases/download/v${SNAPWEB_VERSION}/${WEB_DEB}" && \
    wget -O snapweb.deb "$WEB_URL" && \
    apt-get install -y --no-install-recommends ./snapweb.deb && \
    rm snapweb.deb && \
    # 5. 安装 Plexamp
    wget -O plexamp.tar.bz2 "https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v${PLEXAMP_VERSION}.tar.bz2" && \
    tar -xjf plexamp.tar.bz2 -C / && \
    rm plexamp.tar.bz2 && \
    # 6. 配置 PulseAudio
    sed -i 's/; autospawn = yes/autospawn = no/g' /etc/pulse/client.conf && \
    sed -i 's/; allow-autospawn-for-root = no/allow-autospawn-for-root = yes/g' /etc/pulse/client.conf && \
    # 7. 清理工作
    apt-get purge -y --auto-remove wget bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /plexamp
# 复制启动脚本和控制脚本
COPY run.sh /run.sh
COPY plex_bridge.py /usr/local/bin/plex_bridge.py
RUN chmod +x /run.sh /usr/local/bin/plex_bridge.py

EXPOSE 1704 1705 1780 32500

ENTRYPOINT ["/run.sh"]
