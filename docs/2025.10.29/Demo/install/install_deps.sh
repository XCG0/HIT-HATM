#!/bin/bash
# 安装 openGauss 编译依赖 (适配 CentOS 7 和 openEuler 22.03 LTS)
set -e

echo ">>> 开始安装依赖..."

# ===== 1. 检测操作系统类型 =====
OS_TYPE=""
if grep -qi "centos" /etc/os-release 2>/dev/null; then
    OS_TYPE="centos"
    echo ">>> 检测到系统: CentOS"
elif grep -qi "openeuler" /etc/os-release 2>/dev/null; then
    OS_TYPE="openeuler"
    echo ">>> 检测到系统: openEuler"
else
    echo ">>> 警告: 未能识别操作系统类型。按 Ctrl-C 取消，5 秒后尝试使用 openEuler 流程..."
    sleep 5
    OS_TYPE="openeuler"
fi

# ===== 2. 根据操作系统执行相应的安装流程 =====
if [ "$OS_TYPE" = "centos" ]; then
    echo ">>> 使用包管理器: yum"
    
    # 更新缓存
    echo ">>> 配置阿里云 CentOS 镜像源..."
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    yum clean all
    yum makecache
    yum makecache fast
    
    # 安装依赖包（不写死版本号，避免找不到包）
    echo ">>> 安装核心依赖..."
    yum install -y \
        gcc gcc-c++ make cmake autoconf automake libtool libtool-devel \
        git git-lfs wget tar \
        bison flex \
        python3 python3-devel \
        glibc-devel libaio-devel ncurses-devel zlib-devel openssl-devel \
        readline-devel pam-devel libffi-devel \
        patch redhat-lsb-core diffutils

elif [ "$OS_TYPE" = "openeuler" ]; then
    echo ">>> 使用包管理器: dnf"
    
    # 刷新缓存（容错）
    dnf clean all || true
    dnf makecache -y || true
    
    # 核心依赖（移除 redhat-lsb-core、git-lfs 等可能不存在的包）
    CORE_PKGS=(
        gcc gcc-c++ make cmake autoconf automake libtool libtool-devel
        git wget tar
        bison flex
        python3 python3-devel
        glibc-devel libaio-devel ncurses-devel zlib-devel openssl-devel
        readline-devel pam-devel libffi-devel
        patch diffutils dkms
    )
    
    echo ">>> 安装核心依赖..."
    dnf install -y "${CORE_PKGS[@]}" || echo ">>> 注意：核心依赖安装过程中有失败，请检查网络/仓库并重试。"
fi

# 3. ===== 确保 python 可用 =====
#（在很多系统中 python 指向 python2，openEuler 可能只提供 python3）
echo ">>> 确认 python 可用性..."
if command -v python >/dev/null 2>&1; then
  echo ">>> python 已存在: $(command -v python)"
else
  if command -v python3 >/dev/null 2>&1; then
    PY3_BIN=$(command -v python3)
    echo ">>> python 不存在，找到 python3: $PY3_BIN，创建符号链接 /usr/bin/python -> $PY3_BIN"
    ln -sf "$PY3_BIN" /usr/bin/python || echo ">>> 无法创建 /usr/bin/python 链接，请以 root 权限运行或手动创建。"
  else
    echo ">>> 系统中未发现 python3，尝试通过包管理器安装 python3..."
    PM="yum"
    [ "$OS_TYPE" = "openeuler" ] && PM="dnf"
    if $PM install -y python3; then
      PY3_BIN=$(command -v python3 || true)
      if [ -n "$PY3_BIN" ]; then
        ln -sf "$PY3_BIN" /usr/bin/python || echo ">>> 无法创建 /usr/bin/python 链接，请以 root 权限运行或手动创建。"
      fi
    else
      echo ">>> 警告: 无法安装 python3，请手动安装 python/python3 或联系管理员。"
    fi
  fi
fi

echo ">>> 依赖安装完成"
