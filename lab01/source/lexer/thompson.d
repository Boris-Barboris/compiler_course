module lab01.thompson;

import std.algorithm;
import std.array: array;
import std.conv: to;
import std.stdio;
import std.string;
import std.range;

public import lab01.fa;
public import lab01.re;


bool default_alphabet(char c)
{
    if (c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' ||
        c >= '0' && c <= '9')
    {
        return true;
    }
    return false;
}

FiniteAutomata* thompsonConstruction(string regex,
    bool function(char) alphabet_pred = &default_alphabet)
{
    assert(regex.length);
    auto rtree = parseRegex(regex, alphabet_pred);
    printRegexTree(rtree);
    return recursThompson(rtree);
}


FiniteAutomata* recursThompson(RegexTreeEl* regHead)
{
    if (regHead == null)
        return emptyRegexp();
    if (!regHead.isOp)
        return trivialRegexp(regHead.content.glyph);
    else
    {
        switch (regHead.content.op)
        {
            case ReOp.parenthesis:
                assert(0, "All () symbols should be out of the tree");
            case ReOp.concat:
                return reduce!concatRegexp(map!recursThompson(regHead.children));
            case ReOp.or:
                assert(regHead.children.length == 2);
                return orRegexp(recursThompson(regHead.children[0]),
                                recursThompson(regHead.children[1]));
            case ReOp.star:
                assert(regHead.children.length == 1);
                return kleeneStar(recursThompson(regHead.children[0]));
            default:
                assert(0);
        }
    }
}

private FiniteAutomata* emptyRegexp()
{
    FiniteAutomata* fa = new FiniteAutomata();
    auto start = fa.addNewState(true, false);
    auto finish = fa.addNewState(false, true);
    FAState.createTransition(start, finish, true);
    return fa;
}

import std.format;

private FiniteAutomata* trivialRegexp(char c)
{
    FiniteAutomata* fa = new FiniteAutomata();
    auto start = fa.addNewState(true, false);
    auto finish = fa.addNewState(false, true);
    auto t = FAState.createTransition(start, finish, false, c);
    //writeln("Transition for trivial regexp: %d %d %d %c".format(t.source.id, t.dest.id, t.epsilon, t.symbol));
    return fa;
}

FiniteAutomata* orRegexp(FiniteAutomata* left, FiniteAutomata* right)
{
    if (left == null || right == null)
        throw new Exception("cannot apply | to empty regexp");
    FiniteAutomata* fa = new FiniteAutomata();
    auto start = fa.addNewState(true, false);
    FAState.createTransition(start, left.initial_state, true);
    FAState.createTransition(start, right.initial_state, true);
    assert(left.fin_state);
    assert(right.fin_state);
    // we make right fin state shared
    foreach (Transition* t; left.fin_state.in_transitions)
    {
        assert(t.dest == left.fin_state);
        Transition.rebindDest(t, right.fin_state);
    }
    fa.states ~= array(filter!(a => !a.fin)(left.states));
    fa.states ~= right.states;
    fa.fin_state = right.fin_state;
    return fa;
}

FiniteAutomata* concatRegexp(FiniteAutomata* first, FiniteAutomata* second)
{
    if (first == null)
        return second;
    if (second == null)
        return first;
    FiniteAutomata* fa = new FiniteAutomata();
    assert(first.fin_state);
    assert(second.fin_state);
    // change first FA final state to second one's initial
    foreach (Transition* t; first.fin_state.in_transitions)
    {
        assert(t.dest == first.fin_state);
        Transition.rebindDest(t, second.initial_state);
    }
    fa.states = array(filter!(a => !a.fin)(first.states)) ~ second.states;
    fa.initial_state = first.initial_state;
    fa.fin_state = second.fin_state;
    //writeln("Concatinating: removed first fin_state ", first.fin_state.id);
    return fa;
}

private FiniteAutomata* kleeneStar(FiniteAutomata* sub)
{
    if (sub == null)
        throw new Exception("Can't apply * to empty regexp");
    FiniteAutomata* fa = new FiniteAutomata();
    assert(sub.fin_state);
    assert(sub.initial_state);
    auto start = fa.addNewState(true, false);
    auto finish = fa.addNewState(false, true);
    fa.states ~= sub.states;
    sub.fin_state.fin = false;
    FAState.createTransition(start, finish, true);
    FAState.createTransition(start, sub.initial_state, true);
    FAState.createTransition(sub.fin_state, finish, true);
    FAState.createTransition(sub.fin_state, sub.initial_state, true);
    return fa;
}
