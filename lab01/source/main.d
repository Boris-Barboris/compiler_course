import std.stdio;

import lab01.fa;
import lab01.thompson;
import lab01.powerset;


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
    writeln("NFA constructed and written to nfs.dot");
    return 0;
}
