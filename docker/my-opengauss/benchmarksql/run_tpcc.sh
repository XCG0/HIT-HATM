#!/bin/bash
# run_tpcc.sh 仅用于运行 TPCC 测试
set -e

MSYS_NO_PATHCONV=1
BENCHSQL_HOME="/home/benchmarksql"
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PG_USER=${PG_USER:-bot}
PG_PASS=${PG_PASS:-Gaussdba@Mpp}
PG_DB=${PG_DB:-tpcc1000}
PROPS_FILE="props.opengauss.1000w"

function run_bench() {
  echo "[运行 TPCC 性能测试]"
  cd "$BENCHSQL_HOME/run"
  ./runBenchmark.sh $PROPS_FILE
}

function usage() {
  echo "用法: $0 run"
}

case "$1" in
  run)
    run_bench
    ;;
  *)
    usage
    ;;
esac
