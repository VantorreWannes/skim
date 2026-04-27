const std = @import("std");
const skim = @import("skim");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    const prog = if (args.len > 0) args[0] else "skim";
    const valid_args = args.len == 4 and
        (std.mem.eql(u8, args[1], "-c") or std.mem.eql(u8, args[1], "-d")) and
        !std.mem.eql(u8, args[2], args[3]);

    if (!valid_args) {
        std.debug.print("Usage: {s}[-c | -d] <input> <output>\n", .{prog});
        return;
    }

    const is_decode = args[1][1] == 'd';
    const cwd = std.Io.Dir.cwd();

    const input_file = try cwd.openFile(io, args[2], .{});
    defer input_file.close(io);

    const output_file = try cwd.createFile(io, args[3], .{});
    defer output_file.close(io);

    const file_size = (try input_file.stat(io)).size;
    if (file_size == 0) return;

    const file_buffer = try arena.alloc(u8, @intCast(file_size));
    var reader_wrap = input_file.readerStreaming(io, &.{});
    const bytes_read = try reader_wrap.interface.readSliceShort(file_buffer);
    const input = file_buffer[0..bytes_read];

    var writer_wrap = output_file.writerStreaming(io, &.{});
    const writer = &writer_wrap.interface;

    const BLOCK_SIZE = comptime std.math.maxInt(u21);
    var offset: usize = 0;

    if (is_decode) {
        var decoder = try skim.Decoder.init(arena);
        defer decoder.deinit(arena);
        const buffer = try arena.alloc(u8, BLOCK_SIZE);

        while (offset < input.len) {
            const chunk = input[offset..];
            const out_len = skim.Decoder.exactOutputLength(chunk);
            
            const consumed = decoder.decompressBlockToBuffer(chunk, buffer[0..out_len]);
            try writer.writeAll(buffer[0..out_len]);
            
            offset += consumed;
        }
    } else {
        var encoder = try skim.Encoder.init(arena);
        defer encoder.deinit(arena);
        const buffer = try arena.alloc(u8, comptime skim.Encoder.outputBufferBound(BLOCK_SIZE));

        while (offset < input.len) {
            const chunk_size = @min(input.len - offset, BLOCK_SIZE);
            const chunk = input[offset .. offset + chunk_size];
            
            const len = encoder.compressBlockToBuffer(chunk, buffer);
            try writer.writeAll(buffer[0..len]);
            
            offset += chunk_size;
        }
    }
}