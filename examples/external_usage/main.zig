const std = @import("std");

// Direct C API usage (when linking against .a file)
extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;
extern "c" fn calloc(num: usize, size: usize) ?*anyopaque;
extern "c" fn realloc(ptr: ?*anyopaque, size: usize) ?*anyopaque;
extern "c" fn malloc_usable_size(ptr: ?*anyopaque) usize;
extern "c" fn memalign(alignment: usize, size: usize) ?*anyopaque;
extern "c" fn malloc_stats() void;

// Wrapper to make it a Zig allocator
const DLMallocAllocator = struct {
    const Self = @This();
    
    pub fn allocator(self: *Self) std.mem.Allocator {
        _ = self;
        return std.mem.Allocator{
            .ptr = undefined,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize, 
                .free = freeImpl,
                .remap = remap,
            },
        };
    }
    
    fn alloc(_: *anyopaque, len: usize, ptr_align: std.mem.Alignment, _: usize) ?[*]u8 {
        const alignment = ptr_align.toByteUnits();
        
        const ptr = if (alignment <= 16) // Default malloc alignment
            malloc(len)
        else 
            memalign(alignment, len);
            
        return @as(?[*]u8, @ptrCast(ptr));
    }
    
    fn resize(_: *anyopaque, buf: []u8, _: std.mem.Alignment, new_len: usize, _: usize) bool {
        const current_size = malloc_usable_size(buf.ptr);
        return new_len <= current_size;
    }
    
    fn freeImpl(_: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void {
        free(buf.ptr);
    }
    
    fn remap(_: *anyopaque, buf: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        const new_ptr = realloc(buf.ptr, new_len) orelse return null;
        return @as([*]u8, @ptrCast(new_ptr));
    }
};

pub fn main() !void {
    std.log.info("External Usage: Using libdlmalloc-zig.a", .{});
    
    // Method 1: Direct C API usage
    std.log.info("\n=== Direct C API Usage ===", .{});
    {
        const ptr = malloc(1024);
        defer free(ptr);
        
        if (ptr) |p| {
            const bytes = @as([*]u8, @ptrCast(p));
            bytes[0] = 0xAA;
            bytes[1023] = 0xBB;
            
            std.log.info("Direct malloc: {} bytes at 0x{X}", .{ 
                malloc_usable_size(p), @intFromPtr(p) 
            });
            std.log.info("Data check: first=0x{X}, last=0x{X}", .{ bytes[0], bytes[1023] });
        }
    }
    
    // Method 2: Wrapped as Zig allocator with defer support
    std.log.info("\n=== Zig Allocator Interface with defer ===", .{});
    {
        var dl_alloc = DLMallocAllocator{};
        const allocator = dl_alloc.allocator();
        
        // Use defer for automatic cleanup
        const memory = try allocator.alloc(u32, 256);
        defer allocator.free(memory);
        
        // Fill with data
        for (memory, 0..) |*item, i| {
            item.* = @intCast(i * i);
        }
        
        std.log.info("Allocated {} u32 elements", .{memory.len});
        std.log.info("memory[10] = {}, memory[255] = {}", .{ memory[10], memory[255] });
        
        // Use with ArrayList
        var list = std.ArrayList([]const u8){};
        defer list.deinit(allocator);
        
        try list.append(allocator, "Hello");
        try list.append(allocator, "from");
        try list.append(allocator, "external");
        try list.append(allocator, "usage!");
        
        std.log.info("ArrayList: {any}", .{list.items});
    } // Memory automatically freed by defer
    
    // Method 3: Show that it works with complex data structures
    std.log.info("\n=== Complex Data Structures ===", .{});
    {
        var dl_alloc = DLMallocAllocator{};
        const allocator = dl_alloc.allocator();
        
        // Skip HashMap complexity for now
        const simple_data = try allocator.alloc(u8, 100);
        defer allocator.free(simple_data);
        
        @memset(simple_data, 42);
        std.log.info("Simple data array size: {}", .{simple_data.len});
        std.log.info("First byte: {}", .{simple_data[0]});
        
        // Tree-like structure
        const Node = struct {
            value: i32,
            children: std.ArrayList(*@This()),
            
            const NodeSelf = @This();
            
            pub fn create(alloc: std.mem.Allocator, value: i32) !*NodeSelf {
                const node = try alloc.create(NodeSelf);
                node.* = NodeSelf{
                    .value = value,
                    .children = std.ArrayList(*NodeSelf){},
                };
                return node;
            }
            
            pub fn destroy(self: *NodeSelf, alloc: std.mem.Allocator) void {
                for (self.children.items) |child| {
                    child.destroy(alloc);
                }
                self.children.deinit(alloc);
                alloc.destroy(self);
            }
        };
        
        // Build a small tree
        const root = try Node.create(allocator, 100);
        defer root.destroy(allocator);
        
        const child1 = try Node.create(allocator, 200);
        const child2 = try Node.create(allocator, 300);
        
        try root.children.append(allocator, child1);
        try root.children.append(allocator, child2);
        
        std.log.info("Tree root: {}, children: {}", .{ root.value, root.children.items.len });
    }
    
    std.log.info("\n=== Memory Statistics ===", .{});
    malloc_stats();
    
    std.log.info("\nExternal usage example completed successfully!", .{});
}