#!/bin/bash
# serve.sh — Trading daemon management CLI
#
# Usage:
#   ./serve.sh run          Run daemon in foreground (for debugging)
#   ./serve.sh install      Install launchd agent (auto-start on login)
#   ./serve.sh uninstall    Remove launchd agent
#   ./serve.sh status       Show if daemon is running
#   ./serve.sh logs         Tail daemon log
#   ./serve.sh dev          Start Next.js dev server + file server (hot reload)

set -e
cd "$(dirname "$0")"

LABEL="com.crudeoilandgas.daemon"
PLIST="com.crudeoilandgas.daemon.plist"
PLIST_SRC="$(pwd)/$PLIST"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST"
LOG_FILE="$(pwd)/data/live/daemon.log"
DOMAIN="gui/$(id -u)"

case "${1:-help}" in
  run)
    echo "=== Running daemon in foreground ==="
    echo "=== Dashboard: http://localhost:8080/web/out/index.html ==="
    exec bun run daemon.ts
    ;;

  install)
    if [ -f "$PLIST_DST" ]; then
      echo "Removing existing agent..."
      launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
      rm -f "$PLIST_DST"
    fi

    echo "Installing launchd agent..."
    mkdir -p "$HOME/Library/LaunchAgents"
    ln -sf "$PLIST_SRC" "$PLIST_DST"

    # Clear old log
    > "$LOG_FILE"

    launchctl bootstrap "$DOMAIN" "$PLIST_DST"
    echo "Installed and started: $LABEL"
    echo "Dashboard: http://localhost:8080/web/out/index.html"
    echo "Logs: ./serve.sh logs"
    ;;

  uninstall)
    echo "Removing launchd agent..."
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST_DST"
    echo "Uninstalled: $LABEL"
    ;;

  status)
    if launchctl print "$DOMAIN/$LABEL" 2>/dev/null | head -5; then
      echo ""
      echo "Status: RUNNING"
    else
      echo "Status: NOT RUNNING"
    fi
    ;;

  logs)
    if [ ! -f "$LOG_FILE" ]; then
      echo "No log file yet: $LOG_FILE"
      exit 1
    fi
    tail -f "$LOG_FILE"
    ;;

  dev)
    echo "=== Starting file server (port 8080) + Next.js dev server (port 3000) ==="
    echo "=== Dashboard at http://localhost:3000/web/out ==="
    echo ""
    bun run daemon.ts &
    DAEMON_PID=$!
    trap "kill $DAEMON_PID 2>/dev/null" EXIT
    cd web && bun run dev
    ;;

  help|*)
    echo "Usage: ./serve.sh <command>"
    echo ""
    echo "Commands:"
    echo "  run        Run daemon in foreground (Ctrl+C to stop)"
    echo "  install    Install launchd agent (auto-start on login)"
    echo "  uninstall  Remove launchd agent"
    echo "  status     Show if daemon is running"
    echo "  logs       Tail daemon log"
    echo "  dev        Daemon + Next.js dev server (hot reload)"
    ;;
esac
