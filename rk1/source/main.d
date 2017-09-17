import std.algorithm;
import std.array;
import std.stdio;
import std.string;

import lexer.fa;
import lexer.utils;


void main()
{
    TestBlock[] blocks = readTestsFromFile("tests.txt");
    foreach (block; blocks)
    {
        writeln(block.name);
        foreach (test; block.tests)
        {
            writeln(test);
            simulateSm(block.sm, test);
        }
    }
}

void simulateSm(FiniteAutomata* sm, string input)
{
    FAState* cur_state = sm.initial_state;
    foreach (c; input)
    {
        write(cur_state.id);
        cur_state = cur_state.move(c);
        assert(cur_state, "Fail to move at " ~ c);
    }
    write(cur_state.id);
    writeln();
}

struct TestBlock
{
    string name;
    FiniteAutomata* sm;
    string[] tests;
}

TestBlock[] readTestsFromFile(string filename)
{
    auto f = File(filename, "r");
    scope(exit) f.close();

    TestBlock[] res;
    while (!f.eof)
    {
        TestBlock block;
        block.name = f.readln.strip;
        writeln(block.name);
        FAState*[string] states;

        FAState* ensure_state(string id)
        {
            if (!(id in states))
                states[id] = new FAState(id, id == "*");
            return states[id];
        }

        string line = f.readln.strip;
        while (line != ".")
        {
            writeln(line);
            auto trans = line.split;
            assert(trans.length == 3);
            string state_name = trans[0];
            string ifzero = trans[1];
            string ifone = trans[2];
            FAState* source = ensure_state(state_name);
            FAState* if0 = ensure_state(ifzero);
            FAState* if1 = ensure_state(ifone);
            FAState.createTransition(source, if0, false, '0');
            FAState.createTransition(source, if1, false, '1');
            line = f.readln.strip;
        }

        FiniteAutomata* sm = new FiniteAutomata();
        foreach (state; states.byValue)
        {
            sm.states ~= state;
            if (!sm.initial_state && state.id == "$")
                sm.initial_state = state;
            else if (!sm.fin_state && state.id == "*")
                sm.fin_state = state;
        }
        block.sm = sm;

        line = f.readln.strip;
        while (line != ".")
        {
            writeln(line);
            block.tests ~= line;
            line = f.readln.strip;
        }

        res ~= block;
    }

    return res;
}
