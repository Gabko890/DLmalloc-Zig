const std = @import("std");
const dlmalloc = @import("dlmalloc");

pub fn main() !void {
    std.log.info("DLMalloc-Zig Basic Example", .{});
    
    // Basic allocation
    std.log.info("=== Basic Allocation ===", .{});
    const ptr1 = dlmalloc.malloc(1024);
    if (ptr1) |p| {
        std.log.info("Allocated 1024 bytes at address: 0x{X}", .{@intFromPtr(p)});
        std.log.info("Usable size: {} bytes", .{dlmalloc.malloc_usable_size(p)});
        dlmalloc.free(p);
        std.log.info("Freed memory", .{});
    }
    
    // Calloc - zero-initialized
    std.log.info("\n=== Calloc (Zero-initialized) ===", .{});
    const ptr2 = dlmalloc.calloc(256, 4); // 256 elements of 4 bytes each
    if (ptr2) |p| {
        const bytes = @as([*]u8, @ptrCast(p));
        std.log.info("Allocated {} bytes, first byte: {}, last byte: {}", .{
            dlmalloc.malloc_usable_size(p), bytes[0], bytes[1023]
        });
        dlmalloc.free(p);
    }
    
    // Realloc
    std.log.info("\n=== Realloc ===", .{});
    var ptr3 = dlmalloc.malloc(512);
    if (ptr3) |p| {
        const bytes = @as([*]u8, @ptrCast(p));
        bytes[0] = 0xAA;
        bytes[511] = 0xBB;
        std.log.info("Original: {} bytes, first: 0x{X}, last: 0x{X}", .{
            dlmalloc.malloc_usable_size(p), bytes[0], bytes[511]
        });
        
        ptr3 = dlmalloc.realloc(p, 2048);
        if (ptr3) |new_p| {
            const new_bytes = @as([*]u8, @ptrCast(new_p));
            std.log.info("Reallocated: {} bytes, first: 0x{X}, last: 0x{X}", .{
                dlmalloc.malloc_usable_size(new_p), new_bytes[0], new_bytes[511]
            });
            dlmalloc.free(new_p);
        }
    }
    
    // Aligned allocation
    std.log.info("\n=== Aligned Allocation ===", .{});
    const aligned_ptr = dlmalloc.memalign(64, 1000);
    if (aligned_ptr) |p| {
        const addr = @intFromPtr(p);
        std.log.info("64-byte aligned address: 0x{X} (alignment check: {})", .{
            addr, addr % 64 == 0
        });
        dlmalloc.free(p);
    }
    
    // Page-aligned allocation
    std.log.info("\n=== Page-aligned Allocation (valloc) ===", .{});
    const page_ptr = dlmalloc.valloc(3000);
    if (page_ptr) |p| {
        const addr = @intFromPtr(p);
        const page_size = dlmalloc.Platform.getPageSize();
        std.log.info("Page-aligned address: 0x{X}, page size: {}, aligned: {}", .{
            addr, page_size, addr % page_size == 0
        });
        dlmalloc.free(p);
    }
    
    // Configuration
    std.log.info("\n=== Configuration ===", .{});
    _ = dlmalloc.mallopt(dlmalloc.config.M_MXFAST, 32);
    std.log.info("Set max fast bin size to 32 bytes", .{});
    
    // DL-prefixed functions
    std.log.info("\n=== DL-prefixed Functions ===", .{});
    const dl_ptr = dlmalloc.dlmalloc(256);
    if (dl_ptr) |p| {
        std.log.info("dlmalloc() allocated {} bytes", .{dlmalloc.dlmalloc_usable_size(p)});
        dlmalloc.dlfree(p);
    }
    
    // Zig allocator interface
    std.log.info("\n=== Zig Allocator Interface ===", .{});
    var zig_allocator = dlmalloc.ZigAllocator.init(dlmalloc.Config{});
    const allocator = zig_allocator.allocator();
    
    const slice = try allocator.alloc(u32, 100);
    std.log.info("Allocated slice of {} u32 elements via Zig interface", .{slice.len});
    allocator.free(slice);
    
    // Statistics
    std.log.info("\n=== Memory Statistics ===", .{});
    dlmalloc.malloc_stats();
    
    std.log.info("\nExample completed successfully!", .{});
}