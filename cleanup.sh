#!/bin/bash
# 容器清理脚本 - 在打包镜像前执行
# 用途：保留 openGauss 运行和 GDB 调试功能，删除不必要的文件

echo "========== 开始清理容器 =========="

# 1. 清理编译产物和源代码（保留已安装的二进制文件）
echo "清理编译源码和临时文件..."
if [ -d "/home/openGauss/openGauss-server" ]; then
    # 保留安装目录，删除源码和编译中间文件
    cd /home/openGauss/openGauss-server
    rm -rf .git binarylibs build simpleInstall
    rm -rf openGauss-third_party openGauss-third_party_binarylibs
    find . -name "*.o" -delete
    find . -name "*.a" -delete
    find . -name "*.la" -delete
    find . -name "*.pyc" -delete
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
fi

# 2. 清理 yum/dnf 缓存
echo "清理包管理器缓存..."
yum clean all 2>/dev/null || dnf clean all 2>/dev/null
rm -rf /var/cache/yum/* /var/cache/dnf/*

# 3. 清理日志文件（保留日志目录结构）
echo "清理日志文件..."
find /var/log -type f -name "*.log" -delete
find /var/log -type f -name "*.old" -delete
find /var/log -type f -name "*.gz" -delete
> /var/log/messages 2>/dev/null
> /var/log/secure 2>/dev/null

# 4. 清理临时文件
echo "清理临时文件..."
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache/*
rm -rf /Demo/build/*
mkdir -p /Demo/build

# 5. 清理不必要的文档和手册
echo "清理文档和手册..."
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/locale/*  # 删除多语言支持（如果不需要）

# 6. 清理不必要的开发工具（保留 GDB 和必要工具）
echo "保留 GDB，清理其他不必要的开发工具..."
# 列出要保留的包
KEEP_PACKAGES="gdb gcc g++ make cmake git"

# 列出可以删除的开发工具（根据实际情况调整）
# 注意：不要删除 openGauss 运行依赖的库
# yum remove -y autoconf automake libtool  # 如果确定不需要可以删除

# 7. 清理 pip 缓存
echo "清理 Python pip 缓存..."
rm -rf /root/.cache/pip/*

# 8. 清理 bash 历史
echo "清理命令历史..."
> /root/.bash_history
> /home/omm/.bash_history 2>/dev/null
history -c

# 9. 清理 openGauss 相关（保留运行必需）
echo "清理 openGauss 非必要文件..."
# 清理 openGauss 日志（如果不需要历史日志）
if [ -d "/home/omm/data/pg_log" ]; then
    find /home/omm/data/pg_log -type f -mtime +7 -delete  # 只保留最近7天日志
fi

# 清理数据库临时文件
rm -rf /home/omm/data/base/pgsql_tmp/* 2>/dev/null

# 10. 清理下载的安装包
echo "清理下载的安装包..."
rm -rf /root/*.tar.gz /root/*.zip /root/*.rpm

# 11. 统计清理效果
echo ""
echo "========== 清理完成 =========="
echo "当前磁盘使用情况："
df -h /
echo ""
echo "各目录大小："
du -sh /home/* 2>/dev/null
du -sh /var/log 2>/dev/null
du -sh /usr/share 2>/dev/null

echo ""
echo "========== 重要提示 =========="
echo "1. 请验证 openGauss 数据库是否正常运行"
echo "2. 请验证 GDB 是否可用: gdb --version"
echo "3. 确认无误后再执行 docker commit"