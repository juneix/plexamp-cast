FROM node:20-bookworm-slim

# --- 版本定义 ---
ENV PLEXAMP_VERSION="v4.12.4"
ENV SNAPCAST_VERSION="0.34.0"
ENV DEBIAN_FRONTEND=noninteractive

# --- 合并执行：安装依赖 -> 下载配置 -> 清理垃圾 ---
RUN set -ex && \
    # 1. 更新源
    apt-get update && \
    # 2. 安装运行时必须的包
    # pulseaudio/utils: 音频服务
    # ca-certificates: HTTPS请求必须 (Plexamp登录用)
    # libasound2: 音频底层库
    apt-get install -y --no-install-recommends \
        pulseaudio \
        pulseaudio-utils \
        ca-certificates \
        libasound2 \
        # 安装临时构建工具 (稍后会卸载)
        wget \
        bzip2 \
    && \
    # 3. 自动检测架构并下载 Snapserver
    ARCH=$(dpkg --print-architecture) && \
    echo "Building for architecture: $ARCH" && \
    DEB_NAME="snapserver_${SNAPCAST_VERSION}-1_${ARCH}_bookworm.deb" && \
    DOWNLOAD_URL="https://github.com/badaix/snapcast/releases/download/v${SNAPCAST_VERSION}/${DEB_NAME}" && \
    wget -O snapserver.deb "$DOWNLOAD_URL" && \
    # 使用 apt install ./xxx.deb 自动处理依赖，比 dpkg 更智能
    apt-get install -y --no-install-recommends ./snapserver.deb && \
    rm snapserver.deb && \
    # 4. 下载并解压 Plexamp Headless
    wget -O plexamp.tar.bz2 "https://plexamp.plex.tv/headless/Plexamp-Linux-headless-${PLEXAMP_VERSION}.tar.bz2" && \
    tar -xjf plexamp.tar.bz2 -C / && \
    rm plexamp.tar.bz2 && \
    mkdir -p /root/.local/share/Plexamp && \
    # 5. 修改 PulseAudio 配置 (允许 Root 运行)
    sed -i 's/; autospawn = yes/autospawn = no/g' /etc/pulse/client.conf && \
    sed -i 's/; allow-autospawn-for-root = no/allow-autospawn-for-root = yes/g' /etc/pulse/client.conf && \
    # 6. 深度清理 (关键步骤)
    # 卸载 wget 和 bzip2，同时自动移除不再需要的依赖
    apt-get purge -y --auto-remove wget bzip2 && \
    # 清理 apt 缓存
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 设置工作目录
WORKDIR /plexamp
COPY run.sh /run.sh
RUN chmod +x /run.sh

# 端口暴露
EXPOSE 1704 1705 1780 32500

ENTRYPOINT ["/run.sh"]
