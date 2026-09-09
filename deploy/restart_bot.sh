#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_PYTHON="$PROJECT_DIR/venv/bin/python"
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"

echo "=== Futurabot Start Script ==="
echo "Started at $(date)"

# --- Method 1: Direct (for manual/screen/tmux use) ---
start_direct() {
    echo "[1/2] Starting main.py (scanner)..."
    cd "$PROJECT_DIR"
    nohup "$VENV_PYTHON" main.py > "$LOG_DIR/main.log" 2>&1 &
    MAIN_PID=$!
    echo "  PID: $MAIN_PID"

    echo "[2/2] Starting auto_trades.py (executor)..."
    cd "$PROJECT_DIR"
    nohup "$VENV_PYTHON" auto_trades.py > "$LOG_DIR/auto_trades.log" 2>&1 &
    TRADES_PID=$!
    echo "  PID: $TRADES_PID"

    echo ""
    echo "Bot started successfully!"
    echo "  main.py PID      : $MAIN_PID"
    echo "  auto_trades.py PID: $TRADES_PID"
    echo "  Logs: $LOG_DIR/"
    echo ""
    echo "To stop: kill $MAIN_PID $TRADES_PID"
}

# --- Method 2: Systemd (for production) ---
start_systemd() {
    echo "Starting via systemd..."

    # Install service files if not present
    if [ ! -f /etc/systemd/system/bot.service ]; then
        echo "Installing service files..."
        sudo cp "$PROJECT_DIR/deploy/bot.service" /etc/systemd/system/
        sudo cp "$PROJECT_DIR/deploy/auto_trades.service" /etc/systemd/system/ 2>/dev/null
        sudo systemctl daemon-reload
    fi

    sudo systemctl start bybit_bot
    sudo systemctl start auto_trades
    echo "Bot started via systemd!"
    sudo systemctl status bybit_bot --no-pager
}

# --- Stop all ---
stop_all() {
    echo "Stopping all bot processes..."

    # Stop systemd services if running
    sudo systemctl stop bybit_bot 2>/dev/null
    sudo systemctl stop auto_trades 2>/dev/null

    # Kill any remaining processes
    pkill -f "python main.py" 2>/dev/null
    pkill -f "python auto_trades.py" 2>/dev/null

    echo "All bot processes stopped at $(date)"
}

# --- Status ---
status() {
    echo "=== Bot Status ==="
    echo ""
    echo "--- Systemd Services ---"
    sudo systemctl status bybit_bot --no-pager 2>/dev/null || echo "  bybit_bot: not installed"
    sudo systemctl status auto_trades --no-pager 2>/dev/null || echo "  auto_trades: not installed"
    echo ""
    echo "--- Running Processes ---"
    ps aux | grep -E "(main\.py|auto_trades\.py)" | grep -v grep || echo "  No bot processes running"
}

# --- Main ---
case "${1:-start}" in
    start)
        start_direct
        ;;
    start-systemd)
        start_systemd
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_direct
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|start-systemd|stop|restart|status}"
        echo ""
        echo "  start          - Start bot directly (manual/screen/tmux)"
        echo "  start-systemd  - Start bot via systemd (production)"
        echo "  stop           - Stop all bot processes"
        echo "  restart        - Restart all bot processes"
        echo "  status         - Show bot status"
        exit 1
        ;;
esac