const std = @import("std");

pub fn parse(code: []u8, alloc: std.mem.Allocator) ![]u8 {
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
