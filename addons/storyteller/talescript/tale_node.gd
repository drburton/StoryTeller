class_name TaleNode
extends RefCounted
## One statement in a tale's syntax tree.
##
## Every physical line of the source belongs to exactly one node (blank lines
## and comments included), so the tree can be printed back unchanged. Block
## statements such as [code]beat[/code], [code]if[/code], and
## [code]choose[/code] keep their nested statements in [member body].

enum Kind {
	BLANK,          ## Empty or whitespace-only line.
	COMMENT,        ## Line holding only a comment.
	ANNOTATION,     ## Line holding only annotations, e.g. [code]@title("Prologue")[/code].
	VAR,            ## [code]var name := value[/code]
	CONST,          ## [code]const NAME := value[/code]
	BEAT,           ## [code]beat name:[/code]
	DIALOGUE,       ## [code]speaker: "text"[/code] or [code]speaker (mood): "text"[/code]
	NARRATION,      ## [code]"text"[/code]
	JUMP,           ## [code]jump beat[/code] or [code]jump tale.beat[/code]
	EXPRESSION,     ## Any expression used as a statement, usually a call.
	ASSIGN,         ## [code]target = value[/code], [code]target += value[/code], ...
	IF,             ## [code]if condition:[/code]
	ELIF,           ## [code]elif condition:[/code]
	ELSE,           ## [code]else:[/code]
	WHILE,          ## [code]while condition:[/code]
	FOR,            ## [code]for name in iterable:[/code]
	MATCH,          ## [code]match value:[/code]
	MATCH_BRANCH,   ## [code]pattern, pattern when guard:[/code] inside a match.
	CHOOSE,         ## [code]choose:[/code] or [code]choose(style = "list"):[/code]
	OPTION,         ## [code]"text" if condition:[/code] inside a choose.
	TIMEOUT,        ## [code]timeout:[/code] inside a choose.
	RETURN,         ## [code]return[/code] or [code]return value[/code]
	PASS,
	BREAK,
	CONTINUE,
	ERROR,          ## A line that could not be parsed. See [member message].
}

## Kinds that end with ':' and own a block of statements.
const BLOCK_KINDS: Array[Kind] = [
	Kind.BEAT, Kind.IF, Kind.ELIF, Kind.ELSE, Kind.WHILE, Kind.FOR, Kind.MATCH,
	Kind.MATCH_BRANCH, Kind.CHOOSE, Kind.OPTION, Kind.TIMEOUT,
]

var kind: Kind
## First and last physical line of this statement (1-based, inclusive),
## excluding its body.
var line_start := 0
var line_end := 0
## Leading whitespace of the statement's first line.
var indent := ""
## True when this statement sits on the same line as its block header,
## as in [code]if done: jump end[/code].
var inline := false
## Annotations written before the statement on the same line.
var annotations: Array[TaleExpr] = []
## Comment at the end of the line (text after '#'), or the text of a COMMENT line.
var comment := ""

## Name of a VAR, CONST, BEAT, or FOR variable, or the speaker of a DIALOGUE.
var name := ""
## Type hint of a VAR, CONST, or FOR variable, e.g. "int" or "Array[String]".
var type_hint := ""
## True for VAR and CONST declared with ':='.
var infer_type := false
## Mood of a DIALOGUE, e.g. "curious". Empty when not given.
var mood := ""
## Main expression: VAR/CONST value, DIALOGUE/NARRATION/OPTION text,
## condition of IF/ELIF/WHILE, iterable of FOR, subject of MATCH, value of
## ASSIGN/RETURN/EXPRESSION, arguments of CHOOSE (as a call).
var expr: TaleExpr
## Target of an ASSIGN.
var target: TaleExpr
## Assignment operator of an ASSIGN, e.g. "=" or "+=".
var op := ""
## Condition of an OPTION ([code]if ...[/code]) or guard of a MATCH_BRANCH ([code]when ...[/code]).
var condition: TaleExpr
## Patterns of a MATCH_BRANCH.
var patterns: Array[TaleExpr] = []
## Destination of a JUMP: "beat" or "tale.beat".
var jump_target := ""
## Nested statements of a block.
var body: Array[TaleNode] = []
## Error message of an ERROR node.
var message := ""


func _init(p_kind: Kind) -> void:
	kind = p_kind


func is_block() -> bool:
	return kind in BLOCK_KINDS


## True for blank and comment lines, which do not affect the story.
func is_trivia() -> bool:
	return kind == Kind.BLANK or kind == Kind.COMMENT


## Returns an indented text form of this node and its body, used by tests.
func dump(depth := 0) -> String:
	var parts := PackedStringArray([Kind.keys()[kind]])
	for annotation in annotations:
		parts.append(annotation.to_sexpr())
	match kind:
		Kind.COMMENT:
			parts.append("\"%s\"" % comment.c_escape())
		Kind.VAR, Kind.CONST:
			parts.append(name + (": " + type_hint if type_hint else ""))
			if expr:
				parts.append(":=" if infer_type else "=")
				parts.append(expr.to_sexpr())
		Kind.BEAT:
			parts.append(name)
		Kind.DIALOGUE:
			parts.append(name)
			if mood:
				parts.append("(%s)" % mood)
			parts.append(expr.to_sexpr())
		Kind.JUMP:
			parts.append(jump_target)
		Kind.ASSIGN:
			parts.append_array([target.to_sexpr(), op, expr.to_sexpr()])
		Kind.FOR:
			parts.append(name + (": " + type_hint if type_hint else ""))
			parts.append("in")
			parts.append(expr.to_sexpr())
		Kind.MATCH_BRANCH:
			for pattern in patterns:
				parts.append(pattern.to_sexpr())
		Kind.ERROR:
			parts.append("\"%s\"" % message.c_escape())
		_:
			if expr:
				parts.append(expr.to_sexpr())
	if condition:
		parts.append("when" if kind == Kind.MATCH_BRANCH else "if")
		parts.append(condition.to_sexpr())
	if comment and kind != Kind.COMMENT:
		parts.append("#\"%s\"" % comment.c_escape())
	var span := "%d" % line_start if line_start == line_end else "%d-%d" % [line_start, line_end]
	var text := "%s%s [%s]%s\n" % ["  ".repeat(depth), " ".join(parts), span, " inline" if inline else ""]
	for child in body:
		text += child.dump(depth + 1)
	return text
