module parser.topdown;

import std.algorithm;
import std.array: array;
/*import std.container.rbtree;*/
//import std.container.slist;
import std.conv: to;
import std.stdio;
import std.string;
import std.typecons;
import std.range;

import lexer.utils;
import grammar;


// top-down with rollbacks
void parseExpression(Grammar* grm, string[] exp)
{
    struct NontermAlt
    {
        Symbol* nonterm;
        Production*[] alternatives; // ordered alternatives
    }

    enum AlgState
    {
        normal,
        rlback,
        finish
    }

    struct L1Record
    {
        Symbol* symb;
        int choice = -1;    // -1 for terminal
    }

    // first we build nonterminal alternatives hash
    NontermAlt[Symbol*] alts;
    foreach (symb; grm.nonterminals)
        alts[symb] = NontermAlt(symb,
            grm.productions.filter!(a => a.input == symb).array);

    // 4 states of the algorithm
    AlgState state = AlgState.normal;
    int caret = 0;
    L1Record[] L1;                  // stack of alternative choices
    assert(grm.axiom);
    Symbol*[] L2 = [ grm.axiom ];   // stack of current total froduction;

    string L1toString()
    {
        string res = "[";
        foreach (rec; L1)
        {
            if (rec.choice >= 0)
                res ~= rec.symb.repr ~ " " ~ rec.choice.to!string ~ "; ";
            else
                res ~= rec.symb.repr ~ "; ";
        }
        return res ~ "]";
    }

    string L2toString()
    {
        string res = "[";
        foreach (symb; L2.retro)
        {
            res ~= symb.repr ~ "; ";
        }
        return res ~ "]";
    }

    // algorithm building blocks

    // expand nonterminal to it's alt production
    void expandTree(int alt)
    {
        Symbol* nt = L2.back;
        assert(!nt.term);
        L2.popBack;
        auto prod = alts[nt].alternatives[alt];
        foreach (s; prod.output.retro)
            L2 ~= s;
        L1 ~= L1Record(nt, alt);
    }

    void successfulComp(Symbol* term)
    {
        if (!term.eps)
            caret++;
        L1 ~= L1Record(term);
        assert(term == L2.back);
        L2.popBack();
    }

    void terminationOk()
    {
        assert(L2.empty);
        state = AlgState.finish;
    }

    void failedComp()
    {
        state = AlgState.rlback;
    }

    void rollback()
    {
        assert(state == AlgState.rlback);
        while (true)
        {
            auto rec = L1.back;
            if (rec.choice == -1)
            {
                // it's a terminal
                if (!rec.symb.eps)
                    caret--;
                assert(caret >= 0);
                L1.popBack();
                L2 ~= rec.symb;
                rec = L1.back;
            }
            else
                break;
        }
    }

    void anotherAlternative()
    {
        assert(state == AlgState.rlback);
        auto rec = L1.back;
        assert(rec.choice >= 0);    // only for nonterminals
        L1.popBack();
        auto prev_prod = alts[rec.symb].alternatives[rec.choice];
        L2 = L2[0 .. $-prev_prod.output.length];    // remove old expansion
        L2 ~= rec.symb;
        rec.choice++;
        if (rec.choice >= alts[rec.symb].alternatives.length)
        {
            // we have exhausted all our alternatives
            assert(L2.length > 0);
            if (L2.length == 1)
                throw new Exception("rolling back from axiom, parsing error");
        }
        else
        {
            // we can pick next alternative
            state = AlgState.normal;
            expandTree(rec.choice); // rec.choice is already incremented
        }
    }

    while (state != AlgState.finish)
    {
        writeln("Current configuration: ", state, " ", caret, " ", L1toString(),
            "  ", L2toString());

        if (state == AlgState.normal)
        {
            if (L2.empty)
            {
                terminationOk();
                break;
            }
            auto symb = L2.back;
            if (!symb.term)
            {
                // it's a non-terminal
                expandTree(0);  // start from it's first expansion
            }
            else
            {
                // it's a terminal
                if (caret == exp.length && L2.length > 0 && !L2.back.eps)
                    failedComp();
                else if (symb.eps || exp[caret] == symb.repr)
                    successfulComp(symb);
                else
                    failedComp();
            }
        }
        else if (state == AlgState.rlback)
        {
            if (L1.empty)
                throw new Exception("rolling back with empty L1, parse failed");
            rollback();
            anotherAlternative();   // let's try another alternative
        }
    }

    writeln("Result configuration:  ", state, " ", caret, " ", L1toString(),
        "  ", L2toString());
}
