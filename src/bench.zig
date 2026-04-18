const std = @import("std");
const Io = std.Io;
const zbench = @import("zbench");
const skim = @import("skim");

fn readFile(allocator: std.mem.Allocator, io: Io, path: []const u8) ![]u8 {
    var file = try std.Io.Dir.openFileAbsolute(io, path, .{});
    defer file.close(io);

    const stat = try file.stat(io);
    const buffer = try allocator.alloc(u8, @intCast(stat.size));

    _ = try file.readPositionalAll(io, buffer, 0);
    return buffer;
}

fn basename(path: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |idx| {
        return path[idx + 1 ..];
    }
    return path;
}

pub fn EncodeBenchmark(Encoder: type) type {
    return struct {
        const Self = @This();
        ctx: *Encoder,
        input: []const u8,
        output: []u8,

        pub fn init(ctx: *Encoder, input: []const u8, output: []u8) Self {
            return .{ .ctx = ctx, .input = input, .output = output };
        }

        pub fn run(self: *Self, _: std.mem.Allocator) void {
            _ = self.ctx.compressBlockToBuffer(self.input, self.output);
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const writer = &stdout_file_writer.interface;

    var bench = zbench.Benchmark.init(arena, .{});
    defer bench.deinit();

    if (args.len > 1) {
        const file_path = args[1];
        try writer.print("Loading {s}...\n", .{file_path});
        try writer.flush();

        const input_data = try readFile(arena, io, file_path);

        {
            const Encoder = skim.FastEncoder;
            const encoder = try arena.create(Encoder);
            encoder.* = try Encoder.init(arena);

            const output_data = try arena.alloc(u8, Encoder.outputBufferBound(input_data.len));
            const name = try std.fmt.allocPrint(arena, "FastEncoder: {s}", .{basename(file_path)});

            const param = try arena.create(EncodeBenchmark(Encoder));
            param.* = EncodeBenchmark(Encoder).init(encoder, input_data, output_data);

            try bench.addParam(name, @as(*const EncodeBenchmark(Encoder), param), .{});
        }

        {
            const Encoder = skim.TinyEncoder;
            const encoder = try arena.create(Encoder);
            encoder.* = try Encoder.init(arena);

            const output_data = try arena.alloc(u8, Encoder.outputBufferBound(input_data.len));
            const name = try std.fmt.allocPrint(arena, "TinyEncoder: {s}", .{basename(file_path)});

            const param = try arena.create(EncodeBenchmark(Encoder));
            param.* = EncodeBenchmark(Encoder).init(encoder, input_data, output_data);

            try bench.addParam(name, @as(*const EncodeBenchmark(Encoder), param), .{});
        }
    }

    try writer.writeAll("\n");

    // Flush our own custom prints before running zbench
    try writer.flush();

    // zbench natively handles the rest
    try bench.run(io, std.Io.File.stdout());
}
