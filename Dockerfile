# 使用 node:20-slim (基于 Debian 12 Bookworm)
FROM node:20.19.6-slim

# 定义构建参数，方便后续升级
ARG PLEXAMP_VERSION=4.12.4
ARG TARGETARCH

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PLEXAMP_VERSION=$PLEXAMP_VERSION

# 1. 安装基础依赖和音频工具
# jq: 用于解析 GitHub API
# alsa-utils/libasound2: 提供音频底层支持
# atomicparsley/ffmpeg: Plexamp 可能需要的转码或元数据工具
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    jq \
    alsa-utils \
    libasound2 \
    libasound2-plugins \
    bzip2 \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# 2. 自动下载并安装最新版 Snapserver
# 逻辑：查询 GitHub API -> 获取对应架构的 .deb 下载链接 -> 下载 -> 安装
RUN echo "Building for architecture: $TARGETARCH" && \
    if [ "$TARGETARCH" = "amd64" ]; then SNAP_ARCH="amd64"; else SNAP_ARCH="arm64"; fi && \
    LATEST_URL=$(curl -s https://api.github.com/repos/badaix/snapcast/releases/latest | \
    jq -r --arg arch "$SNAP_ARCH" '.assets[] | select(.name | contains($arch)) | select(.name | endswith(".deb")) | .browser_download_url' | head -n 1) && \
    echo "Downloading Snapserver from: $LATEST_URL" && \
    wget -O snapserver.deb "$LATEST_URL" && \
    dpkg -i snapserver.deb || apt-get install -f -y && \
    rm snapserver.deb

# 3. 安装 Plexamp Headless
# 注意：Plexamp Headless 的包通常包含 x64 和 arm64 的二进制文件，或者主要是 JS 代码
WORKDIR /plexamp
RUN wget -O plexamp.tar.bz2 "https://plexamp.plex.tv/headless/Plexamp-Linux-headless-v${PLEXAMP_VERSION}.tar.bz2" && \
    tar -xjf plexamp.tar.bz2 --strip-components=1 && \
    rm plexamp.tar.bz2

# 创建数据目录
RUN mkdir -p /root/.local/share/Plexamp

# 复制启动脚本
COPY run.sh /run.sh
RUN chmod +x /run.sh

# 暴露 Snapcast 端口 (虽然 Host 模式下不需要 EXPOSE，但为了文档化)
EXPOSE 1704 1705 1780 32500

ENTRYPOINT ["/run.sh"]