#!/bin/bash
# openGauss 多节点集群 - 初始化脚本
# 在主节点容器内以 root 身份运行此脚本

set -e

echo "=== openGauss 集群初始化 ==="
echo ""

# 节点信息
PRIMARY_IP="172.18.0.10"
STANDBY1_IP="172.18.0.11"
STANDBY2_IP="172.18.0.12"

# 检查是否在主节点
CURRENT_IP=$(hostname -I | awk '{print $1}')
if [ "$CURRENT_IP" != "$PRIMARY_IP" ]; then
    echo "错误: 此脚本必须在主节点 (primary - $PRIMARY_IP) 上运行"
    echo "当前节点 IP: $CURRENT_IP"
    exit 1
fi

# 创建必要的目录
echo "在所有节点创建必要的目录..."
for node in primary standby1 standby2; do
    container="opengauss-${node}"
    
    echo "  配置节点: $node"
    docker exec $container bash -c "
        # 创建目录
        su - omm -c '
            mkdir -p /home/omm/{data,log,tmp,archivelog,corefile}
            chmod 700 /home/omm/data
        '
    "
done
echo "✓ 目录创建完成"
echo ""

# 在主节点初始化数据库
echo "在主节点初始化数据库..."
su - omm << 'EOF'
# 设置环境变量
export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH

# 初始化数据库
gs_initdb -D /home/omm/data --nodename=primary -w omm_1234

echo "✓ 主节点数据库初始化完成"
EOF

echo "✓ 主节点初始化完成"
echo ""

# 配置主节点 postgresql.conf
echo "配置主节点 postgresql.conf..."
su - omm << 'EOF'
cat >> /home/omm/data/postgresql.conf << 'EOPG'

# === 主备复制配置 ===
listen_addresses = '*'
port = 5432
max_connections = 200

# WAL 配置
wal_level = hot_standby
max_wal_senders = 10
wal_keep_segments = 256
hot_standby = on

# 同步备节点配置 (任意1个备节点同步即可)
synchronous_standby_names = 'ANY 1(standby1,standby2)'

# 归档配置
archive_mode = on
archive_command = 'test ! -f /home/omm/archivelog/%f && cp %p /home/omm/archivelog/%f'

# 日志配置
logging_collector = on
log_directory = '/home/omm/log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_line_prefix = '%m [%p] '

EOPG

echo "✓ postgresql.conf 配置完成"
EOF

# 配置主节点 pg_hba.conf
echo "配置主节点 pg_hba.conf..."
su - omm << 'EOF'
cat >> /home/omm/data/pg_hba.conf << 'EOHBA'

# === 集群访问控制 ===
# 本地连接
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

# 集群内部连接
host    all             all             172.18.0.0/16           trust

# 流复制连接
host    replication     omm             172.18.0.0/16           trust

EOHBA

echo "✓ pg_hba.conf 配置完成"
EOF

echo "✓ 主节点配置完成"
echo ""

# 启动主节点
echo "启动主节点数据库..."
su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
"

# 等待主节点启动
sleep 5

# 检查主节点状态
echo "检查主节点状态..."
su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl query -D /home/omm/data
"

echo "✓ 主节点启动成功"
echo ""

# 创建复制用户（如果不存在）
echo "配置复制权限..."
su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gsql -d postgres -p 5432 << 'EOSQL'
-- 修改 omm 密码
ALTER USER omm WITH PASSWORD 'omm_1234';

-- 授予复制权限
ALTER USER omm REPLICATION;

-- 查看用户权限
\du omm
EOSQL
"

echo "✓ 复制权限配置完成"
echo ""

# 使用 pg_basebackup 初始化备节点
echo "使用 pg_basebackup 初始化备节点..."

for standby in standby1 standby2; do
    standby_container="opengauss-${standby}"
    
    echo "  初始化 $standby..."
    
    # 在备节点使用 pg_basebackup
    docker exec $standby_container bash -c "
        su - omm -c '
            export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
            export PATH=\$GAUSSHOME/bin:\$PATH
            export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
            
            # 删除可能存在的旧数据
            rm -rf /home/omm/data/*
            
            # 使用 pg_basebackup 从主节点复制数据
            pg_basebackup -h $PRIMARY_IP -p 5432 -U omm -D /home/omm/data -X stream -P -v
            
            echo \"✓ $standby 数据复制完成\"
        '
    "
    
    # 配置 recovery.conf (备节点)
    echo "  配置 $standby recovery.conf..."
    docker exec $standby_container su - omm -c "
        cat > /home/omm/data/recovery.conf << 'EOREC'
standby_mode = 'on'
primary_conninfo = 'host=$PRIMARY_IP port=5432 user=omm application_name=$standby'
recovery_target_timeline = 'latest'
EOREC
        chmod 600 /home/omm/data/recovery.conf
    "
    
    # 修改 postgresql.conf (备节点特定配置)
    echo "  配置 $standby postgresql.conf..."
    docker exec $standby_container su - omm -c "
        cat >> /home/omm/data/postgresql.conf << 'EOPG'

# === 备节点特定配置 ===
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s

EOPG
    "
    
    echo "  ✓ $standby 初始化完成"
done

echo "✓ 备节点初始化完成"
echo ""

echo "=== 集群初始化完成 ==="
echo ""
echo "下一步: 启动集群"
echo "运行: cd /home/scripts && bash 04_start_cluster.sh"
