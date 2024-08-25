const std = @import("std");
const Inst = @import("inst.zig").Inst;
const utils = @import("utils.zig");

pub fn tokenize(code: []u8, alloc: std.mem.Allocator) ![]u8 {
    var inst = std.ArrayList(u8).init(alloc);
    for (code) |c| {
        if (c == '>' or c == '<' or c == '+' or c == '-' or c == '.' or
            c == ',' or c == '[' or c == ']')
        {
            try inst.append(c);
        }
    }

    return inst.toOwnedSlice();
}

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

fn parse(code: []u8, alloc: std.mem.Allocator) ![]Inst {
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
