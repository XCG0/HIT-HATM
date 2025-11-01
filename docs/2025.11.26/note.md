# 工作总结

## 扁平化镜像

Docker 镜像是分层的，删除操作只是在新的一层标记文件为“已删除”，
原始文件仍然存在于之前的层中，占用空间。

`docker commit` 会保留所有历史层，打包的镜像体积较大，可以通过以下步骤清理容器内不必要的文件，生成扁平化镜像，从而减小镜像体积，提高上传速度：

- 容器内执行：

    ```shell
    # 在容器内停止数据库
    su - omm
    gs_ctl stop -D /home/omm/data

    cd /home
    bash cleanup.sh
    ```
- 在宿主机执行：

    ```shell
    # 1. 导出容器为 tar 文件（）
    docker export opengauss-node0 > opengauss-clean.tar

    # 2. 导入为新镜像
    cat opengauss-clean.tar | docker import \
      --change 'CMD ["/bin/bash"]' \
      --change 'WORKDIR /home' \
      --change 'ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
      - xcg0/opengauss-openeuler_22.03:x86_64

    # 3. 推送新镜像
    docker login
    docker push xcg0/opengauss-openeuler_22.03:x86_64

    # 4. 清理临时文件
    rm opengauss-clean.tar
    ```
    
## 验证 openGauss 调试模式编译

验证数据库是否以调试模式编译，确保可以使用 GDB 进行源码级调试。

> 验证结果
>
> ✅ 如果以下检查都通过，说明：
> - 编译时已启用调试模式
> - 二进制文件包含完整的 DWARF 调试符号
> - 可以使用 GDB 进行源码级调试、设置断点、查看变量等
> 
> ⚠️ **注意：** 调试版本的可执行文件体积较大，生产环境可使用 `strip` 命令移除调试符号以减小体积。

### 1. 检查编译配置

```bash
# 查看 Makefile 中的调试配置
grep -E "^enable_debug|^enable_cassert" /home/openGauss/openGauss-server/src/Makefile.global
```

**期望输出：**
```
enable_cassert  = yes
enable_debug    = yes
```

### 2. 验证二进制文件包含调试信息

```bash
# 检查可执行文件类型
file /home/openGauss/openGauss-server/mppdb_temp_install/bin/gaussdb
```

**关键标志：**
- `with debug_info` - 包含调试信息
- `not stripped` - 未剥离符号表

### 3. 检查 DWARF 调试段

```bash
# 查看 ELF 文件中的调试段
readelf -S /home/openGauss/openGauss-server/mppdb_temp_install/bin/gaussdb | grep "\.debug_"
```

**应包含的调试段：**
- `.debug_info` - 核心调试信息（变量、函数等）
- `.debug_line` - 源代码行号映射
- `.debug_str` - 调试字符串
- `.debug_abbrev` - 调试信息缩写表
- `.debug_aranges` - 地址范围信息
- `.debug_loc` - 位置列表
- `.debug_ranges` - 地址范围
- `.debug_macro` - 宏定义信息

## 在 Docker 容器中推送代码至 GitHub

```bash
git init
git remote add origin https://gitee.com/XuChGu/HIT-HADB.git
git pull origin main
git checkout -f main
```

> 创建容器时自动执行脚本 [init-container.sh](../../init-container.sh) 完成上述操作。

## 在 VS Code 中调试 openGauss 数据库内核

### ⚡ 快速开始

1. **启动数据库**
   ```bash
   su - omm
   gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
   ```

2. **找到要调试的进程**
   ```bash
   ps aux | grep gaussdb
   ```

3. **在 VS Code 中启动调试**
   - 按 `F5` 选择"附加到 gaussdb 进程（内核调试）"
   - 在进程列表中选择目标进程
   - 设置断点并执行 SQL 触发

### 🔧 调试配置

已为工作区添加了调试配置（见 `.vscode/launch.json`）：

| 配置名称 | 用途 | 使用场景 |
|---------|------|---------|
| **编译+调试客户端程序** | 调试 libpq 客户端程序 | 调试自己编写的数据库应用程序 |
| **附加到 gaussdb 进程（内核调试）** | 附加到运行中的进程 | ⭐ 推荐：调试数据库内核 |

### 🎯 常用调试场景

| 场景 | 关键断点 | 调试目标 | 示例 SQL |
|------|---------|---------|---------|
| **1. 查询执行流程** | `exec_simple_query()`<br>`pg_parse_query()`<br>`pg_plan_queries()`<br>`ExecutorRun()` | SQL 解析→优化→执行完整流程 | `INSERT INTO test VALUES (1, 'x');`<br>`SELECT * FROM test;` |
| **2. 事务和 MVCC** | `StartTransaction()`<br>`GetTransactionSnapshot()`<br>`HeapTupleSatisfiesMVCC()`<br>`CommitTransaction()` | 快照隔离、可见性判断 | 两会话并发读写同一行 |
| **3. 锁机制** | `LockAcquire()`<br>`LockRelease()`<br>`DeadLockCheck()`<br>`ProcSleep()` | 锁冲突、死锁检测 | 两会话交叉更新不同行 |
| **4. 缓冲区管理** | `ReadBuffer()`<br>`BufferAlloc()`<br>`FlushBuffer()`<br>`StrategyGetBuffer()` | 页面读取、缓冲区替换策略 | 大表全表扫描 |
| **5. 索引操作** | `_bt_search()`<br>`_bt_insert()`<br>`_bt_split()` | B-Tree 查找/插入/分裂 | `CREATE INDEX`<br>索引查询 |
| **6. WAL 和恢复** | `XLogInsert()`<br>`XLogFlush()`<br>`StartupXLOG()`<br>`redo()` | 日志写入、崩溃恢复 | 模拟崩溃后重启 |
| **7. 并发控制** | `heap_hot_search()`<br>`heap_page_prune()`<br>`vacuum_rel()` | HOT 更新、页面清理 | 频繁更新同一页数据 |
| **8. 优化器决策** | `planner()`<br>`create_plan()`<br>`cost_seqscan()`<br>`cost_index()` | 执行计划生成、代价估算 | `EXPLAIN` 对比不同查询计划 |
| **9. 内存管理** | `AllocSetAlloc()`<br>`MemoryContextReset()`<br>`MemoryContextDelete()` | 内存分配与释放 | 执行复杂查询观察内存 |
| **10. 扩展功能** | `ExecCallTriggerFunc()`<br>`exec_stmt_execsql()`<br>`fmgr_info()` | 触发器、存储过程执行 | 创建并触发触发器 |

### 📋 学习路径

| 阶段 | 推荐场景 | 难度 |
|------|---------|------|
| **初级** | 场景 1（查询执行流程） | ⭐ |
| **中级** | 场景 2（事务 MVCC）+ 场景 3（锁机制） | ⭐⭐ |
| **高级** | 场景 8（优化器）+ 场景 6（WAL 恢复） | ⭐⭐⭐ |
| **专家** | 场景 7（并发控制）+ 场景 4（缓冲区） | ⭐⭐⭐⭐ |

### 🛠️ 实用 GDB 命令

```bash
# 条件断点
(gdb) break heap_insert if relation->rd_id == 16384

# 查看调用栈
(gdb) backtrace

# 打印结构体
(gdb) p *relation
(gdb) p relation->rd_rel->relname.data

# 继续执行到下一个断点
(gdb) continue

# 单步执行（进入函数）
(gdb) step

# 单步执行（跳过函数）
(gdb) next
```