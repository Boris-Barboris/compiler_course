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
    struct SuperStateWrp
    {
        SuperState val;
        FAState* resultState;
        bool marked;

        this(SuperState ss)
        {
            writeln("merging ", ss.states.length, " states");
            bool fin = ss.states.any!(a => a.fin);
            string merged_id = ss.states.map!(a => a.id).join('+');
            writeln("Created merged state ", merged_id);
            resultState = new FAState(merged_id, fin);
            val = ss;
        }
    }

    // hash for all our superstates
    SuperStateWrp[int] superstates;
    // starting DFA state as epsilon-closure of NFA's starting state
    auto start_state = SuperStateWrp(
        SuperState(eclosure([nfa.initial_state])));
    writeln("Created start state ", *start_state.resultState);
    assert(start_state.val.states);
    // add it to our hash
    superstates[sethash(start_state.val.states)] = start_state;
    // now we start the main loop
    int ss_added = 1;
    while (ss_added > 0)
    {
        ss_added = 0;
        // for every unmarked superstate
        foreach (ref ss; superstates.byValue.filter!(a => !a.marked))
        {
            writeln("Processing superstate ", ss.resultState.id);
            // find array of symbols that lead out of this superstate
            Transition*[] transitions = ss.val.states.map!(a => a.out_transitions).
                flatten.filter!(a => !a.epsilon).array;
            writeln("Found ", transitions.length, " non-epsilon transitions");
            byte[] symbols = transitions.map!(a => cast(byte) a.symbol).array.sort.uniq.array;
            writeln("Symbols: ", symbols.map!(a => cast(char) a));
            foreach (symbol; symbols)
            {
                // for each symbol we find set of states that is reachable from
                // current superstate
                FAState*[] reachable = transitions.filter!(a => a.symbol == cast(char)symbol).
                    map!(a => a.dest).array;
                // and find it's epsilon cosure
                FAState*[] ereachable = eclosure(reachable).sort.uniq.array;
                writeln("Eclosure of reachable by symbol ", cast(char)symbol, ": ",
                    ereachable.map!(a => a.id));
                // ereachable is already sorted in memory order, so let's hash it
                int h = sethash(ereachable);
                SuperStateWrp* old = h in superstates;
                if (old == null)
                {
                    // new superstate, register it
                    superstates[h] = SuperStateWrp(SuperState(ereachable));
                    ss_added++;
                    old = h in superstates;
                    assert(old);
                }
                // now we register new transition
                writeln("Adding new transition");
                FAState.createTransition(
                    ss.resultState, old.resultState, false, cast(char)symbol);
            }
            ss.marked = true;   // mark it processed
        }
    }

    // now let's output our automata
    FiniteAutomata* res = new FiniteAutomata();
    foreach (ss; superstates.byValue)
        res.addState(ss.resultState, false);
    res.initial_state = start_state.resultState;

    return res;
}

// superstate wich is actually a subset of all states of NFA
private struct SuperState
{
    FAState*[] states;
}

private SetEl[] sloveSetEquation(alias func, SetEl)(SetEl[] startPoint)
{
    struct ElWrap
    {
        SetEl ptr;
        bool marked;
    }

    ElWrap[] worklist = array(startPoint.map!(a => ElWrap(a, false)));
    int marked = 0;
    while (true)
    {
        worklist.sort!("a.ptr < b.ptr");    // memory order
        ElWrap[] ereach = array(
            func(worklist.filter!(a => !a.marked).map!(a => a.ptr)).
                map!(a => ElWrap(a, false)));
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
            return array(worklist.map!(a => a.ptr));
    }
}

alias eclosure = sloveSetEquation!(findEpsReachableStates, FAState*);

auto findEpsReachableStates(FAStateR)(FAStateR source_states)
{
    /*auto r1 = source_states.map!(a => a.ptr.out_transitions);
    auto r2 = r1.flatten;
    auto r3 = r2.filter!(a => a.epsilon);
    auto r4 = r3.map!(a => StateCtx(a.dest, false));
    return r4;*/
    return source_states.map!(a => a.out_transitions).flatten.
        filter!(a => a.epsilon).map!(a => a.dest);
}

auto moveTransition(FAStateR)(FAStateR source_states)
{

}

unittest
{
    FAState* a = new FAState("a", false);
    FAState* b = new FAState("b", false);
    FAState* c = new FAState("c", false);
    FAState.createTransition(a, b, true);
    FAState.createTransition(a, c, true);
    FAState.createTransition(b, c, true);
    auto c1 = eclosure([a]);
    assert(
        equal(
            [a, b, c],
            c1
        ));
}
