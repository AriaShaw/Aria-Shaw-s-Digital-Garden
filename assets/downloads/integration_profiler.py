#!/usr/bin/env python3
"""
Integration Performance Profiler
Measures sync latency, identifies bottlenecks, analyzes throughput.
"""

import requests
import time
import json
import statistics
from datetime import datetime
import argparse
from typing import List, Dict

class IntegrationProfiler:
    def __init__(self):
        self.metrics = []

    def profile_api_call(self, url: str, method='GET', headers=None, data=None, iterations=10):
        """
        Profile API call performance over multiple iterations

        Args:
            url: API endpoint URL
            method: HTTP method (GET, POST, etc.)
            headers: Optional headers dictionary
            data: Optional request data
            iterations: Number of test iterations
        """
        print(f"\n[PROFILING] Testing {method} {url}")
        print(f"Iterations: {iterations}")
        print("-" * 80)

        latencies = []
        errors = 0

        for i in range(iterations):
            print(f"  Request {i+1}/{iterations}... ", end='', flush=True)

            start_time = time.time()
            try:
                if method == 'GET':
                    response = requests.get(url, headers=headers, timeout=30)
                elif method == 'POST':
                    response = requests.post(url, headers=headers, json=data, timeout=30)
                else:
                    raise ValueError(f"Unsupported method: {method}")

                latency = (time.time() - start_time) * 1000  # Convert to ms
                latencies.append(latency)

                if response.status_code == 200:
                    print(f"✓ {latency:.2f}ms")
                else:
                    print(f"✗ HTTP {response.status_code}")
                    errors += 1

            except requests.exceptions.Timeout:
                print(f"✗ TIMEOUT")
                errors += 1
            except Exception as e:
                print(f"✗ ERROR: {e}")
                errors += 1

            # Small delay between requests
            time.sleep(0.1)

        # Calculate statistics
        if latencies:
            metrics = {
                'url': url,
                'method': method,
                'iterations': iterations,
                'successful': iterations - errors,
                'failed': errors,
                'min_latency_ms': min(latencies),
                'max_latency_ms': max(latencies),
                'avg_latency_ms': statistics.mean(latencies),
                'median_latency_ms': statistics.median(latencies),
                'p95_latency_ms': self.percentile(latencies, 95),
                'p99_latency_ms': self.percentile(latencies, 99),
                'throughput_rps': 1000 / statistics.mean(latencies) if latencies else 0
            }

            self.metrics.append(metrics)
            self.print_metrics(metrics)
            return metrics
        else:
            print("\n  ✗ All requests failed - no metrics available")
            return None

    def percentile(self, data: List[float], percentile: int) -> float:
        """Calculate percentile of data"""
        size = len(data)
        sorted_data = sorted(data)
        index = (percentile / 100) * size
        if index.is_integer():
            return sorted_data[int(index) - 1]
        else:
            lower = sorted_data[int(index) - 1]
            upper = sorted_data[int(index)]
            return (lower + upper) / 2

    def print_metrics(self, metrics: Dict):
        """Print performance metrics"""
        print(f"\n  Performance Metrics:")
        print(f"    Min Latency:    {metrics['min_latency_ms']:.2f}ms")
        print(f"    Max Latency:    {metrics['max_latency_ms']:.2f}ms")
        print(f"    Avg Latency:    {metrics['avg_latency_ms']:.2f}ms")
        print(f"    Median:         {metrics['median_latency_ms']:.2f}ms")
        print(f"    P95:            {metrics['p95_latency_ms']:.2f}ms")
        print(f"    P99:            {metrics['p99_latency_ms']:.2f}ms")
        print(f"    Throughput:     {metrics['throughput_rps']:.2f} req/s")
        print(f"    Success Rate:   {metrics['successful']}/{metrics['iterations']} ({metrics['successful']/metrics['iterations']*100:.1f}%)")

    def identify_bottlenecks(self):
        """Analyze metrics to identify performance bottlenecks"""
        print("\n" + "=" * 80)
        print("BOTTLENECK ANALYSIS")
        print("=" * 80)

        if not self.metrics:
            print("\n  No metrics available for analysis")
            return

        # Find slowest endpoints
        slowest = sorted(self.metrics, key=lambda x: x['avg_latency_ms'], reverse=True)

        print(f"\nSlowest Endpoints (by avg latency):")
        for i, metric in enumerate(slowest[:3], 1):
            print(f"\n  {i}. {metric['url']}")
            print(f"     Avg: {metric['avg_latency_ms']:.2f}ms")
            print(f"     P95: {metric['p95_latency_ms']:.2f}ms")

            # Recommendations
            if metric['avg_latency_ms'] > 2000:
                print(f"     ⚠ CRITICAL: Latency >2s - consider caching or async processing")
            elif metric['avg_latency_ms'] > 1000:
                print(f"     ⚠ WARNING: Latency >1s - optimize query or add pagination")
            elif metric['avg_latency_ms'] > 500:
                print(f"     ℹ INFO: Latency >500ms - monitor for degradation")

        # Check success rates
        print(f"\nReliability Check:")
        for metric in self.metrics:
            success_rate = metric['successful'] / metric['iterations'] * 100
            if success_rate < 95:
                print(f"  ⚠ {metric['url']}: {success_rate:.1f}% success rate")
                print(f"     Failed: {metric['failed']}/{metric['iterations']} requests")

    def generate_report(self, output_file=None):
        """Generate detailed profiling report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'total_endpoints': len(self.metrics),
            'metrics': self.metrics
        }

        if output_file:
            with open(output_file, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"\n📊 Report saved to: {output_file}")

        return report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Profile integration performance')
    parser.add_argument('urls', nargs='+', help='API URLs to profile')
    parser.add_argument('--method', default='GET', help='HTTP method (default: GET)')
    parser.add_argument('--iterations', type=int, default=10, help='Number of test iterations (default: 10)')
    parser.add_argument('--output', help='Output file for profiling report (JSON)')

    args = parser.parse_args()

    profiler = IntegrationProfiler()

    print("=" * 80)
    print("INTEGRATION PERFORMANCE PROFILER")
    print("=" * 80)

    # Profile each URL
    for url in args.urls:
        profiler.profile_api_call(url, method=args.method, iterations=args.iterations)

    # Analyze results
    profiler.identify_bottlenecks()

    # Generate report
    profiler.generate_report(args.output)

    print("\n" + "=" * 80)
    print("PROFILING COMPLETE")
    print("=" * 80)
