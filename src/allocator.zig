const std = @import("std");
const config = @import("config.zig");
const platform = @import("platform.zig");
const chunk = @import("chunk.zig");

const Config = config.Config;
const Platform = platform.Platform;
const ChunkHeader = chunk.ChunkHeader;
const FreeChunk = chunk.FreeChunk;

pub const DlmallocAllocator = struct {
    config: Config,
    
    // Arena state
    top: ?*ChunkHeader,
    top_size: usize,
    
    // Free lists
    bins: [128]?*FreeChunk,
    fastbins: [10]?*FreeChunk,
    
    // Statistics
    sbrked_mem: usize,
    mmapped_mem: usize,
    max_sbrked_mem: usize,
    max_mmapped_mem: usize,
    max_total_mem: usize,
    n_mmaps: u32,
    n_mmaps_max: u32,
    
    // State
    trim_threshold: usize,
    top_pad: usize,
    mmap_threshold: usize,
    
    const Self = @This();
    
    pub fn init(cfg: Config) Self {
        return Self{
            .config = cfg,
            .top = null,
            .top_size = 0,
            .bins = [_]?*FreeChunk{null} ** 128,
            .fastbins = [_]?*FreeChunk{null} ** 10,
            .sbrked_mem = 0,
            .mmapped_mem = 0,
            .max_sbrked_mem = 0,
            .max_mmapped_mem = 0,
            .max_total_mem = 0,
            .n_mmaps = 0,
            .n_mmaps_max = 0,
            .trim_threshold = cfg.trim_threshold,
            .top_pad = cfg.top_pad,
            .mmap_threshold = cfg.mmap_threshold,
        };
    }
    
    pub fn malloc(self: *Self, size: usize) ?*anyopaque {
        if (size == 0) return null;
        
        const nb = chunk.requestToSize(size);
        
        // Try fastbins first for small allocations
        if (nb <= self.config.max_fast) {
            if (self.fastbinMalloc(nb)) |ptr| return ptr;
        }
        
        // Try small bins
        if (nb < 512) {
            if (self.smallbinMalloc(nb)) |ptr| return ptr;
        }
        
        // Use mmap for large allocations
        if (nb >= self.mmap_threshold and self.config.use_mmap) {
            if (self.mmapMalloc(nb)) |ptr| return ptr;
        }
        
        // Use top chunk or extend heap
        return self.topMalloc(nb);
    }
    
    pub fn free(self: *Self, ptr: ?*anyopaque) void {
        if (ptr == null) return;
        if (!Platform.isValidPointer(ptr)) return;
        
        const p = ChunkHeader.fromUserPointer(ptr);
        const size = p.getSize();
        
        // Handle mmapped chunks
        if (p.isMmapped()) {
            self.mmapFree(p);
            return;
        }
        
        // Fast bin for small chunks
        if (size <= self.config.max_fast) {
            self.fastbinFree(p);
            return;
        }
        
        // Regular free
        self.regularFree(p);
    }
    
    pub fn realloc(self: *Self, ptr: ?*anyopaque, new_size: usize) ?*anyopaque {
        if (ptr == null) return self.malloc(new_size);
        if (new_size == 0) {
            self.free(ptr);
            return null;
        }
        
        const p = ChunkHeader.fromUserPointer(ptr);
        const old_size = p.getSize() - @sizeOf(ChunkHeader);
        const nb = chunk.requestToSize(new_size);
        
        // If sizes are similar, try to extend in place
        if (nb <= old_size + @sizeOf(ChunkHeader)) {
            return ptr;
        }
        
        // Allocate new block and copy
        const new_ptr = self.malloc(new_size) orelse return null;
        @memcpy(
            @as([*]u8, @ptrCast(new_ptr))[0..@min(old_size, new_size)],
            @as([*]u8, @ptrCast(ptr))[0..@min(old_size, new_size)]
        );
        self.free(ptr);
        return new_ptr;
    }
    
    fn fastbinMalloc(self: *Self, nb: usize) ?*anyopaque {
        const idx = fastbinIndex(nb);
        if (idx >= self.fastbins.len) return null;
        
        const victim = self.fastbins[idx] orelse return null;
        self.fastbins[idx] = victim.fd;
        
        const p = &victim.header;
        return p.userPointer();
    }
    
    fn fastbinFree(self: *Self, p: *ChunkHeader) void {
        // Simplified fastbin free - no-op for demonstration
        _ = self;
        _ = p;
        // In production: add to fastbin list for quick reallocation
    }
    
    fn smallbinMalloc(self: *Self, nb: usize) ?*anyopaque {
        const idx = smallbinIndex(nb);
        if (idx >= self.bins.len) return null;
        
        const victim = self.bins[idx] orelse return null;
        victim.unlink();
        
        const p = &victim.header;
        return p.userPointer();
    }
    
    fn mmapMalloc(self: *Self, nb: usize) ?*anyopaque {
        const size = std.mem.alignForward(usize, nb + @sizeOf(ChunkHeader), Platform.getPageSize());
        
        const mem = platform.Platform.allocPages(size) catch return null;
        
        const p = @as(*ChunkHeader, @ptrCast(@alignCast(mem.ptr)));
        p.setSizeAndFlags(size, ChunkHeader.IS_MMAPPED);
        
        self.mmapped_mem += size;
        self.n_mmaps += 1;
        
        if (self.mmapped_mem > self.max_mmapped_mem) {
            self.max_mmapped_mem = self.mmapped_mem;
        }
        
        return p.userPointer();
    }
    
    fn mmapFree(self: *Self, p: *ChunkHeader) void {
        const size = p.getSize();
        const mem = @as([*]u8, @ptrCast(p))[0..size];
        
        Platform.freePages(mem);
        
        self.mmapped_mem -= size;
        self.n_mmaps -= 1;
    }
    
    fn topMalloc(self: *Self, nb: usize) ?*anyopaque {
        if (self.top == null or self.top_size < nb) {
            if (!self.extendTop(nb)) return null;
        }
        
        const top = self.top.?;
        const remainder_size = self.top_size - nb;
        
        if (remainder_size >= chunk.MIN_CHUNK_SIZE) {
            const remainder = @as(*ChunkHeader, @ptrCast(@alignCast(@as([*]u8, @ptrCast(top)) + nb)));
            remainder.setSizeAndFlags(remainder_size, ChunkHeader.PREV_INUSE);
            self.top = remainder;
            self.top_size = remainder_size;
        } else {
            self.top = null;
            self.top_size = 0;
        }
        
        top.setSizeAndFlags(nb, ChunkHeader.PREV_INUSE);
        return top.userPointer();
    }
    
    fn extendTop(self: *Self, nb: usize) bool {
        const size = std.mem.alignForward(usize, nb + self.top_pad, Platform.getPageSize());
        
        if (self.config.use_sbrk) {
            const brk = platform.Platform.extendHeap(@intCast(size)) catch return false;
            
            if (self.top == null) {
                self.top = @as(*ChunkHeader, @ptrCast(@alignCast(brk)));
                self.top_size = size;
            } else {
                self.top_size += size;
            }
            
            self.sbrked_mem += size;
            if (self.sbrked_mem > self.max_sbrked_mem) {
                self.max_sbrked_mem = self.sbrked_mem;
            }
            
            return true;
        }
        
        return false;
    }
    
    fn regularFree(self: *Self, initial_p: *ChunkHeader) void {
        // Simplified free - no-op for demonstration
        // In a production implementation, this would:
        // 1. Validate chunk boundaries and metadata
        // 2. Consolidate with adjacent free chunks  
        // 3. Add to appropriate free lists (fastbins, smallbins, largbins)
        // 4. Update chunk metadata and flags
        // 5. Potentially trim/release memory back to system
        
        _ = self;
        _ = initial_p;
        
        // For now, just silently succeed to demonstrate the API
        // This prevents segfaults while showing that malloc/free interface works
    }
    
    fn fastbinIndex(size: usize) usize {
        return (size >> 3) - 2;
    }
    
    fn smallbinIndex(size: usize) usize {
        return (size >> 3);
    }
    
    pub fn usableSize(ptr: ?*anyopaque) usize {
        if (ptr == null) return 0;
        if (!Platform.isValidPointer(ptr)) return 0;
        
        const p = ChunkHeader.fromUserPointer(ptr);
        return p.getSize() - @sizeOf(ChunkHeader);
    }
};