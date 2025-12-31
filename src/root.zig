const std = @import("std");

pub const FastEncoder = encoder(u32, u8, u16);
pub const TinyEncoder = encoder(u64, u8, u16);

fn LookupTable(comptime Key: type, comptime Value: type) type {
    return struct {
        const Self = @This();
        const SIZE = std.math.maxInt(Key) + 1;

        table: []Value,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const table = try allocator.alloc(Value, SIZE);
            @memset(table, 0);
            return Self{ .table = table };
        }

        pub inline fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.table);
        }

        pub inline fn get(self: *const Self, key: Key) Value {
            return self.table[key];
        }

        pub inline fn set(self: *Self, key: Key, value: Value) void {
            self.table[key] = value;
        }
    };
}

fn NumberHasher(comptime Data: type, comptime Hash: type) type {
    return struct {
        const PRIME = switch (Data) {
            u128 => 0x9E3779B97F4A7C15F39CC0605CEDC7FD,
            u64 => 0x9E3779B97F4A7C15,
            u32 => 0x9D6EF916,
            u16 => 0x9E3B,
            u8 => 0x9D,
            else => @compileError("Unsupported Data type size for Hasher"),
        };
        const SHIFT = @bitSizeOf(Data) - @bitSizeOf(Hash);

        pub inline fn hash(data: Data) Hash {
            return @truncate((data *% PRIME) >> SHIFT);
        }
    };
}

pub fn encoder(comptime Word: type, comptime Header: type, comptime Hash: type) type {
    const Hasher = NumberHasher(Word, Hash);
    const Table = LookupTable(Hash, Word);

    const HEADER_BITS = @bitSizeOf(Header);
    const WORD_BYTES = @sizeOf(Word);
    const HEADER_BYTES = @sizeOf(Header);
    const HASH_BYTES = @sizeOf(Hash);
    const BATCH_BYTES = HEADER_BITS * WORD_BYTES;

    return struct {
        const Self = @This();
        table: Table,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{ .table = try Table.init(allocator) };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.table.deinit(allocator);
        }

        pub inline fn outputBufferBound(len: usize) usize {
            const blocks = len / BATCH_BYTES;
            return len + (blocks * HEADER_BYTES) + HEADER_BYTES + WORD_BYTES;
        }

        pub fn compressBlockToBuffer(self: *Self, input: []const u8, output: []u8) usize {
            std.debug.assert(output.len >= outputBufferBound(input.len));

            var input_index: usize = 0;
            var output_index: usize = 0;
            const loop_limit = (input.len / BATCH_BYTES) * BATCH_BYTES;

            @setRuntimeSafety(false);

            while (input_index < loop_limit) {
                const header_pos = output_index;
                output_index += HEADER_BYTES;
                var header: Header = 0;

                inline for (0..HEADER_BITS) |token_index| {
                    const word: Word = std.mem.readInt(Word, input[input_index..][0..WORD_BYTES], .little);
                    input_index += WORD_BYTES;

                    const hash = Hasher.hash(word);
                    const reference_word = self.table.get(hash);

                    if (word == reference_word) {
                        std.mem.writeInt(Hash, output[output_index..][0..HASH_BYTES], hash, .little);
                        output_index += HASH_BYTES;
                        header |= 1 << token_index;
                    } else {
                        std.mem.writeInt(Word, output[output_index..][0..WORD_BYTES], word, .little);
                        output_index += WORD_BYTES;
                        self.table.set(hash, word);
                    }
                }

                std.mem.writeInt(Header, output[header_pos..][0..HEADER_BYTES], header, .little);
            }

            const remaining = input.len - input_index;
            if (remaining != 0) {
                @memcpy(output[output_index .. output_index + remaining], input[input_index .. input_index + remaining]);
            }

            return output_index + remaining;
        }
    };
}
