const std = @import("std");
const Note = @import("./markov.zig").Note;

buffer: std.ArrayList(u8),

pub fn init(allocator: std.mem.Allocator) @This() {
    var buffer = std.ArrayList(u8).init(allocator);

    return .{
        .buffer = buffer,
    };
}

pub fn noteOn(self: *@This(), delay: u28, note: Note) !void {
    const channel = 0x00;
    const writer = self.buffer.writer();
    try int(writer, delay);
    try writer.writeByte(0x9 << 4 | channel);
    try writer.writeByte(note.toMidiNote());
    try writer.writeByte(127);
}

pub fn noteOff(self: *@This(), delay: u28, note: Note) !void {
    const channel = 0x00;
    const writer = self.buffer.writer();
    try int(writer, delay);
    try writer.writeByte(0x8 << 4 | channel);
    try writer.writeByte(note.toMidiNote());
    try writer.writeByte(127);
}

pub fn sequenceName(self: *@This(), name: []const u8) !void {
    const writer = self.buffer.writer();
    try int(writer, 0);
    try writer.writeByte(0xff);
    try writer.writeByte(0x03);
    try int(writer, @intCast(u28, name.len));
    try writer.writeAll(name);
}

pub fn text(self: *@This(), value: []const u8) !void {
    const writer = self.buffer.writer();
    try int(writer, 0);
    try writer.writeByte(0xff);
    try writer.writeByte(0x01);
    try int(writer, @intCast(u28, value.len));
    try writer.writeAll(value);
}

pub fn setTempo(self: *@This(), bpm: u9) !void {
    const writer = self.buffer.writer();
    const us_per_beat = std.time.us_per_min / @intCast(u64, bpm);

    try int(writer, 0);
    try writer.writeByte(0xff);
    try writer.writeByte(0x51);
    try writer.writeByte(0x03);
    try writer.writeIntBig(u24, @intCast(u24, us_per_beat));
}

pub fn setSignature(self: *@This()) !void {
    const writer = self.buffer.writer();

    try int(writer, 0);
    try writer.writeByte(0xff);
    try writer.writeByte(0x58);
    try writer.writeByte(0x04);

    try writer.writeByte(0x04); // Numerator
    try writer.writeByte(0x02); // Denominator
    try writer.writeByte(0x18); // bb
    try writer.writeByte(0x08); // cc
}

pub fn commit(self: *@This(), writer: std.fs.File.Writer) !void {
    try writer.writeAll("MThd");
    try writer.writeIntBig(u32, 6);
    try writer.writeIntBig(u16, 0);
    try writer.writeIntBig(u16, 1);
    try writer.writeIntBig(u16, 480);

    const len = @intCast(u32, 4 + self.buffer.items.len);

    try writer.writeAll("MTrk");
    try writer.writeIntBig(u32, len);

    try writer.writeAll(self.buffer.items);
    self.buffer.deinit();

    // End of track
    try writer.writeByte(0x00);
    try writer.writeByte(0xff);
    try writer.writeByte(0x2f);
    try writer.writeByte(0x00);
}

// Taken from https://github.com/Hejsil/zig-midi/blob/master/midi/encode.zig
pub fn int(writer: anytype, i: u28) !void {
    var tmp = i;
    var is_first = true;
    var buf: [4]u8 = undefined;
    var fbs_backing = std.io.fixedBufferStream(&buf);
    var fbs = fbs_backing.writer();

    // TODO: Can we find a way to not encode this in reverse order and then flipping the bytes?
    while (tmp != 0 or is_first) : (is_first = false) {
        fbs.writeByte(@truncate(u7, tmp) | (@as(u8, 1 << 7) * @boolToInt(!is_first))) catch
            unreachable;
        tmp >>= 7;
    }
    std.mem.reverse(u8, fbs.context.getWritten());
    try writer.writeAll(fbs.context.getWritten());
}
