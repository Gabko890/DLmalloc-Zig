const std = @import("std");
const testing = std.testing;
const dlmalloc = @import("dlmalloc");

test "basic compilation and imports" {
    // Test that all the modules compile and can be imported
    const cfg = dlmalloc.Config{};
    _ = cfg;
    
    // Test that platform abstraction works
    const page_size = dlmalloc.Platform.getPageSize();
    try testing.expect(page_size > 0);
    try testing.expect(page_size >= 4096);
}

test "config constants" {
    // Test configuration constants
    try testing.expect(dlmalloc.config.M_MXFAST == 1);
    try testing.expect(dlmalloc.config.M_TRIM_THRESHOLD == -1);
}

test "chunk constants" {
    // Test that chunk header constants are accessible
    const header = std.mem.zeroes(dlmalloc.chunk.ChunkHeader);
    _ = header;
    
    try testing.expect(dlmalloc.chunk.ChunkHeader.PREV_INUSE == 0x1);
    try testing.expect(dlmalloc.chunk.ChunkHeader.IS_MMAPPED == 0x2);
    try testing.expect(dlmalloc.chunk.MIN_CHUNK_SIZE > 0);
}

test "platform abstraction" {
    // Test platform utilities
    const result = dlmalloc.Platform.isValidPointer(null);
    try testing.expect(result == false);
    
    // Test with a valid stack pointer
    var x: u32 = 42;
    const valid_result = dlmalloc.Platform.isValidPointer(&x);
    try testing.expect(valid_result == true);
}