const utils = @import("utils.zig");
const std = @import("std");
const bf = @import("bf.zig");

const codegen_x86 = @import("codegen_x86_64.zig");
const jit = @import("jit.zig");

const Interpreter = @import("interpreter.zig").Interpreter;

fn readFile(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(
        filename,
        .{},
    );
    defer file.close();

    const stat = try file.stat();
    return try file.readToEndAlloc(allocator, stat.size);
}

pub fn main() !void {
    std.debug.print("\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    const program = try readFile(alloc, args[1]);
    defer alloc.free(program);

    var ops = try bf.parse(program, alloc);
    defer ops.deinit();

    try bf.optimize(&ops);
    try bf.fillJmpLocations(ops.items, alloc);

    // var interpreter = Interpreter.init(&bf.global_tape);
    // try interpreter.run(ops.items, false);

    var builder = jit.Builder.init(alloc);
    defer builder.deinit();

    try codegen_x86.generate(ops.items, &bf.global_tape, &builder, alloc);

    // Dump to binary, insepct with: `objdump -D -b binary -mi386:x86-64 file`
    var code_file = try std.fs.cwd().createFile("code", .{});
    try code_file.writeAll(builder.code.items);

    const jit_code = try builder.build();
    defer jit_code.deinit();
    jit_code.run();

    std.debug.print("\n", .{});
}
