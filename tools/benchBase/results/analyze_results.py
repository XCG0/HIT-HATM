#!/usr/bin/env python3
"""
TPC-C 基准测试结果分析工具
功能：解析并展示 BenchBase TPC-C 测试的性能指标
作者：自动生成
日期：2025-12-02
"""


import json
import sys
import os
import glob
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

# 输出写入器，支持同时写入屏幕和文件
class OutputWriter:
    def __init__(self, file_path=None, encoding='utf-8'):
        self.file_path = file_path
        self.encoding = encoding
        self.file = open(file_path, 'w', encoding=encoding) if file_path else None

    def write(self, text: str = ""):
        # 去除 ANSI 颜色码后写入文件
        if self.file:
            import re
            ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
            plain = ansi_escape.sub('', text)
            self.file.write(plain + '\n')
        print(text)

    def close(self):
        if self.file:
            self.file.close()

# ANSI 颜色代码
class Colors:
    CYAN = '\033[0;36m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    MAGENTA = '\033[0;35m'
    BLUE = '\033[0;34m'
    RED = '\033[0;31m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color


def find_latest_result(results_dir: str) -> Optional[str]:
    """查找最新的测试结果文件(递归搜索子文件夹)"""
    # 首先搜索顶层目录
    json_files = glob.glob(os.path.join(results_dir, "*.summary.json"))
    
    # 然后搜索子文件夹
    json_files.extend(glob.glob(os.path.join(results_dir, "*", "*.summary.json")))
    
    if not json_files:
        return None
    
    # 按修改时间排序，返回最新的
    latest_file = max(json_files, key=os.path.getmtime)
    return latest_file


def format_number(num: float, decimals: int = 2) -> str:
    """格式化数字，添加千位分隔符"""
    if decimals == 0:
        return f"{int(num):,}"
    return f"{num:,.{decimals}f}"


def get_performance_rating(metric_type: str, value: float) -> tuple:
    """
    根据指标类型和值返回性能等级
    返回: (等级名称, 颜色代码)
    """
    if metric_type == "p95_latency":
        # P95 延迟评级 (毫秒)
        if value < 50:
            return "优秀", Colors.GREEN
        elif value < 100:
            return "良好", Colors.YELLOW
        elif value < 200:
            return "一般", Colors.YELLOW
        else:
            return "较差", Colors.RED
    
    elif metric_type == "tpmc":
        # tpmC 吞吐量评级
        if value > 50000:
            return "优秀", Colors.GREEN
        elif value > 20000:
            return "良好", Colors.GREEN
        elif value > 10000:
            return "一般", Colors.YELLOW
        else:
            return "较低", Colors.YELLOW
    
    elif metric_type == "p99_latency":
        # P99 延迟评级 (毫秒)
        if value < 100:
            return "优秀", Colors.GREEN
        elif value < 200:
            return "良好", Colors.YELLOW
        elif value < 500:
            return "一般", Colors.YELLOW
        else:
            return "较差", Colors.RED
    
    return "未知", Colors.NC



def print_header(writer, title: str, width: int = 70):
    writer.write(f"\n{Colors.CYAN}╔{'═' * (width)}╗{Colors.NC}")
    writer.write(f"{Colors.CYAN}{title.center(width-5)}{Colors.NC}")
    writer.write(f"{Colors.CYAN}╚{'═' * (width)}╝{Colors.NC}")


def print_metric(writer, label: str, value: str, bold: bool = False):
    color = Colors.BOLD if bold else Colors.MAGENTA
    end_color = Colors.NC if bold else Colors.NC
    writer.write(f"  {color}{label}:{Colors.NC} {value:>30}{end_color}")



def analyze_summary(summary_file: str, writer):
    """分析 summary.json 文件并输出结果到 writer"""
    try:
        with open(summary_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        writer.write(f"{Colors.RED}错误: 文件不存在: {summary_file}{Colors.NC}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        writer.write(f"{Colors.RED}错误: JSON 格式无效: {e}{Colors.NC}")
        sys.exit(1)

    # 提取基本信息
    start_time_ms = data.get('Start timestamp (milliseconds)', 0)
    end_time_ms = data.get('Current Timestamp (milliseconds)', 0)
    elapsed_ns = data.get('Elapsed Time (nanoseconds)', 0)
    elapsed_sec = elapsed_ns / 1_000_000_000

    start_time = datetime.fromtimestamp(start_time_ms / 1000)
    end_time = datetime.fromtimestamp(end_time_ms / 1000)

    dbms_type = data.get('DBMS Type', 'Unknown')
    dbms_version = data.get('DBMS Version', 'Unknown')
    benchmark_type = data.get('Benchmark Type', 'Unknown')
    final_state = data.get('Final State', 'Unknown')
    measured_requests = data.get('Measured Requests', 0)
    scalefactor = data.get('scalefactor', 'N/A')
    terminals = data.get('terminals', 'N/A')
    isolation = data.get('isolation', 'N/A')

    # 提取性能指标
    throughput = data.get('Throughput (requests/second)', 0)
    goodput = data.get('Goodput (requests/second)', 0)
    tpmc = throughput * 60  # 转换为每分钟事务数

    # 提取延迟分布（单位：微秒）
    latency_dist = data.get('Latency Distribution', {})
    avg_latency_us = latency_dist.get('Average Latency (microseconds)', 0)
    min_latency_us = latency_dist.get('Minimum Latency (microseconds)', 0)
    max_latency_us = latency_dist.get('Maximum Latency (microseconds)', 0)
    median_latency_us = latency_dist.get('Median Latency (microseconds)', 0)
    p25_latency_us = latency_dist.get('25th Percentile Latency (microseconds)', 0)
    p75_latency_us = latency_dist.get('75th Percentile Latency (microseconds)', 0)
    p90_latency_us = latency_dist.get('90th Percentile Latency (microseconds)', 0)
    p95_latency_us = latency_dist.get('95th Percentile Latency (microseconds)', 0)
    p99_latency_us = latency_dist.get('99th Percentile Latency (microseconds)', 0)

    # 转换为毫秒
    avg_latency_ms = avg_latency_us / 1000
    min_latency_ms = min_latency_us / 1000
    max_latency_ms = max_latency_us / 1000
    median_latency_ms = median_latency_us / 1000
    p25_latency_ms = p25_latency_us / 1000
    p75_latency_ms = p75_latency_us / 1000
    p90_latency_ms = p90_latency_us / 1000
    p95_latency_ms = p95_latency_us / 1000
    p99_latency_ms = p99_latency_us / 1000

    # ============ 输出结果 ============
    writer.write(f"\n{Colors.BLUE}{'=' * 70}{Colors.NC}")
    writer.write(f"{Colors.BOLD}{Colors.BLUE}{'TPC-C 基准测试结果分析'.center(70)}{Colors.NC}")
    writer.write(f"{Colors.BLUE}{'=' * 70}{Colors.NC}")

    # 文件信息
    print_header(writer, "文件信息")
    writer.write(f"  {Colors.MAGENTA}结果文件:{Colors.NC}     {os.path.basename(summary_file)}")
    writer.write(f"  {Colors.MAGENTA}文件路径:{Colors.NC}     {summary_file}")
    writer.write(f"  {Colors.MAGENTA}生成时间:{Colors.NC}     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # 测试配置
    print_header(writer, "测试配置")
    writer.write(f"  {Colors.MAGENTA}数据库类型:{Colors.NC}   {dbms_type}")

    # 提取简短的版本信息
    if "openGauss" in dbms_version:
        version_short = dbms_version.split(')')[0] + ')'
    else:
        version_short = dbms_version[:50] + "..." if len(dbms_version) > 50 else dbms_version

    writer.write(f"  {Colors.MAGENTA}数据库版本:{Colors.NC}   {version_short}")
    writer.write(f"  {Colors.MAGENTA}基准类型:{Colors.NC}     {benchmark_type.upper()}")
    writer.write(f"  {Colors.MAGENTA}仓库数量:{Colors.NC}     {scalefactor}")
    writer.write(f"  {Colors.MAGENTA}并发终端:{Colors.NC}     {terminals}")
    writer.write(f"  {Colors.MAGENTA}隔离级别:{Colors.NC}     {isolation}")
    writer.write(f"  {Colors.MAGENTA}测试时长:{Colors.NC}     {elapsed_sec:.1f} 秒")
    writer.write(f"  {Colors.MAGENTA}开始时间:{Colors.NC}     {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    writer.write(f"  {Colors.MAGENTA}结束时间:{Colors.NC}     {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    writer.write(f"  {Colors.MAGENTA}测试状态:{Colors.NC}     {final_state}")
    writer.write(f"  {Colors.MAGENTA}测试请求数:{Colors.NC}   {format_number(measured_requests, 0)}")

    # 总体性能指标
    print_header(writer, "总体性能指标")

    # 吞吐量
    tpmc_rating, tpmc_color = get_performance_rating("tpmc", tpmc)
    writer.write(f"  {Colors.BOLD}{Colors.GREEN}吞吐量 (Throughput):{Colors.NC}  {Colors.BOLD}{format_number(throughput)} requests/sec{Colors.NC}")
    writer.write(f"  {Colors.BOLD}{tpmc_color}吞吐量 (tpmC):{Colors.NC}        {Colors.BOLD}{format_number(tpmc, 0)} txn/min{Colors.NC} ({tpmc_color}{tpmc_rating}{Colors.NC})")
    writer.write(f"  {Colors.MAGENTA}Goodput:{Colors.NC}               {format_number(goodput)} requests/sec")

    # 延迟分布
    print_header(writer, "延迟分布 (毫秒)")

    writer.write(f"  {Colors.MAGENTA}最小延迟 (Min):{Colors.NC}        {format_number(min_latency_ms)} ms")
    writer.write(f"  {Colors.MAGENTA}25th 百分位:{Colors.NC}           {format_number(p25_latency_ms)} ms")
    writer.write(f"  {Colors.BOLD}{Colors.MAGENTA}50th 百分位 (Median):{Colors.NC} {Colors.BOLD}{format_number(median_latency_ms)} ms{Colors.NC}")
    writer.write(f"  {Colors.MAGENTA}平均延迟 (Average):{Colors.NC}    {format_number(avg_latency_ms)} ms")
    writer.write(f"  {Colors.MAGENTA}75th 百分位:{Colors.NC}           {format_number(p75_latency_ms)} ms")
    writer.write(f"  {Colors.MAGENTA}90th 百分位:{Colors.NC}           {format_number(p90_latency_ms)} ms")

    p95_rating, p95_color = get_performance_rating("p95_latency", p95_latency_ms)
    writer.write(f"  {Colors.BOLD}{p95_color}95th 百分位 (P95):{Colors.NC}    {Colors.BOLD}{format_number(p95_latency_ms)} ms{Colors.NC} ({p95_color}{p95_rating}{Colors.NC})")

    p99_rating, p99_color = get_performance_rating("p99_latency", p99_latency_ms)
    writer.write(f"  {Colors.BOLD}{p99_color}99th 百分位 (P99):{Colors.NC}    {Colors.BOLD}{format_number(p99_latency_ms)} ms{Colors.NC} ({p99_color}{p99_rating}{Colors.NC})")

    writer.write(f"  {Colors.MAGENTA}最大延迟 (Max):{Colors.NC}        {format_number(max_latency_ms)} ms")

    # 性能评估
    print_header(writer, "性能评估")

    # 综合评分
    tpmc_score = min(100, (tpmc / 500))  # 50000 tpmC = 100分
    p95_score = max(0, 100 - p95_latency_ms)  # P95 < 100ms = 好
    overall_score = (tpmc_score * 0.6 + p95_score * 0.4)  # 吞吐量权重60%，延迟40%

    if overall_score >= 80:
        overall_rating = "优秀"
        overall_color = Colors.GREEN
    elif overall_score >= 60:
        overall_rating = "良好"
        overall_color = Colors.YELLOW
    else:
        overall_rating = "一般"
        overall_color = Colors.YELLOW

    writer.write(f"  {Colors.MAGENTA}延迟性能:{Colors.NC}             {p95_color}{p95_rating}{Colors.NC} (P95 延迟 {format_number(p95_latency_ms)} ms)")
    writer.write(f"  {Colors.MAGENTA}吞吐量性能:{Colors.NC}           {tpmc_color}{tpmc_rating}{Colors.NC} (tpmC {format_number(tpmc, 0)})")
    writer.write(f"  {Colors.BOLD}{overall_color}综合评分:{Colors.NC}             {Colors.BOLD}{overall_rating}{Colors.NC}")

    # 性能基准对比
    print_header(writer, "性能基准参考")
    writer.write(f"  {Colors.CYAN}延迟基准:{Colors.NC}")
    writer.write(f"    - P95 < 50ms:  优秀")
    writer.write(f"    - P95 < 100ms: 良好")
    writer.write(f"    - P95 < 200ms: 一般")
    writer.write(f"  {Colors.CYAN}吞吐量基准:{Colors.NC}")
    writer.write(f"    - tpmC > 50000: 优秀")
    writer.write(f"    - tpmC > 20000: 良好")
    writer.write(f"    - tpmC > 10000: 一般")

    # 关键发现
    print_header(writer, "关键发现")
    findings = []

    if p95_latency_ms < 50:
        findings.append(f"{Colors.GREEN}✓ P95 延迟表现优秀 ({format_number(p95_latency_ms)} ms){Colors.NC}")
    elif p95_latency_ms > 200:
        findings.append(f"{Colors.RED}⚠ P95 延迟较高，建议优化 ({format_number(p95_latency_ms)} ms){Colors.NC}")

    if tpmc > 20000:
        findings.append(f"{Colors.GREEN}✓ 吞吐量表现良好 ({format_number(tpmc, 0)} tpmC){Colors.NC}")
    elif tpmc < 10000:
        findings.append(f"{Colors.YELLOW}⚠ 吞吐量偏低，可能需要调优 ({format_number(tpmc, 0)} tpmC){Colors.NC}")

    if max_latency_ms > 1000:
        findings.append(f"{Colors.YELLOW}⚠ 最大延迟较高 ({format_number(max_latency_ms)} ms)，存在性能毛刺{Colors.NC}")

    if median_latency_ms > 0 and p99_latency_ms / median_latency_ms > 5:
        findings.append(f"{Colors.YELLOW}⚠ P99/P50 比例较大 ({p99_latency_ms/median_latency_ms:.1f}x)，延迟分布不均{Colors.NC}")

    if not findings:
        findings.append(f"{Colors.GREEN}✓ 整体性能表现稳定{Colors.NC}")

    for i, finding in enumerate(findings, 1):
        writer.write(f"  {i}. {finding}")

    writer.write(f"\n{Colors.BLUE}{'=' * 70}{Colors.NC}\n")



def main():
    """主函数"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    results_dir = os.path.join(script_dir, "")

    # 检查命令行参数
    if len(sys.argv) > 1:
        summary_file = sys.argv[1]
        if not os.path.exists(summary_file):
            print(f"{Colors.RED}错误: 文件不存在: {summary_file}{Colors.NC}")
            sys.exit(1)
    else:
        if not os.path.exists(results_dir):
            print(f"{Colors.RED}错误: 结果目录不存在: {results_dir}{Colors.NC}")
            sys.exit(1)
        summary_file = find_latest_result(results_dir)
        if not summary_file:
            print(f"{Colors.RED}错误: 未找到测试结果文件{Colors.NC}")
            print(f"{Colors.YELLOW}提示: 请先运行基准测试{Colors.NC}")
            sys.exit(1)

    # 获取文件名前缀和输出路径
    basename = os.path.basename(summary_file)
    prefix = basename.replace('.summary.json', '')
    
    # 确定输出文件路径（假设文件已被 shell 脚本组织到子文件夹）
    result_dir = os.path.dirname(summary_file)
    output_file = os.path.join(result_dir, "final_report.txt")

    # 创建 writer，输出到屏幕和文件
    writer = OutputWriter(output_file)
    try:
        analyze_summary(summary_file, writer)
        print(f"\n{Colors.GREEN}✓ 结果目录: {result_dir}{Colors.NC}")
        print(f"{Colors.GREEN}✓ 分析报告: {output_file}{Colors.NC}")
    finally:
        writer.close()


if __name__ == "__main__":
    main()
