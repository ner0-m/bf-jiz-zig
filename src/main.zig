const std = @import("std");

const utils = @import("utils.zig");
const parse = @import("parse.zig");
const Inst = @import("inst.zig").Inst;

fn optimize(loop: *std.ArrayList(Inst)) !bool {
    if (loop.items.len == 3 and (loop.items[1] == .dec_data or loop.items[1] == .inc_data)) {
        // Optimize [-]
        // std.debug.print("Optimizing [-] and [+]\n", .{});
        loop.clearRetainingCapacity();
        try loop.append(Inst.loop_set_zero);
        return true;
    } else if (loop.items.len == 3 and (loop.items[1] == .inc_ptr or loop.items[1] == .dec_data)) {
        // Optimize [<] and [>] (with multiple < / >)
        // std.debug.print("Optimizing [<] and [>]\n", .{});
        _ = loop.pop();
        var item = loop.pop();
        _ = loop.pop();

        switch (item) {
            .inc_ptr => |*val| {
                try loop.append(Inst{ .move_ptr = @intCast(val.*) });
                return true;
            },
            .dec_ptr => |*val| {
                try loop.append(Inst{ .move_ptr = -@as(isize, @intCast(val.*)) });
                return true;
            },
            else => {},
        }
    } else if (loop.items.len == 5 and loop.items[1] == .dec_data and loop.items[3] == .inc_data) {
        // Optimize [-<+>] and [->+<]
        std.debug.print("Optimize [-<+>] and [->+<]\n", .{});
        _ = loop.pop(); // [
        var dec = loop.pop();
        var mov1 = loop.pop(); // < / >
        var inc = loop.pop();
        var mov2 = loop.pop(); // < / >
        _ = loop.pop(); // ]

        switch (dec) {
            .dec_data => |*decval| {
                switch (inc) {
                    .inc_data => |*incval| {
                        if (decval.* != incval.*) {
                            return false;
                        }
                    },
                    else => return false,
                }
            },
            else => return false,
        }

        switch (mov1) {
            .inc_ptr => |*val1| {
                switch (mov2) {
                    .dec_ptr => |*val2| {
                        if (val1.* == val2.*) {
                            try loop.append(Inst{ .move_data = @intCast(val1.*) });
                            return true;
                        } else {
                            return false;
                        }
                    },
                    else => return false,
                }
            },

            .dec_ptr => |*val1| {
                switch (mov2) {
                    .inc_ptr => |*val2| {
                        if (val1.* == val2.*) {
                            try loop.append(Inst{ .move_data = -@as(isize, @intCast(val1.*)) });
                            return true;
                        } else {
                            return false;
                        }
                    },
                    else => return false,
                }
            },
            else => return false,
        }
    }
    return false;
}

fn lex(code: []u8, alloc: std.mem.Allocator) ![]Inst {
    var ops = std.ArrayList(Inst).init(alloc);

    var stack = std.ArrayList(usize).init(alloc);
    defer stack.deinit();

    var ip: usize = 0;
    while (ip < code.len) {
        const inst = code[ip];
        const num_repeat = utils.indexOfNextNotEql(code[ip..], inst);

        switch (inst) {
            '[' => {
                try stack.append(ops.items.len);
                try ops.append(Inst{ .jmp_if_zero = 0 });
                ip += 1;
            },
            ']' => {
                if (stack.items.len == 0) {
                    std.debug.print("unmatched ']' at pc={}\n", .{ip});
                    std.process.exit(1);
                }
                const pos = stack.pop();
                try ops.append(Inst{ .jmp_if_not_zero = pos });

                // Copy loop to a new array and if possible optimize it
                var loop = std.ArrayList(Inst).init(alloc);
                try loop.appendSlice(ops.items[pos..]);
                defer loop.deinit();

                const did_opti = try optimize(&loop);

                if (did_opti) {
                    // Now replace all loop instructions with the new one
                    try ops.replaceRange(pos, ops.items.len - pos, loop.items);
                } else {
                    switch (ops.items[pos]) {
                        .jmp_if_zero => |*op| op.* = ops.items.len - 1,
                        else => {
                            std.debug.print("Wrong jump position, pc={} to pos={}\n", .{ ip, pos });
                            std.process.exit(1);
                        },
                    }
                }
                ip += 1;
            },
            '>' => {
                try ops.append(Inst{ .inc_ptr = num_repeat });
                ip += num_repeat;
            },
            '<' => {
                try ops.append(Inst{ .dec_ptr = num_repeat });
                ip += num_repeat;
            },
            '+' => {
                try ops.append(Inst{ .inc_data = num_repeat });
                ip += num_repeat;
            },
            '-' => {
                try ops.append(Inst{ .dec_data = num_repeat });
                ip += num_repeat;
            },
            ',' => {
                try ops.append(Inst{ .read = num_repeat });
                ip += num_repeat;
            },
            '.' => {
                try ops.append(Inst{ .write = num_repeat });
                ip += num_repeat;
            },
            else => {
                std.debug.print("bad char '{}' at pc={}\n", .{ inst, ip });
                std.process.exit(1);
            },
        }
    }

    return ops.toOwnedSlice();
}

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
            // else => {},
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

    const code = try parse.parse(program, alloc);
    defer alloc.free(code);

    const ops = try lex(code, alloc);
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
