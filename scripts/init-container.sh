#!/bin/bash
# 容器启动初始化脚本

echo ">>> 开始初始化容器..."

# 切换到 /home 目录
cd /home

# 检查是否已经初始化过 Git 仓库
if [ ! -d ".git" ]; then
    git init
    git remote add origin https://github.com/XCG0/HIT-HATM.git
    git pull origin main  # 从远程 origin 的 main 分支拉取并合并最新代码
    git checkout -f main  # 强制切换到 main 分支
    code /home            # 启动 VS Code 编辑器，打开 /home 目录
fi


# 保持容器运行
exec /bin/bash
