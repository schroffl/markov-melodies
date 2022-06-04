const std = @import("std");
const markov = @import("./markov.zig");
const Tokenizer = @import("./tokenizer.zig");
const Parser = @import("./parser.zig");
const midigen = @import("./midigen.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stderr = std.io.getStdErr();
    var log = stderr.writer();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        const exe_name = std.fs.path.basename(args[0]);
        try log.print("Usage: {s} <file>\n", .{exe_name});
        return 1;
    }

    const filename = args[1];

    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const str = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    var parser = Parser.init(allocator, str);

    const result = try parser.parse();
    defer result.deinit();

    var gen = midigen.init(allocator);
    var interp = try markov.Interpreter.init(allocator, "a", result, .{
        .max_count = 1000,
    });

    const speed_multiplier = 120;
    var delay: u28 = 0;

    while (try interp.nextAlternative()) |event| {
        switch (event) {
            .none => {},
            .pause => |duration| delay += @intCast(u28, duration) * speed_multiplier,
            .single => |single| {
                try gen.noteOn(delay, single.note);
                try gen.noteOff(@intCast(u28, single.duration) * speed_multiplier, single.note);
                delay = 0;
            },
            .chord => |chord| {
                if (chord.notes.items.len < 1) {
                    continue;
                }

                try gen.noteOn(delay, chord.notes.items[0]);
                for (chord.notes.items[1..]) |note| try gen.noteOn(0, note);

                try gen.noteOff(@intCast(u28, chord.duration) * speed_multiplier, chord.notes.items[0]);
                for (chord.notes.items[1..]) |note| try gen.noteOff(0, note);

                delay = 0;
            },
        }
    }

    var stdout = std.io.getStdOut();
    try gen.commit(stdout.writer());

    return 0;
}
