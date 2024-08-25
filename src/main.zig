const utils = @import("utils.zig");
const parse = @import("parse.zig");
const Inst = @import("inst.zig").Inst;
const std = @import("std");

const simple_inter = @import("simple_interpreter.zig").interpret;
const opti_inter = @import("opti_interpreter.zig").interpret;

/// Optimizing interpreter function. This version of the interpreter uses
/// certain parsing optimizations, such as setting a memory location to zero,
/// instead of simply running the loop
fn interpret(ops: []Inst, alloc: std.mem.Allocator) !void {
    var mem: [1024 * 30]u8 = undefined;
    @memset(&mem, 0);

    var cur_trace = std.ArrayList(u8).init(alloc);
    defer cur_trace.deinit();

    const in = std.io.getStdIn();
    var reader = in.reader();

    var op_count = std.AutoHashMap(u8, usize).init(alloc);
    defer op_count.deinit();

    var dp: usize = 0;
    var ip: usize = 0;

    while (true) {
        const op = ops[ip];

        switch (op) {
            .inc_ptr => |*val| dp += val.*,
            .dec_ptr => |*val| dp -= val.*,
            .inc_data => |*val| mem[dp] +%= @intCast(val.*),
            .dec_data => |*val| mem[dp] -%= @intCast(val.*),
            .write => |*val| {
                for (0..val.*) |_| {
                    std.debug.print("{c}", .{mem[dp]});
                }
            },
            .read => |*val| {
                for (0..val.*) |_| {
                    mem[dp] = try reader.readByte();
                }
            },
            .jmp_if_zero => |*jmp| {
                if (mem[dp] == 0) {
                    ip = jmp.*;
                }
            },
            .jmp_if_not_zero => |*jmp| {
                if (mem[dp] != 0) {
                    ip = jmp.*;
                }
            },
            .loop_set_zero => mem[dp] = 0,
            .move_ptr => |*val| {
                while (mem[dp] != 0) {
                    dp = @intCast(@as(isize, @intCast(dp)) + val.*);
                }
            },
            .move_data => |*val| {
                if (mem[dp] != 0) {
                    const dest: usize = @intCast(@as(isize, @intCast(dp)) + val.*);
                    mem[dest] = mem[dp];
                    mem[dp] = 0;
                }
            },
        }

        // Counter instructions
        const entry = try op_count.getOrPutValue(utils.opToChar(op), 0);
        entry.value_ptr.* += 1;

        ip += 1;

        if (ip == ops.len) {
            break;
        }
    }

    var it1 = op_count.iterator();
    std.debug.print("\n\nTrace summary: \n", .{});
    while (it1.next()) |e| {
        std.debug.print("{c} => {}\n", .{ e.key_ptr.*, e.value_ptr.* });
    }
    std.debug.print("\n", .{});
}

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

    const code = try parse.tokenize(program, alloc);
    defer alloc.free(code);

    const ops = try parse.parse(code, alloc);
    defer alloc.free(ops);

    try interpret(ops, alloc);

    // try interpret01(code);

    // var jmptable = std.AutoHashMap(usize, usize).init(alloc);
    // defer jmptable.deinit();
    // try init_jumptable(code, &jmptable);
    //
    // try interpret02(code, jmptable);

    std.debug.print("\n", .{});
}
