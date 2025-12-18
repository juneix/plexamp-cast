#!/bin/bash

# --- 环境变量 ---
export PULSE_SOCKET=/tmp/pulseaudio.socket
export PULSE_SERVER=unix:$PULSE_SOCKET

# --- 1. 清理工作 (关键) ---
echo "--- 正在清理临时文件 ---"
echo "--- Cleaning up temporary files ---"

# 清理系统级残留 (防止重启时 Socket 被占用导致 PA 启动失败)
rm -rf /var/run/pulse /run/pulse /root/.config/pulse $PULSE_SOCKET /tmp/snapfifo

# 智能清理 Plexamp 缓存 (保留登录凭证)
PLEXAMP_DATA="/root/.local/share/Plexamp"
if [ -d "$PLEXAMP_DATA" ]; then
    echo "正在清理 Plexamp 缓存和日志以释放空间..."
    echo "Cleaning Plexamp Cache/Logs to save space..."
    
    # 仅删除临时数据
    rm -rf "$PLEXAMP_DATA/Cache"
    rm -rf "$PLEXAMP_DATA/Logs"
    rm -rf "$PLEXAMP_DATA/Code Cache"
    rm -rf "$PLEXAMP_DATA/GPUCache"
    
    # 注意：严禁删除 server.json (Token) 和 config.json (设置)
    echo "清理完成。登录凭证已保留。"
    echo "Done. Auth data preserved."
else
    echo "检测到首次运行（无现有数据）。"
    echo "First run detected (No existing Plexamp data)."
fi

# --- 2. 启动 PulseAudio ---
echo "--- 正在启动 PulseAudio (系统模式) ---"
echo "--- Starting PulseAudio (System Mode) ---"

# --system: 允许 Root 运行
# --disallow-exit: 守护进程模式，禁止自动退出
# module-native-protocol-unix: 暴露 Socket 供 Plexamp 连接
pulseaudio --system -D \
    --disallow-exit \
    --disallow-module-loading=false \
    --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulseaudio.socket" \
    --log-target=stderr

# 阻塞等待 Socket 就绪
echo "正在等待 PulseAudio 接口就绪..."
echo "Waiting for PulseAudio socket..."

TIMEOUT=0
while [ ! -S "$PULSE_SOCKET" ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT+1))
    if [ $TIMEOUT -gt 10 ]; then
        echo "错误：PulseAudio 启动失败。"
        echo "Error: PulseAudio start failed."
        exit 1
    fi
done

# --- 3. 配置音频路由 ---
echo "--- 正在配置音频回环 ---"
echo "--- Configuring Audio Loopback ---"

# 加载管道 Sink：将音频流写入 /tmp/snapfifo
pactl -s $PULSE_SERVER load-module module-pipe-sink file=/tmp/snapfifo sink_name=Snapcast-Plexamp format=s16le rate=44100
# 设置为默认输出，并强制最大音量
pactl -s $PULSE_SERVER set-default-sink Snapcast-Plexamp
pactl -s $PULSE_SERVER set-sink-volume Snapcast-Plexamp 100%

# --- 4. 配置 Snapserver ---
echo "--- 正在检查 Snapserver 配置 ---"
echo "--- Checking Snapserver config ---"

# 逻辑：如果用户挂载了 /etc/snapserver.conf，则不覆盖
if [ ! -f /etc/snapserver.conf ]; then
    echo "未找到配置文件，正在生成默认配置..."
    echo "Config not found, generating default..."
    
    # 使用 Shell 参数扩展设置默认流名称
    STREAM_NAME=${SNAPCAST_NAME:-Plexamp-Cast}
    
    mkdir -p /etc/snapserver
    cat > /etc/snapserver.conf <<EOF
[server]
datadir = /var/lib/snapserver
user = root
[http]
enabled = true
doc_root = /usr/share/snapweb
[tcp]
enabled = true
[stream]
# 这里的 source 必须与上面的 module-pipe-sink file 路径一致
source = pipe:///tmp/snapfifo?name=${STREAM_NAME}&sampleformat=44100:16:2
EOF
else
    echo "发现自定义配置文件，跳过生成。"
    echo "Custom config found, skipping generation."
fi

# --- 5. 启动服务 ---
echo "--- 正在启动 Snapserver ---"
echo "--- Starting Snapserver ---"
# -d: 后台运行 Snapserver
snapserver -d -c /etc/snapserver.conf

echo "--- 正在启动 Plexamp Headless ---"
echo "--- Starting Plexamp Headless ---"
cd /plexamp
export PULSE_SERVER=unix:$PULSE_SOCKET
# 前台运行 Plexamp，作为容器主进程
node js/index.js
