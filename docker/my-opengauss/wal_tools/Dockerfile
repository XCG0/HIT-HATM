# ========== 仅安装 openGauss WAL 工具 ===========
FROM xcg0/opengauss-openeuler_22.03:x86_64 AS builder

# 打包 WAL 工具
RUN mkdir -p /tmp/waltools && \
    cp -r /home/openGauss/openGauss-server/mppdb_temp_install/bin/* /tmp/waltools/ && \
    tar czf /tmp/waltools.tar.gz -C /tmp waltools

FROM xcg0/opengauss-openeuler_22.03:x86_64

# 创建 omm 用户
RUN groupadd -g 1000 dbgrp || true && \
    useradd -u 1000 -g dbgrp -m omm || true

# 拷贝 WAL 工具
COPY --from=builder /tmp/waltools.tar.gz /tmp/waltools.tar.gz
RUN mkdir -p /home/omm/waltools && \
    tar xzf /tmp/waltools.tar.gz -C /home/omm && \
    rm -f /tmp/waltools.tar.gz && \
    chmod -R +x /home/omm/waltools

# 设置环境变量
RUN echo 'export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH' >> /root/.bashrc \
    && echo 'export CODE_BASE=/home/openGauss/openGauss-server' >> /root/.bashrc \
    && echo 'export GAUSSHOME=$CODE_BASE/mppdb_temp_install' >> /root/.bashrc \
    && echo 'export PATH=$GAUSSHOME/bin:/home/omm/waltools:$PATH' >> /root/.bashrc \
    && echo 'export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH' >> /root/.bashrc \
    && echo 'export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH' >> /home/omm/.bashrc \
    && echo 'export CODE_BASE=/home/openGauss/openGauss-server' >> /home/omm/.bashrc \
    && echo 'export GAUSSHOME=$CODE_BASE/mppdb_temp_install' >> /home/omm/.bashrc \
    && echo 'export PATH=$GAUSSHOME/bin:/home/omm/waltools:$PATH' >> /home/omm/.bashrc \
    && echo 'export LD_LIBRARY_PATH=$GAUSSHOME/lib:$LD_LIBRARY_PATH' >> /home/omm/.bashrc

USER root
WORKDIR /home
CMD ["bash"]