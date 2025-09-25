const std = @import("std");
const builtin = @import("builtin");

// C API declarations without dynamic inclusion
pub const c = struct {
    // Standard C library functions we need
    extern "c" fn sbrk(increment: isize) ?*anyopaque;
    extern "c" fn mmap(addr: ?*anyopaque, length: usize, prot: c_int, flags: c_int, fd: c_int, offset: isize) ?*anyopaque;
    extern "c" fn munmap(addr: ?*anyopaque, length: usize) c_int;
    extern "c" fn getpagesize() c_int;
    
    // Platform-specific constants
    pub const PROT_READ = 0x1;
    pub const PROT_WRITE = 0x2;
    pub const MAP_PRIVATE = switch (builtin.os.tag) {
        .linux => 0x02,
        .macos, .ios, .watchos, .tvos => 0x0002,
        else => 0x02,
    };
    pub const MAP_ANONYMOUS = switch (builtin.os.tag) {
        .linux => 0x20,
        .macos, .ios, .watchos, .tvos => 0x1000,
        else => 0x20,
    };
    pub const MAP_FAILED = @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))));
};

// Safe wrappers around C functions
pub const CSafety = struct {
    pub fn sbrk(increment: isize) ?*anyopaque {
        return switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => blk: {
                const result = c.sbrk(increment);
                if (result == @as(?*anyopaque, @ptrFromInt(@as(usize, @bitCast(@as(isize, -1)))))) {
                    break :blk null;
                }
                break :blk result;
            },
            .wasi => null,
            else => null,
        };
    }

    pub fn mmap(addr: ?*anyopaque, length: usize, prot: c_int, flags: c_int, fd: c_int, offset: isize) ?*anyopaque {
        return switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => blk: {
                const result = c.mmap(addr, length, prot, flags, fd, offset);
                if (result == c.MAP_FAILED) {
                    break :blk null;
                }
                break :blk result;
            },
            else => null,
        };
    }

    pub fn munmap(addr: ?*anyopaque, length: usize) c_int {
        return switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => c.munmap(addr, length),
            else => -1,
        };
    }

    pub fn getPageSize() usize {
        return switch (builtin.os.tag) {
            .linux, .macos, .ios, .watchos, .tvos => blk: {
                const page_size = c.getpagesize();
                break :blk if (page_size > 0) @intCast(page_size) else 4096;
            },
            .wasi => 65536,
            else => 4096,
        };
    }
};