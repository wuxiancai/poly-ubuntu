#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== Ubuntu 自动化安装脚本 ==="

# 检查系统类型
if [[ "$(uname)" != "Linux" ]]; then
    echo "${RED}错误: 此脚本只能在 Linux 系统上运行${NC}"
    exit 1
fi

# 检查是否为Ubuntu系统
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "${RED}警告: 此脚本专为 Ubuntu 系统设计,其他Linux发行版可能需要调整${NC}"
fi

CHIP_TYPE=$(uname -m)
echo "检测到芯片类型: $CHIP_TYPE"

# 自动确认所有提示
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 更新系统包列表
echo "更新系统包列表..."
sudo apt update

# 安装必要的系统依赖
echo "安装系统依赖..."
sudo apt install -y software-properties-common apt-transport-https ca-certificates gnupg lsb-release curl wget build-essential

# 添加deadsnakes PPA以获取Python 3.9
echo "添加Python PPA..."
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update

# 安装 Python 3.9 和相关包
echo "安装 Python 3.9..."
sudo apt install -y python3.9 python3.9-venv python3.9-dev python3.9-distutils python3-pip
sudo apt install -y python3-tk python3.9-tk

# 确保python3.9可用
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# 创建虚拟环境
echo "创建虚拟环境..."
python3.9 -m venv venv --clear
source venv/bin/activate

# 升级 pip
echo "升级 pip..."
python3.9 -m pip install --upgrade pip

# 安装依赖
echo "安装Python依赖..."
pip3 install --no-cache-dir selenium
pip3 install --no-cache-dir pyautogui
pip3 install --no-cache-dir screeninfo
pip3 install --no-cache-dir requests

# 安装GUI相关依赖（Ubuntu特有）
echo "安装GUI相关依赖..."
sudo apt install -y python3-xlib scrot python3-dev
pip3 install --no-cache-dir python3-xlib

# 配置环境变量
echo "配置环境变量..."
if ! grep -q "# Python 配置" ~/.bashrc; then
    echo '# Python 配置' >> ~/.bashrc
    echo 'export PATH="/usr/bin:$PATH"' >> ~/.bashrc
    echo 'export TK_SILENCE_DEPRECATION=1' >> ~/.bashrc
    echo 'export DISPLAY=:0' >> ~/.bashrc
fi

# 检查并安装 Chrome
echo "检查并安装 Chrome..."

# 检查 Chrome 是否已安装
if command -v google-chrome &> /dev/null || command -v google-chrome-stable &> /dev/null; then
    echo "${GREEN}Chrome 已安装${NC}"
    CHROME_INSTALLED=true
else
    echo "Chrome 未安装"
    CHROME_INSTALLED=false
fi

# 检查 ChromeDriver 是否已安装
if command -v chromedriver &> /dev/null; then
    echo "${GREEN}ChromeDriver 已安装${NC}"
    CHROMEDRIVER_INSTALLED=true
else
    echo "ChromeDriver 未安装"
    CHROMEDRIVER_INSTALLED=false
fi

# 安装Chrome
if [ "$CHROME_INSTALLED" = false ]; then
    echo "安装 Chrome..."
    # 添加Google Chrome的官方APT仓库
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    sudo apt update
    sudo apt install -y google-chrome-stable
fi

# 安装ChromeDriver
if [ "$CHROMEDRIVER_INSTALLED" = false ]; then
    echo "安装 ChromeDriver..."
    # 获取Chrome版本
    CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d'.' -f1-3)
    echo "Chrome版本: $CHROME_VERSION"
    
    # 下载对应版本的ChromeDriver
    DRIVER_VERSION=$(curl -s "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROME_VERSION}")
    if [ -z "$DRIVER_VERSION" ]; then
        # 如果找不到对应版本，使用最新版本
        DRIVER_VERSION=$(curl -s "https://chromedriver.storage.googleapis.com/LATEST_RELEASE")
    fi
    
    echo "下载ChromeDriver版本: $DRIVER_VERSION"
    wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/${DRIVER_VERSION}/chromedriver_linux64.zip"
    
    # 解压并安装
    sudo unzip -o /tmp/chromedriver.zip -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/chromedriver
    rm /tmp/chromedriver.zip
fi

# 设置Chrome启动脚本权限
chmod +x start_chrome_ubuntu.sh

# 创建自动启动脚本
cat > run_trader.sh << 'EOL'
#!/bin/bash

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
EOL

chmod +x run_trader.sh

# 验证安装
echo "=== 验证安装 ==="
echo "Python 路径: $(which python3)"
echo "Python 版本: $(python3 --version)"
echo "Pip 版本: $(pip3 --version)"
echo "Chrome 版本: $(google-chrome --version 2>/dev/null || google-chrome-stable --version 2>/dev/null || echo '未安装')"
echo "ChromeDriver 版本: $(chromedriver --version 2>/dev/null || echo '未安装')"
echo "已安装的Python包:"
pip3 list

# 创建自动化测试脚本
cat > test_environment.py << 'EOL'
import sys
import tkinter
import selenium
import pyautogui

def test_imports():
    modules = {
        'tkinter': tkinter,
        'selenium': selenium,
        'pyautogui': pyautogui
    }
    
    print("Python 版本:", sys.version)
    print("\n已安装模块:")
    for name, module in modules.items():
        print(f"{name}: {module.__version__ if hasattr(module, '__version__') else '已安装'}")

if __name__ == "__main__":
    test_imports()
EOL

# 运行测试
echo "运行环境测试..."
python3 test_environment.py

echo "${GREEN}安装完成！${NC}"
echo "使用说明:"
echo "1. 直接运行 ./run_trader.sh 即可启动程序"
echo "2. 程序会自动启动 Chrome 并运行交易脚本"
echo "3. 所有配置已自动完成，无需手动操作"
echo "4. 如果遇到显示问题,请确保已设置DISPLAY环境变量"

# 自动清理安装缓存
sudo apt autoremove -y
sudo apt autoclean
pip3 cache purge
rm -rf test_environment.py

echo "${GREEN}Ubuntu安装脚本执行完成!${NC}"