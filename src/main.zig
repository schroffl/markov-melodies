const std = @import("std");
const clap = @import("clap");
const markov = @import("./markov.zig");
const Tokenizer = @import("./tokenizer.zig");
const Parser = @import("./parser.zig");
const midigen = @import("./midigen.zig");

const io = std.io;
const mem = std.mem;

var stderr = io.getStdErr().writer();
var stdout = io.getStdOut().writer();

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help               Display this text and exit.
        \\-t, --tempo <u9>         Tempo of the midi track
        \\-v, --verbose            Print state changes.
        \\-i, --initial <str>      The initial state of the interpreter.
        \\-m, --max-count <int>    Set the maximum amount of substitutions applied.
        \\                         This can be used to break infinite loops.
        \\<file>
    );

    const parsers = comptime .{
        .int = clap.parsers.int(usize, 10),
        .u28 = clap.parsers.int(u28, 10),
        .u9 = clap.parsers.int(u9, 10),
        .file = clap.parsers.string,
        .str = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(stderr, err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(stderr, clap.Help, &params, .{});
        return;
    }

    if (res.positionals.len < 1) {
        const binary_name = try getBinaryName(allocator);
        try stderr.writeAll(binary_name);
        try stderr.writeByte(' ');

        try clap.usage(stderr, clap.Help, &params);
        try stderr.writeByte('\n');

        return;
    }

    const filename = res.positionals[0];
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const str = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(str);

    var parser = Parser.init(allocator, str);
    defer parser.deinit();

    var timer = try std.time.Timer.start();
    const result = try parser.parse();
    const took_parse = timer.read();

    try stderr.print("Parsing took {d:.3}ms\n", .{nsToMs(took_parse)});

    timer.reset();

    var gen = midigen.init(allocator);
    try gen.sequenceName("markov-melodies");
    try gen.setSignature();
    try gen.setTempo(res.args.tempo orelse 120);

    try generateMidi(
        allocator,
        &gen,
        stdout,
        result,
        res.args.@"max-count",
        res.args.initial orelse "",
        res.args.verbose != 0,
    );
    const took_execution = timer.read();

    try stderr.print("Execution took {d:.3}ms\n", .{nsToMs(took_execution)});
}

fn getBinaryName(allocator: std.mem.Allocator) ![]const u8 {
    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    const name = std.fs.path.basename(it.next().?);
    return allocator.dupe(u8, name);
}

fn nsToMs(ns: u64) f64 {
    return @intToFloat(f64, ns) / std.time.ns_per_ms;
}

fn generateMidi(
    allocator: std.mem.Allocator,
    gen: *midigen,
    out: anytype,
    result: markov.RuleSet,
    max_count: ?usize,
    initial: []const u8,
    verbose: bool,
) !void {
    var interp = try markov.Interpreter.init(allocator, initial, result, .{
        .max_count = max_count,
        .verbose = verbose,
    });

    var delay: u28 = 0;

    while (try interp.nextAlternative()) |event| {
        switch (event) {
            .none => {},
            .pause => |duration| delay += durationToDeltaTime(duration, 480),
            .single => |single| {
                const duration = durationToDeltaTime(single.duration, 480);
                try gen.noteOn(delay, single.note);
                try gen.noteOff(duration, single.note);
                delay = 0;
            },
            .chord => |chord| {
                if (chord.notes.items.len < 1) {
                    continue;
                }

                try gen.noteOn(delay, chord.notes.items[0]);
                for (chord.notes.items[1..]) |note| try gen.noteOn(0, note);

                const duration = durationToDeltaTime(chord.duration, 480);

                try gen.noteOff(duration, chord.notes.items[0]);
                for (chord.notes.items[1..]) |note| try gen.noteOff(0, note);

                delay = 0;
            },
        }
    }

    try gen.commit(out);
}

fn durationToDeltaTime(duration: markov.Duration, precision: u16) u28 {
    const top = @intCast(u28, duration.numerator) * @intCast(u28, precision) * 4;
    return top / @intCast(u28, duration.denominator);
}
