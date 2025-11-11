# openGauss 多节点集群快速部署指南

## 一、快速开始（5 分钟部署）

### Windows PowerShell

```powershell
# 1. 创建容器
cd docs\multi-node\scripts
.\01_create_containers.ps1

# 2. 进入主节点容器
docker exec -it opengauss-primary bash

# 在容器内执行以下命令：

# 3. 将脚本复制到容器内
mkdir -p /home/scripts
docker cp docs/multi-node/scripts/. opengauss-primary:/home/scripts/

# 退出容器后，重新进入
docker exec -it opengauss-primary bash

# 4. 配置 SSH 互信
cd /home/scripts
bash 02_setup_ssh.sh

# 5. 初始化集群
bash 03_init_cluster.sh

# 6. 启动集群
bash 04_start_cluster.sh

# 7. 验证集群
bash 05_verify_cluster.sh
```

### Linux / macOS

```bash
# 1. 创建容器
cd docs/multi-node/scripts
bash 01_create_containers.sh

# 2. 复制脚本到容器
docker cp . opengauss-primary:/home/scripts/

# 3. 进入主节点容器
docker exec -it opengauss-primary bash

# 在容器内执行：

# 4. 配置 SSH 互信
cd /home/scripts
bash 02_setup_ssh.sh

# 5. 初始化集群
bash 03_init_cluster.sh

# 6. 启动集群
bash 04_start_cluster.sh

# 7. 验证集群
bash 05_verify_cluster.sh
```

## 二、脚本说明

| 脚本文件 | 说明 | 执行环境 |
|---------|------|---------|
| `01_create_containers.ps1/.sh` | 创建 Docker 网络和 3 个容器 | 宿主机 |
| `02_setup_ssh.sh` | 配置所有节点间 SSH 互信 | 主节点容器（root） |
| `03_init_cluster.sh` | 初始化数据库和主备配置 | 主节点容器（root） |
| `04_start_cluster.sh` | 启动所有节点数据库 | 主节点容器（root） |
| `05_verify_cluster.sh` | 验证集群状态和主备同步 | 主节点容器（root） |
| `06_stop_cluster.sh` | 停止集群 | 主节点容器（root） |
| `07_test_failover.sh` | 测试故障切换 | 主节点容器（root） |

## 三、节点信息

| 节点 | 容器名 | 主机名 | IP 地址 | 宿主机端口 | 角色 |
|------|--------|--------|---------|-----------|------|
| 主节点 | opengauss-primary | primary | 172.18.0.10 | 15432 | Primary |
| 备节点1 | opengauss-standby1 | standby1 | 172.18.0.11 | 15433 | Standby |
| 备节点2 | opengauss-standby2 | standby2 | 172.18.0.12 | 15434 | Standby |

## 四、常用操作

### 连接数据库

```bash
# 从宿主机连接主节点
gsql -h 127.0.0.1 -p 15432 -d postgres -U omm

# 从容器内连接
docker exec -it opengauss-primary su - omm
gsql -d postgres -p 5432

# 连接备节点（只读）
docker exec -it opengauss-standby1 su - omm
gsql -d postgres -p 5432
```

### 查看集群状态

```bash
# 在主节点查看复制状态
docker exec opengauss-primary su - omm -c "
    gsql -d postgres -p 5432 -c 'SELECT * FROM pg_stat_replication;'
"

# 查看节点角色
docker exec opengauss-primary su - omm -c "gs_ctl query -D /home/omm/data"
```

### 停止/启动集群

```bash
# 停止集群
docker exec -it opengauss-primary bash
cd /home/scripts && bash 06_stop_cluster.sh

# 启动集群
docker exec -it opengauss-primary bash
cd /home/scripts && bash 04_start_cluster.sh
```

## 五、故障切换测试

```bash
# 进入主节点容器
docker exec -it opengauss-primary bash

# 执行故障切换测试脚本
cd /home/scripts
bash 07_test_failover.sh
```

该脚本会：
1. 停止当前主节点
2. 将 standby1 提升为新主节点
3. 验证新主节点可写入
4. 可选：将原主节点降级为备节点

## 六、清理环境

```bash
# 停止并删除所有容器
docker stop opengauss-primary opengauss-standby1 opengauss-standby2
docker rm opengauss-primary opengauss-standby1 opengauss-standby2

# 删除网络
docker network rm opengauss-network
```

## 七、故障排查

### SSH 连接失败

```bash
# 检查 SSH 服务
docker exec opengauss-primary systemctl status sshd

# 手动重启 SSH
docker exec opengauss-primary systemctl restart sshd
```

### 数据库无法启动

```bash
# 查看日志
docker exec opengauss-primary su - omm -c "tail -100 /home/omm/log/opengauss.log"

# 检查数据目录权限
docker exec opengauss-primary ls -la /home/omm/data
```

### 主备同步失败

```bash
# 检查 pg_hba.conf 配置
docker exec opengauss-primary cat /home/omm/data/pg_hba.conf

# 检查 recovery.conf（备节点）
docker exec opengauss-standby1 cat /home/omm/data/recovery.conf

# 查看备节点日志
docker exec opengauss-standby1 su - omm -c "tail -100 /home/omm/log/opengauss.log"
```

## 八、注意事项

1. **环境要求**：确保 Docker Desktop 已启动且有足够的资源（建议至少 4GB 内存）
2. **网络配置**：172.18.0.0/16 网段不与现有网络冲突
3. **数据持久化**：容器删除后数据会丢失，生产环境建议挂载数据卷
4. **安全性**：示例配置使用简单密码，生产环境需要加强安全配置
5. **端口映射**：确保宿主机端口 15432-15434 未被占用

## 九、进阶配置

详细配置说明请参考：
- [集群配置文件说明](../config/README.md)
- [主 README 文档](../README.md)
