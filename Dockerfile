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
    # 2. 安装 Snapserver (自动检测架构)
    ARCH=$(dpkg --print-architecture) && \
    SNAP_DEB="snapserver_${SNAPCAST_VERSION}-1_${ARCH}_bookworm.deb" && \
    SNAP_URL="https://github.com/snapcast/snapcast/releases/download/v${SNAPCAST_VERSION}/${SNAP_DEB}" && \
    wget -O snapserver.deb "$SNAP_URL" && \
    apt-get install -y --no-install-recommends ./snapserver.deb && \
    rm snapserver.deb && \
    rm -f /etc/snapserver.conf && \
    # 3. 安装 Snapweb
    WEB_DEB="snapweb_${SNAPWEB_VERSION}-1_all.deb" && \
    WEB_URL="https://github.com/snapcast/snapweb/releases/download/v${SNAPWEB_VERSION}/${WEB_DEB}" && \
    wget -O snapweb.deb "$WEB_URL" && \
    apt-get install -y --no-install-recommends ./snapweb.deb && \
    rm snapweb.deb && \
    # 4. 安装 Plexamp
    wget -O plexamp.tar.bz2 "https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v${PLEXAMP_VERSION}.tar.bz2" && \
    tar -xjf plexamp.tar.bz2 -C / && \
    rm plexamp.tar.bz2 && \
    # 5. 安装 PlexAPI (最小化安装)
    pip3 install plexapi --no-cache-dir --break-system-packages && \
    # 6. 下载 Plex Bridge 脚本
    wget -O /usr/local/bin/plex_bridge.py "https://raw.githubusercontent.com/snapcast/snapcast/develop/server/etc/plug-ins/plex_bridge.py" && \
    chmod +x /usr/local/bin/plex_bridge.py && \
    # 7. 配置 PulseAudio
    sed -i 's/; autospawn = yes/autospawn = no/g' /etc/pulse/client.conf && \
    sed -i 's/; allow-autospawn-for-root = no/allow-autospawn-for-root = yes/g' /etc/pulse/client.conf && \
    # 8. 清理工作
    apt-get purge -y --auto-remove wget bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /plexamp
# 复制启动脚本
COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 1704 1705 1780 32500

ENTRYPOINT ["/run.sh"]
