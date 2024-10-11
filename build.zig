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

    addProject(b, .{
        .name = "demo",
        .root_source_file = b.path("src/demo.zig"),
        .target = target,
        .optimize = optimize,
    }, .{});

    addProject(b, .{
        .name = "pong",
        .root_source_file = b.path("src/pong.zig"),
        .target = target,
        .optimize = optimize,
    }, .{});

    addProject(b, .{
        .name = "space_shooter",
        .root_source_file = b.path("src/space_shooter.zig"),
        .target = target,
        .optimize = optimize,
    }, .{});

    addProject(b, .{
        .name = "breakout",
        .root_source_file = b.path("src/breakout.zig"),
        .target = target,
        .optimize = optimize,
    }, .{});

    addProject(b, .{
        .name = "prey",
        .root_source_file = b.path("src/prey.zig"),
        .target = target,
        .optimize = optimize,
    }, .{});

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

const ProjectOptions = struct {
    install_on_run: bool = true,
    link_sys_deps: bool = true,
    add_run_step: bool = true,
};

fn addProject(b: *Build, exe_options: std.Build.ExecutableOptions, proj_options: ProjectOptions) void {
    const exe = b.addExecutable(exe_options);

    if (proj_options.link_sys_deps) linkSystemDep(exe_options.target, exe);

    var scratch: [1024]u8 = undefined;
    const name = exe_options.name;

    const build_desc = std.fmt.bufPrint(scratch[0..], "build project {s}", .{name}) catch unreachable;
    const build_step = b.step(name, build_desc);
    const build_exe = b.addInstallArtifact(exe, .{});
    build_step.dependOn(b.getInstallStep());
    build_step.dependOn(&build_exe.step);

    if (proj_options.add_run_step) {
        const run_name = std.fmt.bufPrint(scratch[0..], "run-{s}", .{name}) catch unreachable;
        const run_desc = std.fmt.bufPrint(scratch[512..], "run project {s}", .{name}) catch unreachable;
        const run_step = b.step(run_name, run_desc);
        const run_exe = b.addRunArtifact(exe);
        if (proj_options.install_on_run) run_step.dependOn(&build_exe.step);
        run_step.dependOn(&run_exe.step);
    }
}
