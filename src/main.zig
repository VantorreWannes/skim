const std = @import("std");
const skim = @import("skim");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <input> <output>\n", .{args[1]});
        return;
    }

    var input_file = try std.fs.cwd().openFile(args[1], .{});
    defer input_file.close();

    var output_file = try std.fs.cwd().createFile(args[2], .{});
    defer output_file.close();

    const Encoder = skim.TinyEncoder;
    var encoder = try Encoder.init(allocator);
    defer encoder.deinit(allocator);

    const INPUT_SIZE = std.math.maxInt(u21);
    const OUTPUT_BUFFER_SIZE = comptime Encoder.outputBufferBound(INPUT_SIZE);

    const in_io_mem = try allocator.alloc(u8, INPUT_SIZE);
    defer allocator.free(in_io_mem);

    const out_io_mem = try allocator.alloc(u8, OUTPUT_BUFFER_SIZE);
    defer allocator.free(out_io_mem);

    while (true) {
        const bytes_read = try input_file.readAll(in_io_mem);
        if (bytes_read == 0) break;

        const output_length = encoder.compressBlockToBuffer(in_io_mem[0..bytes_read], out_io_mem);

        try output_file.writeAll(out_io_mem[0..output_length]);
    }
}
