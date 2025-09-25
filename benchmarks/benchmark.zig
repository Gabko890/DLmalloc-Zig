const std = @import("std");
const dlmalloc = @import("dlmalloc");

const BenchmarkResult = struct {
    name: []const u8,
    operations: u64,
    time_ns: u64,
    ops_per_sec: f64,
};

fn benchmark(comptime name: []const u8, operations: u64, func: fn () void) BenchmarkResult {
    const start = std.time.nanoTimestamp();
    
    var i: u64 = 0;
    while (i < operations) : (i += 1) {
        func();
    }
    
    const end = std.time.nanoTimestamp();
    const elapsed = @as(u64, @intCast(end - start));
    const ops_per_sec = @as(f64, @floatFromInt(operations * std.time.ns_per_s)) / @as(f64, @floatFromInt(elapsed));
    
    return BenchmarkResult{
        .name = name,
        .operations = operations,
        .time_ns = elapsed,
        .ops_per_sec = ops_per_sec,
    };
}

fn printResult(result: BenchmarkResult) void {
    const time_ms = @as(f64, @floatFromInt(result.time_ns)) / 1_000_000.0;
    std.log.info("{s}: {} ops in {d:.2}ms ({d:.0} ops/sec)", .{
        result.name,
        result.operations,
        time_ms,
        result.ops_per_sec,
    });
}

fn benchmarkMalloc() void {
    const ptr = dlmalloc.malloc(64);
    dlmalloc.free(ptr);
}

fn benchmarkCalloc() void {
    const ptr = dlmalloc.calloc(16, 4);
    dlmalloc.free(ptr);
}

fn benchmarkRealloc() void {
    var ptr = dlmalloc.malloc(32);
    ptr = dlmalloc.realloc(ptr, 128);
    dlmalloc.free(ptr);
}

fn benchmarkMemalign() void {
    const ptr = dlmalloc.memalign(64, 100);
    dlmalloc.free(ptr);
}

var preallocated: [1000]?*anyopaque = undefined;

fn benchmarkRandomFree() void {
    // Pre-allocate some blocks
    for (&preallocated, 0..) |*ptr, i| {
        ptr.* = dlmalloc.malloc(64 + (i % 256));
    }
    
    // Free them in random order
    var rng = std.Random.DefaultPrng.init(12345);
    var indices = [_]usize{0} ** 1000;
    for (&indices, 0..) |*idx, i| {
        idx.* = i;
    }
    
    // Shuffle
    for (0..1000) |i| {
        const j = rng.random().uintLessThan(usize, 1000);
        const temp = indices[i];
        indices[i] = indices[j];
        indices[j] = temp;
    }
    
    // Free in shuffled order
    for (indices) |idx| {
        dlmalloc.free(preallocated[idx]);
    }
}

fn benchmarkZigAllocator() void {
    var zig_allocator = dlmalloc.ZigAllocator.init(dlmalloc.Config{});
    const allocator = zig_allocator.allocator();
    
    const slice = allocator.alloc(u8, 64) catch return;
    allocator.free(slice);
}

pub fn main() !void {
    std.log.info("DLMalloc-Zig Benchmark Suite", .{});
    std.log.info("============================", .{});
    
    const operations = 1_000_000;
    
    // Warm up
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        benchmarkMalloc();
    }
    
    // Run benchmarks
    const results = [_]BenchmarkResult{
        benchmark("malloc/free(64)", operations, benchmarkMalloc),
        benchmark("calloc/free(16*4)", operations, benchmarkCalloc),
        benchmark("malloc/realloc/free", operations / 10, benchmarkRealloc),
        benchmark("memalign/free(64,100)", operations, benchmarkMemalign),
        benchmark("zig allocator", operations, benchmarkZigAllocator),
    };
    
    std.log.info("", .{});
    for (results) |result| {
        printResult(result);
    }
    
    // Special test for fragmentation
    std.log.info("", .{});
    std.log.info("Random free test (1000 allocs/frees):", .{});
    const random_start = std.time.nanoTimestamp();
    benchmarkRandomFree();
    const random_end = std.time.nanoTimestamp();
    const random_elapsed = @as(u64, @intCast(random_end - random_start));
    const random_ms = @as(f64, @floatFromInt(random_elapsed)) / 1_000_000.0;
    std.log.info("Random allocation/free pattern: {d:.2}ms", .{random_ms});
    
    std.log.info("", .{});
    std.log.info("Memory statistics:", .{});
    dlmalloc.malloc_stats();
}