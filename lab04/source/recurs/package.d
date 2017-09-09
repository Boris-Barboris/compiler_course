module recurs;

import std.algorithm;
import std.array: array;
import std.conv: to;
import std.stdio;
import std.string;
import std.typecons;
import std.range;

//import grammar;
//import lexer.utils;

struct ParserState
{
    string[] lderiv;
    int cursor;
}

// parse expression exp with grammar grm using recursive descent
string parseExpressionRecursive(string[] exp)
{
    ParserState state;
    parseProgram(state, exp);
    return state.lderiv.join(" ");
}

string pthrow(string msg)
{
    return `if (state.cursor < exp.length)
    throw new Exception("Error on token number " ~ state.cursor.to!string ~ "` ~
        ` '" ~ exp[state.cursor] ~ "', ` ~ msg ~ `");
    else
        throw new Exception("Error on the end of token list: ` ~ msg ~ `");`;
}

void consume(string expected)(ref ParserState state, string[] exp)
{
    if (exp.length - state.cursor < 1)
        throw new Exception("Unexpected end of input after " ~ exp[$-1]);
    if (expected != exp[state.cursor])
        mixin(pthrow("Expected " ~ expected));
    state.lderiv ~= expected;
    state.cursor++;
}

bool consumeSafe(string expected)(ref ParserState state, string[] exp)
{
    if (exp.length - state.cursor < 1)
        return false;
    if (expected != exp[state.cursor])
        return false;
    state.lderiv ~= expected;
    state.cursor++;
    return true;
}

void parseProgram(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Program";
    consume!"{"(state, exp);
    parseExprList(state, exp);
    consume!"}"(state, exp);
    if (state.cursor != exp.length)
        mixin(pthrow("Unexpected symbol after }"));
}

void parseExprList(ref ParserState state, string[] exp)
{
    state.lderiv ~= "ExprList";
    parseExpr(state, exp);
    parseTail(state, exp);
}

void parseExpr(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Expr";
    //writeln("parsing Expr");
    ParserState state_backup = state;
    try
    {
        parseArithmExpr(state, exp);
        parseRelationOp(state, exp);
        parseArithmExpr(state, exp);
    }
    catch (Exception e1)
    {
        state = state_backup;
        parseArithmExpr(state, exp);
    }
}

void parseArithmExpr(ref ParserState state, string[] exp)
{
    state.lderiv ~= "ArithmExpr";
    //writeln("parsing ArithmExpr");
    ParserState state_backup = state;
    try
    {
        parseTerm(state, exp);
        parseArithmExpr2(state, exp);
    }
    catch (Exception e1)
    {
        state = state_backup;
        parseTerm(state, exp);
    }
}

void parseArithmExpr2(ref ParserState state, string[] exp)
{
    state.lderiv ~= "ArithmExpr'";
    //writeln("parsing ArithmExpr'");
    ParserState state_backup = state;
    try
    {
        parseAddOp(state, exp);
        parseTerm(state, exp);
        parseArithmExpr2(state, exp);
    }
    catch (Exception e1)
    {
        state = state_backup;
        parseAddOp(state, exp);
        parseTerm(state, exp);
    }
}

void parseTerm(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Term";
    ParserState state_backup = state;
    try
    {
        consume!"id"(state, exp);
        parseTerm2(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    try
    {
        consume!"id"(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    try
    {
        consume!"const"(state, exp);
        parseTerm2(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    try
    {
        consume!"const"(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    try
    {
        consume!"("(state, exp);
        parseArithmExpr(state, exp);
        consume!")"(state, exp);
        parseTerm2(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    try
    {
        consume!"("(state, exp);
        parseArithmExpr(state, exp);
        consume!")"(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }

    mixin(pthrow("Unable to parse Term"));
}

void parseTerm2(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Term'";
    ParserState state_backup = state;
    try
    {
        parseMultOp(state, exp);
        parseFactor(state, exp);
        parseTerm2(state, exp);
    }
    catch (Exception e1)
    {
        state = state_backup;
        parseMultOp(state, exp);
        parseFactor(state, exp);
    }
}

void parseFactor(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Factor";
    ParserState state_backup = state;
    try
    {
        consume!"id"(state, exp);
        return;
    }
    catch (Exception e1)
    {
        state = state_backup;
    }
    try
    {
        consume!"const"(state, exp);
        return;
    }
    catch (Exception e2)
    {
        state = state_backup;
    }
    consume!"("(state, exp);
    parseArithmExpr(state, exp);
    consume!")"(state, exp);
}

import std.meta: aliasSeqOf;

void parseRelationOp(ref ParserState state, string[] exp)
{
    enum string[] ops = ["<", "<=", "=", "<>", ">=", ">"];
    state.lderiv ~= "RelationOp";
    foreach (op; aliasSeqOf!ops)
    {
        bool consumed = consumeSafe!op(state, exp);
        if (consumed)
            return;
    }
    mixin(pthrow("Expected one of " ~ ops.join(" ")));
}

void parseAddOp(ref ParserState state, string[] exp)
{
    enum string[] ops = ["+", "-"];
    state.lderiv ~= "AddOp";
    foreach (op; aliasSeqOf!ops)
    {
        bool consumed = consumeSafe!op(state, exp);
        if (consumed)
            return;
    }
    mixin(pthrow("Expected one of " ~ ops.join(" ")));
}

void parseMultOp(ref ParserState state, string[] exp)
{
    enum string[] ops = ["*", "/"];
    state.lderiv ~= "MultOp";
    foreach (op; aliasSeqOf!ops)
    {
        bool consumed = consumeSafe!op(state, exp);
        if (consumed)
            return;
    }
    mixin(pthrow("Expected one of " ~ ops.join(" ")));
}

void parseTail(ref ParserState state, string[] exp)
{
    state.lderiv ~= "Tail";
    bool closed = consumeSafe!";"(state, exp);
    if (closed)
    {
        parseExpr(state, exp);
        parseTail(state, exp);
    }
    else
        state.lderiv ~= "__eps";
}
