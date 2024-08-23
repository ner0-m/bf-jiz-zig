const std = @import("std");

pub fn interpret(instructions: []u8) !void {
    var mem: [1024 * 30]u8 = undefined;
    @memset(&mem, 0);

    const in = std.io.getStdIn();
    var reader = in.reader();

    var dp: usize = 0;
    var ip: usize = 0;

    while (true) {
        // printState(instructions, &mem, dp, ip);
        const inst = instructions[ip];
        var offset: isize = 1;
        switch (inst) {
            '>' => {
                dp += 1;
            },
            '<' => {
                dp -= 1;
            },
            '+' => {
                mem[dp] +%= 1;
            },
            '-' => {
                mem[dp] -%= 1;
            },
            '.' => {
                std.debug.print("{c}", .{mem[dp]});
            },
            ',' => {
                mem[dp] = try reader.readByte();
            },
            '[' => {
                if (mem[dp] == 0) {
                    var depth: i32 = 1;
                    var pc = ip;

                    while (depth != 0) : (offset += 1) {
                        if (pc == instructions.len - 1) {
                            std.debug.print("unmatched '[' at pc={}\n", .{ip});
                            return;
                        }

                        pc += 1;

                        switch (instructions[pc]) {
                            '[' => depth += 1,
                            ']' => depth -= 1,
                            else => {},
                        }
                    }
                }
            },
            ']' => {
                if (mem[dp] != 0) {
                    var depth: i32 = 1;
                    var pc = ip;

                    while (depth != 0) : (offset -= 1) {
                        if (pc == 0) {
                            std.debug.print("unmatched ']' at pc={}\n", .{ip});
                            return;
                        }

                        pc -= 1;

                        switch (instructions[pc]) {
                            '[' => depth -= 1,
                            ']' => depth += 1,
                            else => {},
                        }
                    }
                }
            },
            else => {
                std.debug.print("bad char '{}' at pc={}\n", .{ inst, ip });
                return;
            },
        }

        ip = @intCast(@as(isize, @intCast(ip)) + offset);

        if (ip == instructions.len) {
            break;
        }
    }
}
