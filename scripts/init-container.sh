#!/bin/bash
# 容器启动初始化脚本

echo ">>> 开始初始化容器..."

# 切换到 /home 目录
cd /home

# 检查是否已经初始化过 Git 仓库
if [ ! -d ".git" ]; then
    echo ">>> 初始化 Git 仓库..."
    git init
    
    # 首先尝试从 GitHub 拉取
    echo ">>> 尝试从 GitHub 拉取代码..."
    git remote add origin https://github.com/XCG0/HIT-HATM.git
    
    if git pull origin main 2>/dev/null; then
        echo ">>> ✓ 成功从 GitHub 拉取代码"
        git checkout -f main
    else
        echo ">>> ✗ GitHub 拉取失败，尝试使用 Gitee 镜像仓库..."
        
        # 移除失败的 GitHub remote
        git remote remove origin
        
        # 添加 Gitee 作为 origin
        git remote add origin https://gitee.com/XuChGu/HIT-HATM.git
        
        # 使用 --allow-unrelated-histories 和强制覆盖本地文件
        if git pull origin main --allow-unrelated-histories 2>&1 | tee /tmp/git_pull.log; then
            echo ">>> ✓ 成功从 Gitee 拉取代码"
            git reset --hard origin/main  # 强制重置到远程分支状态
            git checkout -f main
        else
            # 检查是否是文件冲突问题
            if grep -q "untracked working tree files" /tmp/git_pull.log; then
                echo ">>> 检测到文件冲突，执行强制拉取..."
                git fetch origin main
                git reset --hard origin/main
                git checkout -f main
                echo ">>> ✓ 强制拉取成功"
            else
                echo ">>> ✗ Gitee 拉取也失败，请检查网络连接"
                echo ">>> 可以手动执行以下命令重试:"
                echo "    cd /home"
                echo "    git fetch origin main"
                echo "    git reset --hard origin/main"
                exit 1
            fi
        fi
    fi
    
    code /home  # 启动 VS Code 编辑器，打开 /home 目录
else
    echo ">>> Git 仓库已存在，跳过初始化"
fi


# 保持容器运行
exec /bin/bash
