module lab01.fa;

import std.algorithm;
import std.stdio;
import std.range;

import lab01.utils;


struct FAState
{
    int id;         // numerical id
    bool fin;       // it this state final
    Transition*[] out_transitions;
    Transition*[] in_transitions;

    static Transition* createTransition(FAState* source, FAState* dest,
        bool epsilon, char symbol = cast(char)0)
    {
        auto t = new Transition(source, dest, epsilon, symbol);
        source.out_transitions ~= t;
        dest.in_transitions ~= t;
        return t;
    }

    // selects first matching transition
    FAState* move(char c)
    {
        if (fin)
            return null;
        foreach (t; out_transitions)
            if (t.symbol == c)
                return t.dest;
        return null;
    }
}

struct Transition
{
    FAState *source;
    FAState *dest;
    bool epsilon;   // if true, this transition does not require reding symbol
    char symbol;    // symbol to transit on

    static void rebindDest(Transition* t, FAState* new_dest)
    {
        t.dest.in_transitions = t.dest.in_transitions.remove_one(t);
        t.dest = new_dest;
        new_dest.in_transitions ~= t;
    }
}

// global id counter
int id_counter = 0;

struct FiniteAutomata
{
    FAState*[] states;
    FAState* initial_state;
    FAState* fin_state;     // ok for regexp-derived automatons

    FAState* addState(bool initial = false, bool fin = false)
    {
        auto state = new FAState(id_counter++, fin);
        //writeln("Created state ", *state);
        if (initial)
        {
            assert(initial_state == null);
            initial_state = state;
        }
        if (fin)
        {
            assert(fin_state == null);
            fin_state = state;
        }
        states ~= state;
        return state;
    }

    bool verifyAsDeterministic(string input)
    {
        assert(initial_state);
        FAState* cur_state = initial_state;
        while (input.length > 0)
        {
            writeln("state ", cur_state.id, " character: ", input[0]);
            FAState* next = cur_state.move(input[0]);
            if (next == null)
            {
                writeln("Unable to move from state ", cur_state.id,
                    " with character '", input[0], "'");
                return false;
            }
            cur_state = next;
            input.popFront();
        }
        if (cur_state.fin)
        {
            writeln("finished in state ", cur_state.id);
            return true;
        }
        else
        {
            writeln("finished in state ", cur_state.id, ", wich is not final");
            return false;
        }
    }
}

import std.conv: to;
import std.format;


void writeDotFile(const(FiniteAutomata)* fa, string fname = "automata.dot")
{
    auto f = File(fname, "w");
    f.writeln("digraph {");
    f.writeln("\trankdir=LR;");

    string stateName(const(FAState)* state)
    {
        string state_name = state.id.to!string;
        if (fa.initial_state == state)
            state_name = "initial_" ~ state_name;
        if (state.fin)
            state_name = "final_" ~ state_name;
        return state_name;
    }

    foreach (state; fa.states)
    {
        string source_name = stateName(state);
        foreach (t; state.out_transitions)
        {
            string dest_name = stateName(t.dest);
            string label = "ε";
            if (!t.epsilon)
                label = [t.symbol];
            f.writeln('\t', source_name, " -> ", dest_name, " [label=", label, "];");
        }
    }
    f.writeln("}");
}
