# skim

The fastest compression algorithm ever created.

`skim` makes a single, extreme trade-off: **It sacrifices compression ratio to achieve absolute maximum throughput.**

By avoiding complex math and relying entirely on a hash-based lookup table, it operates near hardware memory-bandwidth limits.

## The Profile

- **Speed:** ~12.6 GB/s encoding | ~15.5 GB/s decoding
- **Efficiency:** Compresses 100MB in 34ms.
- **Ratio:** Low.

## Use Cases

Because `skim` requires almost zero CPU overhead, it serves specific applications where traditional compression is too slow to be viable:

1. **In-Memory Caching:** Compressing database pages or RAM caches where read/write speed is the primary bottleneck.
2. **High-Volume IPC:** Shrinking Inter-Process Communication payloads without stalling the pipeline.
3. **Real-Time Telemetry:** Buffering massive streams of unoptimized log/sensor data on the fly.

---

## Usage

### CLI Tool

The standalone executable memory-maps files for zero-copy operations.

#### Compress a file

```bash
skim -c <input_file> <output_file>
```

#### Decompress a file

```bash
skim -d <input_file> <output_file>
```

### Zig Library Integration

To see how to integrate `skim` programmatically, please look at the existing implementation in `src/main.zig` and `src/bench.zig`. They contain the canonical examples of how to initialize, encode, and decode data buffers using the library.
