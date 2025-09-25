const std = @import("std");
const dlmalloc = @import("dlmalloc");

pub fn main() !void {
    std.log.info("DLMalloc as Zig Standard Allocator Example", .{});
    
    // Create a dlmalloc-based Zig allocator
    var dl_allocator = dlmalloc.ZigAllocator.init(dlmalloc.Config{});
    const allocator = dl_allocator.allocator();
    
    std.log.info("\n=== Using defer with dlmalloc allocator ===", .{});
    
    // Example 1: Simple allocation with defer
    {
        const memory = try allocator.alloc(u8, 1024);
        defer allocator.free(memory);  // Automatically freed when scope exits
        
        // Use the memory
        @memset(memory, 0xAA);
        std.log.info("Allocated {} bytes, filled with 0xAA", .{memory.len});
        std.log.info("First byte: 0x{X}, last byte: 0x{X}", .{ memory[0], memory[memory.len-1] });
    } // memory is automatically freed here due to defer
    
    // Example 2: ArrayList with dlmalloc
    std.log.info("\n=== ArrayList with dlmalloc ===", .{});
    {
        var list = std.ArrayList(u32){};
        defer list.deinit(allocator); // Automatically cleans up when scope exits
        
        // Add some items
        try list.append(allocator, 1);
        try list.append(allocator, 2);
        try list.append(allocator, 3);
        try list.append(allocator, 4);
        
        std.log.info("ArrayList contains: {any}", .{list.items});
        std.log.info("ArrayList capacity: {}", .{list.capacity});
    } // list is automatically cleaned up here
    
    // Example 3: Simple allocations instead of HashMap complexity
    std.log.info("\n=== Multiple allocations with dlmalloc ===", .{});
    {
        const buffer1 = try allocator.alloc(i32, 10);
        defer allocator.free(buffer1);
        
        const buffer2 = try allocator.alloc(f64, 5); 
        defer allocator.free(buffer2);
        
        // Fill buffers
        for (buffer1, 0..) |*item, i| {
            item.* = @intCast(i * 2);
        }
        
        for (buffer2, 0..) |*item, i| {
            item.* = @as(f64, @floatFromInt(i)) * 3.14;
        }
        
        std.log.info("Buffer1[5] = {}, Buffer2[2] = {d:.2}", .{ buffer1[5], buffer2[2] });
    } // buffers are automatically freed
    
    // Example 4: Error handling with cleanup
    std.log.info("\n=== Error handling with proper cleanup ===", .{});
    {
        const result = allocateAndProcess(allocator);
        if (result) |data| {
            defer allocator.free(data); // Cleanup on success
            std.log.info("Processing succeeded, got {} bytes", .{data.len});
        } else |err| {
            std.log.info("Processing failed: {}", .{err});
        }
    }
    
    // Example 5: Nested allocations with proper cleanup
    std.log.info("\n=== Nested allocations ===", .{});
    {
        const outer = try allocator.alloc(u8, 512);
        defer allocator.free(outer);
        
        const inner = try allocator.alloc(u32, 100);  
        defer allocator.free(inner);
        
        // Use both allocations
        @memset(outer, 0xBB);
        for (inner, 0..) |*item, i| {
            item.* = @intCast(i * i);
        }
        
        std.log.info("Outer: {} bytes, Inner: {} items", .{ outer.len, inner.len });
        std.log.info("Inner[10] = {}", .{inner[10]});
    } // Both allocations automatically freed in reverse order
    
    // Example 6: Custom struct with allocator
    std.log.info("\n=== Custom struct using allocator ===", .{});
    {
        var buffer = try StringBuffer.init(allocator);
        defer buffer.deinit(); // Cleanup the struct
        
        try buffer.append("Hello ");
        try buffer.append("from ");
        try buffer.append("dlmalloc!");
        
        std.log.info("Buffer contents: '{s}'", .{buffer.data()});
        std.log.info("Buffer length: {}", .{buffer.len()});
    }
    
    // Show final memory statistics
    std.log.info("\n=== Final Memory Statistics ===", .{});
    dlmalloc.malloc_stats();
    
    std.log.info("\nExample completed successfully!", .{});
}

// Helper function that shows error handling with allocations
fn allocateAndProcess(allocator: std.mem.Allocator) ![]u8 {
    const data = try allocator.alloc(u8, 256);
    errdefer allocator.free(data); // Cleanup on error
    
    // Simulate some processing that might fail
    if (data.len < 100) {
        return error.BufferTooSmall; // This would trigger errdefer cleanup
    }
    
    // Fill with some data
    for (data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }
    
    return data; // Caller takes ownership
}

// Example custom struct that uses the allocator
const StringBuffer = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    length: usize,
    
    const Self = @This();
    
    pub fn init(allocator: std.mem.Allocator) !Self {
        const buffer = try allocator.alloc(u8, 256);
        return Self{
            .allocator = allocator,
            .buffer = buffer,
            .length = 0,
        };
    }
    
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }
    
    pub fn append(self: *Self, str: []const u8) !void {
        if (self.length + str.len > self.buffer.len) {
            return error.BufferFull;
        }
        
        @memcpy(self.buffer[self.length..self.length + str.len], str);
        self.length += str.len;
    }
    
    pub fn data(self: *const Self) []const u8 {
        return self.buffer[0..self.length];
    }
    
    pub fn len(self: *const Self) usize {
        return self.length;
    }
};