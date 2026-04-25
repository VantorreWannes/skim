const std = @import("std");
const skim = @import("skim");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    const prog = if (args.len > 0) args[0] else "skim";

    if (args.len == 2 and std.mem.eql(u8, args[1], "-h")) {
        std.debug.print("Usage: {s} [-c | -d] <input> <output>\n", .{prog});
        return;
    }

    if (args.len != 4 or (!std.mem.eql(u8, args[1], "-c") and !std.mem.eql(u8, args[1], "-d")) or std.mem.eql(u8, args[2], args[3])) {
        std.debug.print("Usage: {s}[-c | -d] <input> <output>\n", .{prog});
        return;
    }

    const is_decode = std.mem.eql(u8, args[1], "-d");

    const cwd = std.Io.Dir.cwd();

    const input_file = try cwd.openFile(io, args[2], .{});
    defer input_file.close(io);

    const output_file = try cwd.createFile(io, args[3], .{});
    defer output_file.close(io);

    const file_size = (try input_file.stat(io)).size;
    if (file_size == 0) return;

    const mapped_input = try std.posix.mmap(
        null,
        @intCast(file_size),
        .{ .READ = true },
        .{ .TYPE = .PRIVATE },
        input_file.handle,
        0,
    );
    defer std.posix.munmap(mapped_input);

    const BLOCK_SIZE = comptime std.math.maxInt(u21);

    if (is_decode) {
        var decoder = try skim.Decoder.init(arena);
        defer decoder.deinit(arena);

        const buffer = try arena.alloc(u8, BLOCK_SIZE);
        defer arena.free(buffer);

        var offset: usize = 0;
        while (offset < mapped_input.len) {
            const chunk = mapped_input[offset..];
            const uncompressed_size = skim.Decoder.exactOutputLength(chunk);

            const consumed_bytes = decoder.decompressBlockToBuffer(chunk, buffer[0..uncompressed_size]);
            try output_file.writeStreamingAll(io, buffer[0..uncompressed_size]);

            offset += consumed_bytes;
        }
    } else {
        var encoder = try skim.Encoder.init(arena);
        defer encoder.deinit(arena);

        const buffer = try arena.alloc(u8, comptime skim.Encoder.outputBufferBound(BLOCK_SIZE));
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
}
