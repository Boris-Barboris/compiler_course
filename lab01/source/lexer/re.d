module lab01.re;

import std.algorithm;
import std.range;
import std.stdio;

import lab01.utils;


enum ReOp: byte
{
    concat,     // ab
    or,         // a|b
    star,       // a*
    parenthesis // (
}

union RTreeContent
{
    ReOp op;
    char glyph;
}

struct RegexTreeEl
{
    bool isOp;
    RTreeContent content;
    RegexTreeEl* parent;
    RegexTreeEl*[] children;
}

private
{
    static RegexTreeEl* addChild(RegexTreeEl* par, RegexTreeEl* child)
    {
        par.children ~= child;
        child.parent = par;
        return child;
    }

    static void replaceRightestChild(RegexTreeEl* par, RegexTreeEl* new_child)
    {
        new_child.parent = par;
        if (par)
            par.children[$-1] = new_child;
    }

    static void replaceChild(RegexTreeEl* par, RegexTreeEl* old_child, RegexTreeEl* new_child)
    {
        new_child.parent = par;
        if (par)
        {
            auto child_pos = find(par.children, old_child);
            child_pos[0] = new_child;
        }
    }

    // removes element from the tree, binding his sole child to it's parent
    static void collapseChild(RegexTreeEl* el)
    {
        auto p = el.parent;
        assert(p);
        auto r = find(p.children, el);
        assert(r);
        assert(el.children.length <= 1);
        if (el.children)
            r[0] = el.children[0];
        else
            p.children = p.children.remove_one(el);
    }

    static RegexTreeEl* traverseToRoot(RegexTreeEl* el)
    {
        assert(el);
        while (el.parent)
            el = el.parent;
        return el;
    }

    static RegexTreeEl* traverseToParenthesis(RegexTreeEl* el)
    {
        assert(el);
        do
        {
            if (el.isOp && el.content.op == ReOp.parenthesis)
                return el;
            el = el.parent;
        } while (el);
        return null;
    }
}

// returns index of closing parenthesis
int match_parenthesis(string s)
{
    assert(s[0] == '(');
    int depth = 1;
    foreach (i, c; s)
    {
        switch (c)
        {
            case '(':
                depth++;
                break;
            case ')':
                if (--depth == 0)
                    return i;
                break;
            default:
                break;
        }
    }
    writeln("unable to match parenthesis in string ", s);
    return -1;
}

// form regex tree from regex string
RegexTreeEl* parseRegex(string regex, bool function(char) alphabet_pred)
{
    if (regex.length == 0)
        return null;
    int pcounter = 0;
    RTreeContent content = { op : ReOp.concat };
    RegexTreeEl* root = new RegexTreeEl(true, content, null);
    auto res = rparseRegex(root, regex, alphabet_pred, pcounter);
    if (pcounter != 0)
        throw new Exception("unbalanced parenthesis");
    return res;
}

void printRegexTree(RegexTreeEl* root)
{
    rprintRegexTree(root, 0);
}

private void rprintRegexTree(bool inline = false)(RegexTreeEl* head, int depth)
{
    assert(head);
    static if (inline)
        string shift = "";
    else
        auto shift = repeat(' ', depth * 6);
    if (!head.isOp)
        writeln(shift, "=====", head.content.glyph);
    else
    {
        if (head.content.op == ReOp.concat)
            write(shift, "==conc");
        else if (head.content.op == ReOp.star)
            write(shift, "=====*");
        else if (head.content.op == ReOp.or)
            write(shift, "=====|");
        else
            assert(0);
        foreach (i, child; head.children)
        {
            if (i == 0)
                rprintRegexTree!true(child, depth + 1);
            else
                rprintRegexTree!false(child, depth + 1);
        }
    }
}


private RegexTreeEl* rparseRegex(RegexTreeEl* head, string tail,
    bool function(char) alphabet_pred, ref int pcounter)
{
    assert(head);
    if (tail.length == 0)
        return head.traverseToRoot();
    char c = tail[0];
    if (c == '(')
    {
        // create new parenthesis leaf
        RTreeContent content = { op : ReOp.parenthesis };
        auto pleaf = new RegexTreeEl(true, content);
        head.addChild(pleaf);
        pcounter++;
        // add concatenation child wich spans insides of parenthesis
        content.op = ReOp.concat;
        auto pt = new RegexTreeEl(true, content);
        pleaf.addChild(pt);
        // go deeper
        return rparseRegex(pt, tail[1..$], alphabet_pred, pcounter);
    }
    if (c == ')')
    {
        if (pcounter-- <= 0)
            throw new Exception("Unbalanced closing parenthesis at " ~ tail);
        // search the tree for opening parenthesis element
        auto opening = head.traverseToParenthesis();
        if (opening == null)
            throw new Exception("Unmatched closing parenthesis at " ~ tail);
        assert(opening.children.length <= 1);
        // we can now remove this element from the tree
        opening.collapseChild();
        return rparseRegex(opening.parent, tail[1..$], alphabet_pred, pcounter);
    }
    if (c == '*')
    {
        // star is always applied to the rightest child of the head
        if (head.children.length == 0)
            throw new Exception("Cannot apply * to empty regex at " ~ tail);
        auto sub = head.children[$-1];
        RTreeContent content = { op : ReOp.star };
        auto start = new RegexTreeEl(true, content);
        start.addChild(head.children[$-1]);
        head.replaceRightestChild(start);
        return rparseRegex(head, tail[1..$], alphabet_pred, pcounter);
    }
    if (c == '|')
    {
        // or is low priority binary operation
        if (head.children.length == 0)
            throw new Exception("Cannot apply | to empty regex at " ~ tail);
        RTreeContent content = { op : ReOp.or };
        auto orel = new RegexTreeEl(true, content);
        head.parent.replaceChild(head, orel);
        orel.addChild(head);
        // and add concatenation child on the right
        content.op = ReOp.concat;
        auto right_child = new RegexTreeEl(true, content);
        orel.addChild(right_child);
        // and descend into it
        return rparseRegex(right_child, tail[1..$], alphabet_pred, pcounter);
    }
    if (alphabet_pred(c))
    {
        // simple letter
        assert(head.isOp && head.content.op == ReOp.concat);
        RTreeContent content = { glyph : c };
        head.addChild(new RegexTreeEl(false, content));
        return rparseRegex(head, tail[1..$], alphabet_pred, pcounter);
    }
    throw new Exception("Symbol at " ~ tail ~ " not allowed");
}
