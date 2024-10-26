const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const breakout = b.addExecutable(.{
        .name = "particle",
        .root_source_file = b.path("src/particle.zig"),
        .target = target,
        .optimize = optimize,
    });

    const dep_softsrv = b.dependency("softsrv", .{
        .target = target,
        .optimize = optimize,
    });

    breakout.root_module.addImport("softsrv", dep_softsrv.module("softsrv"));

    b.installArtifact(breakout);

    // module_softsrv = b.dependency("softsrv", .{}).module("softsrv");

    // module_softsrv = b.addModule("softsrv", .{
    //     .root_source_file = b.path("src/softsrv.zig"),
    //     .optimize = optimize,
    //     .target = target,
    //     // .link_libc = true,
    // });

    // const playground_lazy_path = b.path("src/playground/");
    // const playground_path = playground_lazy_path.getPath(b);
    // std.debug.print("building playground files @ {s}\n", .{playground_path});
    // var playground_dir = try std.fs.openDirAbsolute(playground_path, .{ .iterate = true });
    // var playground_dir_iter = playground_dir.iterate();
    // while (playground_dir_iter.next()) |entry_or_null| {
    //     if (entry_or_null) |entry| {
    //         switch (entry.kind) {
    //             .file => {
    //                 std.debug.print("building {s}\n", .{entry.name});
    //                 addProject(b, .{
    //                     .name = std.fs.path.stem(entry.name),
    //                     .root_source_file = b.path(b.pathJoin(&.{ playground_lazy_path.src_path.sub_path, entry.name })),
    //                     .target = target,
    //                     .optimize = optimize,
    //                 }, .{});
    //             },
    //             else => {},
    //         }
    //     } else break;
    // } else |_| {}
    // std.debug.print("done!\n", .{});
}

// const ProjectOptions = struct {
//     install_on_run: bool = true,
//     link_sys_deps: bool = true,
//     add_run_step: bool = true,
// };

// fn addProject(b: *Build, exe_options: std.Build.ExecutableOptions, proj_options: ProjectOptions) void {
//     const exe = b.addExecutable(exe_options);

//     if (proj_options.link_sys_deps) linkSystemDep(exe_options.target, exe);

//     var scratch: [1024]u8 = undefined;
//     const name = exe_options.name;

//     const build_desc = std.fmt.bufPrint(scratch[0..], "build project {s}", .{name}) catch unreachable;
//     const build_step = b.step(name, build_desc);
//     const build_exe = b.addInstallArtifact(exe, .{});
//     build_step.dependOn(b.getInstallStep());
//     build_step.dependOn(&build_exe.step);

//     if (proj_options.add_run_step) {
//         const run_name = std.fmt.bufPrint(scratch[0..], "run-{s}", .{name}) catch unreachable;
//         const run_desc = std.fmt.bufPrint(scratch[512..], "run project {s}", .{name}) catch unreachable;
//         const run_step = b.step(run_name, run_desc);
//         const run_exe = b.addRunArtifact(exe);
//         if (proj_options.install_on_run) run_step.dependOn(&build_exe.step);
//         run_step.dependOn(&run_exe.step);
//     }
// }

// fn linkSystemDep(target: std.Build.ResolvedTarget, compile: *Build.Step.Compile) void {
//     switch (target.result.os.tag) {
//         .windows => {
//             compile.linkLibC();
//         },
//         .linux => {
//             compile.linkLibC();
//             compile.linkSystemLibrary("xcb");
//             compile.linkSystemLibrary("xcb-xkb");
//             compile.linkSystemLibrary("xcb-shm");
//             compile.linkSystemLibrary("xkbcommon");
//             compile.linkSystemLibrary("xkbcommon-x11");
//         },
//         // .macos => {
//         //     // TODO mac build
//         //     compile.addCSourceFile(.{
//         //         .file = .{ .path = "src/system/osx.m" },
//         //         .flags = &.{"-framework Cocoa"},
//         //     });
//         // },
//         else => @panic("unhandled os"),
//     }
// }
