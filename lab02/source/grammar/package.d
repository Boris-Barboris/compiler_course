module lab02.grammar;

import std.algorithm;
import std.array: array;
import std.container.rbtree;
import std.conv: to;
import std.stdio;
import std.string;
import std.typecons;
import std.range;

import lexer.utils;


// http://www.cse.yorku.ca/~oz/hash.html
pure ulong djb2(string str) @safe
{
    ulong hash = 5381;
    foreach (char c; str)
        hash = ((hash << 5) + hash) + c;
    return hash;
}

struct Symbol
{
    bool term;      // true when this is terminal symbol
    string repr;    // unique representation
    bool eps;       // is this an empty terminal?
    //bool nullable;  // wheter this symbol can be
}

struct Production
{
    Symbol* input;
    Symbol*[] output;

    this(Symbol* i, Symbol*[] o)
    {
        assert(!i.term);    // context-free grammar
        input = i;
        output = o;
    }
}

//alias SymbolSet = RedBlackTree!(Symbol*, (Symbol* a, Symbol* b) => djb2(a.repr) < djb2(b.repr), false);
alias SymbolSet = Symbol*[string];

void add(ref SymbolSet set, Symbol* s)
{
    if (!(s.repr in set))
        set[s.repr] = s;
}

struct Grammar
{
    SymbolSet nonterminals;
    SymbolSet terminals;
    SymbolSet symbols;  // global hash, for all symbols
    Symbol* axiom;
    Symbol* eps;
    Production*[] productions;
}


// works inplace
void eliminateLeftRecursions(Grammar* grm)
{
    Symbol*[] nonterms = grm.nonterminals.byValue.array;
    writeln("array of nonterminals: ", nonterms.map!(a => a.repr));
    for (int i = 0; i < nonterms.length; i++)
    {
        for (int j = 0; j < i; j++)
        {
            Production*[] to_remove;
            Production*[] to_add;
            foreach (prod; grm.productions.
                filter!(a => a.input == nonterms[i]).
                filter!(a => a.output[0] == nonterms[j]))
            {
                to_remove ~= prod;
                writeln("removing production (from bigger to smaller index): ", prod.to!string);
                foreach (prevprod; grm.productions.
                    filter!(a => a.input == nonterms[j]))
                {
                    auto p = new Production(
                        nonterms[i],
                        prevprod.output ~ prod.output[1..$]);
                    writeln("adding production: ", p.to!string);
                    to_add ~= p;
                }
            }
            // apply to_remove and to_add
            foreach (tr; to_remove)
                grm.productions = grm.productions.remove_one(tr);
            grm.productions ~= to_add;
        }

        // remove immediate recursions from Ai productions

        if (!grm.productions.canFind!(a => (a.output[0] == a.input) && (a.input == nonterms[i])))
            continue;   // no recursions for Ai
        writeln("recustions found in productions of ", nonterms[i].repr);
        string new_repr = nonterms[i].repr ~ '\'';
        assert(!(new_repr in grm.symbols));
        Symbol* new_nonterm = new Symbol(false, new_repr);
        grm.nonterminals[new_repr] = new_nonterm;
        grm.symbols[new_repr] = new_nonterm;
        Production*[] to_add;
        // iterate over it's productions
        foreach (prod; grm.productions.filter!(a => a.input == nonterms[i]))
        {
            if (prod.output[0] == prod.input)
            {
                // prod is production of type Ai -> "Ai a". We replace it by A'i -> "a A'i"
                writeln("eliminating immediate recursion in: ", prod.to!string);
                assert(prod.output.length > 1); // true for non-looped grammars
                prod.input = new_nonterm;
                prod.output = prod.output[1..$];
                //to_add ~= new Production(new_nonterm, prod.output);
                prod.output ~= new_nonterm;
                writeln("replacing it with ", prod.to!string);
                //writeln(" and adding ", to_add[$-1].to!string);
            }
            else
            {
                // prod is production of type Ai -> "b". We add new production
                // Ai -> "b A'i"
                writeln("replacing: ", prod.to!string);
                prod.output = (prod.output ~ new_nonterm).filter!(a => !a.eps).array;
                writeln("with: ", prod.to!string);
            }
        }
        grm.productions ~= to_add;
        grm.productions ~= new Production(new_nonterm, [grm.eps]);
        writeln("adding ", grm.productions[$-1].to!string);
    }
}

void printGrammar(Grammar* grm)
{
    writeln("nonterminals:");
    foreach (symb; grm.nonterminals.byValue)
        write(symb.repr, " ");
    writeln();
    writeln("terminals:");
    foreach (symb; grm.terminals.byValue)
        write(symb.repr, " ");
    writeln();
    writeln("productions:");
    foreach (prod; grm.productions)
    {
        write(prod.input.repr, " -> ");
        foreach (symb; prod.output)
            write(symb.repr, " ");
        writeln();
    }
    writeln("axiom: ", grm.axiom.repr);
}

string to(T: string)(const(Production)* prod)
{
    return prod.input.repr ~ " -> " ~ prod.output.map!(a => a.repr).join(" ");
}

Grammar* readFromFile(string filename)
{
    Grammar* res = new Grammar();
    res.eps = new Symbol(true, "__eps", true);
    res.symbols["__eps"] = res.eps;
    auto f = File(filename, "r");
    scope(exit) f.close();

    int nt_count = f.readln.strip.to!int;
    writeln(nt_count, " nonterminals");
    string[] nonterms = f.readln.strip.split(" ");
    assert(nt_count == nonterms.length);
    writeln(nonterms);
    foreach (nt; nonterms)
    {
        auto s = new Symbol(false, nt);
        res.nonterminals.add(s);
        res.symbols.add(s);
    }

    int t_count = f.readln.strip.to!int;
    writeln(t_count, " terminals");
    string[] terms = f.readln.strip.split(" ");
    assert(t_count == terms.length);
    writeln(terms);
    foreach (t; terms)
    {
        auto s = new Symbol(true, t);
        res.terminals.add(s);
        res.symbols.add(s);
    }

    int p_count = f.readln.strip.to!int;
    writeln(p_count, " productions:");
    while ((p_count--) > 0)
    {
        string[] prod = f.readln.strip.split(" ");
        string nt = prod[0];
        assert(prod[1] == "->");
        string[] output = prod[2..$];
        Production* p;
        if (output.length > 0)
             p = new Production(res.nonterminals[nt], output.map!(a => res.symbols[a]).array);
        else
            p = new Production(res.nonterminals[nt], [res.eps]);
        writeln(p.to!string);
        res.productions ~= p;
    }

    string axiom = f.readln.strip;
    writeln("axiom: ", axiom);
    res.axiom = res.nonterminals[axiom];

    writeln("Grammar is built");

    return res;
}
