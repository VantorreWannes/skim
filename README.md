# skim

The fastest compression algorithm ever created.

**Skim sacrifices compression ratio for an absolute maximum throughput.**

## TLDR

All benchmarks are done on my pc. Take them with a grain of salt.

### Skim

- **Speed:** ~3.27 GB/s encoding | ~15.5 GB/s decoding
- **Efficiency:** Compresses 100MB in 30.6 ms.
- **Ratio:** Low | 75% saved for log or repetitive files.

### XZ

- **Speed:** 390.6 MB/s encoding | ~1.14 GB/s decoding
- **Efficiency:** Compresses 100MB in 256.0 ms.
- **Ratio:** High | 99% saved for log or repetitive files.

---

## Usage

### CLI Tool

#### Compress a file

```bash
skim -c <input_file> <output_file>
```

#### Decompress a file

```bash
skim -d <input_file> <output_file>
```
