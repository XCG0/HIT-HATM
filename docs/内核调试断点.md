# Gdb 调试 opengauss 内核

本文档介绍如何使用 GDB 调试 openGauss 数据库内核，重点演示在 SQL 执行入口函数 `exec_simple_query` 处设置断点并单步调试 SQL 查询的过程。

## 步骤 1：gdb -p <pid>

使用 gdb 附加到进程 ID 为 1148 的 gaussdb 主进程：

```bash
[root@node0 home]# gdb -p 1148
GNU gdb (GDB) openEuler 11.1-7.oe2203
...
Attaching to process 1148          # 正在附加到进程
[New LWP 1149]                     # 发现新的轻量级进程（线程）
[New LWP 1153]                     # WalWriter、BgWriter 等后台线程
...
[Thread debugging using libthread_db enabled]       # 启用线程调试支持
Using host libthread_db library "/usr/lib64/libthread_db.so.1".
0x0000745699cc68df in poll () from /usr/lib64/libc.so.6    # 当前程序停在 poll 系统调用
```

## 步骤 2：handle SIG...

配置 GDB 忽略 PostgreSQL 内部信号，避免调试时频繁中断：

- `SIGUSR1`：用户自定义信号 1，用于进程间通信
- `SIGUSR2`：用户自定义信号 2，用于进程间通信
- `SIGPIPE`：管道破裂信号，忽略以防止写入已关闭的管道时终止进程
- `SIGCHLD`：子进程状态改变信号，忽略以防止僵尸进程

```bash

(gdb) handle SIGUSR1 nostop noprint pass
Signal        Stop      Print   Pass to program      Description
SIGUSR1       No        No      Yes         User defined signal 1
# nostop: 收到信号时不停止程序
# noprint: 不打印信号信息
# pass: 将信号传递给程序处理

(gdb) handle SIGUSR2 nostop noprint pass
Signal        Stop      Print   Pass to program      Description
SIGUSR2       No        No      Yes         User defined signal 2

(gdb) handle SIGPIPE nostop noprint pass
Signal        Stop      Print   Pass to program      Description
SIGPIPE       No        No      Yes         Broken pipe

(gdb) handle SIGCHLD nostop noprint pass
Signal        Stop      Print   Pass to program      Description
SIGCHLD       No        No      Yes         Child status changed
```

## 步骤 3：break exec_simple_query

在 exec_simple_query 函数入口设置断点（SQL 执行的入口点）：

```bash
(gdb) break exec_simple_query
Breakpoint 1 at 0x1a2a366: file postgres.cpp, line 2370.
# 断点 1 设置在 postgres.cpp 文件的第 2370 行
```

## 步骤 4: gsql -d postgres

gsql 连接数据库，执行 SQL 触发断点

```bash
[omm@node0 home]$ gsql -d postgres
gsql ((openGauss 5.0.5 build d4f4dd12) compiled at 2025-10-31 14:28:36 commit 0 last mr 8501 debug)
Non-SSL connection (SSL connection is recommended when requiring high-security)
Type "help" for help.

openGauss=# SELECT 1;
```

## 步骤 5：continue

继续执行程序，等待断点触发：

```bash
(gdb) continue
Continuing.
...
# 当有客户端执行 SQL 查询时，断点被触发
Thread 43 "worker" hit Breakpoint 1, exec_simple_query (query_string=0x74555ef62060 "select name, setting from pg_settings where name in ('connection_info')", messageType=QUERY_MESSAGE, msg=0x745560808d60) at postgres.cpp:2370
2370    {
# 工作线程 43 触发断点，正在执行的 SQL 是查询 pg_settings
```

## 步骤 6：list

查看源代码：

```bash
(gdb) list
2365     * Add default parameter unint16 messageType. Its default vaule is 0. If we receive
2366     * hybridmesage, this parameter will be set to 1 to tell us the normal query string
2367     * followed by information string. query_string = normal querystring + message.
2368     */
2369    static void exec_simple_query(const char* query_string, MessageType messageType, StringInfo msg = NULL)
2370    {                                                      # ← 当前停止位置
2371        CommandDest dest = (CommandDest)t_thrd.postgres_cxt.whereToSendOutput;
2372        MemoryContext oldcontext;
2373        MemoryContext OptimizerContext;
2374        AttachInfoContext attachInfoCtx = {0};
```

## 步骤 7：print query_string

- 打印当前正在执行的 SQL 语句：

```bash
(gdb) print query_string
$1 = 0x74555ef62060 "select name, setting from pg_settings where name in ('connection_info')"
# 显示 query_string 指向的字符串内容
```

## 步骤 8：backtrace

查看完整的函数调用栈，了解执行路径：

```bash
(gdb) backtrace
#0  exec_simple_query (
    query_string=0x74555ef62060 "select name, setting from pg_settings where name in ('connection_info')", messageType=QUERY_MESSAGE, 
    msg=0x745560808d60) at postgres.cpp:2370
    # 当前函数：SQL 执行入口

/#1  0x0000000001a392d1 in PostgresMain (argc=1, argv=0x7455adbe3228, dbname=0x7455adbe21f8 "postgres", username=0x7455adbe21b0 "omm") at postgres.cpp:9142
    # 调用者：PostgreSQL 主处理循环

/#2  0x0000000001978e1e in BackendRun (port=0x745560809250) at postmaster.cpp:9249
    # 后端进程运行函数

/#3  0x0000000001989e1f in GaussDbThreadMain<(knl_thread_role)1> (arg=0x7455c1447048) at postmaster.cpp:13703
    # 数据库线程主函数

/#4  0x00000000019856d3 in InternalThreadFunc (args=0x7455c1447048) at postmaster.cpp:14324
    # 内部线程函数

/#5  0x000000000256424f in ThreadStarterFunc (arg=0x7455c1447038) at gs_thread.cpp:382
    # 线程启动函数

/#6  0x0000745699c5122a in ?? () from /usr/lib64/libc.so.6
/#7  0x0000745699cd3a60 in ?? () from /usr/lib64/libc.so.6
    # 系统库函数（创建线程）
```

## 步骤 9：next

单步执行（不进入函数）：

```bash
(gdb) next
# 切换到另一个线程
[New Thread 0x745562dcf640 (LWP 210084)]
[Switching to Thread 0x7455657df640 (LWP 208272)]

# 客户端执行另一条 SQL 时再次触发断点
Thread 41 "worker" hit Breakpoint 1, exec_simple_query (query_string=0x745563484060 "show sql_compatibility", messageType=QUERY_MESSAGE, msg=0x7455657a8d60) at postgres.cpp:2370
2370    {
# 工作线程 41 执行 SHOW 命令
```

## 步骤 10：step

单步进入函数内部：

```bash
(gdb) step
2371        CommandDest dest = (CommandDest)t_thrd.postgres_cxt.whereToSendOutput;
# 进入函数第一行，获取输出目标
```

## 步骤 11：info locals

查看当前函数的所有局部变量：

```bash
(gdb) info locals
dest = 37                          # 输出目标（未初始化的垃圾值）
oldcontext = 0x7455657a8bec        # 旧的内存上下文
OptimizerContext = 0x1600002000    # 优化器内存上下文
attachInfoCtx = {...}              # 附加信息上下文
parsetree_list = 0x7455657a8bb0    # 解析树列表（尚未初始化）
parsetree_item = 0x7456fffffffe    # 当前解析树项
save_log_statement_stats = 62      # 是否保存语句统计
was_logged = 116                   # 是否已记录日志
isTopLevel = true                  # 是否顶层 SQL（非嵌套）
msec_str = "..."                   # 毫秒字符串
query_string_locationlist = 0x4f   # 查询字符串位置列表
stmt_num = 29782                   # 语句编号
query_string_len = 1761997866      # 查询字符串长度（未初始化）
query_string_single = 0x13e8e96    # 单条查询字符串指针
is_multistmt = false               # 是否多语句
is_compl_sql = false               # 是否完整 SQL
savedisAllowCommitRollback = 85    # 保存的提交回滚允许标志
needResetErrMsg = false            # 是否需要重置错误消息
sql_query_string = 0x13e8590       # SQL 查询字符串
info_query_string = 0x7455657a8a90 # 信息查询字符串
__func__ = "exec_simple_query"     # 当前函数名
runLightProxyCheck = false         # 是否运行轻量代理检查
runOpfusionCheck = false           # 是否运行算子融合检查
current_user = 29781               # 当前用户 ID
is_multi_query_text = 16           # 是否多查询文本
```

## 步骤 12：continue

继续执行程序：

```gdb
(gdb) continue
Continuing.

# 客户端执行 SELECT 1; 时再次触发断点
Thread 41 "worker" hit Breakpoint 1, exec_simple_query (query_string=0x745563484060 "SELECT 1;", messageType=QUERY_MESSAGE, msg=0x7455657a8d60) at postgres.cpp:2370
2370    {
# 这次执行的是简单的 SELECT 1 查询
```

此时执行 `gsql` 客户端会收到查询结果：

```bash
 ?column? 
----------
        1
(1 row)
```

## 步骤 13：quit

退出调试器：

```bash
(gdb) quit
A debugging session is active.

        Inferior 1 [process 1148] will be detached.
        # 警告：有一个活动的调试会话，进程 1148 将被分离

Quit anyway? (y or n) y            # 确认退出
Detaching from program: /home/openGauss/openGauss-server/mppdb_temp_install/bin/gaussdb, process 1148
[Inferior 1 (process 1148) detached]    # 已从进程分离
```

