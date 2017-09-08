import std.stdio;

import lab01.fa;
import lab01.thompson;
import lab01.powerset;
import lab01.minimization;


int main(string[] args)
{
    writeln("Processiing args: ", args);
    if (args.length < 2)
    {
        writeln("Pass regexp as parameter please!");
        return 1;
    }
    string regexp = args[1];
    auto nfa = thompsonConstruction(regexp);
    writeDotFile(nfa, "nfa.dot");
    writeln("NFA constructed and written to nfa.dot");
    writeln("Running powerset construction...");
    auto dfa = powersetConstruction(nfa);
    writeDotFile(dfa, "dfa.dot");
    writeln("DFA constructed and written to dfa.dot");
    auto dfa_min = minimizeDfa(dfa);
    writeDotFile(dfa_min, "dfa_min.dot");
    writeln("DFA minimized and written to dfa_min.dot");
    while (true)
    {
        writeln("Enter the string to test:");
        string input = readln();
        writeln("modeling input '", input, "'");
        try
        {
            bool accepted = dfa_min.verifyAsDeterministic(input[0..$-1]);
            if (accepted)
                writeln("string ACCEPTED by DFA");
            else
                writeln("string REJECTED by DFA");
        }
        catch (Exception e)
        {
            writeln("Error: ", e.msg);
        }
    }
}
