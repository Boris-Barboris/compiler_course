import std.algorithm;
import std.stdio;

import grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");
    assert(grammar.eps);

    writeln("\nEliminating useless");
    grammar = eliminateUseless(grammar);
    assert(grammar.eps);
    writeln("\nGrammar after removed not needed symbols:");
    grammar.printGrammar();

    /*writeln("\nEliminating epsilon productions");
    grammar = eliminateEpsProductions(grammar);
    assert(grammar.eps);
    writeln("\nGrammar after removed epsilon productions:");
    grammar.printGrammar();*/

    writeln("\nEliminating left recursions");
    grammar.eliminateLeftRecursions();
    assert(grammar.eps);
    writeln("\nGrammar with left recursion eliminated:");
    grammar.printGrammar();

    writeln("\nEliminating epsilon productions");
    grammar = eliminateEpsProductions(grammar);
    assert(grammar.eps);
    writeln("\nGrammar after removed epsilon productions:");
    grammar.printGrammar();

    return 0;
}
