const std = @import("std");

pub fn init_jumptable(code: []u8, jmptable: *std.AutoHashMap(usize, usize)) !void {
    var ip: usize = 0;
    while (ip < code.len) : (ip += 1) {
        const inst = code[ip];

        if (inst == '[') {
            var depth: usize = 1;
            var seek = ip;

            while (depth != 0) {
                if (seek == code.len) {
                    break;
                }

                seek += 1;

                switch (code[seek]) {
                    ']' => depth -= 1,
                    '[' => depth += 1,
                    else => {},
                }
            }

            try jmptable.put(ip, seek);
            try jmptable.put(seek, ip);
        }
    }
}

pub fn interpret(code: []u8, jmptable: std.AutoHashMap(usize, usize)) !void {
    var mem: [1024 * 30]u8 = undefined;
    @memset(&mem, 0);

    const in = std.io.getStdIn();
    var reader = in.reader();

    var dp: usize = 0;
    var ip: usize = 0;

    while (true) {
        const inst = code[ip];
        switch (inst) {
            '>' => dp += 1,
            '<' => dp -= 1,
            '+' => mem[dp] +%= 1,
            '-' => mem[dp] -%= 1,
            '.' => std.debug.print("{c}", .{mem[dp]}),
            ',' => mem[dp] = try reader.readByte(),
            '[' => {
                if (mem[dp] == 0) {
                    ip = jmptable.get(ip).?;
                }
            },
            ']' => {
                if (mem[dp] != 0) {
                    ip = jmptable.get(ip).?;
                }
            },
            else => {
                std.debug.print("bad char '{}' at pc={}\n", .{ inst, ip });
                return;
            },
        }

        ip += 1;

        if (ip == code.len) {
            break;
        }
    }
}
