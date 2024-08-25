const std = @import("std");

pub const Op = union(enum) {
    add: u8,
    sub: u8,
    move_right: u8,
    move_left: u8,
    jmp_if_zero: u32,
    jmp_if_not_zero: u32,
    write: u32,
    read: u32,
};

pub fn opFromInt(i: usize) ?Op {
    return switch (i) {
        0 => Op{ .add = 0 },
        1 => Op{ .sub = 0 },
        2 => Op{ .move_right = 0 },
        3 => Op{ .move_left = 0 },
        4 => Op{ .jmp_if_zero = 0 },
        5 => Op{ .jmp_if_not_zero = 0 },
        6 => Op{ .write = 1 },
        7 => Op{ .read = 1 },
        else => null,
    };
}

pub const TAPE_SIZE = 4 * 1024 * 1024;
pub const Tape = [TAPE_SIZE]u8;

pub var global_tape: Tape = [_]u8{0} ** TAPE_SIZE;

pub fn parse(code: []u8, alloc: std.mem.Allocator) !std.ArrayList(Op) {
    var ops = std.ArrayList(Op).init(alloc);
    for (code) |c| {
        const op = switch (c) {
            '+' => Op{ .add = 1 },
            '-' => Op{ .sub = 1 },
            '>' => Op{ .move_right = 1 },
            '<' => Op{ .move_left = 1 },
            '[' => Op{ .jmp_if_zero = 0xDEADBEEF },
            ']' => Op{ .jmp_if_not_zero = 0xDEADBEEF },
            '.' => Op{ .write = 1 },
            ',' => Op{ .read = 1 },
            else => null,
        };

        if (op) |o| {
            try ops.append(o);
        }
    }

    return ops;
}

pub fn optimize(ops: *std.ArrayList(Op)) !void {
    var i: usize = 1;
    while (i < ops.items.len) {
        const cur = ops.items[i];
        const prev = ops.items[i - 1];

        switch (cur) {
            .add => |cur_amount| {
                switch (prev) {
                    .add => |prev_amount| {
                        ops.items[i - 1] = Op{ .add = prev_amount + cur_amount };
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    .sub => |prev_amount| {
                        if (prev_amount >= cur_amount) {
                            ops.items[i - 1] = Op{ .sub = prev_amount - cur_amount };
                            _ = ops.orderedRemove(i);
                            continue;
                        } else {
                            ops.items[i - 1] = Op{ .add = cur_amount - prev_amount };
                            _ = ops.orderedRemove(i);
                            continue;
                        }
                    },
                    else => {},
                }
            },
            .sub => |cur_amount| {
                switch (prev) {
                    .sub => |prev_amount| {
                        ops.items[i - 1] = Op{ .sub = cur_amount + prev_amount };
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    .add => |prev_amount| {
                        if (cur_amount >= prev_amount) {
                            ops.items[i - 1] = Op{ .sub = cur_amount - prev_amount };
                            _ = ops.orderedRemove(i);
                            continue;
                        } else {
                            ops.items[i - 1] = Op{ .add = prev_amount - cur_amount };
                            _ = ops.orderedRemove(i);
                            continue;
                        }
                    },
                    else => {},
                }
            },
            .move_right => |cur_amount| {
                switch (prev) {
                    .move_right => |prev_amount| {
                        ops.items[i - 1] = Op{ .move_right = cur_amount + prev_amount };
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    .move_left => |prev_amount| {
                        if (prev_amount > cur_amount) {
                            ops.items[i - 1] = Op{ .move_right = prev_amount - cur_amount };
                        } else {
                            ops.items[i - 1] = Op{ .move_left = cur_amount - prev_amount };
                        }
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    else => {},
                }
            },
            .move_left => |cur_amount| {
                switch (prev) {
                    .move_left => |prev_amount| {
                        ops.items[i - 1] = Op{ .move_left = cur_amount + prev_amount };
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    .move_right => |prev_amount| {
                        if (prev_amount > cur_amount) {
                            ops.items[i - 1] = Op{ .move_left = prev_amount - cur_amount };
                        } else {
                            ops.items[i - 1] = Op{ .move_right = cur_amount - prev_amount };
                        }
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    else => {},
                }
            },
            .write => |cur_amount| {
                switch (prev) {
                    .write => |prev_amount| {
                        ops.items[i - 1] = Op{ .write = cur_amount + prev_amount };
                        _ = ops.orderedRemove(i);
                        continue;
                    },
                    else => {},
                }
            },
            else => {},
        }

        i += 1;
    }
}

pub fn fillJmpLocations(ops: []Op, alloc: std.mem.Allocator) !void {
    var jmp_stack = std.ArrayList(u32).init(alloc);
    defer jmp_stack.deinit();

    for (ops, 0..) |*op, i| {
        switch (op.*) {
            .jmp_if_zero => {
                try jmp_stack.append(@intCast(i));
            },
            .jmp_if_not_zero => {
                const pair = jmp_stack.pop();
                ops[pair].jmp_if_zero = @intCast(i);
                op.jmp_if_not_zero = pair;
            },
            else => {},
        }
    }

    if (jmp_stack.items.len != 0) {
        std.debug.print("mismatched brackets", .{});
    }
}
