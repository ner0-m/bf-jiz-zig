const std = @import("std");

pub const Code = struct {
    const Self = @This();

    mem: []align(4096) u8,

    pub fn init(code: []u8) !Self {
        const len = try std.math.divCeil(usize, code.len, std.mem.page_size) * std.mem.page_size;
        var mmap_mem = try std.posix.mmap(
            null,
            len,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            std.posix.system.MAP{ .TYPE = .SHARED, .ANONYMOUS = true },
            -1,
            0,
        );
        @memcpy(mmap_mem[0..code.len], code);

        try std.posix.mprotect(mmap_mem, std.posix.PROT.READ | std.posix.PROT.EXEC);

        return Self{ .mem = mmap_mem };
    }

    pub fn deinit(self: Self) void {
        std.posix.munmap(self.mem);
    }

    pub fn run(self: *const Self) void {
        const Env = packed struct {
            write: *const fn (u8) callconv(.C) void,
            read: *const fn () callconv(.C) u8,
        };

        var env = Env{ .write = undefined, .read = undefined };
        env.write = envWrite;
        env.read = envRead;

        const f: *const fn () callconv(.C) void = @alignCast(@ptrCast(self.mem.ptr));
        f();
    }

    fn envWrite(ch: u8) callconv(.C) void {
        std.io.getStdOut().writeAll(
            &[1]u8{ch},
        ) catch unreachable;
    }

    fn envRead() callconv(.C) u8 {
        var buf: [1]u8 = undefined;
        const read_count = std.io.getStdIn().read(&buf) catch return 0;
        if (read_count == 0) {
            return 0;
        } else {
            return buf[0];
        }
    }
};

pub const Builder = struct {
    const Self = @This();

    code: std.ArrayList(u8),

    pub fn len(self: *Self) usize {
        return self.code.items.len;
    }

    pub fn emit8(self: *Self, byte: u8) !void {
        try self.code.append(byte);
    }

    pub fn emit(self: *Self, bytes: []const u8) !void {
        for (bytes) |byte| {
            try self.code.append(byte);
        }
    }

    pub fn emit32(self: *Self, v: u32) !void {
        // Assume little-endian
        try self.emit8(@intCast(v & 0xFF));
        try self.emit8(@intCast((v >> 8) & 0xFF));
        try self.emit8(@intCast((v >> 16) & 0xFF));
        try self.emit8(@intCast((v >> 24) & 0xFF));
    }

    pub fn emit64(self: *Self, v: u64) !void {
        try self.emit32(@intCast(v & 0xFFFFFFFF));
        try self.emit32(@intCast((v >> 32) & 0xFFFFFFFF));
    }

    pub fn fill32(self: *Self, offset: usize, v: u32) void {
        std.debug.assert(offset + 3 < self.code.items.len);

        self.code.items[offset] = @truncate(v);
        self.code.items[offset + 1] = @truncate(v >> 8);
        self.code.items[offset + 2] = @truncate(v >> 16);
        self.code.items[offset + 3] = @truncate(v >> 24);
    }

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{ .code = std.ArrayList(u8).init(alloc) };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
    }

    pub fn build(self: *const Self) !Code {
        return try Code.init(self.code.items);
    }
};
