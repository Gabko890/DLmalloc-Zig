const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Example: Using the pre-built libdlmalloc-zig.a static library
    const exe = b.addExecutable(.{
        .name = "external-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link against the pre-built dlmalloc static library
    exe.addLibraryPath(b.path("../../zig-out/lib"));
    exe.linkSystemLibrary("dlmalloc-zig");
    exe.linkLibC();

    // Include the header/interface files
    exe.addIncludePath(b.path("../../src"));
    
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);
}