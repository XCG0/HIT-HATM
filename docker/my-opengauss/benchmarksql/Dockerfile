
FROM xcg0/opengauss-openeuler_22.03:xlog_tools

# 安装 openjdk、unzip 和 ant
RUN yum install -y java-1.8.0-openjdk unzip ant && \
    yum clean all



# 拷贝 benchmarksql-5.0.zip 和 JDBC 驱动到 /home
COPY benchmarksql-5.0.zip /home/
COPY openGauss-5.0.0-JDBC.tar.gz /opt/

# 拷贝脚本文件
COPY build_tpcc_env.sh /home/benchmarksql/build_tpcc_env.sh
COPY run_tpcc.sh /home/benchmarksql/run_tpcc.sh

# 解压 benchmarksql 和 JDBC 驱动，并删除压缩包
RUN unzip /home/benchmarksql-5.0.zip -d /home/ && \
    mkdir -p /home/benchmarksql && \
    mv /home/benchmarksql-5.0/* /home/benchmarksql/ && \
    rm -rf /home/benchmarksql-5.0 /home/benchmarksql-5.0.zip && \
    mkdir -p /opt/jdbc && \
    tar -xzf /opt/openGauss-5.0.0-JDBC.tar.gz -C /opt/jdbc --strip-components=1 && \
    rm -f /opt/openGauss-5.0.0-JDBC.tar.gz && \
    ln -sf $(ls /opt/jdbc/*.jar | head -n1) /opt/jdbc/postgresql.jar

# 设置 JAVA_HOME、PATH 和 JAVA 编码为 UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
ENV JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

# 赋予脚本可执行权限
RUN chmod +x /home/benchmarksql/build_tpcc_env.sh /home/benchmarksql/run_tpcc.sh

WORKDIR /home/benchmarksql

# 默认进入 bash
CMD ["/bin/bash"]
