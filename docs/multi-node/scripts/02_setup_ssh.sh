#!/bin/bash
# openGauss 多节点集群 - SSH 互信配置脚本
# 在主节点容器内运行此脚本

set -e

echo "=== SSH 互信配置 ==="
echo ""

# 节点信息
PRIMARY_IP="172.18.0.10"
STANDBY1_IP="172.18.0.11"
STANDBY2_IP="172.18.0.12"

NODES=("$PRIMARY_IP" "$STANDBY1_IP" "$STANDBY2_IP")
NODE_NAMES=("primary" "standby1" "standby2")

# 确保 SSH 服务已安装并启动
echo "检查并启动 SSH 服务..."
if ! command -v sshd &> /dev/null; then
    echo "安装 OpenSSH Server..."
    yum install -y openssh-server openssh-clients
fi

# 启动 SSH 服务
systemctl enable sshd
systemctl start sshd

# 检查 SSH 服务状态
if ! systemctl is-active --quiet sshd; then
    echo "错误: SSH 服务启动失败"
    exit 1
fi
echo "✓ SSH 服务运行正常"
echo ""

# 为 root 用户生成 SSH 密钥（如果不存在）
echo "配置 root 用户 SSH 密钥..."
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
    echo "✓ SSH 密钥生成成功"
else
    echo "✓ SSH 密钥已存在"
fi
echo ""

# 配置 SSH 客户端，跳过主机密钥检查
echo "配置 SSH 客户端..."
mkdir -p ~/.ssh
cat > ~/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOF
chmod 600 ~/.ssh/config
echo "✓ SSH 客户端配置完成"
echo ""

# 在所有节点上启动 SSH 服务并配置
echo "在所有节点上配置 SSH..."
for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    echo "配置节点: $node_name ($node_ip)"
    
    # 通过 docker exec 在其他容器中执行命令
    if [ "$node_ip" != "$PRIMARY_IP" ]; then
        container_name="opengauss-${node_name}"
        
        # 安装并启动 SSH
        docker exec $container_name bash -c "
            if ! command -v sshd &> /dev/null; then
                yum install -y openssh-server openssh-clients
            fi
            systemctl enable sshd
            systemctl start sshd
            
            # 生成 SSH 密钥
            if [ ! -f ~/.ssh/id_rsa ]; then
                ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa
            fi
            
            # 配置 SSH 客户端
            mkdir -p ~/.ssh
            cat > ~/.ssh/config << 'EOFINNER'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOFINNER
            chmod 600 ~/.ssh/config
        " 2>/dev/null
        
        echo "  ✓ $node_name SSH 配置完成"
    else
        echo "  ✓ 当前节点，跳过"
    fi
done
echo ""

# 分发公钥到所有节点
echo "分发 SSH 公钥..."
PRIMARY_PUBKEY=$(cat ~/.ssh/id_rsa.pub)

for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    echo "分发公钥到: $node_name ($node_ip)"
    
    if [ "$node_ip" = "$PRIMARY_IP" ]; then
        # 主节点
        echo "$PRIMARY_PUBKEY" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    else
        # 备节点 - 通过 docker exec
        container_name="opengauss-${node_name}"
        docker exec $container_name bash -c "
            mkdir -p ~/.ssh
            echo '$PRIMARY_PUBKEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        "
        
        # 获取备节点的公钥并添加到主节点
        STANDBY_PUBKEY=$(docker exec $container_name cat ~/.ssh/id_rsa.pub)
        echo "$STANDBY_PUBKEY" >> ~/.ssh/authorized_keys
        
        # 将备节点公钥分发到其他节点
        for j in "${!NODES[@]}"; do
            other_ip="${NODES[$j]}"
            other_name="${NODE_NAMES[$j]}"
            
            if [ "$other_ip" != "$node_ip" ]; then
                if [ "$other_ip" = "$PRIMARY_IP" ]; then
                    # 已经添加到主节点
                    continue
                else
                    other_container="opengauss-${other_name}"
                    docker exec $other_container bash -c "
                        mkdir -p ~/.ssh
                        echo '$STANDBY_PUBKEY' >> ~/.ssh/authorized_keys
                        chmod 600 ~/.ssh/authorized_keys
                    "
                fi
            fi
        done
    fi
    echo "  ✓ 公钥分发完成"
done

# 去重 authorized_keys
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "✓ SSH 公钥分发完成"
echo ""

# 配置 omm 用户的 SSH 互信
echo "配置 omm 用户 SSH 互信..."
for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    echo "配置 omm@$node_name"
    
    if [ "$node_ip" = "$PRIMARY_IP" ]; then
        # 主节点
        su - omm -c "
            mkdir -p ~/.ssh
            if [ ! -f ~/.ssh/id_rsa ]; then
                ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa
            fi
            cat > ~/.ssh/config << 'EOFOMM'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOFOMM
            chmod 600 ~/.ssh/config
        "
        
        # 获取 omm 公钥
        OMM_PUBKEY=$(su - omm -c "cat ~/.ssh/id_rsa.pub")
        
        # 添加到本地
        su - omm -c "
            echo '$OMM_PUBKEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        "
    else
        # 备节点
        container_name="opengauss-${node_name}"
        docker exec $container_name su - omm -c "
            mkdir -p ~/.ssh
            if [ ! -f ~/.ssh/id_rsa ]; then
                ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa
            fi
            cat > ~/.ssh/config << 'EOFOMM'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOFOMM
            chmod 600 ~/.ssh/config
        "
        
        # 分发主节点 omm 公钥到备节点
        docker exec $container_name su - omm -c "
            echo '$OMM_PUBKEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        "
        
        # 获取备节点 omm 公钥
        STANDBY_OMM_PUBKEY=$(docker exec $container_name su - omm -c "cat ~/.ssh/id_rsa.pub")
        
        # 添加到主节点 omm
        su - omm -c "
            echo '$STANDBY_OMM_PUBKEY' >> ~/.ssh/authorized_keys
        "
        
        # 分发到其他备节点
        for j in "${!NODES[@]}"; do
            other_ip="${NODES[$j]}"
            other_name="${NODE_NAMES[$j]}"
            
            if [ "$other_ip" != "$node_ip" ] && [ "$other_ip" != "$PRIMARY_IP" ]; then
                other_container="opengauss-${other_name}"
                docker exec $other_container su - omm -c "
                    echo '$STANDBY_OMM_PUBKEY' >> ~/.ssh/authorized_keys
                    echo '$OMM_PUBKEY' >> ~/.ssh/authorized_keys
                    chmod 600 ~/.ssh/authorized_keys
                "
            fi
        done
    fi
    echo "  ✓ omm@$node_name 配置完成"
done

# 去重 omm 的 authorized_keys
su - omm -c "
    sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
"

for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    if [ "$node_ip" != "$PRIMARY_IP" ]; then
        container_name="opengauss-${node_name}"
        docker exec $container_name su - omm -c "
            sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        "
    fi
done

echo "✓ omm 用户 SSH 互信配置完成"
echo ""

# 验证 SSH 连接
echo "=== 验证 SSH 连接 ==="
echo ""

echo "验证 root 用户 SSH 连接..."
for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    if ssh -o ConnectTimeout=5 root@$node_ip "hostname" &>/dev/null; then
        echo "  ✓ root@$node_name ($node_ip) 连接成功"
    else
        echo "  ✗ root@$node_name ($node_ip) 连接失败"
    fi
done
echo ""

echo "验证 omm 用户 SSH 连接..."
for i in "${!NODES[@]}"; do
    node_ip="${NODES[$i]}"
    node_name="${NODE_NAMES[$i]}"
    
    if su - omm -c "ssh -o ConnectTimeout=5 omm@$node_ip 'hostname'" &>/dev/null; then
        echo "  ✓ omm@$node_name ($node_ip) 连接成功"
    else
        echo "  ✗ omm@$node_name ($node_ip) 连接失败"
    fi
done
echo ""

echo "=== SSH 互信配置完成 ==="
echo "下一步: 初始化集群"
echo "运行: cd /home/scripts && bash 03_init_cluster.sh"
