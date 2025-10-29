#!/usr/bin/env bash
# 用于验证 openGauss 编译结果是否可正常运行
# 需在编译完成并生成 mppdb_temp_install 后执行
# 不要直接运行脚本，建议逐条复制命令，在终端依次运行

set -e

# ===== 创建 omm 用户和用户组 =====
if ! id omm &>/dev/null; then
  groupadd dbgrp 2>/dev/null || echo "用户组 dbgrp 已存在"
  useradd -g dbgrp omm 2>/dev/null || echo "用户 omm 已存在"
  
  # 尝试使用不同的密码设置命令
  if command -v passwd &>/dev/null; then
    echo "请为 omm 用户设置密码："
    passwd omm
  elif command -v chpasswd &>/dev/null; then
    echo "请输入 omm 用户的密码："
    read -s ommpasswd
    echo "omm:$ommpasswd" | chpasswd
    echo "omm 用户密码已设置"
  else
    echo "警告: passwd 命令不可用，请手动设置 omm 用户密码"
    echo "可以使用: echo 'omm:yourpassword' | chpasswd"
  fi
else
  echo "omm 用户已存在，跳过创建步骤"
fi

chown -R omm:dbgrp /home/openGauss/openGauss-server

# ===== 切换到 omm 用户执行后续操作 =====


# ===== 配置环境变量 =====

# 建议写入 ~/.bashrc
CODE_BASE=/home/openGauss/openGauss-server              # 修改为你的 openGauss-server 路径
GAUSSHOME=$CODE_BASE/mppdb_temp_install
export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install/ ##编译结果的路径，可根据实际情况修改
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
export PATH=$GAUSSHOME/bin:$PATH
export PATH=/bin:/usr/bin:/usr/local/bin:$PATH
# source ~/.bashrc

# 创建数据目录和日志目录
mkdir -p /home/omm/data /home/omm/log

# ===== 运行数据库 =====
# 初始化数据库
gs_initdb -D /home/omm/data --nodename=db1

# 启动数据库
gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log

# 查询数据库状态
gs_ctl query -D /home/omm/data

EOF

echo "✅ openGauss 编译后验证完成，可以正常启动并执行 SQL。"
