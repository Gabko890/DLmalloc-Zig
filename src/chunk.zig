const std = @import("std");

// Chunk header structure - matches dlmalloc layout
pub const ChunkHeader = extern struct {
    prev_size: usize,  // Size of previous chunk (if free)
    size: usize,       // Size of this chunk (with flags in low bits)
    
    pub const PREV_INUSE = 0x1;    // Previous chunk is in use
    pub const IS_MMAPPED = 0x2;    // Chunk obtained via mmap
    pub const NON_MAIN_ARENA = 0x4; // Chunk belongs to non-main arena
    
    const SIZE_BITS: usize = PREV_INUSE | IS_MMAPPED | NON_MAIN_ARENA;
    
    pub fn getSize(self: *const ChunkHeader) usize {
        return self.size & ~SIZE_BITS;
    }
    
    pub fn setSize(self: *ChunkHeader, size: usize) void {
        self.size = size | (self.size & SIZE_BITS);
    }
    
    pub fn setSizeAndFlags(self: *ChunkHeader, size: usize, flags: usize) void {
        self.size = size | flags;
    }
    
    pub fn isPrevInUse(self: *const ChunkHeader) bool {
        return (self.size & PREV_INUSE) != 0;
    }
    
    pub fn setPrevInUse(self: *ChunkHeader) void {
        self.size |= PREV_INUSE;
    }
    
    pub fn clearPrevInUse(self: *ChunkHeader) void {
        self.size &= ~@as(usize, PREV_INUSE);
    }
    
    pub fn isMmapped(self: *const ChunkHeader) bool {
        return (self.size & IS_MMAPPED) != 0;
    }
    
    pub fn setMmapped(self: *ChunkHeader) void {
        self.size |= IS_MMAPPED;
    }
    
    pub fn clearMmapped(self: *ChunkHeader) void {
        self.size &= ~@as(usize, IS_MMAPPED);
    }
    
    pub fn isNonMainArena(self: *const ChunkHeader) bool {
        return (self.size & NON_MAIN_ARENA) != 0;
    }
    
    pub fn setNonMainArena(self: *ChunkHeader) void {
        self.size |= NON_MAIN_ARENA;
    }
    
    pub fn nextChunk(self: *const ChunkHeader) *ChunkHeader {
        const self_ptr = @as([*]u8, @ptrCast(@constCast(self)));
        return @as(*ChunkHeader, @ptrCast(@alignCast(self_ptr + self.getSize())));
    }
    
    pub fn prevChunk(self: *const ChunkHeader) *ChunkHeader {
        const self_ptr = @as([*]u8, @ptrCast(@constCast(self)));
        return @as(*ChunkHeader, @ptrCast(@alignCast(self_ptr - self.prev_size)));
    }
    
    pub fn userPointer(self: *const ChunkHeader) *anyopaque {
        const self_ptr = @as([*]u8, @ptrCast(@constCast(self)));
        return @as(*anyopaque, @ptrCast(self_ptr + @sizeOf(ChunkHeader)));
    }
    
    pub fn fromUserPointer(ptr: ?*anyopaque) *ChunkHeader {
        if (ptr == null) return undefined;
        const user_ptr = @as([*]u8, @ptrCast(ptr));
        return @as(*ChunkHeader, @ptrCast(@alignCast(user_ptr - @sizeOf(ChunkHeader))));
    }
};

// Free chunk structure - extends ChunkHeader with link pointers
pub const FreeChunk = extern struct {
    header: ChunkHeader,
    fd: ?*FreeChunk,    // Forward pointer in free list
    bk: ?*FreeChunk,    // Backward pointer in free list
    
    pub fn init(self: *FreeChunk, size: usize) void {
        self.header.prev_size = 0;
        self.header.size = size;
        self.fd = null;
        self.bk = null;
    }
    
    pub fn unlink(self: *FreeChunk) void {
        if (self.fd) |fd| fd.bk = self.bk;
        if (self.bk) |bk| bk.fd = self.fd;
    }
    
    pub fn linkAfter(self: *FreeChunk, prev: *FreeChunk) void {
        self.fd = prev.fd;
        self.bk = prev;
        if (prev.fd) |fd| fd.bk = self;
        prev.fd = self;
    }
};

// Constants from dlmalloc
pub const MIN_CHUNK_SIZE = @sizeOf(ChunkHeader) + 2 * @sizeOf(usize);
pub const MALLOC_ALIGNMENT = 2 * @sizeOf(usize);

pub fn chunkAlign(size: usize) usize {
    return std.mem.alignForward(usize, size, MALLOC_ALIGNMENT);
}

pub fn requestToSize(req: usize) usize {
    const aligned = chunkAlign(req + @sizeOf(ChunkHeader));
    return if (aligned < MIN_CHUNK_SIZE) MIN_CHUNK_SIZE else aligned;
}