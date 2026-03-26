#!/bin/bash

set -u

# --- 环境变量 ---
export PULSE_SOCKET=/tmp/pulseaudio.socket
export PULSE_SERVER=unix:$PULSE_SOCKET
export PULSE_LATENCY_MSEC=${PULSE_LATENCY_MSEC:-60}
LOG_LANG=${LOG_LANG:-zh}
SNAPSERVER_PID=""
PLEXAMP_PID=""
PULSE_SINK_NAME="Snapcast-Plexamp"

log() {
    local zh_msg="$1"
    local en_msg="$2"

    case "$LOG_LANG" in
        en)
            printf '%s\n' "$en_msg"
            ;;
        both)
            printf '%s | %s\n' "$zh_msg" "$en_msg"
            ;;
        *)
            printf '%s\n' "$zh_msg"
            ;;
    esac
}

cleanup() {
    local exit_code=$?

    if [ -n "$PLEXAMP_PID" ] && kill -0 "$PLEXAMP_PID" 2>/dev/null; then
        kill "$PLEXAMP_PID" 2>/dev/null || true
    fi

    if [ -n "$SNAPSERVER_PID" ] && kill -0 "$SNAPSERVER_PID" 2>/dev/null; then
        kill "$SNAPSERVER_PID" 2>/dev/null || true
    fi

    wait 2>/dev/null || true
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

# --- 1. 清理工作 ---
log "--- 正在清理临时文件 ---" "--- Cleaning up temporary files ---"

rm -rf /var/run/pulse /run/pulse /root/.config/pulse $PULSE_SOCKET /tmp/snapfifo

PLEXAMP_DATA="/root/.local/share/Plexamp"
if [ -d "$PLEXAMP_DATA" ]; then
    log "正在清理 Plexamp 缓存和日志以释放空间..." "Cleaning Plexamp cache and logs to save space..."
    rm -rf "$PLEXAMP_DATA/Cache"
    rm -rf "$PLEXAMP_DATA/Logs"
    rm -rf "$PLEXAMP_DATA/Code Cache"
    rm -rf "$PLEXAMP_DATA/GPUCache"
    log "清理完成，登录凭证已保留。" "Done. Auth data preserved."
else
    log "检测到首次运行（无现有数据）。" "First run detected (no existing Plexamp data)."
fi

# --- 2. 启动 PulseAudio ---
log "--- 正在启动 PulseAudio（系统模式） ---" "--- Starting PulseAudio (system mode) ---"

pulseaudio --system -D \
    --disallow-exit \
    --disallow-module-loading \
    --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulseaudio.socket" \
    --load="module-pipe-sink file=/tmp/snapfifo sink_name=${PULSE_SINK_NAME} format=s16le rate=44100" \
    --log-target=stderr \
    --log-level=warning

log "正在等待 PulseAudio 接口就绪..." "Waiting for PulseAudio socket..."

TIMEOUT=0
while [ ! -S "$PULSE_SOCKET" ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT+1))
    if [ $TIMEOUT -gt 10 ]; then
        log "错误：PulseAudio 启动失败。" "Error: PulseAudio start failed."
        exit 1
    fi
done

# --- 3. 配置音频路由 ---
log "--- 正在配置音频回环 ---" "--- Configuring audio loopback ---"

pactl -s "$PULSE_SERVER" set-default-sink "$PULSE_SINK_NAME"
pactl -s "$PULSE_SERVER" update-sink-proplist "$PULSE_SINK_NAME" device.description="$PULSE_SINK_NAME"
pactl -s "$PULSE_SERVER" set-sink-volume "$PULSE_SINK_NAME" 100%
log "PulseAudio 管道输出已就绪，输出设备: ${PULSE_SINK_NAME}" "PulseAudio pipe sink is ready, output device: ${PULSE_SINK_NAME}"

# --- 4. 配置 Snapserver ---
log "--- 正在检查 Snapserver 配置 ---" "--- Checking Snapserver config ---"

if [ ! -f /etc/snapserver.conf ]; then
    log "未找到配置文件，正在生成默认配置..." "Config not found, generating default..."
    
    # a.处理播放器名称
    # 如果用户未设置，默认为 "Plexamp"
    PLAYER_NAME=${PLEX_PLAYER:-Plexamp}
    
    log "当前播放器名称（Plexamp 与 Snapcast）: ${PLAYER_NAME}" "Current player name (Plexamp and Snapcast): ${PLAYER_NAME}"
    
    # b.构建基础音频源 (Pipe)
    SOURCE_STR="pipe:///tmp/snapfifo?name=${PLAYER_NAME}&sampleformat=44100:16:2&codec=flac"
    
    # c.检查并启用控制脚本
    if [ -n "$PLEX_HOST" ] && [ -n "$PLEX_TOKEN" ]; then
        log "检测到 X-Plex-Token，正在启用双向控制..." "X-Plex-Token found, enabling control script..."
        
        # 必须使用绝对路径，确保 Snapserver 能找到脚本
        SCRIPT_PATH="/usr/local/bin/plex_bridge.py"
        
        # 拼接控制脚本所需参数：Token、IP、播放器名称等
        PARAMS="--token=${PLEX_TOKEN} --ip=${PLEX_HOST} --player=${PLAYER_NAME}"
        SOURCE_STR="${SOURCE_STR}&controlscript=${SCRIPT_PATH}&controlscriptparams=${PARAMS}"
    else
        log "未检测到 X-Plex-Token，仅启用音频串流..." "X-Plex-Token not set, only enabling audio streaming..."
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
    log "发现自定义配置文件，跳过生成。" "Custom config found, skipping generation."
fi

# --- 5. 启动服务 ---
log "--- 正在启动 Snapserver ---" "--- Starting Snapserver ---"

snapserver -c /etc/snapserver.conf &
SNAPSERVER_PID=$!
log "Snapserver 已启动，PID: ${SNAPSERVER_PID}" "Snapserver started, pid: ${SNAPSERVER_PID}"

log "--- 正在启动 Plexamp Headless ---" "--- Starting Plexamp Headless ---"
cd /plexamp
export PULSE_SERVER=unix:$PULSE_SOCKET

# 如果有 Claim Token，尝试传递给 Node 进程
if [ -n "$PLEXAMP_CLAIM_TOKEN" ]; then
    export PLEX_CLAIM=$PLEXAMP_CLAIM_TOKEN
fi

node js/index.js &
PLEXAMP_PID=$!
log "Plexamp Headless 已启动，PID: ${PLEXAMP_PID}" "Plexamp Headless started, pid: ${PLEXAMP_PID}"

wait -n "$SNAPSERVER_PID" "$PLEXAMP_PID"
EXITED_PID=$?
log "检测到服务退出，容器即将停止。" "A managed service exited, the container will stop."
exit "$EXITED_PID"
