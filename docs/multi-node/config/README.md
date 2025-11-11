# openGauss 主备配置说明

## postgresql.conf 关键配置项

### 主节点配置
```conf
# 监听地址
listen_addresses = '*'

# 端口
port = 5432

# 最大连接数
max_connections = 200

# WAL 配置
wal_level = hot_standby
max_wal_senders = 10
wal_keep_segments = 256
hot_standby = on

# 同步备节点配置
synchronous_standby_names = 'ANY 1(standby1,standby2)'

# 归档配置
archive_mode = on
archive_command = 'cp %p /home/omm/archivelog/%f'
```

### 备节点配置
```conf
# 监听地址
listen_addresses = '*'

# 端口
port = 5432

# 最大连接数
max_connections = 200

# WAL 配置
wal_level = hot_standby
hot_standby = on
hot_standby_feedback = on

# 备节点特定配置
max_standby_streaming_delay = 30s
wal_receiver_status_interval = 10s
```

## pg_hba.conf 配置

### 主节点和备节点都需要
```conf
# 允许本地连接
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

# 允许集群内部连接
host    all             all             172.18.0.0/16           trust

# 流复制连接
host    replication     omm             172.18.0.0/16           trust
```

## recovery.conf 配置（备节点）

备节点1 (172.18.0.11):
```conf
standby_mode = 'on'
primary_conninfo = 'host=172.18.0.10 port=5432 user=omm application_name=standby1'
recovery_target_timeline = 'latest'
```

备节点2 (172.18.0.12):
```conf
standby_mode = 'on'
primary_conninfo = 'host=172.18.0.10 port=5432 user=omm application_name=standby2'
recovery_target_timeline = 'latest'
```

## 节点信息

| 节点 | 主机名 | IP地址 | 端口 | 角色 |
|------|--------|--------|------|------|
| 主节点 | primary | 172.18.0.10 | 5432 | Primary |
| 备节点1 | standby1 | 172.18.0.11 | 5432 | Standby |
| 备节点2 | standby2 | 172.18.0.12 | 5432 | Standby |

## 数据目录结构

```
/home/omm/
├── data/           # 数据库数据目录
├── log/            # 日志目录
├── tmp/            # 临时文件目录
├── archivelog/     # 归档日志目录
└── corefile/       # Core文件目录
```
