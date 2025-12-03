#!/bin/bash
# openGauss 多节点集群 - SSH 互信配置脚本
set -e
export MSYS_NO_PATHCONV=1

echo "[1/4] 发现集群节点"
CONTAINERS=()
NODE_IPS=()
NODE_NAMES=()

# 主节点
if ! docker ps -q -f name=opengauss-primary | grep -q .; then
    echo "错误: 未找到主节点"
    exit 1
fi
CONTAINERS+=("opengauss-primary")
NODE_IPS+=("172.18.0.10")
NODE_NAMES+=("primary")

# 备节点
STANDBY_COUNT=0
for i in {1..10}; do
    if docker ps -q -f name=opengauss-standby$i | grep -q .; then
        CONTAINERS+=("opengauss-standby$i")
        NODE_IPS+=("172.18.0.$((10 + i))")
        NODE_NAMES+=("standby$i")
        STANDBY_COUNT=$((STANDBY_COUNT + 1))
    fi
done

echo "  发现: 1主+${STANDBY_COUNT}备"

echo "[2/4] 配置 SSH 服务"
for i in "${!CONTAINERS[@]}"; do
    container="${CONTAINERS[$i]}"
    printf "  [%d/%d] %s ... " $((i+1)) ${#CONTAINERS[@]} "${NODE_NAMES[$i]}"
    
    docker exec $container bash -c '
        command -v sshd &> /dev/null || yum install -y openssh-server openssh-clients > /dev/null 2>&1
        [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A > /dev/null 2>&1
        /usr/sbin/sshd 2>/dev/null || true
        mkdir -p ~/.ssh
        [ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa > /dev/null 2>&1
        cat > ~/.ssh/config << "EOF"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOF
        chmod 600 ~/.ssh/config
    ' > /dev/null 2>&1
    
    echo "✓"
done

echo "[3/4] 配置 root 互信"
# 收集公钥
declare -a ROOT_PUBKEYS
for i in "${!CONTAINERS[@]}"; do
    ROOT_PUBKEYS[$i]=$(docker exec ${CONTAINERS[$i]} cat /root/.ssh/id_rsa.pub 2>/dev/null)
done

# 分发公钥
for i in "${!CONTAINERS[@]}"; do
    container="${CONTAINERS[$i]}"
    printf "  [%d/%d] %s ... " $((i+1)) ${#CONTAINERS[@]} "${NODE_NAMES[$i]}"
    
    docker exec $container bash -c 'mkdir -p ~/.ssh && > ~/.ssh/authorized_keys' > /dev/null 2>&1
    for pubkey in "${ROOT_PUBKEYS[@]}"; do
        docker exec $container bash -c "echo '$pubkey' >> ~/.ssh/authorized_keys" > /dev/null 2>&1
    done
    docker exec $container bash -c 'chmod 600 ~/.ssh/authorized_keys' > /dev/null 2>&1
    
    echo "✓"
done

echo "[4/4] 配置 omm 互信"
# 生成 omm 密钥
for i in "${!CONTAINERS[@]}"; do
    docker exec ${CONTAINERS[$i]} bash -c 'su - omm -c "
        mkdir -p ~/.ssh
        [ -f ~/.ssh/id_rsa ] || ssh-keygen -t rsa -b 2048 -N \"\" -f ~/.ssh/id_rsa > /dev/null 2>&1
        cat > ~/.ssh/config << \"EOF\"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    LogLevel ERROR
EOF
        chmod 600 ~/.ssh/config
    "' > /dev/null 2>&1
done

# 收集 omm 公钥
declare -a OMM_PUBKEYS
for i in "${!CONTAINERS[@]}"; do
    OMM_PUBKEYS[$i]=$(docker exec ${CONTAINERS[$i]} su - omm -c "cat ~/.ssh/id_rsa.pub" 2>/dev/null)
done

# 分发 omm 公钥
for i in "${!CONTAINERS[@]}"; do
    container="${CONTAINERS[$i]}"
    printf "  [%d/%d] %s ... " $((i+1)) ${#CONTAINERS[@]} "${NODE_NAMES[$i]}"
    
    docker exec $container su - omm -c 'mkdir -p ~/.ssh && > ~/.ssh/authorized_keys' > /dev/null 2>&1
    for pubkey in "${OMM_PUBKEYS[@]}"; do
        docker exec $container su - omm -c "echo '$pubkey' >> ~/.ssh/authorized_keys" > /dev/null 2>&1
    done
    docker exec $container su - omm -c 'chmod 600 ~/.ssh/authorized_keys' > /dev/null 2>&1
    
    echo "✓"
done

echo "✓ SSH 互信配置完成"
