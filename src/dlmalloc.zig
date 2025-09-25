const std = @import("std");
pub const config = @import("config.zig");
pub const platform = @import("platform.zig");
pub const chunk = @import("chunk.zig");
const allocator_mod = @import("allocator.zig");

pub const Config = config.Config;
pub const Platform = platform.Platform;
pub const DlmallocAllocator = allocator_mod.DlmallocAllocator;

// Global allocator instance
var global_allocator: ?DlmallocAllocator = null;
var global_allocator_mutex: std.Thread.Mutex = .{};

fn getGlobalAllocator() *DlmallocAllocator {
    if (global_allocator == null) {
        global_allocator_mutex.lock();
        defer global_allocator_mutex.unlock();
        
        if (global_allocator == null) {
            global_allocator = DlmallocAllocator.init(config.default_config);
        }
    }
    return &global_allocator.?;
}

// Standard malloc interface
pub export fn malloc(size: usize) ?*anyopaque {
    return getGlobalAllocator().malloc(size);
}

pub export fn free(ptr: ?*anyopaque) void {
    getGlobalAllocator().free(ptr);
}

pub export fn calloc(num: usize, size: usize) ?*anyopaque {
    const total_size = num * size;
    if (num != 0 and total_size / num != size) return null; // overflow check
    
    const ptr = malloc(total_size) orelse return null;
    @memset(@as([*]u8, @ptrCast(ptr))[0..total_size], 0);
    return ptr;
}

pub export fn realloc(ptr: ?*anyopaque, size: usize) ?*anyopaque {
    return getGlobalAllocator().realloc(ptr, size);
}

pub export fn malloc_usable_size(ptr: ?*anyopaque) usize {
    return DlmallocAllocator.usableSize(ptr);
}

// Aligned allocation functions
pub export fn memalign(alignment: usize, size: usize) ?*anyopaque {
    if (alignment == 0 or (alignment & (alignment - 1)) != 0) return null;
    if (alignment <= @sizeOf(usize) * 2) return malloc(size);
    
    const total_size = size + alignment + @sizeOf(usize);
    const raw_ptr = malloc(total_size) orelse return null;
    
    const raw_addr = @intFromPtr(raw_ptr);
    const aligned_addr = std.mem.alignForward(usize, raw_addr + @sizeOf(usize), alignment);
    const aligned_ptr = @as(*anyopaque, @ptrFromInt(aligned_addr));
    
    // Store the original pointer before the aligned block
    const header = @as(*usize, @ptrFromInt(aligned_addr - @sizeOf(usize)));
    header.* = raw_addr;
    
    return aligned_ptr;
}

pub export fn valloc(size: usize) ?*anyopaque {
    return memalign(Platform.getPageSize(), size);
}

pub export fn pvalloc(size: usize) ?*anyopaque {
    const page_size = Platform.getPageSize();
    const aligned_size = std.mem.alignForward(usize, size, page_size);
    return valloc(aligned_size);
}

pub export fn cfree(ptr: ?*anyopaque) void {
    free(ptr);
}

// Extended dlmalloc interface (with dl prefix)
pub export fn dlmalloc(size: usize) ?*anyopaque {
    return malloc(size);
}

pub export fn dlfree(ptr: ?*anyopaque) void {
    free(ptr);
}

pub export fn dlcalloc(num: usize, size: usize) ?*anyopaque {
    return calloc(num, size);
}

pub export fn dlrealloc(ptr: ?*anyopaque, size: usize) ?*anyopaque {
    return realloc(ptr, size);
}

pub export fn dlmemalign(alignment: usize, size: usize) ?*anyopaque {
    return memalign(alignment, size);
}

pub export fn dlvalloc(size: usize) ?*anyopaque {
    return valloc(size);
}

pub export fn dlpvalloc(size: usize) ?*anyopaque {
    return pvalloc(size);
}

pub export fn dlcfree(ptr: ?*anyopaque) void {
    cfree(ptr);
}

pub export fn dlmalloc_usable_size(ptr: ?*anyopaque) usize {
    return malloc_usable_size(ptr);
}

// Configuration and tuning
pub export fn mallopt(param: c_int, value: c_int) c_int {
    const allocator = getGlobalAllocator();
    
    switch (param) {
        config.M_MXFAST => {
            if (value >= 0 and value <= 80) {
                allocator.config.max_fast = @intCast(value);
                return 1;
            }
        },
        config.M_TRIM_THRESHOLD => {
            if (value >= 0) {
                allocator.trim_threshold = @intCast(value);
                return 1;
            }
        },
        config.M_TOP_PAD => {
            if (value >= 0) {
                allocator.top_pad = @intCast(value);
                return 1;
            }
        },
        config.M_MMAP_THRESHOLD => {
            if (value >= 0) {
                allocator.mmap_threshold = @intCast(value);
                return 1;
            }
        },
        config.M_MMAP_MAX => {
            if (value >= 0) {
                allocator.config.mmap_max = @intCast(value);
                return 1;
            }
        },
        else => {},
    }
    
    return 0;
}

pub export fn dlmallopt(param: c_int, value: c_int) c_int {
    return mallopt(param, value);
}

// Statistics and info
pub const mallinfo = extern struct {
    arena: c_int,
    ordblks: c_int,
    smblks: c_int,
    hblks: c_int,
    hblkhd: c_int,
    usmblks: c_int,
    fsmblks: c_int,
    uordblks: c_int,
    fordblks: c_int,
    keepcost: c_int,
};

pub export fn malloc_stats() void {
    // Use log.info instead of direct stdout to avoid API issues
    const allocator = getGlobalAllocator();
    
    std.log.info("Memory allocation statistics:", .{});
    std.log.info("  Total sbrked: {} bytes", .{allocator.sbrked_mem});
    std.log.info("  Total mmapped: {} bytes", .{allocator.mmapped_mem});
    std.log.info("  Max sbrked: {} bytes", .{allocator.max_sbrked_mem});
    std.log.info("  Max mmapped: {} bytes", .{allocator.max_mmapped_mem});
    std.log.info("  Current mmap regions: {}", .{allocator.n_mmaps});
    std.log.info("  Max mmap regions: {}", .{allocator.n_mmaps_max});
    std.log.info("  Trim threshold: {} bytes", .{allocator.trim_threshold});
    std.log.info("  Mmap threshold: {} bytes", .{allocator.mmap_threshold});
    std.log.info("  Top pad: {} bytes", .{allocator.top_pad});
}

pub export fn dlmalloc_stats() void {
    malloc_stats();
}

// Zig-style allocator interface
pub const ZigAllocator = struct {
    dlmalloc_allocator: *DlmallocAllocator,
    
    const Self = @This();
    
    pub fn init(cfg: Config) Self {
        // This would need to be managed differently in a real implementation
        // to avoid the global allocator
        _ = cfg;
        return Self{
            .dlmalloc_allocator = getGlobalAllocator(),
        };
    }
    
    pub fn allocator(self: *Self) std.mem.Allocator {
        return std.mem.Allocator{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = freeImpl,
                .remap = remap,
            },
        };
    }
    
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        const alignment = ptr_align.toByteUnits();
        
        if (alignment <= @sizeOf(usize) * 2) {
            const ptr = self.dlmalloc_allocator.malloc(len) orelse return null;
            return @as([*]u8, @ptrCast(ptr));
        } else {
            const ptr = memalign(alignment, len) orelse return null;
            return @as([*]u8, @ptrCast(ptr));
        }
    }
    
    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;
        
        const current_size = DlmallocAllocator.usableSize(buf.ptr);
        return new_len <= current_size;
    }
    
    fn freeImpl(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = buf_align;
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.dlmalloc_allocator.free(buf.ptr);
    }
    
    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;
        _ = buf;
        _ = new_len;
        return null; // Not supported
    }
};