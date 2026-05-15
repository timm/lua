"""Pygments lexer for .fun (Lua + fun/let/! /++ )."""
from pygments.lexer import RegexLexer, bygroups, words
from pygments.token import (Comment, Keyword, Name, Number,
                            Operator, Punctuation, String, Text)


class FunLexer(RegexLexer):
    name = "Fun"
    aliases = ["fun"]
    filenames = ["*.fun"]

    tokens = {
        "root": [
            (r"\s+", Text),
            (r"--\[\[", Comment.Multiline, "longcomment"),
            (r"--.*$", Comment.Single),
            (r"\[\[", String, "longstring"),
            (r'"', String, "dqstring"),
            (r"'", String, "sqstring"),
            (r"\b(fun)(\s*)(\()",
             bygroups(Keyword.Declaration, Text, Punctuation),
             "params"),
            (r"\blet\b", Keyword.Declaration),
            (r"!", Keyword),
            (r"\+\+", Operator),
            (r"\?=", Operator),
            (r"(==|~=|<=|>=|<|>|=)", Operator),
            (r"(\+|-|\*|/|//|%|\^|#|\.\.)", Operator),
            (words(("and", "or", "not", "if", "elseif", "else",
                    "end", "do", "while", "for", "in", "repeat",
                    "until", "break", "return"),
                   suffix=r"\b"), Keyword),
            (words(("ipairs", "pairs", "print", "type", "tostring",
                    "tonumber", "setmetatable", "table", "math",
                    "string", "io", "os"), suffix=r"\b"),
             Name.Builtin),
            (r"0[xX][0-9a-fA-F]+", Number.Hex),
            (r"\d+\.\d*([eE][+-]?\d+)?", Number.Float),
            (r"\.\d+([eE][+-]?\d+)?", Number.Float),
            (r"\d+[eE][+-]?\d+", Number.Float),
            (r"\d+", Number.Integer),
            (r"[A-Z][\w_]*", Name.Class),
            (r"[a-zA-Z_]\w*", Name),
            (r"[\(\)\{\}\[\],;:.]", Punctuation),
        ],
        "params": [
            (r"\)", Punctuation, "#pop"),
            (r"[a-zA-Z_]\w*", Name.Variable),
            (r"[,\s]+", Text),
        ],
        "longcomment": [
            (r"\]\]", Comment.Multiline, "#pop"),
            (r"[^\]]+", Comment.Multiline),
            (r"\]", Comment.Multiline),
        ],
        "longstring": [
            (r"\]\]", String, "#pop"),
            (r"[^\]]+", String),
            (r"\]", String),
        ],
        "dqstring": [
            (r'"', String, "#pop"),
            (r"\\.", String.Escape),
            (r'[^"\\]+', String),
        ],
        "sqstring": [
            (r"'", String, "#pop"),
            (r"\\.", String.Escape),
            (r"[^'\\]+", String),
        ],
    }
