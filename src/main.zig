const std = @import("std");
const Io = std.Io;
const skim = @import("skim");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    if (args.len < 3) {
        std.debug.print("Usage: {s} <input> <output>\n", .{args[1]});
        return;
    }

    const input_file = try std.Io.Dir.openFileAbsolute(io, args[1], .{});
    defer input_file.close(io);

    const output_file = try std.Io.Dir.createFileAbsolute(io, args[2], .{});
    defer output_file.close(io);

    const Encoder = skim.TinyEncoder;
    var encoder = try Encoder.init(arena);
    defer encoder.deinit(arena);

    const file_size = (try input_file.stat(io)).size;
    const mapped_input = try std.posix.mmap(null, @intCast(file_size), .{ .READ = true }, .{ .TYPE = .PRIVATE }, input_file.handle, 0);
    defer std.posix.munmap(mapped_input);

    const BLOCK_SIZE = comptime std.math.maxInt(u21);
    const buffer = try arena.alloc(u8, comptime Encoder.outputBufferBound(BLOCK_SIZE));
    defer arena.free(buffer);

    var offset: usize = 0;
    while (offset < mapped_input.len) {
        const chunk_size = @min(mapped_input.len - offset, BLOCK_SIZE);
        const chunk = mapped_input[offset .. offset + chunk_size];

        const len = encoder.compressBlockToBuffer(chunk, buffer);
        try output_file.writeStreamingAll(io, buffer[0..len]);

        offset += chunk_size;
    }
}
