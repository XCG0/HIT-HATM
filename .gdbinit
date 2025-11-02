# ============================================
# openGauss 调试专用 GDB 配置
# ============================================

# 忽略数据库内部信号（避免频繁中断）
handle SIGUSR1 nostop noprint pass
handle SIGUSR2 nostop noprint pass
handle SIGPIPE nostop noprint pass
handle SIGCHLD nostop noprint pass
handle SIGHUP nostop noprint pass
handle SIGTERM nostop print pass

# 美化输出
set print pretty on
set print array on
set pagination off
set history save on
set history size 10000
set history filename /home/.gdb_history

# Intel 汇编
set disassembly-flavor intel