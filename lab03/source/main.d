import std.algorithm;
import std.stdio;
import std.string;

import parser.topdown;
import grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");

    writeln("\nremoving left recursion");
    grammar.eliminateLeftRecursions();
    writeln("\nGrammar without left recursions:");
    grammar.printGrammar();

    writeln("\nremoving epsilon productions...");
    grammar = eliminateEpsProductions(grammar);
    writeln("\nGrammar without epsilon productions:");
    grammar.printGrammar();

    /*
    writeln("\nremoving useless symbols...");
    grammar = eliminateUseless(grammar);
    writeln("\nGrammar without useless:");
    grammar.printGrammar();*/

    writeln("\nResulting grammar:");
    grammar.printGrammar();

    while (true)
    {
        writeln("Enter the string to parse:");
        string[] input = readln().strip.split(" ");
        writeln("modeling input '", input, "'");
        try
        {
            parseExpression(grammar, input);
            writeln("string PARSED by grammar");
        }
        catch (Exception e)
        {
            writeln("string REJECTED by grammar");
            writeln("Error: ", e.msg);
        }
    }
}
