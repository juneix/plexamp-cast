#!/bin/bash

# --- 1. 环境准备 ---
echo "--- Starting Plexamp-Cast Container ---"

# 定义命名管道路径
PIPE_PATH="/tmp/snapfifo"

# 如果没有管道文件，则创建
if [ ! -p "$PIPE_PATH" ]; then
    echo "Creating named pipe at $PIPE_PATH"
    mkfifo "$PIPE_PATH"
    # 赋予读写权限，确保 node 和 snapserver 都能访问
    chmod 666 "$PIPE_PATH"
fi

# --- 2. 配置 ALSA (Plexamp 的输出端) ---
# 这段配置将欺骗 Plexamp，让它以为在向默认声卡播放，实际是写入 Pipe
echo "Configuring ALSA to redirect audio to pipe..."
cat > /etc/asound.conf <<EOF
pcm.!default {
    type file
    file "$PIPE_PATH"
    format "raw"
    slave {
        pcm null
    }
}
EOF

# --- 3. 配置 Snapserver (Snapcast 的输入端) ---
# 读取环境变量 SNAPCAST_NAME，如果未设置则默认为 "Plexamp"
STREAM_NAME=${SNAPCAST_NAME:-Plexamp}

echo "Configuring Snapserver source..."
# 生成最小化配置文件
# 格式: pipe://<path>?name=<name>&sampleformat=<rate:bits:channels>
# Plexamp 默认输出通常是 44100Hz, 16bit, 2ch
mkdir -p /etc/snapserver
cat > /etc/snapserver/snapserver.conf <<EOF
[stream]
source = pipe://${PIPE_PATH}?name=${STREAM_NAME}&sampleformat=44100:16:2

[http]
doc_root = /usr/share/snapserver/snapweb
EOF

# --- 4. 启动服务 ---

# A. 启动 Snapserver (后台运行)
echo "Starting Snapserver..."
snapserver &
SNAP_PID=$!

# 等待几秒确保 snapserver 启动
sleep 2

# B. 启动 Plexamp (前台运行，作为主进程)
echo "Starting Plexamp..."
# 确保在 /plexamp 目录下运行
cd /plexamp

# 检查是否需要声明 Token (初次运行)
if [ ! -z "$PLEXAMP_CLAIM_TOKEN" ]; then
    echo "Claim token found, attempting to claim..."
    # 注意：Plexamp 的 claim 逻辑通常在第一次运行也是自动的，
    # 只要环境变量存在。这里只是打印提示。
fi

# 启动 Node 进程
# 使用 exec 让 node 进程替代 shell 成为 PID 1 (或者作为前台主进程)
node js/index.js &
PLEX_PID=$!

# --- 5. 进程守护 ---
# 等待任一进程退出
wait -n $SNAP_PID $PLEX_PID

# 如果其中一个退出了，杀掉另一个并退出容器
echo "One of the processes exited."
kill $SNAP_PID $PLEX_PID 2>/dev/null
exit 1