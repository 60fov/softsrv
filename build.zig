const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO demo

    // module for other build system import
    _ = b.addModule("softsrv", .{
        .root_source_file = b.path("src/softsrv.zig"),
        .target = target,
        .optimize = optimize,
    });

    // static lib
    const lib_static = b.addStaticLibrary(.{
        .name = "softsrv",
        .root_source_file = b.path("src/softsrv.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkSystemDep(target, lib_static);
    const lib_static_install = b.addInstallArtifact(lib_static, .{});
    const step_static = b.step("static", "build static library");
    step_static.dependOn(&lib_static_install.step);

    // dynamic lib
    const lib_dynamic = b.addSharedLibrary(.{
        .name = "softsrv",
        .root_source_file = b.path("src/softsrv.zig"),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 0, .patch = 0 },
    });
    linkSystemDep(target, lib_dynamic);
    const lib_dynamic_install = b.addInstallArtifact(lib_dynamic, .{});
    const step_dynamic = b.step("dynamic", "build dynamic library");
    step_dynamic.dependOn(&lib_dynamic_install.step);

    // install both on `zig build`
    const step_install = b.getInstallStep();
    step_install.dependOn(step_dynamic);
    step_install.dependOn(step_static);

    // tests
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    linkSystemDep(target, tests);

    // check
    // TODO how to get to apply to the file im currently in?
    // const demo_check = b.step("check-demo", "check if demo compiles");
    // demo_check.dependOn(&demo_exe.step);

    // const check = b.step("check", "check on build (for zls)");
    // check.dependOn(demo_check);

    // test
    const run_tests = b.addRunArtifact(tests);
    // TODO ??? https://zig.guide/build-system/zig-build
    // run_tests.step.dependOn(b.getInstallStep());

    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_tests.step);
}

fn linkSystemDep(target: std.Build.ResolvedTarget, compile: *Build.Step.Compile) void {
    switch (target.result.os.tag) {
        .windows => {
            compile.linkLibC();
        },
        .linux => {
            compile.linkLibC();
            compile.linkSystemLibrary("xcb");
            compile.linkSystemLibrary("xcb-xkb");
            compile.linkSystemLibrary("xcb-shm");
            compile.linkSystemLibrary("xkbcommon");
            compile.linkSystemLibrary("xkbcommon-x11");
        },
        // .macos => {
        //     // TODO mac build
        //     compile.addCSourceFile(.{
        //         .file = .{ .path = "src/system/osx.m" },
        //         .flags = &.{"-framework Cocoa"},
        //     });
        // },
        else => @panic("unhandled os"),
    }
}
