# openGauss 多节点集群部署指南

本文档介绍如何使用 Docker 容器部署 openGauss 一主两备的多节点集群。

## 架构说明

- **主节点 (Primary)**: opengauss-primary，负责读写操作
- **备节点1 (Standby1)**: opengauss-standby1，实时同步主节点数据
- **备节点2 (Standby2)**: opengauss-standby2，实时同步主节点数据

## 部署步骤

### 前置准备

确保已安装：
- Docker Desktop（Windows）或 Docker Engine（Linux/macOS）
- 已拉取镜像：`xcg0/opengauss-openeuler_22.03:x86_64`

### 1. 创建 Docker 网络和容器

运行脚本创建自定义网络和 3 个容器节点：

```bash
# Windows PowerShell
cd docs\multi-node\scripts
.\01_create_containers.ps1

# Linux/macOS
cd docs/multi-node/scripts
bash 01_create_containers.sh
```

该脚本会：
- 创建名为 `opengauss-network` 的 Docker 网络
- 启动 3 个容器并分配固定 IP：
  - `opengauss-primary`: 172.18.0.10
  - `opengauss-standby1`: 172.18.0.11
  - `opengauss-standby2`: 172.18.0.12

### 2. 配置 SSH 互信

在**主节点**容器中执行：

```bash
docker exec -it opengauss-primary bash
cd /home/scripts
bash 02_setup_ssh.sh
```

该脚本会自动配置所有节点间的 SSH 免密登录。

### 3. 初始化集群

在**主节点**容器中执行：

```bash
cd /home/scripts
bash 03_init_cluster.sh
```

该脚本会：
- 在主节点初始化数据库
- 配置主备复制
- 在备节点创建从库

### 4. 启动集群

在**主节点**容器中执行：

```bash
cd /home/scripts
bash 04_start_cluster.sh
```

### 5. 验证集群状态

```bash
cd /home/scripts
bash 05_verify_cluster.sh
```

验证内容包括：
- 主节点状态
- 备节点同步状态
- 数据复制测试
- 故障切换测试（可选）

## 集群管理

### 查看集群状态

```bash
# 在主节点执行
gs_ctl query -D /home/omm/data

# 查看主备同步状态
gs_ctl build -D /home/omm/data -q
```

### 停止集群

```bash
# 按顺序停止：先备节点，后主节点
docker exec opengauss-standby2 su - omm -c "gs_ctl stop -D /home/omm/data"
docker exec opengauss-standby1 su - omm -c "gs_ctl stop -D /home/omm/data"
docker exec opengauss-primary su - omm -c "gs_ctl stop -D /home/omm/data"
```

### 启动集群

```bash
# 按顺序启动：先主节点，后备节点
docker exec opengauss-primary su - omm -c "gs_ctl start -D /home/omm/data"
docker exec opengauss-standby1 su - omm -c "gs_ctl start -D /home/omm/data"
docker exec opengauss-standby2 su - omm -c "gs_ctl start -D /home/omm/data"
```

## 故障切换

### 手动故障切换

当主节点故障时，可以将备节点提升为主节点：

```bash
# 在备节点执行
su - omm
gs_ctl failover -D /home/omm/data
```

### 主节点降级为备节点

```bash
# 在原主节点执行
su - omm
gs_ctl build -D /home/omm/data -b full
```

## 常见问题

### 1. 容器间网络不通

检查防火墙和 Docker 网络配置：
```bash
docker network inspect opengauss-network
```

### 2. SSH 连接失败

确保 SSH 服务已启动：
```bash
systemctl status sshd
systemctl start sshd
```

### 3. 数据同步延迟

检查网络状况和数据库日志：
```bash
tail -f /home/omm/log/opengauss.log
```

## 参考资料

- [openGauss 官方文档 - 主备部署](https://docs.opengauss.org/)
- [Docker 网络配置](https://docs.docker.com/network/)
