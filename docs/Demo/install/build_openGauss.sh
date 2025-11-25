#!/bin/bash
set -e

# ===== 1. 下载源码 =====
echo "[Step 1] 下载 openGauss 源码..."
WORKDIR=/home/openGauss
mkdir -p $WORKDIR && cd $WORKDIR

if [ ! -d "openGauss-server" ]; then
  git clone https://gitcode.com/opengauss/openGauss-server.git openGauss-server -b 5.0.0
fi

# ===== 2. 下载 binarylibs =====
echo "[Step 2] 下载预编译好的 binarylibs..."
cd $WORKDIR

# 自动检测硬件架构
ARCH=$(uname -m)

# 根据架构设置对应的下载URL和目录名
case "$ARCH" in
    x86_64)
        BINARYLIBS_URL="https://opengauss.obs.cn-south-1.myhuaweicloud.com/5.0.0/binarylibs/openGauss-third_party_binarylibs_openEuler_x86_64.tar.gz"
        BINARYLIBS_DIR="openGauss-third_party_binarylibs_openEuler_x86_64"
        ;;
    aarch64)
        BINARYLIBS_URL="https://opengauss.obs.cn-south-1.myhuaweicloud.com/5.0.0/binarylibs/openGauss-third_party_binarylibs_openEuler_arm.tar.gz"
        BINARYLIBS_DIR="openGauss-third_party_binarylibs_openEuler_arm"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        echo "当前仅支持 x86_64 和 aarch64 架构"
        exit 1
        ;;
esac

echo "检测到架构: $ARCH"
echo "下载 binarylibs: $BINARYLIBS_URL"

if [ ! -f "binarylibs.tar.gz" ]; then
  wget "$BINARYLIBS_URL" -O binarylibs.tar.gz
fi

tar -xzf binarylibs.tar.gz
mv "$BINARYLIBS_DIR" binarylibs
rm -f binarylibs.tar.gz

# ===== 3. 编译 openGauss =====
echo "[Step 3] 编译 openGauss..."
cd $WORKDIR/openGauss-server
sh build.sh -m release -3rd $WORKDIR/binarylibs
rm -rf $WORKDIR/binarylibs # 编译完成后删除 binarylibs 目录，节省空间

# ===== 4. 配置 root 环境变量 =====
# openGauss 环境变量
echo "[Step 4] 配置 root 环境变量..."
export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
export CODE_BASE=/home/openGauss/openGauss-server
export GAUSSHOME=$CODE_BASE/mppdb_temp_install
export PATH=$GAUSSHOME/bin:$PATH
export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH
# 手动写入 /root/.bashrc 
