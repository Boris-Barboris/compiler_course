import std.algorithm;
import std.stdio;
import std.string;

import parser.topdown;
import grammar;


int main(string[] args)
{
    auto grammar = readFromFile("input.gram");
    while (true)
    {
        writeln("Enter the string to parse:");
        string input = readln().strip;
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
