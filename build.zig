const std = @import("std");
const Build = std.Build;

// TODO how to build softsrv a lib (or something)

pub fn build(b: *Build) void {
    const install_options: Build.InstallDirectoryOptions = .{
        .source_dir = .{ .path = "assets" },
        .install_dir = .{ .prefix = {} },
        .install_subdir = "assets",
    };
    b.installDirectory(install_options);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // demo
    const demo_exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = .{ .path = "src/demo.zig" },
        .optimize = .ReleaseFast,
        .target = target,
    });

    systemDep(b, demo_exe);

    const demo_step = b.step("demo", "run softsrv demo");
    const run_demo = b.addRunArtifact(demo_exe);
    demo_step.dependOn(&run_demo.step);

    // tests
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    systemDep(b, tests);

    const run_tests = b.addRunArtifact(tests);
    // TODO ??? https://zig.guide/build-system/zig-build
    // run_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}

fn systemDep(b: *Build, compile: *Build.Step.Compile) void {
    // compile.linkLibC();

    if (b.host.target.os.tag == std.Target.Os.Tag.windows) {
        // compile.linkSystemLibrary("gdi32");
    } else {
        // TODO mac build
        compile.addCSourceFile(.{
            .file = .{ .path = "src/system/osx.m" },
            .flags = &.{"-framework Cocoa"},
        });
    }
}
