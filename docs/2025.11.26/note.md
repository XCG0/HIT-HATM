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

> 创建容器时自动执行脚本 [init-container.sh](../../init-container.sh)，会拉取最新的镜像配置仓库并初始化数据库环境，建议定期更新镜像（`git pull`）以获取最新的代码和配置。
>
> ```powershell
>    # Windows PowerShell
>    docker run -itd --name opengauss-node0 `
>      --hostname node0 `
>      --privileged=true `
>      -p 127.0.0.1:5432:5432 `
>      -v ${PWD}/init-container.sh:/init-container.sh:ro `
>      xcg0/opengauss-openeuler_22.03:x86_64 `
>      bash /init-container.sh
>
>    # macOS / Linux
>    docker run -itd --name opengauss-node0 \
>      --hostname node0 \
>      --privileged=true \
>      -p 127.0.0.1:5432:5432 \
>      -v $(pwd)/init-container.sh:/init-container.sh:ro \
>      xcg0/opengauss-openeuler_22.03:aarch64 \
>      bash /init-container.sh
>    ```
    
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

## 在 VS Code 中调试 openGauss 数据库内核

### 调试配置

已为工作区添加了调试配置（见 [launch.json](../../.vscode/launch.json)）：

| 配置名称 | 用途 | 使用场景 |
|---------|------|---------|
| **编译+调试客户端程序** | 调试 libpq 客户端程序 | 调试自己编写的数据库应用程序 |
| **附加到 gaussdb 进程（内核调试）** | 附加到运行中的进程 | 调试数据库内核 |

### 快速开始

1. **启动数据库**
   ```bash
   su - omm
   gs_ctl start -D /home/omm/data -Z single_node -l /home/omm/log/opengauss.log
   ```

2. **在 VS Code 中启动调试**
  - 按 `F5` 选择"附加到 gaussdb 进程（内核调试）"
  - 在进程列表中选择目标进程（这一步可能需要十几秒左右加载进程列表）
  - 设置断点并执行 SQL 触发

  ![在 VS Code 中启动调试](../../images/image-7.png)

### 常用调试场景

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

### 查询执行流程调试示例

以 `exec_simple_query` 断点为例。监视变量：
1. `query_string`：当前执行的 SQL 语句
2. `parsetree_list`：解析后的语法树列表
3. `dest`：结果发送目标

完整命令流程，[详细说明](./exec_simple_query.md)：

| 序号 | 终端1 (GDB) | 终端2 (gsql) | 命令 | 简单说明 |
|------:|:-------------:|:--------------:|:------:|:----|
| 1 | 🔴 |&nbsp;| `gdb -p 1148` | 附加到主进程(PID 从 4.2 步骤获得) |
| 2 | 🔴 |&nbsp;| `handle SIGUSR1 nostop noprint pass` | 忽略 SIGUSR1 信号(避免调试中断) |
| 3 | 🔴 |&nbsp;| `break exec_simple_query` | 在 SQL 执行入口函数设置断点 |
| 4 | 🔴 |&nbsp;| `continue` | 继续执行,等待断点触发 |
| 5 |&nbsp;| 🟡 | `gsql -d postgres` | 连接到 postgres 数据库 |
| 6 |&nbsp;| 🟡 | `SELECT 1;` | 执行 SQL(触发 GDB 断点) |
| 7 | 🔴 |&nbsp;| `list` | 显示当前断点处的源代码 |
| 8 | 🔴 |&nbsp;| `print query_string` | 打印当前执行的 SQL 语句 |
| 9 | 🔴 |&nbsp;| `backtrace` | 显示完整调用栈(函数调用链) |
| 10 | 🔴 |&nbsp;| `next` | 单步执行(跳过函数) |
| 11 | 🔴 |&nbsp;| `step` | 单步进入函数内部 |
| 12 | 🔴 |&nbsp;| `info locals` | 显示所有局部变量 |
| 13 | 🔴 |&nbsp;| `continue` | 继续执行到下一个断点或结束 |
| 14 |&nbsp;| 🟡 | (查看 SQL 执行结果) | 终端显示查询结果: `?column? = 1` |
| 15 | 🔴 |&nbsp;| `quit` → `y` | 退出 GDB,选择 `y` 确认分离进程 |
| 16 |&nbsp;| 🟡 | `\q` | 退出 gsql 客户端 |

> 注意终端返回了执行结果后再执行下一条命令，没返回结果继续 `continue` 即可。
>
> VS Code 调试界面中也可以完成上述 GDB 命令操作，终端 1 可以使用 VS Code 调试界面，终端 2 使用 VS Code 内置终端即可。
>
> ![VS Code 调试 exec_simple_query](images/image-8.png)