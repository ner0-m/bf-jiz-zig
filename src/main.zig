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

    const opts = try parseArguments(args);

    if (opts.print_help) {
        usage();
        return;
    }

    const program = try readFile(alloc, opts.file);
    defer alloc.free(program);

    var ops = try bf.parse(program, alloc);
    defer ops.deinit();

    if (opts.optimize) {
        try bf.optimize(&ops);
    }
    try bf.fillJmpLocations(ops.items, alloc);

    if (!opts.jit) {
        var interpreter = Interpreter.init(&bf.global_tape);
        try interpreter.run(ops.items, false);
    } else {
        var builder = jit.Builder.init(alloc);
        defer builder.deinit();

        try codegen_x86.generate(ops.items, &bf.global_tape, &builder, alloc);

        // Dump to binary, insepct with: `objdump -D -b binary -mi386:x86-64 file`
        if (opts.dump_code) {
            var code_file = try std.fs.cwd().createFile("code", .{});
            try code_file.writeAll(builder.code.items);
        }

        const jit_code = try builder.build();
        defer jit_code.deinit();
        jit_code.run();
    }
}

const Options = struct {
    file: []const u8 = undefined,
    dump_code: bool = false,
    optimize: bool = false,
    jit: bool = false,
    print_help: bool = false,
};

const MainError = error{
    UnknownArgumentError,
    MissingFilename,
};

fn parseArguments(args: [][]const u8) !Options {
    var opts = Options{};

    var found_file = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            opts.print_help = true;
            return opts;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.startsWith(u8, arg, "-j") or std.mem.startsWith(u8, arg, "--jit")) {
                opts.jit = true;
            } else if (std.mem.startsWith(u8, arg, "-o") or std.mem.startsWith(u8, arg, "--optimize")) {
                opts.optimize = true;
            } else if (std.mem.startsWith(u8, arg, "-d") or std.mem.startsWith(u8, arg, "--dump")) {
                opts.dump_code = true;
            } else {
                std.debug.print("unrecognized option '{s}'\n", .{arg});
                std.debug.print("Try 'bf-jit --help' for more information.\n", .{});
                return MainError.UnknownArgumentError;
            }
        } else {
            found_file = true;
            opts.file = arg;
        }
    }

    if (!found_file) {
        return MainError.MissingFilename;
    }

    return opts;
}

fn usage() void {
    std.debug.print("Usage: bf-jit [OPTIONS]... FILE\n", .{});
    std.debug.print("Run the given Brainfuck file with an interpreter or JIT\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("     --help\n", .{});
    std.debug.print("  -j --jit       use the jit instead of the interpreter\n", .{});
    std.debug.print("  -o --optimize  run optimizations on the byte code\n", .{});
    std.debug.print("  -d --dump      dump the jitted code\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Example usage:\n", .{});
    std.debug.print("  bf-jit -o -j <file>\n", .{});
    std.debug.print("\n", .{});
}
