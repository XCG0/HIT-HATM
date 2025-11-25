#!/bin/bash
# openGauss 多节点集群 - 初始化脚本（简化版）
set -e
export MSYS_NO_PATHCONV=1

# 默认复制模式
REPLICATION_MODE="ANY1"

# 解析参数
while getopts "m:h" opt; do
    case $opt in
        m) REPLICATION_MODE=$(echo "$OPTARG" | tr '[:lower:]' '[:upper:]') ;;
        h) echo "用法: $0 -m [ANY1|ANY2|FIRST1|FIRST2|SYNC|ASYNC]"; exit 0 ;;
        \?) echo "错误: 无效选项"; exit 1 ;;
    esac
done

# 验证模式
if [[ ! "$REPLICATION_MODE" =~ ^(ANY[0-9]+|FIRST[0-9]+|SYNC|ASYNC)$ ]]; then
    echo "错误: 不支持的复制模式 '$REPLICATION_MODE'"
    exit 1
fi

echo "[1/6] 发现集群节点 (模式: $REPLICATION_MODE)"

# 发现节点
PRIMARY_IP="172.18.0.10"
if ! docker ps -q -f name=opengauss-primary | grep -q .; then
    echo "错误: 未找到主节点"
    exit 1
fi

STANDBY_CONTAINERS=()
STANDBY_IPS=()
STANDBY_NAMES=()
for i in {1..10}; do
    if docker ps -q -f name=opengauss-standby$i | grep -q .; then
        STANDBY_CONTAINERS+=("opengauss-standby$i")
        STANDBY_IPS+=("172.18.0.$((10 + i))")
        STANDBY_NAMES+=("standby$i")
    fi
done

STANDBY_COUNT=${#STANDBY_CONTAINERS[@]}
echo "  发现: 1主+${STANDBY_COUNT}备"

echo "[2/6] 准备主节点"
# 创建目录
docker exec opengauss-primary su - omm -c '
    mkdir -p /home/omm/{data,log,archivelog}
    chmod 700 /home/omm/data
' > /dev/null 2>&1

# 清理进程和数据
docker exec opengauss-primary bash -c 'pkill -9 gaussdb 2>/dev/null || true'
sleep 1
docker exec opengauss-primary su - omm -c 'rm -rf /home/omm/data/*' > /dev/null 2>&1

# 初始化
docker exec opengauss-primary su - omm -c 'gs_initdb -D /home/omm/data --nodename=primary -w omm_1234' > /dev/null 2>&1 || { echo "错误: 主节点初始化失败"; exit 1; }
echo "  ✓ 主节点初始化完成"

echo "[3/6] 配置主节点"
# 构建同步配置
if [ $STANDBY_COUNT -gt 0 ]; then
    STANDBY_LIST=$(IFS=,; echo "${STANDBY_NAMES[*]}")
    case $REPLICATION_MODE in
        ANY*) 
            SYNC_NUM=${REPLICATION_MODE#ANY}
            [ $SYNC_NUM -gt $STANDBY_COUNT ] && SYNC_NUM=$STANDBY_COUNT
            SYNC_STANDBY_CONFIG="synchronous_standby_names = 'ANY $SYNC_NUM($STANDBY_LIST)'"
            ;;
        FIRST*) 
            SYNC_NUM=${REPLICATION_MODE#FIRST}
            [ $SYNC_NUM -gt $STANDBY_COUNT ] && SYNC_NUM=$STANDBY_COUNT
            SYNC_STANDBY_CONFIG="synchronous_standby_names = 'FIRST $SYNC_NUM($STANDBY_LIST)'"
            ;;
        SYNC) SYNC_STANDBY_CONFIG="synchronous_standby_names = 'ANY $STANDBY_COUNT($STANDBY_LIST)'" ;;
        ASYNC) SYNC_STANDBY_CONFIG="synchronous_standby_names = ''" ;;
    esac
else
    SYNC_STANDBY_CONFIG="# synchronous_standby_names = '' # 无备节点"
fi

# 配置文件
docker exec opengauss-primary su - omm -c "
    sed -i \"s/^synchronous_standby_names = '\*'/#synchronous_standby_names = '*'/\" /home/omm/data/postgresql.conf
    cat >> /home/omm/data/postgresql.conf << 'EOF'
listen_addresses = '*'
port = 5432
max_connections = 200
password_encryption_type = 2
wal_level = hot_standby
max_wal_senders = 10
wal_keep_segments = 256
hot_standby = on
archive_mode = on
archive_command = 'test ! -f /home/omm/archivelog/%f && cp %p /home/omm/archivelog/%f'
logging_collector = on
log_directory = '/home/omm/log'
EOF
" > /dev/null 2>&1

# 添加复制连接配置
if [ $STANDBY_COUNT -gt 0 ]; then
    for i in "${!STANDBY_IPS[@]}"; do
        local_port=$((5434 + i * 2))
        local_hb_port=$((5435 + i * 2))
        docker exec opengauss-primary su - omm -c "echo \"replconninfo$((i+1)) = 'localhost=$PRIMARY_IP localport=$local_port localheartbeatport=$local_hb_port localservice=5432 remotehost=${STANDBY_IPS[$i]} remoteport=$local_port remoteheartbeatport=$local_hb_port remoteservice=5432'\" >> /home/omm/data/postgresql.conf" 2>/dev/null
    done
fi

docker exec opengauss-primary su - omm -c "echo \"$SYNC_STANDBY_CONFIG\" >> /home/omm/data/postgresql.conf" 2>/dev/null

# 配置 pg_hba.conf
docker exec opengauss-primary su - omm -c "
    cat >> /home/omm/data/pg_hba.conf << 'EOF'
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             172.18.0.0/16           sha256
EOF
" > /dev/null 2>&1

for standby_ip in "${STANDBY_IPS[@]}"; do
    docker exec opengauss-primary su - omm -c "echo 'host    replication     omm             $standby_ip/32          trust' >> /home/omm/data/pg_hba.conf" 2>/dev/null
done

echo "  ✓ 主节点配置完成"

echo "[4/6] 启动主节点"
docker exec opengauss-primary su - omm -c 'gs_ctl stop -D /home/omm/data -m fast 2>/dev/null || true' > /dev/null 2>&1
sleep 1
docker exec opengauss-primary su - omm -c 'gs_ctl start -D /home/omm/data -M primary -l /home/omm/log/opengauss.log' > /dev/null 2>&1 || { echo "错误: 主节点启动失败"; exit 1; }
sleep 3
docker exec opengauss-primary su - omm -c 'gs_ctl reload -D /home/omm/data' > /dev/null 2>&1
echo "  ✓ 主节点启动完成"

echo "[5/6] 初始化备节点"
if [ $STANDBY_COUNT -eq 0 ]; then
    echo "  跳过: 无备节点"
else
    for i in "${!STANDBY_CONTAINERS[@]}"; do
        standby_container="${STANDBY_CONTAINERS[$i]}"
        standby_name="${STANDBY_NAMES[$i]}"
        standby_ip="${STANDBY_IPS[$i]}"
        
        printf "  [%d/%d] %s ... " $((i+1)) $STANDBY_COUNT $standby_name
        
        # 清理和备份
        docker exec $standby_container su - omm -c 'rm -rf /home/omm/data/*' > /dev/null 2>&1
        docker exec $standby_container su - omm -c "gs_basebackup -h $PRIMARY_IP -p 5432 -U omm -D /home/omm/data -X stream" > /tmp/backup_${standby_name}.log 2>&1 || { 
            echo "❌ 失败"
            echo "错误详情:"
            cat /tmp/backup_${standby_name}.log 2>/dev/null || echo "无法读取错误日志"
            exit 1 
        }
        
        # 配置备节点
        docker exec $standby_container su - omm -c "
            cat > /home/omm/data/recovery.conf << 'EOF'
standby_mode = 'on'
primary_conninfo = 'host=$PRIMARY_IP port=5432 user=omm application_name=$standby_name'
recovery_target_timeline = 'latest'
EOF
            chmod 600 /home/omm/data/recovery.conf
        " > /dev/null 2>&1
        
        # 备节点配置调整
        LOCAL_PORT=$((5434 + i * 2))
        LOCAL_HB_PORT=$((5435 + i * 2))
        docker exec $standby_container su - omm -c "
            sed -i '/replconninfo/d; /hot_standby[[:space:]]*=/d; /max_standby_streaming_delay/d; /wal_receiver_status_interval/d; /hot_standby_feedback/d; /application_name[[:space:]]*=/d' /home/omm/data/postgresql.conf
            cat >> /home/omm/data/postgresql.conf << 'EOF'
replconninfo1 = 'localhost=$standby_ip localport=$LOCAL_PORT localheartbeatport=$LOCAL_HB_PORT localservice=5432 remotehost=$PRIMARY_IP remoteport=$LOCAL_PORT remoteheartbeatport=$LOCAL_HB_PORT remoteservice=5432 application_name=$standby_name'
application_name = '$standby_name'
hot_standby = on
hot_standby_feedback = on
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
EOF
        " > /dev/null 2>&1
        
        echo "✓"
        rm -f /tmp/backup_${standby_name}.log
    done
fi
echo "  ✓ 备节点初始化完成"

echo "✓ 集群初始化完成"
