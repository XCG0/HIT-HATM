#!/bin/bash
# openGauss 多节点集群 - 故障切换测试脚本
# 在主节点容器内以 root 身份运行此脚本

set -e

echo "=== openGauss 故障切换测试 ==="
echo ""
echo "警告: 此脚本将测试故障切换功能"
echo "这将停止当前主节点并将备节点提升为主节点"
echo ""
read -p "是否继续？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "取消操作"
    exit 0
fi

# 节点信息
PRIMARY_IP="172.18.0.10"
STANDBY1_IP="172.18.0.11"
STANDBY2_IP="172.18.0.12"

echo ""
echo "1. 记录当前集群状态"
echo "================================"
echo ""

echo "当前主节点复制状态:"
docker exec opengauss-primary su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gsql -d postgres -p 5432 << 'EOSQL'
SELECT application_name, state, sync_state 
FROM pg_stat_replication;
EOSQL
"
echo ""

echo "2. 模拟主节点故障（停止主节点）"
echo "================================"
echo ""

echo "停止主节点数据库..."
docker exec opengauss-primary su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl stop -D /home/omm/data -m fast
"

echo "✓ 主节点已停止"
echo ""

sleep 3

echo "3. 将备节点1提升为新主节点"
echo "================================"
echo ""

echo "提升 standby1 为主节点..."
docker exec opengauss-standby1 su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    # 提升为主节点
    gs_ctl failover -D /home/omm/data
"

echo "✓ standby1 已提升为主节点"
echo ""

sleep 3

echo "4. 验证新主节点状态"
echo "================================"
echo ""

echo "新主节点 (standby1) 状态:"
docker exec opengauss-standby1 su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl query -D /home/omm/data
"
echo ""

echo "在新主节点测试写入..."
docker exec opengauss-standby1 su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gsql -d postgres -p 5432 << 'EOSQL'
-- 插入测试数据
INSERT INTO replication_test (node_name, data) 
VALUES ('standby1-now-primary', 'Data after failover');

-- 查看数据
SELECT * FROM replication_test ORDER BY id DESC LIMIT 5;
EOSQL
"
echo ""

echo "5. 检查 standby2 是否跟随新主节点"
echo "================================"
echo ""

sleep 3

echo "standby2 数据验证:"
docker exec opengauss-standby2 su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    # 重新配置 recovery.conf 指向新主节点
    cat > /home/omm/data/recovery.conf << 'EOREC'
standby_mode = 'on'
primary_conninfo = 'host=$STANDBY1_IP port=5432 user=omm application_name=standby2'
recovery_target_timeline = 'latest'
EOREC
    
    # 重启以应用新配置
    gs_ctl restart -D /home/omm/data -M standby
"

sleep 5

docker exec opengauss-standby2 su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gsql -d postgres -p 5432 << 'EOSQL'
SELECT * FROM replication_test ORDER BY id DESC LIMIT 5;
EOSQL
"
echo ""

echo "6. 将原主节点降级为备节点（可选）"
echo "================================"
echo ""

read -p "是否将原主节点 (primary) 降级为备节点？(yes/no): " demote

if [ "$demote" = "yes" ]; then
    echo "降级原主节点为备节点..."
    
    docker exec opengauss-primary su - omm -c "
        export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
        export PATH=\$GAUSSHOME/bin:\$PATH
        export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
        
        # 删除现有数据
        rm -rf /home/omm/data/*
        
        # 从新主节点同步数据
        pg_basebackup -h $STANDBY1_IP -p 5432 -U omm -D /home/omm/data -X stream -P
        
        # 配置 recovery.conf
        cat > /home/omm/data/recovery.conf << 'EOREC'
standby_mode = 'on'
primary_conninfo = 'host=$STANDBY1_IP port=5432 user=omm application_name=primary-demoted'
recovery_target_timeline = 'latest'
EOREC
        
        # 启动为备节点
        gs_ctl start -D /home/omm/data -M standby -l /home/omm/log/opengauss.log
    "
    
    echo "✓ 原主节点已降级为备节点"
fi

echo ""
echo "=== 故障切换测试完成 ==="
echo ""
echo "当前集群状态:"
echo "  新主节点: standby1 ($STANDBY1_IP)"
echo "  备节点: standby2 ($STANDBY2_IP)"
if [ "$demote" = "yes" ]; then
    echo "  备节点: primary (已降级) ($PRIMARY_IP)"
fi
echo ""
