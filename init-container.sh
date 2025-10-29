#!/bin/bash
# 容器启动初始化脚本

echo ">>> 开始初始化容器..."

# 切换到 /home 目录
cd /home

# 检查是否已经初始化过 Git 仓库
if [ ! -d ".git" ]; then
    echo ">>> 初始化 Git 仓库并拉取代码..."
    git init
    git remote add origin https://gitee.com/XuChGu/HIT-HADB.git
    git pull origin main
    git checkout -f main
    echo ">>> Git 仓库初始化完成"
else
    echo ">>> Git 仓库已存在，跳过初始化"
fi

echo ">>> 容器初始化完成，启动 bash..."

# 保持容器运行
exec /bin/bash
