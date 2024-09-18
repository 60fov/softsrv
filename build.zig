const std = @import("std");
const Build = std.Build;

// TODO how to build softsrv a lib (or something)

pub fn build(b: *Build) void {
    const install_options: Build.Step.InstallDir.Options = .{
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

    const demo_build_step = b.step("demo", "build demo");
    const demo_build = b.addInstallArtifact(demo_exe, .{});
    demo_build_step.dependOn(&demo_build.step);

    const demo_run_step = b.step("demo-run", "run softsrv demo");
    const run_demo = b.addRunArtifact(demo_exe);
    demo_run_step.dependOn(&demo_build.step);
    demo_run_step.dependOn(&run_demo.step);

    // tests
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    systemDep(b, tests);

    // check
    const demo_check = b.step("check-demo", "check if demo compiles");
    demo_check.dependOn(&demo_exe.step);

    const check = b.step("check", "check on build (for zls)");
    check.dependOn(demo_check);

    // test
    const run_tests = b.addRunArtifact(tests);
    // TODO ??? https://zig.guide/build-system/zig-build
    // run_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}

fn systemDep(b: *Build, compile: *Build.Step.Compile) void {
    switch (b.host.result.os.tag) {
        .windows => {
            compile.linkLibC();
        },
        .linux => {
            compile.linkLibC();
            compile.linkSystemLibrary("xcb");
            compile.linkSystemLibrary("xcb-shm");
        },
        .macos => {
            // TODO mac build
            compile.addCSourceFile(.{
                .file = .{ .path = "src/system/osx.m" },
                .flags = &.{"-framework Cocoa"},
            });
        },
        else => @panic("unhandled os"),
    }
}
