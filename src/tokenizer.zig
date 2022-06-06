const std = @import("std");

pub const Token = struct {
    pub const Tag = enum {
        pattern,
        number,
        paren_open,
        paren_close,
        comma,
        invalid,
        note,
        dot,
        underscore,
        comment,
        brace_open,
        brace_close,
        arrow,
        colon,
    };

    tag: Tag,
    start: usize,
    end: usize,
};

const State = enum {
    begin,
    read_pattern,
    read_number,
    read_note_modifier,
    read_note_octave,
    read_second_slash,
    read_comment,
    read_arrow,
};

buffer: []const u8,
index: usize = 0,

pub fn init(buffer: []const u8) @This() {
    return .{
        .buffer = buffer,
    };
}

pub fn next(self: *@This()) ?Token {
    var state = State.begin;
    var token = Token{
        .tag = undefined,
        .start = self.index,
        .end = self.index,
    };

    const found: ?Token = while (self.index < self.buffer.len) : (self.index += 1) {
        const c = self.buffer[self.index];

        switch (state) {
            .begin => switch (c) {
                ' ', '\n', '\r', '\t' => {
                    token.start += 1;
                },
                'A'...'G' => {
                    token.tag = .note;
                    state = .read_note_modifier;
                },
                '\'' => {
                    token.tag = .pattern;
                    state = .read_pattern;
                },
                '0'...'9' => {
                    token.tag = .number;
                    state = .read_number;
                },
                '(' => {
                    token.tag = .paren_open;
                    token.end = self.index + 1;
                    break token;
                },
                ')' => {
                    token.tag = .paren_close;
                    token.end = self.index + 1;
                    break token;
                },
                ',' => {
                    token.tag = .comma;
                    token.end = self.index + 1;
                    break token;
                },
                '.' => {
                    token.tag = .dot;
                    token.end = self.index + 1;
                    break token;
                },
                '_' => {
                    token.tag = .underscore;
                    token.end = self.index + 1;
                    break token;
                },
                '{' => {
                    token.tag = .brace_open;
                    token.end = self.index + 1;
                    break token;
                },
                '}' => {
                    token.tag = .brace_close;
                    token.end = self.index + 1;
                    break token;
                },
                ':' => {
                    token.tag = .colon;
                    token.end = self.index + 1;
                    break token;
                },
                '/' => state = .read_second_slash,
                '-' => state = .read_arrow,
                else => {
                    token.tag = .invalid;
                    token.end = self.index + 1;
                    break token;
                },
            },
            .read_arrow => switch (c) {
                '>' => {
                    token.tag = .arrow;
                    token.end = self.index + 1;
                    break token;
                },
                else => {
                    token.tag = .invalid;
                    token.end = self.index + 1;
                    break token;
                },
            },
            .read_second_slash => switch (c) {
                '/' => {
                    token.tag = .comment;
                    state = .read_comment;
                },
                else => {
                    token.tag = .invalid;
                    token.end = self.index + 1;
                    break token;
                },
            },
            .read_comment => switch (c) {
                else => {},
                '\n' => {
                    token.end = self.index + 1;
                    self.index -= 1;
                    break token;
                },
            },
            .read_pattern => switch (c) {
                '\'' => {
                    token.end = self.index + 1;
                    break token;
                },
                else => {},
            },
            .read_number => switch (c) {
                '0'...'9' => {},
                else => {
                    token.end = self.index;
                    self.index -= 1;
                    break token;
                },
            },
            .read_note_modifier => switch (c) {
                '#', 'b', '0'...'9' => state = .read_note_octave,
                else => {
                    token.tag = .invalid;
                    token.end = self.index + 1;
                    break token;
                },
            },
            .read_note_octave => switch (c) {
                '0'...'9' => state = .read_note_octave,
                else => {
                    token.tag = .note;
                    token.end = self.index;
                    self.index -= 1;
                    break token;
                },
            },
        }
    } else null;

    self.index += 1;

    return found;
}

pub fn peek(self: *@This()) ?Token {
    const idx = self.index;
    const token = self.next();
    self.index = idx;
    return token;
}

pub fn skipOne(self: *@This()) void {
    _ = self.next();
}

pub fn getSlice(self: @This(), token: Token) []const u8 {
    return self.buffer[token.start..token.end];
}
