const std = @import("std");
const testing = std.testing;
const dlmalloc = @import("dlmalloc");

test "basic allocation and free" {
    const ptr = dlmalloc.malloc(100);
    try testing.expect(ptr != null);
    dlmalloc.free(ptr);
}

test "calloc zeroes memory" {
    const ptr = dlmalloc.calloc(10, 10);
    try testing.expect(ptr != null);
    
    const bytes = @as([*]u8, @ptrCast(ptr))[0..100];
    for (bytes) |byte| {
        try testing.expect(byte == 0);
    }
    
    dlmalloc.free(ptr);
}

test "realloc basic functionality" {
    var ptr = dlmalloc.malloc(50);
    try testing.expect(ptr != null);
    
    // Write some data
    const bytes = @as([*]u8, @ptrCast(ptr));
    bytes[0] = 42;
    bytes[49] = 99;
    
    // Reallocate to larger size
    ptr = dlmalloc.realloc(ptr, 100);
    try testing.expect(ptr != null);
    
    // Check data is preserved
    const new_bytes = @as([*]u8, @ptrCast(ptr));
    try testing.expect(new_bytes[0] == 42);
    try testing.expect(new_bytes[49] == 99);
    
    dlmalloc.free(ptr);
}

test "memalign creates aligned memory" {
    const alignment = 64;
    const ptr = dlmalloc.memalign(alignment, 100);
    try testing.expect(ptr != null);
    
    const addr = @intFromPtr(ptr);
    try testing.expect(addr % alignment == 0);
    
    dlmalloc.free(ptr);
}

test "malloc_usable_size" {
    const ptr = dlmalloc.malloc(100);
    try testing.expect(ptr != null);
    
    const usable_size = dlmalloc.malloc_usable_size(ptr);
    try testing.expect(usable_size >= 100);
    
    dlmalloc.free(ptr);
}

test "multiple allocations" {
    var ptrs: [100]?*anyopaque = undefined;
    
    // Allocate many blocks
    for (&ptrs, 0..) |*ptr, i| {
        ptr.* = dlmalloc.malloc(i + 1);
        try testing.expect(ptr.* != null);
    }
    
    // Free them all
    for (ptrs) |ptr| {
        dlmalloc.free(ptr);
    }
}

test "valloc page alignment" {
    const ptr = dlmalloc.valloc(100);
    try testing.expect(ptr != null);
    
    const page_size = dlmalloc.Platform.getPageSize();
    const addr = @intFromPtr(ptr);
    try testing.expect(addr % page_size == 0);
    
    dlmalloc.free(ptr);
}

test "zero size malloc" {
    const ptr = dlmalloc.malloc(0);
    // Implementation defined - either null or valid pointer
    dlmalloc.free(ptr);
}

test "free null pointer" {
    // Should not crash
    dlmalloc.free(null);
}

test "dl-prefixed functions" {
    const ptr = dlmalloc.dlmalloc(100);
    try testing.expect(ptr != null);
    
    const usable_size = dlmalloc.dlmalloc_usable_size(ptr);
    try testing.expect(usable_size >= 100);
    
    dlmalloc.dlfree(ptr);
}

test "zig allocator interface" {
    var zig_allocator = dlmalloc.ZigAllocator.init(dlmalloc.Config{});
    const allocator = zig_allocator.allocator();
    
    const slice = try allocator.alloc(u8, 100);
    try testing.expect(slice.len == 100);
    
    allocator.free(slice);
}

test "mallopt configuration" {
    const result = dlmalloc.mallopt(dlmalloc.config.M_MXFAST, 32);
    try testing.expect(result == 1); // Success
    
    const invalid_result = dlmalloc.mallopt(dlmalloc.config.M_MXFAST, -1);
    try testing.expect(invalid_result == 0); // Failure
}