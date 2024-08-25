const std = @import("std");
const Op = @import("bf.zig").Op;

pub fn indexOfNextNotEql(haystack: []u8, needle: u8) usize {
    for (haystack, 0..) |byte, i| {
        if (byte != needle) {
            return i;
        }
    }
    return haystack.len;
}

pub fn opToChar(op: Op) u8 {
    return switch (op) {
        .add => '+',
        .sub => '-',
        .move_right => '>',
        .move_left => '<',
        .jmp_if_zero => '[',
        .jmp_if_not_zero => ']',
        .write => '.',
        .read => ',',
    };
}

// pub fn printState(ops: []Inst, mem: []u8, dp: usize, ip: usize) void {
//     const radius = 16;
//
//     const dprint = std.debug.print;
//
//     dprint("\n[\n", .{});
//     dprint("  code:                ", .{});
//
//     var i = if (ip < radius) 0 else ip - radius;
//     while (i < ip + radius) : (i += 1) {
//         if (i < 0) {
//             i = -1;
//         } else if (i >= ops.len) {
//             break;
//         } else if (i == ip) {
//             dprint("({c})", .{opToChar(ops[i])});
//         } else {
//             dprint("{c}", .{opToChar(ops[i])});
//         }
//     }
//     dprint("\n", .{});
//     dprint("  instruction pointer: {d}\n", .{ip});
//
//     dprint("  memory:              ", .{});
//     var d = if (dp < radius) 0 else dp - radius;
//     while (d < dp + radius) : (d += 1) {
//         if (d < 0) {
//             d = -1;
//         } else if (d > mem.len) {
//             break;
//         } else if (d == dp) {
//             dprint("({:>2})", .{mem[d]});
//         } else {
//             dprint("[{:>2}]", .{mem[d]});
//         }
//     }
//     dprint("\n", .{});
//     dprint("  data pointer:        {d}\n", .{dp});
//
//     dprint("]\n", .{});
// }

// fn printState(code: []u8, mem: []u8, dp: usize, ip: usize) void {
//     const radius = 16;
//
//     const dprint = std.debug.print;
//
//     dprint("\n[\n", .{});
//     dprint("  code:                ", .{});
//
//     var i = if (ip < radius) 0 else ip - radius;
//     while (i < ip + radius) : (i += 1) {
//         if (i < 0) {
//             i = -1;
//         } else if (i >= code.len) {
//             break;
//         } else if (i == ip) {
//             dprint("({c})", .{code[i]});
//         } else {
//             dprint("{c}", .{code[i]});
//         }
//     }
//     dprint("\n", .{});
//     dprint("  instruction pointer: {d}\n", .{ip});
//
//     dprint("  memory:              ", .{});
//     var d = if (dp < radius) 0 else dp - radius;
//     while (d < dp + radius) : (d += 1) {
//         if (d < 0) {
//             d = -1;
//         } else if (d > mem.len) {
//             break;
//         } else if (d == dp) {
//             dprint("({x:0>2})", .{mem[d]});
//         } else {
//             dprint("[{x:0>2}]", .{mem[d]});
//         }
//     }
//     dprint("\n", .{});
//     dprint("  data pointer:        {d}\n", .{dp});
//
//     dprint("]\n", .{});
// }
