module lab01.powerset;

import std.algorithm;
import std.array: array;
import std.conv: to;
import std.stdio;
import std.string;
import std.range;

public import lab01.fa;
public import lab01.utils;


// Constructs DFA from NFA, aka subset construction, aka Rabin–Scott construction
FiniteAutomata* powersetConstruction(FiniteAutomata* nfa)
{
    return null;
}


// superstate wich is actually a subset of all states of NFA
private struct SuperState
{
    FAState*[] states;
}

struct StateCtx
{
    FAState* ptr;
    bool marked;
}

// find fixed point of the state equation
private SuperState* eclosure(SuperState* state)
{
    assert(state);
    StateCtx[] worklist = array(state.states.map!(a => StateCtx(a, false)));
    int marked = 0;
    while (true)
    {
        worklist.sort!("a.ptr < b.ptr");    // memory order
        StateCtx[] ereach = array(findEpsReachableStates(worklist.filter!(a => !a.marked)));
        // mark old states
        marked = worklist.length;
        foreach (ctx; worklist)
            ctx.marked = true;
        ereach.sort!("a.ptr < b.ptr");
        // union of worklist and epsilon-reachable
        worklist = array(
            multiwayMerge!("a.ptr < b.ptr")([worklist, ereach]).uniq!("a.ptr == b.ptr"));
        // if no new states were introduced in our superset
        if (worklist.length == marked)
            return new SuperState(array(worklist.map!(a => a.ptr)));
    }
}

auto findEpsReachableStates(StateCtxR)(StateCtxR source_states)
{
    static assert(isInputRange!(Unqual!StateCtxR));
    auto r1 = source_states.map!(a => a.ptr.out_transitions);
    auto r2 = r1.flatten;
    auto r3 = r2.filter!(a => a.epsilon);
    auto r4 = r3.map!(a => StateCtx(a.dest, false));
    return r4;
    pragma(msg, typeof(r4.front()));
}

unittest
{
    FAState* a = new FAState("a", false);
    FAState* b = new FAState("b", false);
    FAState* c = new FAState("c", false);
    FAState.createTransition(a, b, true);
    FAState.createTransition(a, c, true);
    FAState.createTransition(b, c, true);
    StateCtx[] ctxlist = [StateCtx(a)];
    assert(
        equal(
            [b, c],
            findEpsReachableStates(
                ctxlist).map!(a => a.ptr)
            ));
    auto c1 = eclosure(new SuperState([a]));
    assert(
        equal(
            [a, b, c],
            c1.states
        ));
}
