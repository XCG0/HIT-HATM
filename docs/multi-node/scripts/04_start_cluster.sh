#!/bin/bash
# openGauss 多节点集群 - 启动脚本
# 在主节点容器内以 root 身份运行此脚本

set -e

echo "=== openGauss 集群启动 ==="
echo ""

# 检查主节点是否已启动
echo "检查主节点状态..."
MAIN_STATUS=$(docker exec opengauss-primary su - omm -c "
    export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
    export PATH=\$GAUSSHOME/bin:\$PATH
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
    
    gs_ctl query -D /home/omm/data | grep -o 'db_state.*Normal' || echo 'stopped'
")

if [[ "$MAIN_STATUS" == *"Normal"* ]]; then
    echo "✓ 主节点已在运行"
else
    echo "启动主节点..."
    docker exec opengauss-primary su - omm -c "
        export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
        export PATH=\$GAUSSHOME/bin:\$PATH
        export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
        
        gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
    "
    
    echo "等待主节点启动..."
    sleep 5
    echo "✓ 主节点启动完成"
fi
echo ""

# 启动备节点
for standby in standby1 standby2; do
    container="opengauss-${standby}"
    
    echo "启动 $standby..."
    docker exec $container su - omm -c "
        export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
        export PATH=\$GAUSSHOME/bin:\$PATH
        export LD_LIBRARY_PATH=\$GAUSSHOME/lib:\$LD_LIBRARY_PATH
        
        gs_ctl start -D /home/omm/data -M standby -l /home/omm/log/opengauss.log
    "
    
    echo "  ✓ $standby 启动完成"
    sleep 3
done

echo ""
echo "=== 集群启动完成 ==="
echo ""
echo "下一步: 验证集群状态"
echo "运行: cd /home/scripts && bash 05_verify_cluster.sh"
