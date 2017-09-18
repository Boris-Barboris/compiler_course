import std.algorithm;
import std.array;
import std.stdio;
import std.string;

import lexer.fa;
import lexer.utils;
import grammar;
import lr;


void main()
{
    Grammar* grm = new Grammar();
    grm.addSymbol(new Symbol(NONTERM, "S"));
    grm.addSymbol(new Symbol(NONTERM, "A"));
    grm.addSymbol(new Symbol(NONTERM, "B"));
    grm.addSymbol(new Symbol(TERM, "a"));
    grm.addSymbol(new Symbol(TERM, "b"));
    grm.addSymbol(new Symbol(TERM, "("));
    grm.addSymbol(new Symbol(TERM, ")"));
    grm.addSymbol(new Symbol(TERM, ">"));
    grm.axiom = grm.nonterminals["S"];
    grm.productions ~= new Production(grm.nonterminals["S"],
        [ grm.nonterminals["A"] ]);
    grm.productions ~= new Production(grm.nonterminals["S"],
        [ grm.nonterminals["B"] ]);
    grm.productions ~= new Production(grm.nonterminals["A"],
        [ grm.terminals["a"] ]);
    grm.productions ~= new Production(grm.nonterminals["A"],
        [ grm.terminals["("], grm.nonterminals["A"], grm.terminals[")"] ]);
    grm.productions ~= new Production(grm.nonterminals["B"],
        [ grm.terminals["b"] ]);
    grm.productions ~= new Production(grm.nonterminals["B"],
        [ grm.terminals["("], grm.nonterminals["B"], grm.terminals[">"] ]);

    SLRParse(grm, ["(", "(", "b", ">", ">"]);
}
