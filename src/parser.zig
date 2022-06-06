const std = @import("std");
const Tokenizer = @import("./tokenizer.zig");
const markov = @import("./markov.zig");

const ParserState = enum {
    read_from,
    read_arrow,
    read_to,
    read_event,
    read_colon,
};

pub const ParseError = error{
    UnexpectedEndOfInput,
    UnexpectedToken,
    InvalidNumberToken,
    InvalidNoteToken,
    NoPauseInMultiAllowed,
    NestedMultiEventsNotAllowed,
    InvalidPatternToken,
    InvalidDuration,
} || std.mem.Allocator.Error;

arena: std.heap.ArenaAllocator,
tokenizer: Tokenizer,

pub fn init(allocator: std.mem.Allocator, buffer: []const u8) @This() {
    return .{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .tokenizer = Tokenizer.init(buffer),
    };
}

pub fn deinit(self: *@This()) void {
    self.arena.deinit();
}

pub fn parse(self: *@This()) !markov.RuleSet {
    const allocator = self.arena.allocator();

    var root = markov.RuleSet.init(allocator);
    errdefer root.deinit();

    var state = ParserState.read_from;
    var current: markov.Rule = undefined;

    while (true) {
        const token = self.tokenizer.peek() orelse break;
        var consume_token = true;

        switch (state) {
            .read_from => switch (token.tag) {
                .comment => {},
                .pattern => {
                    current.from = try self.parsePattern(token);
                    state = .read_arrow;
                },
                else => return ParseError.UnexpectedToken,
            },
            .read_arrow => switch (token.tag) {
                .arrow => state = .read_to,
                else => return ParseError.UnexpectedToken,
            },
            .read_to => switch (token.tag) {
                .pattern => {
                    current.to = try self.parsePattern(token);
                    state = .read_colon;
                },
                else => return ParseError.UnexpectedToken,
            },
            .read_colon => switch (token.tag) {
                .colon => state = .read_event,
                else => return ParseError.UnexpectedToken,
            },
            .read_event => {
                state = .read_from;
                consume_token = false;
                current.event = try self.parseEvent();
                try root.append(current);
                current = undefined;
            },
        }

        if (consume_token) {
            self.tokenizer.skipOne();
        }
    }

    switch (state) {
        .read_from => {},
        else => return ParseError.UnexpectedEndOfInput,
    }

    return root;
}

fn parseNote(self: @This(), token: Tokenizer.Token) !markov.Note {
    if (token.tag != .note) {
        return ParseError.InvalidNoteToken;
    }

    const slice = self.tokenizer.getSlice(token);
    std.debug.assert(slice.len >= 2);

    const base = slice[0];
    const modifier = switch (slice[1]) {
        '#', 'b' => @intToEnum(markov.Note.Modifier, slice[1]),
        else => null,
    };

    const octave = switch (slice[1]) {
        '#', 'b' => readNumber(u4, slice[2..]),
        else => readNumber(u4, slice[1..]),
    };

    return markov.Note.human(base, octave, modifier);
}

fn parseNumber(self: @This(), comptime T: type, token: Tokenizer.Token) !T {
    if (token.tag != .number) {
        return ParseError.InvalidNumberToken;
    }

    const slice = self.tokenizer.getSlice(token);
    return readNumber(T, slice);
}

fn readNumber(comptime T: type, buffer: []const u8) T {
    return std.fmt.parseInt(T, buffer, 10) catch unreachable;
}

fn parseEvent(self: *@This()) ParseError!markov.Event {
    const first = try self.loadManyTokens(1);

    if (first[0].tag == .dot) {
        return markov.Event{ .none = {} };
    }

    const peeked = self.tokenizer.peek() orelse return error.UnexpectedEndOfInput;

    if (first[0].tag != .paren_open) return ParseError.UnexpectedToken;

    return switch (peeked.tag) {
        .brace_open => {
            const note_list = try self.parseChord();

            const next = try self.loadManyTokens(1);
            if (next[0].tag != .comma) return ParseError.UnexpectedToken;

            const duration = try self.parseDuration();

            const last = try self.loadManyTokens(1);
            if (last[0].tag != .paren_close) return ParseError.UnexpectedToken;

            return markov.Event{
                .chord = .{
                    .notes = note_list,
                    .duration = duration,
                },
            };
        },
        .note => {
            const note_token = try self.loadManyTokens(1);
            const note = try self.parseNote(note_token[0]);

            const comma = try self.loadManyTokens(1);
            if (comma[0].tag != .comma) return ParseError.UnexpectedToken;

            const duration = try self.parseDuration();

            const last = try self.loadManyTokens(1);
            if (last[0].tag != .paren_close) return ParseError.UnexpectedToken;

            return markov.Event{
                .single = .{
                    .note = note,
                    .duration = duration,
                },
            };
        },
        .underscore => {
            const rest = try self.loadManyTokens(4);

            if (rest[1].tag != .comma) return ParseError.UnexpectedToken;
            if (rest[3].tag != .paren_close) return ParseError.UnexpectedToken;

            return markov.Event{
                .pause = try self.parseDuration(),
            };
        },
        else => ParseError.UnexpectedToken,
    };
}

fn parseChord(self: *@This()) !std.ArrayList(markov.Note) {
    const allocator = self.arena.allocator();

    var list = std.ArrayList(markov.Note).init(allocator);
    errdefer list.deinit();

    const next = try self.loadManyTokens(1);
    if (next[0].tag != .brace_open) return error.UnexpectedToken;

    const ChordState = enum { read_note, read_comma };
    var state = ChordState.read_note;

    while (self.tokenizer.next()) |token| {
        switch (state) {
            .read_note => switch (token.tag) {
                .brace_close => break,
                .note => {
                    const note = try self.parseNote(token);
                    try list.append(note);
                    state = .read_comma;
                },
                else => return error.UnexpectedToken,
            },
            .read_comma => switch (token.tag) {
                .comma => state = .read_note,
                .brace_close => break,
                else => return error.UnexpectedToken,
            },
        }
    }

    return list;
}

fn loadManyTokens(self: *@This(), comptime N: usize) ![N]Tokenizer.Token {
    var arr: [N]Tokenizer.Token = undefined;
    var i: usize = 0;

    while (i < N) : (i += 1) {
        const token = self.tokenizer.next();
        arr[i] = token orelse return ParseError.UnexpectedEndOfInput;
    }

    return arr;
}

fn parsePattern(self: *@This(), token: Tokenizer.Token) ![]const u8 {
    if (token.tag != .pattern) {
        return ParseError.InvalidPatternToken;
    }

    const slice = self.tokenizer.getSlice(token);

    if (slice.len > 2) {
        return slice[1 .. slice.len - 1];
    } else {
        return "";
    }
}

fn parseDuration(self: *@This()) !markov.Duration {
    const tokens = try self.loadManyTokens(3);

    if (tokens[0].tag != .number) return ParseError.UnexpectedToken;
    if (tokens[1].tag != .slash) return ParseError.UnexpectedToken;
    if (tokens[2].tag != .number) return ParseError.UnexpectedToken;

    return markov.Duration{
        .numerator = try self.parseNumber(u8, tokens[0]),
        .denominator = try self.parseNumber(u8, tokens[2]),
    };
}
