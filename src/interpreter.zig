const std = @import("std");
const bf = @import("bf.zig");
const Op = bf.Op;
const opToChar = @import("utils.zig").opToChar;

pub const Interpreter = struct {
    const Self = @This();

    tape: []u8,
    dp: usize,
    pc: usize,

    instCounter: [8]usize = .{0} ** 8,

    pub fn init(tape: []u8) Self {
        return Self{
            .tape = tape,
            .dp = 0,
            .pc = 0,
        };
    }

    pub fn run(self: *Self, ops: []Op, debug: bool) !void {
        while (self.pc < ops.len) {
            // if (debug) {
            //     self.printState(ops);
            // }

            const op = ops[self.pc];
            try self.step(op);

            if (debug) {
                self.instrument(op) catch {};
            }

            self.pc += 1;
        }
    }

    fn instrument(self: *Self, op: Op) !void {
        const count = switch (op) {
            .add => |c| c,
            .sub => |c| c,
            .move_left => |c| c,
            .move_right => |c| c,
            .read => |c| c,
            .write => |c| c,
            else => 1,
        };

        self.instCounter[@intFromEnum(op)] += count;
    }

    fn step(self: *Self, op: Op) !void {
        switch (op) {
            .add => |amount| self.tape[self.dp] +%= amount,
            .sub => |amount| self.tape[self.dp] -%= amount,
            .move_right => |amount| self.dp += amount,
            .move_left => |amount| self.dp -= amount,
            .jmp_if_zero => |idx| if (self.tape[self.dp] == 0) {
                self.pc = idx;
            },
            .jmp_if_not_zero => |idx| {
                if (self.tape[self.dp] != 0) {
                    self.pc = idx;
                }
            },
            .write => |n| {
                try std.io.getStdOut().writeAll(self.tape[self.dp .. self.dp + n]);
            },
            .read => |n| {
                var buf: [1024]u8 = undefined;
                const read_count = try std.io.getStdIn().read(&buf);

                // TODO: Assume n < 1024
                if (read_count == 0) {
                    @memset(self.tape[self.dp .. self.dp + n], 0);
                } else {
                    @memcpy(self.tape[self.dp .. self.dp + n], buf[0..n]);
                }
            },
        }
    }

    pub fn printState(self: *Self, ops: []Op) void {
        const radius = 16;

        const dprint = std.debug.print;

        dprint("\n[\n", .{});
        dprint("  code:                ", .{});

        var i = if (self.pc < radius) 0 else self.pc - radius;
        while (i < self.pc + radius) : (i += 1) {
            if (i < 0) {
                i = -1;
            } else if (i >= ops.len) {
                break;
            } else if (i == self.pc) {
                dprint("({c})", .{opToChar(ops[i])});
            } else {
                dprint("{c}", .{opToChar(ops[i])});
            }
        }
        dprint("\n", .{});
        dprint("  instruction pointer: {d}\n", .{self.pc});

        dprint("  memory:              ", .{});
        var d = if (self.dp < radius) 0 else self.dp - radius;
        while (d < self.dp + radius) : (d += 1) {
            if (d < 0) {
                d = -1;
            } else if (d > self.tape.len) {
                break;
            } else if (d == self.dp) {
                dprint("({:>2})", .{self.tape[d]});
            } else {
                dprint("[{:>2}]", .{self.tape[d]});
            }
        }
        dprint("\n", .{});
        dprint("  data pointer:        {d}\n", .{self.dp});

        dprint("]\n", .{});
    }

    pub fn dumpCounter(self: Self) void {
        for (self.instCounter, 0..) |count, i| {
            std.debug.print("{} => {}\n", .{ bf.opFromInt(i).?, count });
        }
    }
};
