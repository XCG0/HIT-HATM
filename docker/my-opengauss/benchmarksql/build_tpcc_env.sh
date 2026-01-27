#!/bin/bash
# build_tpcc_env.sh 用于构建 TPCC 测试环境（镜像构建、JDBC替换、编译、配置、建库、建表、数据导入）
set -e

MSYS_NO_PATHCONV=1
BENCHSQL_HOME="/home/benchmarksql"
JDBC_SRC="/opt/jdbc/postgresql.jar"
JDBC_DST="$BENCHSQL_HOME/lib/postgres/postgresql.jar"
ANT_BIN="ant"
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PG_USER=${PG_USER:-bot}
PG_PASS=${PG_PASS:-Gaussdba@Mpp}
PG_DB=${PG_DB:-tpcc1000}
WAREHOUSE=${WAREHOUSE:-1000}
LOAD_WORKERS=${LOAD_WORKERS:-200}
TERMINALS=${TERMINALS:-812}
RUN_MINS=${RUN_MINS:-5}
PROPS_FILE="props.opengauss.1000w"
RESULT_DIR="my_result_$(date +%Y-%m-%d_%H%M%S)"

# openGauss环境变量
export GAUSSHOME=${GAUSSHOME:-/home/openGauss/openGauss-server/mppdb_temp_install}
export PATH=$GAUSSHOME/bin:$PATH

# 数据库初始化与启动
function init_and_start_opengauss() {
  echo "[0/6] 检查并初始化/启动 openGauss 数据库服务..."
  if [ ! -d "$GAUSSHOME/data" ]; then
    echo "数据库目录不存在，开始初始化..."
    su - omm -c "source ~/.bashrc && gs_initdb -D $GAUSSHOME/data --nodename=single_node --auth=sha256 --username=gaussdb --pwpasswd=$PG_PASS"
  fi
  if ! ps -ef | grep gauss | grep -v grep >/dev/null; then
    su - omm -c "source ~/.bashrc && gs_ctl start -D $GAUSSHOME/data"
    sleep 5
  else
    echo "openGauss 数据库已在运行。"
  fi
}

export GAUSSHOME=/home/openGauss/openGauss-server/mppdb_temp_install
export PATH=$GAUSSHOME/bin:$PATH

function replace_jdbc() {
  echo "[1/6] 替换 JDBC 驱动..."
  mkdir -p /home/benchmarksql/lib/postgres/
  ln -sf /opt/jdbc/postgresql.jar /home/benchmarksql/lib/postgres/postgresql.jar
}

function build_benchsql() {
  echo "[2/6] 编译 benchmarksql..."
  cd "$BENCHSQL_HOME"
  $ANT_BIN
}

function gen_props() {
  echo "[3/6] 生成/修改 TPCC 配置文件..."
  cd "$BENCHSQL_HOME/run"
  cp -f props.pg $PROPS_FILE
  sed -i "s/^db=.*/db=postgres/" $PROPS_FILE
  sed -i "s|^driver=.*|driver=org.postgresql.Driver|" $PROPS_FILE
  sed -i "s|^conn=.*|conn=jdbc:postgresql://$PG_HOST:$PG_PORT/$PG_DB?prepareThreshold=1&batchMode=on&fetchsize=10|" $PROPS_FILE
  sed -i "s/^user=.*/user=$PG_USER/" $PROPS_FILE
  sed -i "s/^password=.*/password=$PG_PASS/" $PROPS_FILE
  sed -i "s/^warehouses=.*/warehouses=$WAREHOUSE/" $PROPS_FILE
  sed -i "s/^loadWorkers=.*/loadWorkers=$LOAD_WORKERS/" $PROPS_FILE
  sed -i "s/^terminals=.*/terminals=$TERMINALS/" $PROPS_FILE
  sed -i "s/^runMins=.*/runMins=$RUN_MINS/" $PROPS_FILE
  sed -i "s|^resultDirectory=.*|resultDirectory=$RESULT_DIR|" $PROPS_FILE
}

function create_db_user() {
  echo "[4/6] 创建数据库和用户..."
  gsql -h $PG_HOST -p $PG_PORT -U gaussdb -W $PG_PASS -d postgres -c "CREATE USER $PG_USER IDENTIFIED BY '$PG_PASS' PROFILE DEFAULT;" || true
  gsql -h $PG_HOST -p $PG_PORT -U gaussdb -W $PG_PASS -d postgres -c "ALTER USER $PG_USER SYSADMIN;" || true
  gsql -h $PG_HOST -p $PG_PORT -U gaussdb -W $PG_PASS -d postgres -c "DROP DATABASE IF EXISTS $PG_DB;"
  gsql -h $PG_HOST -p $PG_PORT -U gaussdb -W $PG_PASS -d postgres -c "CREATE DATABASE $PG_DB ENCODING 'UTF8' TEMPLATE=template0 OWNER $PG_USER;"
}

function create_schema() {
  echo "[5/6] 创建表空间和表结构..."
  gsql -h $PG_HOST -p $PG_PORT -U $PG_USER -W $PG_PASS -d $PG_DB -c "CREATE TABLESPACE IF NOT EXISTS example2 RELATIVE LOCATION 'tablespace2';"
  gsql -h $PG_HOST -p $PG_PORT -U $PG_USER -W $PG_PASS -d $PG_DB -c "CREATE TABLESPACE IF NOT EXISTS example3 RELATIVE LOCATION 'tablespace3';"
  # 如需替换建表SQL可在此处添加
}

function load_data() {
  echo "[6/6] 导入 TPCC 测试数据..."
  cd "$BENCHSQL_HOME/run"
  ./runDatabaseBuild.sh $PROPS_FILE
}

function usage() {
  echo "用法: $0 [all|replace_jdbc|build|config|create_db|schema|load]"
}


case "$1" in
  all)
    init_and_start_opengauss
    replace_jdbc
    build_benchsql
    gen_props
    create_db_user
    create_schema
    load_data
    ;;
  replace_jdbc)
    replace_jdbc
    ;;
  build)
    build_benchsql
    ;;
  config)
    gen_props
    ;;
  create_db)
    init_and_start_opengauss
    create_db_user
    ;;
  schema)
    init_and_start_opengauss
    create_schema
    ;;
  load)
    load_data
    ;;
  *)
    usage
    ;;
esac
