#!/bin/bash

export PULSE_SOCKET=/tmp/pulseaudio.socket
export PULSE_SERVER=unix:$PULSE_SOCKET

# 清理残留
rm -rf /var/run/pulse /run/pulse /root/.config/pulse $PULSE_SOCKET

echo "--- Starting PulseAudio (System Mode as Root) ---"
pulseaudio --system -D \
    --disallow-exit \
    --disallow-module-loading=false \
    --load="module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulseaudio.socket" \
    --log-target=stderr

echo "Waiting for PulseAudio socket..."
TIMEOUT=0
while [ ! -S "$PULSE_SOCKET" ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT+1))
    if [ $TIMEOUT -gt 10 ]; then
        echo "Error: PulseAudio failed to start."
        exit 1
    fi
done

echo "--- Configuring Audio Loopback ---"
pactl -s $PULSE_SERVER load-module module-pipe-sink file=/tmp/snapfifo sink_name=Snapcast-Plexamp format=s16le rate=44100
pactl -s $PULSE_SERVER set-default-sink Snapcast-Plexamp
pactl -s $PULSE_SERVER set-sink-volume Snapcast-Plexamp 100%

echo "--- Generating Snapserver config ---"
STREAM_NAME=${SNAPCAST_NAME:-Plexamp}
mkdir -p /etc/snapserver
cat > /etc/snapserver.conf <<EOF
[server]
datadir = /var/lib/snapserver
[http]
enabled = true
doc_root = /usr/share/snapserver/snapweb
[tcp]
enabled = true
[stream]
source = pipe:///tmp/snapfifo?name=${STREAM_NAME}&sampleformat=44100:16:2
EOF

echo "--- Starting Snapserver ---"
snapserver -d -c /etc/snapserver.conf

echo "--- Starting Plexamp Headless ---"
cd /plexamp
export PULSE_SERVER=unix:$PULSE_SOCKET
node js/index.js
