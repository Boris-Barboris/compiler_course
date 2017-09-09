module grammar;

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


/*alias SymbolHashSet = RedBlackTree!(Symbol*,
    (const(Symbol)* a, const(Symbol)* b) => djb2(a.repr) < djb2(b.repr), false);*/
alias SymbolHashSet = HashSet!(Symbol*);

// algorithm 2.7
bool languageNonEmpty(Grammar* grm, out Symbol*[] ne)
{
    SymbolHashSet N = SymbolHashSet();
    SymbolHashSet all = SymbolHashSet(grm.nonterminals.byValue);

    Symbol* findProducer()
    {
        // for all nonterminals that are left unmarked
        foreach (s; all)
        {
            writeln("Trying nonterm ", s.repr, " as producer");
            // for all productions of this nonterminal
            foreach (prod; grm.productions.filter!(a => a.input == s))
            {
                writeln("Trying production: ", prod.to!string);
                assert(prod.output.length > 0);
                /*if (prod.output.length == 1 && prod.output[0].eps)
                {
                    writeln("It only has empty output");
                    continue;   // empty output
                }*/
                bool fits = true;
                foreach (o; prod.output)
                {
                    // for each output symbol
                    if (!(o in N) && !o.term)
                    {
                        writeln("This production is unfit, symbol " ~ o.repr ~
                            " belongs to N = ", cast(bool)(o in N),
                            " is terminal = ", o.term);
                        fits = false;
                        break;
                    }
                }
                if (fits)
                {
                    // this is a good production
                    writeln("This production fits");
                    return s;
                }
            }
        }
        return null;
    }

    for (int i = 0; i <= grm.nonterminals.length; i++)
    {
        // we must find such nonterminal that in all that is capable of producing
        // non-empty chain of terminal symbols or symbols from N;
        writeln(i, " iteration");
        Symbol* producer = findProducer();
        if (producer is null)
        {
            writeln("unable to find producing nonterminal");
            if (grm.axiom in N)
            {
                writeln("axiom is present in Ne");
                ne = N[].array;
                return true;
            }
            return false;
        }
        writeln("found producer ", producer.repr);
        N.insert(producer);
        writeln("N = ", N[].map!(a => a.repr));
        all.remove(producer);
        writeln("all = ", all[].map!(a => a.repr));
    }
    return false;
}


// algorithm 2.8
Grammar* eliminateUnreachable(Grammar* grm)
{
    SymbolHashSet V = SymbolHashSet();
    SymbolHashSet all = SymbolHashSet(grm.symbols.byValue);

    // axiom symbol is our starting point
    V.insert(grm.axiom);
    all.remove(grm.axiom);

    Symbol* findReachable()
    {
        // for all symbols that are left unmarked
        foreach (s; all)
        {
            writeln("Trying symbol ", s.repr, " as reachable");
            // for all productions of symbols that are already in V
            foreach (prod; grm.productions.filter!(a => V.contains(a.input)))
            {
                writeln("Trying production: ", prod.to!string);
                assert(prod.output.length > 0);
                /*if (prod.output.length == 1 && prod.output[0].eps)
                {
                    writeln("It only has empty output");
                    continue;   // empty output
                }*/
                bool fits = true;
                if (!prod.output.canFind(s))
                {
                    writeln("This production is unfit, symbol " ~ s.repr ~
                        " is not found in it's output");
                    fits = false;
                    continue;
                }
                if (fits)
                {
                    // this is a good production
                    writeln("This production fits");
                    return s;
                }
            }
            writeln("symbol ", s.repr, " is unreachable on this iteration");
        }
        return null;
    }

    int i = 0;
    while(true)
    {
        // we must find such nonterminal that in all that is capable of producing
        // non-empty chain of terminal symbols or symbols from N;
        writeln(i++, " iteration");
        Symbol* reachable = findReachable();
        if (reachable is null)
        {
            writeln("unable to find another reachable symbol");
            break;
        }
        writeln("found reachable ", reachable.repr);
        V.insert(reachable);
        writeln("V = ", V[].map!(a => a.repr));
        all.remove(reachable);
        writeln("all = ", all[].map!(a => a.repr));
    }

    // we now need to intersect our sets with V
    Grammar* res = new Grammar();
    foreach (symb; V[])
    {
        writeln("including symbol ", symb.repr, " in new grammar");
        res.symbols[symb.repr] = symb;
        if (symb.term)
            res.terminals[symb.repr] = symb;
        else if (symb.eps)
            res.eps = symb;
        else
            res.nonterminals[symb.repr] = symb;
    }
    foreach (prod; grm.productions)
    {
        if ((prod.input in V) && (prod.output.any!(a => (a in V))))
        {
            writeln("including production ", prod.to!string, " in new grammar");
            res.productions ~= prod;
        }
    }
    res.axiom = grm.axiom;

    return res;
}


// remove useless symbols
Grammar* eliminateUseless(Grammar* grm)
{
    Symbol*[] NE;
    bool nonempty = languageNonEmpty(grm, NE);
    if (!nonempty)
        throw new Exception("empty language");

    writeln("\nRemoving states that have no terminal productions...");
    Grammar* compressed = new Grammar();
    // copy all terminals
    compressed.terminals = grm.terminals;
    foreach (symb; grm.terminals)
        compressed.symbols[symb.repr] = symb;
    // copy some non-terminals
    foreach (symb; NE)
    {
        writeln("including symbol ", symb.repr, " in compressed grammar");
        compressed.symbols[symb.repr] = symb;
        compressed.nonterminals[symb.repr] = symb;
    }
    SymbolHashSet ne = SymbolHashSet(NE);
    foreach (prod; grm.productions)
    {
        if ((prod.input in ne) && (prod.output.any!(a => (a.term || a.eps || (a in ne)))))
        {
            writeln("including production ", prod.to!string, " in compressed grammar");
            compressed.productions ~= prod;
        }
    }
    // copy epsilon
    compressed.eps = grm.eps;
    compressed.symbols[grm.eps.repr] = grm.eps;
    // copy axiom
    compressed.axiom = grm.axiom;

    writeln("\nNow removing unreachable symbols...");
    return eliminateUnreachable(compressed);
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
