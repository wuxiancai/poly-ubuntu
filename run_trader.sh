#! /bin/bash

# 自动设置 DISPLAY
if [ -z "$DISPLAY" ] || [[ "$DISPLAY" == ":0" ]]; then
    SOCKET=$(ls /tmp/.X11-unix/X* 2>/dev/null | head -n1)
    if [ -n "$SOCKET" ]; then
        DISPLAY_NUMBER=$(basename "$SOCKET" | sed 's/X//')
        export DISPLAY=":$DISPLAY_NUMBER"
        echo "自动设置 DISPLAY=$DISPLAY"
    else
        echo "未检测到 X11 socket,退出"
        exit 1
    fi
fi


# 打印接收到的参数，用于调试
echo "run_trader.sh received args: $@"

# 激活虚拟环境
source venv/bin/activate

# 运行交易程序
exec python3 -u crypto_trader.py "$@"
