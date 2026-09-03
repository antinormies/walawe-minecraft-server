#!/usr/bin/env bash
# Minecraft 1.21.11 vanilla server launcher.
#
# Usage:
#   ./start.sh                start in the foreground (Ctrl+C = graceful stop)
#   MC_RAM=2G ./start.sh      override the memory limit (default 3072M)
#
# For a VPS you normally don't run this by hand - use the systemd unit
# (see minecraft.service + README.md) or tmux:
#   tmux new -s mc ./start.sh
set -euo pipefail
cd "$(dirname "$0")"

# --- pick a Java 21 runtime -----------------------------------------------
# 1) the bundled runtime in ./jre (portable, no install needed)
# 2) a system-wide java
if [ -x "./jre/bin/java" ]; then
  JAVA="./jre/bin/java"
else
  JAVA="$(command -v java || true)"
  if [ -z "$JAVA" ]; then
    echo "ERROR: Java not found." >&2
    echo "Install it with:  sudo apt install openjdk-21-jre-headless" >&2
    echo "or unpack a JDK 21 tarball into ./jre (bin/java inside)." >&2
    exit 1
  fi
fi

echo "Using Java: $("$JAVA" -version 2>&1 | head -1)"

# --- memory ----------------------------------------------------------------
MC_RAM="${MC_RAM:-3072M}"
echo "Heap: -Xms$MC_RAM -Xmx$MC_RAM  (override with MC_RAM=..., e.g. MC_RAM=4G)"
case "$MC_RAM" in
  *[0-9]G|*[0-9]M) ;;
  *) echo "ERROR: MC_RAM must look like 2G or 2048M" >&2; exit 1 ;;
esac

exec "$JAVA" -Xms"$MC_RAM" -Xmx"$MC_RAM" \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+DisableExplicitGC \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 \
  -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=85 \
  -XX:SurvivorRatio=32 \
  -XX:MaxTenuringThreshold=1 \
  -XX:+PerfDisableSharedMem \
  -jar server.jar nogui
