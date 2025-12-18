#!/usr/bin/env python3
import argparse
import sys
import logging
from plexapi.server import PlexServer
from requests.exceptions import RequestException

# 配置日志：输出到 stderr 以便 Docker 捕获
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [PlexBridge] %(levelname)s: %(message)s',
    stream=sys.stderr
)

def get_plex_server(ip, port, token):
    try:
        baseurl = f"http://{ip}:{port}"
        plex = PlexServer(baseurl, token)
        logging.info(f"Connected to Plex Server: {plex.friendlyName} (v{plex.version})")
        return plex
    except Exception as e:
        logging.error(f"Failed to connect to Plex Server at {baseurl}: {e}")
        return None

def find_player(plex, player_name):
    """
    查找指定的播放器。
    如果找不到，会打印当前所有可用的播放器名称，方便调试。
    """
    try:
        # 尝试直接获取
        client = plex.client(player_name)
        return client
    except Exception:
        # 如果报错或找不到，列出当前所有在线设备
        logging.warning(f"Target player '{player_name}' not found directly. Scanning all clients...")
        available_clients = []
        try:
            for c in plex.clients():
                available_clients.append(c.title)
                if c.title == player_name:
                    return c
        except Exception as e:
            logging.error(f"Error listing clients: {e}")
        
        logging.error(f"Could NOT find player: '{player_name}'.")
        logging.info(f"Available players on your server: {available_clients}")
        return None

def process_command(client, cmd):
    """根据 Snapcast 指令控制 Plexamp"""
    try:
        if cmd == "play":
            client.play()
        elif cmd == "pause":
            client.pause()
        elif cmd == "playpause":
            client.pause() if client.isPlaying() else client.play()
        elif cmd == "stop":
            client.stop()
        elif cmd == "next":
            client.skipNext()
        elif cmd == "prev":
            client.skipPrevious()
        elif cmd.startswith("volume"):
            # Snapcast 传来的格式通常是 "volume 50"
            parts = cmd.split()
            if len(parts) > 1:
                # Plex 音量范围是 0-100
                vol = int(parts[1])
                client.setVolume(vol)
        else:
            logging.debug(f"Ignored/Unknown command: {cmd}")
            return False
        
        logging.info(f"Executed command: {cmd}")
        return True
    except Exception as e:
        logging.error(f"Error executing '{cmd}': {e}")
        return False

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--token', required=True)
    parser.add_argument('--ip', required=True)
    parser.add_argument('--port', default=32400)
    parser.add_argument('--player', required=True)
    args = parser.parse_args()

    # 1. 连接服务器
    plex = get_plex_server(args.ip, args.port, args.token)
    if not plex:
        sys.exit(1)

    # 2. 启动时尝试找一次播放器，确认配置无误
    logging.info(f"Looking for player: {args.player}...")
    client = find_player(plex, args.player)
    if client:
        logging.info(f"Found player: {client.title} ({client.product}) at {client.address}")
    else:
        logging.warning("Player not found at startup. Will try again when commands arrive.")

    logging.info("Ready via STDIN...")

    # 3. 循环读取 Snapserver 的指令
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break # EOF

            cmd = line.strip().lower()
            if not cmd:
                continue

            logging.info(f"Received Snapcast command: {cmd}")
            
            # 为了防止连接过期，每次指令都重新获取/刷新 client 对象
            # 这是一个轻量级操作，能极大提高稳定性
            if not client or True: 
                client = find_player(plex, args.player)

            if client:
                process_command(client, cmd)
            
        except KeyboardInterrupt:
            break
        except Exception as e:
            logging.error(f"Loop error: {e}")

if __name__ == "__main__":
    main()
