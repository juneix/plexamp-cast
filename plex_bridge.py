#!/usr/bin/env python3
import argparse
import sys
import time
import logging
from plexapi.server import PlexServer
from requests.exceptions import RequestException

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)

def get_player(plex, player_name):
    try:
        # 尝试通过名字查找客户端 (Plexamp Headless)
        client = plex.client(player_name)
        return client
    except Exception as e:
        logging.error(f"Could not find player '{player_name}': {e}")
        return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--token', required=True, help='Plex Authentication Token')
    parser.add_argument('--ip', required=True, help='Plex Server IP')
    parser.add_argument('--port', default=32400, help='Plex Server Port')
    parser.add_argument('--player', required=True, help='Name of the Plexamp player to control')
    args = parser.parse_args()

    baseurl = f"http://{args.ip}:{args.port}"
    logging.info(f"Connecting to Plex Server at {baseurl}...")

    try:
        plex = PlexServer(baseurl, args.token)
        logging.info(f"Connected to Plex: {plex.friendlyName}")
    except Exception as e:
        logging.error(f"Failed to connect to Plex Server: {e}")
        sys.exit(1)

    # 循环读取 Snapserver 发来的指令
    # Snapserver 会将控制命令写入脚本的 STDIN
    # 命令通常为: "play", "pause", "stop", "next", "prev", "volume <percent>"
    logging.info("Ready to receive commands from Snapserver...")
    
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break # EOF
            
            cmd = line.strip()
            if not cmd:
                continue

            logging.info(f"Received command: {cmd}")
            
            client = get_player(plex, args.player)
            if not client:
                logging.warning("Player not found, ignoring command.")
                continue

            # 解析命令
            try:
                if cmd == "play":
                    client.play()
                elif cmd == "pause":
                    client.pause()
                elif cmd == "playpause": # Snapcast 某些客户端可能发这个
                    if client.isPlaying():
                        client.pause()
                    else:
                        client.play()
                elif cmd == "stop":
                    client.stop()
                elif cmd == "next":
                    client.skipNext()
                elif cmd == "prev":
                    client.skipPrevious()
                elif cmd.startswith("volume"):
                    # volume 50
                    parts = cmd.split()
                    if len(parts) > 1:
                        vol = int(parts[1])
                        client.setVolume(vol)
                else:
                    logging.debug(f"Unknown command: {cmd}")
            except Exception as action_e:
                logging.error(f"Error executing command '{cmd}': {action_e}")

        except KeyboardInterrupt:
            break
        except Exception as e:
            logging.error(f"Loop error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()