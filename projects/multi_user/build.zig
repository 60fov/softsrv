const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    // const install_step = b.getInstallStep();
    // const install_data = b.addInstallDirectory(.{
    //     .source_dir = .{ .path = "data" },
    //     .install_dir = .{ .prefix = {} },
    //     .install_subdir = "data",
    // });
    // install_step.dependOn(&install_data.step);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "multi-user",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const module_softsrv = b.addModule("softsrv", .{
        .root_source_file = .{ .path = "../../src/softsrv.zig" },
    });

    exe.root_module.addImport("softsrv", module_softsrv);

    exe.linkLibC();

    b.installArtifact(exe);

    const step_server = b.step("server", "run multi-user server");
    const run_server = b.addRunArtifact(exe);
    run_server.addArg("server");
    step_server.dependOn(&run_server.step);

    const step_client = b.step("client", "run multi-user client");
    const run_client = b.addRunArtifact(exe);
    run_client.addArg("client");
    step_client.dependOn(&run_client.step);
}
