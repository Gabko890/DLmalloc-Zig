const std = @import("std");
const builtin = @import("builtin");
const c_compat = @import("c_compat.zig");

pub const MemoryError = error{
    OutOfMemory,
    SystemError,
    InvalidArgument,
};

pub const Platform = struct {
    pub fn getPageSize() usize {
        return c_compat.CSafety.getPageSize();
    }

    pub fn allocPages(size: usize) MemoryError![]u8 {
        const aligned_size = std.mem.alignForward(usize, size, getPageSize());
        
        return switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => blk: {
                const ptr = c_compat.CSafety.mmap(
                    null,
                    aligned_size,
                    c_compat.c.PROT_READ | c_compat.c.PROT_WRITE,
                    c_compat.c.MAP_PRIVATE | c_compat.c.MAP_ANONYMOUS,
                    -1,
                    0,
                ) orelse return MemoryError.OutOfMemory;
                break :blk @as([*]u8, @ptrCast(ptr))[0..aligned_size];
            },
            .windows => blk: {
                const ptr = std.os.windows.VirtualAlloc(
                    null,
                    aligned_size,
                    std.os.windows.MEM_COMMIT | std.os.windows.MEM_RESERVE,
                    std.os.windows.PAGE_READWRITE,
                ) catch return MemoryError.OutOfMemory;
                break :blk @as([*]u8, @ptrCast(ptr))[0..aligned_size];
            },
            .wasi => {
                // WASI uses memory.grow - for now just fail
                // TODO: Implement proper WASI memory management
                return MemoryError.SystemError;
            },
            else => MemoryError.SystemError,
        };
    }

    pub fn freePages(memory: []u8) void {
        switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => {
                _ = c_compat.CSafety.munmap(memory.ptr, memory.len);
            },
            .windows => {
                _ = std.os.windows.VirtualFree(memory.ptr, 0, std.os.windows.MEM_RELEASE);
            },
            .wasi => {
                // WASI doesn't support freeing individual pages
            },
            else => {},
        }
    }

    pub fn extendHeap(size: isize) MemoryError!?*anyopaque {
        const result = c_compat.CSafety.sbrk(size);
        return result orelse MemoryError.OutOfMemory;
    }

    pub fn isValidPointer(ptr: ?*anyopaque) bool {
        if (ptr == null) return false;
        
        const addr = @intFromPtr(ptr.?);
        const page_size = getPageSize();
        
        // Basic alignment check
        if (addr % @sizeOf(usize) != 0) return false;
        
        // Platform-specific checks
        return switch (builtin.os.tag) {
            .linux => addr >= page_size and addr < (1 << 47), // x86_64 userspace limit
            .windows => addr >= 0x10000 and addr < (1 << 47), // Windows userspace
            .wasi => addr < (1 << 32), // 32-bit address space
            else => addr >= page_size,
        };
    }
};