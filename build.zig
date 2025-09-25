const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the library directly
    const lib = b.addLibrary(.{
        .name = "dlmalloc-zig", 
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dlmalloc.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    
    lib.linkLibC();
    b.installArtifact(lib);

    // Tests
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dlmalloc", .module = lib.root_module },
            },
        }),
    });
    test_exe.linkLibC();

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(test_exe).step);

    // Examples
    const example_exe = b.addExecutable(.{
        .name = "basic-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dlmalloc", .module = lib.root_module },
            },
        }),
    });
    example_exe.linkLibC();
    
    const example_step = b.step("example", "Build and run example");
    example_step.dependOn(&b.addRunArtifact(example_exe).step);

    // Std allocator example
    const std_allocator_exe = b.addExecutable(.{
        .name = "std-allocator-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/std_allocator.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dlmalloc", .module = lib.root_module },
            },
        }),
    });
    std_allocator_exe.linkLibC();
    
    const std_allocator_step = b.step("std-example", "Build and run std allocator example");
    std_allocator_step.dependOn(&b.addRunArtifact(std_allocator_exe).step);

    // Benchmarks (build only - don't run due to implementation issues)
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "dlmalloc", .module = lib.root_module },
            },
        }),
    });
    benchmark_exe.linkLibC();
    b.installArtifact(benchmark_exe);
}