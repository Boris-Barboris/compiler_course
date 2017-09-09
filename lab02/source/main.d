import std.algorithm;
import std.stdio;

import grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");
    grammar.eliminateLeftRecursions();
    writeln("recursions eliminated");
    writeln("\nResulting grammar:");
    grammar.printGrammar();
    auto fixed = eliminateUseless(grammar);
    writeln("\nGrammar after removed not needed symbols:");
    fixed.printGrammar();
    return 0;
}
