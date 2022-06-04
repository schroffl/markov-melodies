const std = @import("std");

pub const Note = struct {
    pub const Modifier = enum(u8) {
        sharp = '#',
        flat = 'b',
    };

    value: u3,
    octave: u4,
    modifier: ?Modifier = null,

    pub fn human(char: u8, octave: u4, modifier: ?Modifier) Note {
        std.debug.assert(char >= 'A' and char <= 'G');

        return .{
            .value = @intCast(u3, char - 'A'),
            .octave = octave,
            .modifier = modifier,
        };
    }

    pub fn eql(a: Note, b: Note) bool {
        if (a.modifier != null and b.modifier != null) {
            return a.value == b.value and a.modifier.? == b.modifier.?;
        } else if (a.modifier == null and b.modifier == null) {
            return a.value == b.value;
        } else {
            return false;
        }
    }

    pub fn toMidiNote(self: Note) u7 {
        const base = @intCast(u7, self.octave) * 12;
        const add: u7 = switch (self.value) {
            0 => 0,
            1 => 2,
            2 => 3,
            3 => 5,
            4 => 7,
            5 => 8,
            6 => 10,
            else => unreachable,
        };

        if (self.modifier) |modifier| return switch (modifier) {
            .flat => 21 + base + add - 1 - 12,
            .sharp => 21 + base + add + 1 - 12,
        } else {
            return 21 + base + add - 12;
        }
    }

    pub fn format(
        self: Note,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{c}", .{@intCast(u8, self.value) + 'A'});
        if (self.modifier) |mod| try writer.print("{c}", .{@enumToInt(mod)});
        try writer.print("{}", .{self.octave});
    }
};

pub const Rule = struct {
    from: []const u8,
    to: []const u8,
    event: Event,
};

pub const NoteEvent = struct {
    note: Note,
    duration: usize,
};

pub const ChordEvent = struct {
    notes: std.ArrayList(Note),
    duration: usize,
};

pub const Event = union(enum) {
    single: NoteEvent,
    chord: ChordEvent,
    pause: usize,
    none,
};

pub const RuleSet = std.ArrayList(Rule);

pub const Interpreter = struct {
    pub const Config = struct {
        max_count: usize,
    };

    state: std.ArrayList(u8),
    rules: RuleSet,
    count: usize = 0,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, start: []const u8, rules: RuleSet, config: Config) !Interpreter {
        var state = std.ArrayList(u8).init(allocator);
        try state.appendSlice(start);

        return Interpreter{
            .state = state,
            .rules = rules,
            .config = config,
        };
    }

    pub fn next(self: *Interpreter) !?Event {
        if (self.count >= self.config.max_count) {
            return null;
        }

        self.count += 1;

        var i: usize = 0;

        while (i < self.state.items.len) : (i += 1) {
            const slice = self.state.items[i..];

            for (self.rules.items) |rule| {
                if (std.mem.startsWith(u8, slice, rule.from)) {
                    try self.state.replaceRange(i, rule.from.len, rule.to);
                    return rule.event;
                }
            }
        }

        return null;
    }

    pub fn nextAlternative(self: *Interpreter) !?Event {
        if (self.count >= self.config.max_count) {
            return null;
        }

        self.count += 1;

        return for (self.rules.items) |rule| {
            var i: usize = 0;

            const found = while (i < self.state.items.len) : (i += 1) {
                const slice = self.state.items[i..];

                if (std.mem.startsWith(u8, slice, rule.from))
                    break true;
            } else false;

            if (found) {
                // std.log.debug("{s} -> {s}", .{ rule.from, rule.to });
                try self.state.replaceRange(i, rule.from.len, rule.to);
                break rule.event;
            }
        } else null;
    }
};
