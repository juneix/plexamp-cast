FROM node:20-bookworm-slim

# --- 版本定义 ---
ENV PLEXAMP_VERSION="4.12.4"
ENV SNAPCAST_VERSION="0.34.0"
ENV SNAPWEB_VERSION="0.9.3"
ENV DEBIAN_FRONTEND=noninteractive

# --- 合并执行：安装依赖 -> 下载配置 -> 清理垃圾 ---
RUN set -ex && \
    # 1. 更新源并安装基础依赖
    apt-get update && \
    apt-get install -y --no-install-recommends \
        pulseaudio \
        pulseaudio-utils \
        ca-certificates \
        libasound2 \
        wget \
        bzip2 \
    && \
    # 2. 下载并安装 Snapserver (服务端)
    # 逻辑：dpkg 输出 amd64 或 arm64，直接对应 Snapcast release 的命名
    ARCH=$(dpkg --print-architecture) && \
    echo "Building for architecture: $ARCH" && \
    SNAP_DEB="snapserver_${SNAPCAST_VERSION}-1_${ARCH}_bookworm.deb" && \
    SNAP_URL="https://github.com/snapcast/snapcast/releases/download/v${SNAPCAST_VERSION}/${SNAP_DEB}" && \
    wget -O snapserver.deb "$SNAP_URL" && \
    apt-get install -y --no-install-recommends ./snapserver.deb && \
    rm snapserver.deb && \
    # 3. 下载并安装 Snapweb (Web 界面)
    WEB_DEB="snapweb_${SNAPWEB_VERSION}-1_all.deb" && \
    WEB_URL="https://github.com/snapcast/snapweb/releases/download/v${SNAPWEB_VERSION}/${WEB_DEB}" && \
    wget -O snapweb.deb "$WEB_URL" && \
    apt-get install -y --no-install-recommends ./snapweb.deb && \
    rm snapweb.deb && \
    # 4. 下载并解压 Plexamp Headless
    wget -O plexamp.tar.bz2 "https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v${PLEXAMP_VERSION}.tar.bz2" && \
    tar -xjf plexamp.tar.bz2 -C / && \
    rm plexamp.tar.bz2 && \
    # 5. 修改 PulseAudio 配置 (允许 Root 运行)
    sed -i 's/; autospawn = yes/autospawn = no/g' /etc/pulse/client.conf && \
    sed -i 's/; allow-autospawn-for-root = no/allow-autospawn-for-root = yes/g' /etc/pulse/client.conf && \
    # 6. 深度清理
    apt-get purge -y --auto-remove wget bzip2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /plexamp
COPY run.sh /run.sh
RUN chmod +x /run.sh

# 端口说明
# 1704: Snapcast Control (TCP)
# 1705: Snapcast Stream (TCP)
# 1780: Snapweb (HTTP)
# 32500: Plexamp Interface
EXPOSE 1704 1705 1780 32500

ENTRYPOINT ["/run.sh"]
