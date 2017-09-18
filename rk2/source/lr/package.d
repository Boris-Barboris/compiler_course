module lr;

import std.algorithm;
import std.array: array;
import std.container.rbtree;
import std.conv: to;
import std.stdio;
import std.string;
import std.typecons;
import std.range;

import grammar;
import lexer.utils;


enum ActionType
{
    error,
    shift,
    reduction,
    accept,
}

struct Action
{
    ActionType type = ActionType.error;
    int index;  // new state or production index
}

struct LRAnalizer
{
    int state_count;
    Action[][] tableaction;
    int[][] tablegoto;
}

struct Punct
{
    int prod_idx;   // index of pdocution in the grammar
    int p_idx;      // where is the dot placed

    // sorting comparator
    static bool less(const Punct a, const Punct b)
    {
        if (a.prod_idx == b.prod_idx)
            return a.p_idx < b.p_idx;
        else
            return a.prod_idx < b.prod_idx;
    }
}


// parse input tokens by grm grammar using canonical SLR parsing algorithm
void SLRParse(Grammar* grm, scope string[] input)
{
    // first we linearize symbols in order to use simple indexing
    Symbol*[] nonterminals = grm.nonterminals.byValue.array;
    Symbol*[] terminals = grm.terminals.byValue.array;
    terminals ~= new Symbol(TERM, "$"); // special symbol
    // mappings from symbol repr to it's index in the arrays above
    int[Symbol*] nont2idx;
    int[string] t2idx;
    foreach (i, nt; nonterminals)
        nont2idx[nt] = i;
    foreach (i, t; terminals)
        t2idx[t.repr] = i;

    // transform input chain to array of indexes for terminals
    int[] input_chain;
    foreach (symb; input)
        input_chain ~= t2idx[symb];
    input_chain ~= t2idx["$"];

    // augment our grammar
    Symbol* augstart = new Symbol(NONTERM, "AugStart");
    nonterminals ~= augstart;
    nont2idx[nonterminals[$-1]] = nonterminals.length - 1;
    Production*[] productions = grm.productions.dup;
    productions ~= new Production(nonterminals[$-1], [grm.axiom]);
    int root_product_idx = productions.length - 1;

    int[Production*] prod2idx;
    foreach (i, p; productions)
        prod2idx[p] = i;

    writeln("productions:");
    foreach (i, p; productions)
        writeln(i, ": ", toString(p));

    // now we build LR tables
    LRAnalizer anz;

    string toString(const Punct p)
    {
        Production* prod = productions[p.prod_idx];
        string res = prod.input.repr ~ " -> ";
        int i = 0;
        foreach (o; prod.output)
        {
            if (i++ == p.p_idx)
                res ~= "__dot ";
            res ~= o.repr ~ " ";
        }
        if (i == p.p_idx)
            res ~= "__dot ";
        return res;
    }

    // build closure of the set of items
    Punct[] closure(scope Punct[] I)
    {
        Punct[] res = I.dup;
        bool[] added = new bool[nonterminals.length];
        int old_length;
        //writeln("Building closure of ", I);
        do
        {
            old_length = res.length;
            foreach (p; res)
            {
                // dot must not be placed after the last element
                if (p.p_idx == productions[p.prod_idx].output.length)
                    continue;
                Symbol* postdot = productions[p.prod_idx].output[p.p_idx];
                if (postdot.type == NONTERM)
                {
                    // seek for production from it
                    int postdot_idx = nont2idx[postdot];
                    if (added[postdot_idx]) // we have already added it
                        continue;
                    foreach (i, prod; productions)
                    {
                        if (prod.input == postdot)
                        {
                            res ~= Punct(i, 0);
                            //writeln("adding ", toString(res[$-1]), " to closure");
                        }
                    }
                    added[postdot_idx] = true;
                }
            }
        } while (res.length > old_length);
        return res;
    }

    Punct[] fgoto(PunctR)(PunctR I, Symbol* X)
    {
        Punct[] subset;
        foreach (p; I)
        {
            auto prod = productions[p.prod_idx];
            if (prod.output.length > p.p_idx && X == prod.output[p.p_idx])
                subset ~= Punct(p.prod_idx, p.p_idx + 1);
        }
        return closure(subset);
    }

    Punct[][] buildCanonicalSuperset()
    {
        Punct[][] res;
        res ~= closure([Punct(productions.length - 1, 0)]);
        // sorting is needed for equality comparison
        res[0].sort!(Punct.less);

        bool already_in_res(scope Punct[] arr)
        {
            foreach (r; res)
                if (r == arr)
                    return true;
            return false;
        }

        int old_length;
        do
        {
            old_length = res.length;
            foreach (I; res)
            {
                // first we try nontermilans excluding extended axiom
                foreach (nt; nonterminals[0..$-1])
                {
                    auto gotores = fgoto(I, nt);
                    if (gotores.length > 0)
                    {
                        gotores.sort!(Punct.less);
                        if (!already_in_res(gotores))
                        {
                            writeln("adding superset ", gotores);
                            res ~= gotores;
                        }
                    }
                }
                // then all terminals
                foreach (nt; terminals)
                {
                    auto gotores = fgoto(I, nt);
                    if (gotores.length > 0)
                    {
                        gotores.sort!(Punct.less);
                        if (!already_in_res(gotores))
                        {
                            writeln("adding superset ", gotores);
                            res ~= gotores;
                        }
                    }
                }
            }
        } while (res.length > old_length);
        return res;
    }

    Punct[][] LR0 = buildCanonicalSuperset();
    writeln("LR0 state set");
    foreach (i, set; LR0)
    {
        writeln("set I", i);
        foreach (p; set)
            writeln("    ", toString(p));
    }

    // calculate FIRST for all symbols of the grammar
    SymbolHashSet[Symbol*] FIRSTs()
    {
        SymbolHashSet[Symbol*] res;
        // go through terminals
        foreach (term; terminals)
            res[term] = SymbolHashSet([term]);
        // initialize by empty sets for nonterms
        foreach (nt; nonterminals)
            res[nt] = SymbolHashSet();
        // seek epsilon-productions
        foreach (prod; productions)
        {
            if (prod.output.length == 1 && prod.output[0] == grm.eps)
                res[prod.input].insert(grm.eps);
        }
        // now enter loop for productions
        bool added;
        do
        {
            added = false;
            foreach (prod; productions)
            {
                foreach (i, o; prod.output)
                {
                    added |= (res[prod.input].unionn(res[o][]) > 0);
                    if (!res[o].contains(grm.eps))
                        break;
                }
            }
        } while (added);
        return res;
    }

    auto firsts = FIRSTs();
    writeln("FIRSTS:");
    foreach (k, v; firsts)
        writeln("  ", k.repr, " = { ", v[].map!(a => a.repr).join(", "), " }");

    SymbolHashSet FIRST(Symbol*[] arr)
    {
        SymbolHashSet res;
        bool noneps_found = false;
        foreach (s; arr)
        {
            bool has_eps = firsts[s].contains(grm.eps);
            foreach (fs; firsts[s][])
                if (fs.type != EPS)
                    res.insert(fs);
            if (!has_eps)
            {
                noneps_found = true;
                break;
            }
        }
        if (!noneps_found)
            res.insert(grm.eps);
        return res;
    }

    // calculate FOLLOW function for every nonterminal
    SymbolHashSet[Symbol*] FOLLOWs()
    {
        SymbolHashSet[Symbol*] res;
        // initialize with empty sets
        foreach (nt; nonterminals)
            res[nt] = SymbolHashSet();
        // put dollar $ into follow of AugStart
        res[augstart].insert(terminals[$-1]);
        bool added;
        do
        {
            added = false;
            foreach (prod; productions)
            {
                foreach (i, o; prod.output)
                {
                    if (o.type == NONTERM)
                    {
                        if (i == prod.output.length - 1)
                        {
                            // it's the tail of droduction right part
                            added |= res[o].unionn(res[prod.input][]) > 0;
                        }
                        else
                        {
                            // add all from FIRST of the tail of production
                            // except eps
                            auto ffirst = FIRST(prod.output[i+1..$]);
                            added |= res[o].unionn(
                                ffirst[].filter!(a => a.type != EPS)) > 0;
                            if (ffirst.contains(grm.eps))
                            {
                                // tail is null-producing
                                added |= res[o].unionn(res[prod.input][]) > 0;
                            }
                        }
                    }
                }
            }
        } while (added);
        return res;
    }

    auto follows = FOLLOWs();
    writeln("FOLLOWS:");
    foreach (k, v; follows)
        writeln("  ", k.repr, " = { ", v[].map!(a => a.repr).join(", "), " }");

    anz.state_count = LR0.length;
    anz.tableaction.length = anz.state_count;
    anz.tablegoto.length = anz.state_count;
    // fill tables with errors
    for (int i = 0; i < anz.state_count; i++)
    {
        anz.tableaction[i].length = terminals.length;
        anz.tablegoto[i].length = nonterminals.length;
        anz.tablegoto[i][] = -1;
    }
    // now we actually build the tables

    // return index of gotores
    int find_gotores(Punct[] res)
    {
        res.sort!(Punct.less);
        foreach (i, I; LR0)
            if (I == res)
                return i;
        return -1;
    }

    foreach (i, I; LR0)
    {
        // fill action table
        foreach (punct; I)
        {
            Production* p = productions[punct.prod_idx];
            writeln("addressing punct ", toString(punct));
            if (punct.p_idx < p.output.length)
            {
                // possible shift
                Symbol* a = p.output[punct.p_idx];
                if (a.type == TERM)
                {
                    // yeah, it's a shift
                    auto gotores = fgoto(I, a);
                    if (gotores.length > 0)
                    {
                        writeln("a = ", a.repr, " gotores = ",
                            gotores.map!(a => toString(a)));
                        int idx = find_gotores(gotores);
                        writeln("corresponds to superstate I", idx);
                        assert(idx >= 0);
                        Action proposed = Action(ActionType.shift, idx);
                        Action present = anz.tableaction[i][t2idx[a.repr]];
                        assert(present.type == ActionType.error ||
                            present == proposed, "Non-SLR grammar");
                        anz.tableaction[i][t2idx[a.repr]] = proposed;
                        writeln("writing shift action");
                    }
                }
            }
            if (punct.p_idx == p.output.length)
            {
                if (p.input != augstart)
                {
                    foreach (term; follows[p.input][])
                    {
                        Action proposed = Action(ActionType.reduction, prod2idx[p]);
                        Action present = anz.tableaction[i][t2idx[term.repr]];
                        assert(present.type == ActionType.error ||
                            present == proposed, "Non-SLR grammar");
                        anz.tableaction[i][t2idx[term.repr]] = proposed;
                        writeln("writing reduction action for ", term.repr);
                    }
                }
            }
            if (punct.prod_idx == productions.length - 1 && punct.p_idx == 1)
            {
                // it's a AugStart -> S __dot state
                assert(anz.tableaction[i][t2idx["$"]].type == ActionType.error,
                    "Non-SLR grammar");
                anz.tableaction[i][t2idx["$"]] =
                    Action(ActionType.accept);
                writeln("writing accept action for $");
            }
        }

        // fill goto table
        foreach (j, nt; nonterminals)
        {
            auto gotores = fgoto(I, nt);
            int idx = find_gotores(gotores);
            if (idx >= 0)
            {
                writeln("writing goto transition from ", i, " to ", idx,
                    " on ", nt.repr);
                anz.tablegoto[i][j] = idx;
            }
        }
    }


    //
    // now we run the algorithm
    //

    writeln("\n\nRunning SLR analysis:");

    enum ElType
    {
        parserState,
        symbol
    }

    struct StackElement
    {
        ElType type;
        union
        {
            Symbol* symb;
            int state_idx;
        }
    }

    string toString2(const StackElement el)
    {
        if (el.type == ElType.parserState)
            return "I" ~ el.state_idx.to!string;
        else
            return el.symb.repr;
    }

    StackElement[] stack;
    stack.reserve(128);
    auto init_el = StackElement(ElType.parserState);
    init_el.state_idx = 0;
    stack ~= init_el;

    void reportState()
    {
        string res = "stack: " ~ stack.map!(a => toString2(a)).join(" ");
        res ~= "   input: " ~ input_chain.map!(a => terminals[a].repr).join(" ");
        writeln(res);
    }

    while (true)
    {
        reportState();
        int cur_state = stack[$-1].state_idx;
        Action act = anz.tableaction[cur_state][input_chain[0]];
        if (act.type == ActionType.error)
            throw new Exception("Parsing error");
        if (act.type == ActionType.accept)
            break;
        if (act.type == ActionType.shift)
        {
            StackElement nel1;
            nel1.type = ElType.symbol;
            nel1.symb = terminals[input_chain[0]];
            StackElement nel2;
            nel2.type = ElType.parserState;
            nel2.state_idx = act.index;
            stack ~= nel1;
            stack ~= nel2;
            input_chain = input_chain[1..$];
            writeln("shift to ", act.index);
        }
        if (act.type == ActionType.reduction)
        {
            Production* p = productions[act.index];
            stack = stack[0 .. $ - p.output.length*2];
            cur_state = stack[$-1].state_idx;
            int gotores = anz.tablegoto[cur_state][nont2idx[p.input]];
            if (gotores < 0)
                throw new Exception("goto table does not allow such transition");
            StackElement nel1;
            nel1.type = ElType.symbol;
            nel1.symb = p.input;
            StackElement nel2;
            nel2.type = ElType.parserState;
            nel2.state_idx = gotores;
            stack ~= nel1;
            stack ~= nel2;
            writeln("Output: production ", p.toString);
        }
    }
    writeln("Parsing COMPLETE");
}
