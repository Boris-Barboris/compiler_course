import std.stdio;

import lab02.grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");
    grammar.eliminateLeftRecursions();
    writeln("recursions eliminated");
    writeln("\nResulting grammar:");
    grammar.printGrammar();
    return 0;
}
