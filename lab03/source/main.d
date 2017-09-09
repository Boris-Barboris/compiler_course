import std.algorithm;
import std.stdio;
import std.string;

import parser.topdown;
import grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");
    writeln("removing recursions and compressing it...");
    grammar.eliminateLeftRecursions();
    grammar = eliminateUseless(grammar);
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
