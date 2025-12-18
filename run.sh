#!/bin/bash

# --- 环境变量 ---
export PULSE_SOCKET=/tmp/pulseaudio.socket
export PULSE_SERVER=unix:$PULSE_SOCKET

# --- 1. 清理工作 ---
echo "--- 正在清理临时文件 ---"
echo "--- Cleaning up temporary files ---"

rm -rf /var/run/pulse /run/pulse /root/.config/pulse $PULSE_SOCKET /tmp/snapfifo

PLEXAMP_DATA="/root/.local/share/Plexamp"
if [ -d "$PLEXAMP_DATA" ]; then
    echo "正在清理 Plexamp 缓存和日志以释放空间..."
    echo "Cleaning Plexamp Cache/Logs to save space..."
    rm -rf "$PLEXAMP_DATA/Cache"
    rm -rf "$PLEXAMP_DATA/Logs"
    rm -rf "$PLEXAMP_DATA/Code Cache"
    rm -rf "$PLEXAMP_DATA/GPUCache"
    echo "清理完成。登录凭证已保留。"
    echo "Done. Auth data preserved."
else
    echo "检测到首次运行（无现有数据）。"
    echo "First run detected (No existing Plexamp data)."
fi

# --- 2. 启动 PulseAudio ---
echo "--- 正在启动 PulseAudio (系统模式) ---"
echo "--- Starting PulseAudio (System Mode) ---"

pulseaudio --system -D \
    --disallow-exit \
    --disallow-module-loading=false \
    --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulseaudio.socket" \
    --log-target=stderr

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

pactl -s $PULSE_SERVER load-module module-pipe-sink file=/tmp/snapfifo sink_name=Snapcast-Plexamp format=s16le rate=44100
pactl -s $PULSE_SERVER set-default-sink Snapcast-Plexamp
pactl -s $PULSE_SERVER set-sink-volume Snapcast-Plexamp 100%

# --- 4. 配置 Snapserver ---
echo "--- 正在检查 Snapserver 配置 ---"
echo "--- Checking Snapserver config ---"

if [ ! -f /etc/snapserver.conf ]; then
    echo "未找到配置文件，正在生成默认配置..."
    echo "Config not found, generating default..."
    
    # a.处理播放器名称
    # 如果用户未设置，默认为 "Plexamp"
    PLAYER_NAME=${PLEX_PLAYER:-Plexamp}
    
    echo "当前播放器名称 (Plexamp & Snapcast): ${PLAYER_NAME}"
    echo "Current player name (Plexamp & Snapcast): ${PLAYER_NAME}"
    
    # b.构建基础音频源 (Pipe)
    SOURCE_STR="pipe:///tmp/snapfifo?name=${PLAYER_NAME}&sampleformat=44100:16:2&codec=flac"
    
    # c.检查并启用控制脚本
    if [ -n "$PLEX_HOST" ] && [ -n "$PLEX_TOKEN" ]; then
        echo "检测到 X-Plex-Token，正在启用双向控制..."
        echo "X-Plex-Token found, enabling control script..."
        
        # 必须使用绝对路径，确保 Snapserver 能找到脚本
        SCRIPT_PATH="/usr/local/bin/plex_bridge.py"
        
        # 拼接控制脚本所需参数：Token、IP、播放器名称等
        PARAMS="--token=${PLEX_TOKEN} --ip=${PLEX_HOST} --player=${PLAYER_NAME}"
        SOURCE_STR="${SOURCE_STR}&controlscript=${SCRIPT_PATH}&controlscriptparams=${PARAMS}"
    else
        echo "未检测到 X-Plex-Token，仅启用音频串流..."
        echo "X-Plex-Token not set, only enable audio streaming..."
    fi
    
    # d. 写入配置文件
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
source = ${SOURCE_STR}
EOF
else
    echo "发现自定义配置文件，跳过生成。"
    echo "Custom config found, skipping generation."
fi

# --- 5. 启动服务 ---
echo "--- 正在启动 Snapserver ---"
echo "--- Starting Snapserver ---"

snapserver -d -c /etc/snapserver.conf

echo "--- 正在启动 Plexamp Headless ---"
echo "--- Starting Plexamp Headless ---"
cd /plexamp
export PULSE_SERVER=unix:$PULSE_SOCKET

# 如果有 Claim Token，尝试传递给 Node 进程
if [ -n "$PLEXAMP_CLAIM_TOKEN" ]; then
    export PLEX_CLAIM=$PLEXAMP_CLAIM_TOKEN
fi

node js/index.js
