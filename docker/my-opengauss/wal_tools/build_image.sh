#!/bin/bash
set -e

# 路径转换问题
MSYS_NO_PATHCONV=1

docker build -t xcg0/opengauss-openeuler_22.03:xlog_tools .