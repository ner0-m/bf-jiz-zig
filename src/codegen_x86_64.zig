const std = @import("std");

const Op = @import("bf.zig").Op;
const Builder = @import("jit.zig").Builder;

fn compute_relative_32bit_offset(jump_from: u32, jump_to: u32) u32 {
    if (jump_to >= jump_from) {
        return jump_to - jump_from;
    } else {
        return ~(jump_from - jump_to) + 1;
    }
}

pub fn generate(ops: []Op, mem: []u8, builder: *Builder, alloc: std.mem.Allocator) !void {
    // movabs r13, <mem>
    try builder.emit(&[_]u8{ 0x49, 0xBD });
    try builder.emit64(@intFromPtr(&mem[0]));

    var jump_offsets = std.ArrayList(u32).init(alloc);
    defer jump_offsets.deinit();

    for (ops) |op| {
        switch (op) {
            .add => |val| {
                // add    BYTE PTR [r13+0x0], $value
                try builder.emit(&[_]u8{ 0x41, 0x80, 0x45, 0x00, @bitCast(val) });
            },
            .sub => |val| {
                // sub    BYTE PTR [r13+0x0], $value
                try builder.emit(&[_]u8{ 0x41, 0x80, 0x6D, 0x00, @bitCast(val) });
            },
            .move_right => |val| {
                // add    r13d, $value
                try builder.emit(&[_]u8{ 0x41, 0x83, 0xc5, @bitCast(val) });
            },
            .move_left => |val| {
                // sub    r13d, $value
                try builder.emit(&[_]u8{ 0x41, 0x83, 0xed, @bitCast(val) });
            },
            .jmp_if_zero => {
                // cmp    BYTE PTR [r13+0x0], 0x0
                try builder.emit(&[_]u8{ 0x41, 0x80, 0x7D, 0x00, 0x00 });

                try jump_offsets.append(@intCast(builder.len()));

                // je <determine later>
                try builder.emit(&[_]u8{ 0x0F, 0x84, 0x00, 0x00, 0x00, 0x00 });
            },
            .jmp_if_not_zero => {
                if (jump_offsets.items.len == 0) {
                    std.debug.print("unmatched closing ']'\n", .{});
                    return;
                }
                const pair_offset = jump_offsets.pop();
                // cmpb $0, 0(%r13)
                try builder.emit(&[_]u8{ 0x41, 0x80, 0x7D, 0x00, 0x00 });

                // Determine where we have to jump back to
                const jump_from = @as(u32, @intCast(builder.len() + 6));
                const jump_to = pair_offset + 6;
                const relative_offset = compute_relative_32bit_offset(jump_from, jump_to);

                // jnz <open_bracket_location>
                try builder.emit(&[_]u8{ 0x0F, 0x85 });
                try builder.emit32(relative_offset);

                // fixup the jump forward location
                const jump_forward_from = pair_offset + 6;
                const jump_forward_to: u32 = @intCast(builder.len());
                const relative_offset_forward = compute_relative_32bit_offset(jump_forward_from, jump_forward_to);

                builder.fill32(
                    pair_offset + 2,
                    relative_offset_forward,
                );
            },
            .write => |n| {
                // mov    rax, 0x1 ; use the `write` syscall
                // mov    rdi, 0x1 ; write to stdout (fd 1)
                // mov    rsi, r13 ; use memory located in r13
                // mov    rdx, $n ; write n byte
                // syscall         ; make syscall
                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC0, 0x01, 0x00, 0x00, 0x00 });
                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC7, 0x01, 0x00, 0x00, 0x00 });
                try builder.emit(&[_]u8{ 0x4C, 0x89, 0xEE });

                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC2 });
                try builder.emit32(n);
                try builder.emit(&[_]u8{ 0x0F, 0x05 });
            },
            .read => |n| {
                // mov    rax, 0x0 ; use the `read` syscall
                // mov    rdi, 0x0 ; read from stdin (fd 0)
                // mov    rsi, r13 ; use memory located in r13
                // mov    rdx, $n  ; read n byte
                // syscall         ; make syscall
                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC0, 0x00, 0x00, 0x00, 0x00 });
                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC7, 0x00, 0x00, 0x00, 0x00 });
                try builder.emit(&[_]u8{ 0x4C, 0x89, 0xEE });
                try builder.emit(&[_]u8{ 0x48, 0xC7, 0xC2 });
                try builder.emit32(n);
                try builder.emit(&[_]u8{ 0x0F, 0x05 });
            },
        }
    }

    // ret
    try builder.emit8(0xc3);
}
