const std = @import("std");
const builtin = @import("builtin");

pub const Config = struct {
    // Fast bin settings
    max_fast: usize = 64,
    
    // Trim threshold - when to release memory back to system
    trim_threshold: usize = 128 * 1024,
    
    // Top pad - extra padding when extending heap
    top_pad: usize = 0,
    
    // Mmap threshold - when to use mmap for large allocations
    mmap_threshold: usize = 128 * 1024,
    
    // Maximum number of mmap regions
    mmap_max: u32 = 65536,
    
    // Enable/disable various features
    use_mmap: bool = true,
    use_sbrk: bool = true,
    use_locks: bool = false,
    use_dl_prefix: bool = false,
    
    // Platform specific settings
    page_size: usize = getDefaultPageSize(),
    
    // Debug options
    debug: bool = false,
    abort_on_corruption: bool = true,
    
    fn getDefaultPageSize() usize {
        return switch (builtin.os.tag) {
            .windows => 4096,
            .wasi => 65536,
            else => 4096,
        };
    }
};

pub const default_config = Config{};

// Tuning parameters matching original dlmalloc
pub const M_MXFAST = 1;
pub const M_TRIM_THRESHOLD = -1;
pub const M_TOP_PAD = -2;
pub const M_MMAP_THRESHOLD = -3;
pub const M_MMAP_MAX = -4;