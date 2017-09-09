import std.algorithm;
import std.stdio;
import std.string;

import recurs;


int main(string[] args)
{
    while (true)
    {
        writeln("Enter the string to parse:");
        string[] input = readln().strip.split;
        writeln("parsing input '", input, "'");
        try
        {
            string d = parseExpressionRecursive(input);
            writeln("string PARSED by parser");
            writeln("derivation: ", d);
        }
        catch (Exception e)
        {
            writeln("string REJECTED by parser");
            writeln("Error: ", e.msg);
        }
    }
}
