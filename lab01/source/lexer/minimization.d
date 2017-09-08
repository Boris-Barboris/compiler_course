module lab01.minimization;

import std.algorithm;
import std.array: array;
import std.digest.murmurhash;
import std.container.rbtree;
import std.conv: to;
import std.stdio;
import std.string;
import std.typecons;
import std.range;

public import lab01.fa;
public import lab01.re;
public import lab01.utils;


// Myphill-Nerode theorem
FiniteAutomata* minimizeDfa(FiniteAutomata* dfa)
{
    // prepare states array
    FAState*[] states;
    int[FAState*] state_placing;
    states ~= dfa.initial_state;
    state_placing[dfa.initial_state] = 0;
    for (int i = 0; i < dfa.states.length; i++)
    {
        auto state = dfa.states[i];
        if (state != dfa.initial_state)
        {
            states ~= state;
            state_placing[state] = states.length - 1;
        }
    }
    int stc = states.length;
    // reachable array
    bool[] reachable = new bool[stc];
    reachable[] = false;
    //reachable[0] = reachable[1] = true;
    // TODO: check reachability

    // empirically estimate alphabet
    auto alphabet_t = new RedBlackTree!(byte)();
    foreach (s; states)
        foreach (t; s.out_transitions)
            alphabet_t.insert(cast(byte) t.symbol);
    byte[] alphabet = alphabet_t[].array.sort.array;
    writeln("actual dfa alphabet length: ", alphabet.length);

    // build table of marked
    bool[][] buildTable()
    {
        alias QT = Tuple!(int, int);
        QT[] queue;
        bool[][] marked;

        // vsc = virtual state count
        int vsc = stc + 1;  // we introduce special "dead" state to
                            // make DFA complete
        marked.length = vsc;
        for (int i = 0; i < vsc; i++)
            marked[i].length = vsc;
        for (int i = 1; i < vsc; i++)
            for (int j = 0; j < i; j++)
            {
                bool finality = false;
                if (i < stc)
                    finality = states[i].fin != states[j].fin;
                else
                    finality = states[j].fin;
                if (!marked[i][j] && finality)
                {
                    writeln("initially marking indexes ", i, " ", j);
                    //writeln("Marking state pair ", states[i-1].id, " ", states[j-1].id);
                    marked[i][j] = true;
                    queue ~= QT(i, j);
                }
            }

        writeln("queue length: ", queue.length);

        // we now need to create reverse transition in order to quickly
        // iterate over it.
        int[][byte][] sigma;
        sigma.length = vsc;
        foreach (i, s; states)
        {
            byte[] out_processed;
            foreach (t; s.out_transitions)
            {
                byte symb = cast(byte) t.symbol;
                out_processed ~= symb;
                int[]* arr_ptr = symb in sigma[state_placing[t.dest]];
                if (arr_ptr)
                {
                    // vector already exists
                    *arr_ptr ~= i;
                }
                else
                {
                    // we need to create it
                    sigma[state_placing[t.dest]][symb] = [i];
                }
            }
            out_processed.sort;
            byte[] diff = setDifference(alphabet, out_processed).array;
            // we need to add diffs as transitions to the dead state
            foreach (symb; diff)
            {
                int[]* arr_ptr = symb in sigma[$-1];
                if (arr_ptr)
                    *arr_ptr ~= i;
                else
                    sigma[$-1][symb] = [i];
            }
        }
        // now add self-transitions from the dead state into the dead state
        foreach (symb; alphabet)
            sigma[$-1][symb] ~= vsc-1;


        // now dynamic programming for distinguished states
        while (queue.length)
        {
            QT pair = queue[0];
            queue = queue[1..$];

            foreach (c; alphabet)
            {
                if (!(c in sigma[pair[0]]))
                    continue;
                if (!(c in sigma[pair[1]]))
                    continue;
                foreach (int r; sigma[pair[0]][c])
                {
                    foreach (int s; sigma[pair[1]][c])
                    {
                        int imax = max(r, s);
                        int imin = min(r, s);
                        //writeln(imax, ' ', imin);
                        //writeln(stc);
                        if (!marked[imax][imin])
                        {
                            writeln("queue marking ", r, " ", s,
                                " as distinguished by symbol ", cast(char) c);
                            marked[imax][imin] = true;
                            queue ~= QT(imax, imin);
                        }
                    }
                }
            }
        }

        return marked;
    }


    bool[][] marked = buildTable();
    writeln(marked);

    int[] component = new int[stc];
    component[] = -1;
    for (int i = 0; i < stc; i++)
        if (!marked[i][0])
            component[i] = 0;

    writeln("after initial state combination: ", component);

    int componentsCount = 0;
    for (int i = 0; i < stc; i++)
    {
        if (component[i] == -1)
        {
            componentsCount++;
            component[i] = componentsCount;
            for (int j = i + 1; j < stc; j++)
                if (!marked[j][i])
                    component[j] = componentsCount;
        }
    }

    writeln("resulting component distribution ", component);

    FiniteAutomata* res = new FiniteAutomata();

    struct SuperState
    {
        FAState*[] states;
        bool initial;
        bool fin;
    }

    // now we use equivalency classes to build result automata
    int class_count = maxElement(component) + 1;

    SuperState[] ss = new SuperState[class_count];

    // distribute states into superstates
    for (int j = 0; j < stc; j++)
    {
        int cls = component[j];
        ss[cls].states ~= states[j];
    }

    for (int i = 0; i < class_count; i++)
    {
        FAState*[] class_members = ss[i].states;
        bool initial = class_members.canFind(dfa.initial_state);
        bool fin = class_members.map!(a => a.fin).any();
        ss[i].initial = initial;
        ss[i].fin = fin;
        res.addNewState(initial, fin);
    }

    byte[] interlink(int s1i, int s2i)
    {
        byte[] res;
        foreach (state; ss[s1i].states)
        {
            foreach (t; state.out_transitions)
            {
                if (component[state_placing[t.dest]] == s2i)
                {
                    // this is what we need
                    res ~= cast(byte) t.symbol;
                }
            }
        }
        return res.sort.uniq.array;
    }

    // create state objects themself and
    // transitions between them and inside of them
    for (int i = 0; i < class_count; i++)
        for (int j = 0; j < class_count; j++)
        {
            byte[] tts = interlink(i, j);
            foreach (symbol; tts)
            {
                FAState.createTransition(res.states[i], res.states[j], false,
                    cast(char) symbol);
            }
        }

    //writeln(ss);

    return res;
}
