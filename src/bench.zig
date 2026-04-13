const std = @import("std");
const zbench = @import("zbench");
const skim = @import("skim");

fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    _ = try file.readAll(buffer);
    return buffer;
}

pub fn EncodeBenchmark(Encoder: type) type {
    return struct {
        const Self = @This();
        ctx: *Encoder,
        input: []const u8,
        output: []u8,

        fn init(ctx: *Encoder, input: []const u8, output: []u8) Self {
            return .{ .ctx = ctx, .input = input, .output = output };
        }

        pub fn run(self: Self, _: std.mem.Allocator) void {
            _ = self.ctx.compressBlockToBuffer(self.input, self.output);
        }
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    const writer = &stdout.interface;
    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    var input_data: []u8 = undefined;
    var output_data: []u8 = undefined;

    if (args.len > 1) {
        const file_path = args[1];
        try writer.print("Loading {s}...\n", .{file_path});

        input_data = try readFile(allocator, file_path);
        defer allocator.free(input_data);

        {
            const Encoder = skim.FastEncoder;
            var encoder = try Encoder.init(allocator);

            output_data = try allocator.alloc(u8, Encoder.outputBufferBound(input_data.len));
            defer allocator.free(output_data);

            const name = try std.fmt.allocPrint(allocator, "FastEncoder: {s}", .{std.fs.path.basename(file_path)});
            defer allocator.free(name);

            try bench.addParam(name, &EncodeBenchmark(Encoder).init(&encoder, input_data, output_data), .{});
        }

        {
            const Encoder = skim.TinyEncoder;
            var encoder = try Encoder.init(allocator);

            output_data = try allocator.alloc(u8, Encoder.outputBufferBound(input_data.len));
            defer allocator.free(output_data);

            const name = try std.fmt.allocPrint(allocator, "TinyEncoder: {s}", .{std.fs.path.basename(file_path)});
            defer allocator.free(name);

            try bench.addParam(name, &EncodeBenchmark(Encoder).init(&encoder, input_data, output_data), .{});
        }
    }

    try writer.writeAll("\n");
    try bench.run(writer);
}
