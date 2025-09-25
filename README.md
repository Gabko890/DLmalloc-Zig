# DLMalloc-Zig

A portable, customizable Zig implementation of Doug Lea's dlmalloc, translated and restructured from the original C implementation.

## Features

- **Portable**: Works across different architectures and operating systems
- **Customizable**: Extensive configuration options for different use cases
- **Thread-safe**: Optional thread safety with configurable locking
- **Memory efficient**: Implements the proven dlmalloc algorithms
- **Platform abstraction**: Clean separation between core logic and platform-specific code
- **Zig-native**: Provides both C-compatible API and idiomatic Zig allocator interface

## Supported Platforms

- **Linux**: x86_64, aarch64, arm, riscv64
- **macOS**: x86_64, aarch64 (Apple Silicon)
- **Windows**: x86_64
- **WASI**: WebAssembly System Interface
- **Other Unix-like systems** with basic POSIX support

## Quick Start

### Building

```bash
# Build the library
zig build

# Run tests
zig build test

# Build examples
zig build examples

# Cross-compile for all supported targets
zig build cross-compile

# Run benchmarks
zig build benchmark
```

### Basic Usage

```zig
const dlmalloc = @import("dlmalloc-zig");

// Basic allocation
const ptr = dlmalloc.malloc(1024);
defer dlmalloc.free(ptr);

// Use as Zig allocator
var zig_allocator = dlmalloc.ZigAllocator.init(dlmalloc.Config{});
const allocator = zig_allocator.allocator();
const slice = try allocator.alloc(u8, 100);
defer allocator.free(slice);
```

## Configuration

The allocator can be customized through the `Config` struct:

```zig
const config = dlmalloc.Config{
    .max_fast = 64,           // Max size for fast bins
    .trim_threshold = 128 * 1024,  // When to trim memory
    .mmap_threshold = 128 * 1024,  // When to use mmap
    .use_mmap = true,         // Enable mmap support
    .use_sbrk = true,         // Enable sbrk support
    .use_locks = false,       // Thread safety
    .debug = false,           // Debug mode
};
```

## API Reference

### Standard malloc API

- `malloc(size)` - Allocate memory
- `free(ptr)` - Free memory
- `calloc(num, size)` - Allocate zero-initialized memory
- `realloc(ptr, size)` - Reallocate memory
- `memalign(align, size)` - Allocate aligned memory
- `valloc(size)` - Allocate page-aligned memory
- `malloc_usable_size(ptr)` - Get usable size of allocation

### DL-prefixed API

All functions are also available with `dl` prefix:
- `dlmalloc()`, `dlfree()`, `dlcalloc()`, etc.

### Configuration

- `mallopt(param, value)` - Configure allocator parameters
- `malloc_stats()` - Print memory statistics

### Zig Interface

- `ZigAllocator` - Zig-native allocator implementation
- `Config` - Configuration structure
- `Platform` - Platform abstraction utilities

## Architecture

The implementation is structured into several modules:

- **`src/dlmalloc.zig`** - Main API and global allocator
- **`src/allocator.zig`** - Core allocation algorithms
- **`src/chunk.zig`** - Memory chunk management
- **`src/platform.zig`** - Platform abstraction layer
- **`src/c_compat.zig`** - Dynamic C header inclusion
- **`src/config.zig`** - Configuration system

## Platform Abstraction

The platform layer handles:
- Memory mapping (mmap/VirtualAlloc)
- Heap extension (sbrk)
- Page size detection
- Pointer validation
- Platform-specific optimizations

## Thread Safety

Thread safety can be enabled through configuration:

```zig
const config = dlmalloc.Config{
    .use_locks = true,
    // ... other options
};
```

## Performance

The allocator implements several optimization strategies:

- **Fast bins** for small, frequently allocated sizes
- **Small bins** for medium-sized allocations  
- **mmap** for large allocations
- **Coalescing** of adjacent free blocks
- **Top chunk** management for heap extension

See `benchmarks/` for performance testing.

## Memory Debugging

Enable debug mode for additional checks:

```zig
const config = dlmalloc.Config{
    .debug = true,
    .abort_on_corruption = true,
};
```

## Build Options

Configure the build with options:

```bash
zig build -Duse_mmap=false -Ddebug=true -Duse_locks=true
```

Available options:
- `use_mmap` - Enable mmap support (default: true)
- `use_sbrk` - Enable sbrk support (default: true)  
- `use_locks` - Enable thread safety (default: false)
- `debug` - Enable debug mode (default: false)
- `dl_prefix` - Use dl prefix for functions (default: false)

## Testing

Run the test suite:

```bash
zig build test
```

Run examples:

```bash
# Standard allocator example with defer patterns
zig build std-example

# Basic usage example  
zig build example

# External .a library usage
cd examples/external_usage && zig build run
```

### Using the Static Library (.a file)

The build process creates `libdlmalloc-zig.a` in `zig-out/lib/` that can be linked from external projects:

```zig
// External project build.zig
exe.addLibraryPath(b.path("path/to/zig-out/lib"));
exe.linkSystemLibrary("dlmalloc-zig");
exe.linkLibC();
```

See `examples/external_usage/` for a complete example showing:
- Direct C API usage with manual memory management
- Wrapped Zig allocator interface with `defer` support
- Complex data structures with automatic cleanup

Tests cover:
- Basic allocation/deallocation
- Alignment requirements
- Reallocation behavior
- Edge cases and error conditions
- Platform compatibility

## Contributing

This project follows Zig coding conventions. Please:

1. Run `zig build fmt` before committing
2. Ensure `zig build test` passes
3. Test on multiple platforms when possible
4. Update documentation for API changes

## License

This code is released to the public domain, following the original dlmalloc license. Use, modify, and redistribute without restriction.

## Credits

Based on dlmalloc 2.7.2 by Doug Lea. Zig implementation and platform abstraction by the dlmalloc-zig contributors.