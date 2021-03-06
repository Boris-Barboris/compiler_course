module lexer.utils;

import std.algorithm;
import std.functional;
import std.range;


ElType[] remove_one(ElType)(ElType[] r, ElType el)
{
    for (size_t i = 0; i < r.length; i++)
        if (r[i] == el)
        {
            for (size_t j = i; j < r.length - 1; j++)
                r[j] = r[j + 1];
            return r[0 .. $-1];
        }
    return r;
}

auto flatten(RoR)(RoR ror)
    if (isInputRange!RoR)
{
    struct FlatChainResult
    {
        alias SubRT = typeof(ror.front());

        RoR ror;
        SubRT r;
        bool m_empty = false;

        this(RoR ror, SubRT r, bool m_empty)
        {
            this.ror = ror;
            this.r = r;
            this.m_empty = m_empty;
        }

        this(RoR ror)
        {
            this.ror = ror;
            while (!ror.empty && ror.front.empty)
                ror.popFront();
            if (!ror.empty)
            {
                r = ror.front;
                m_empty = false;
            }
            else
                m_empty = true;
        }

        auto front()
        {
            assert(!m_empty);
            return r.front();
        }

        void popFront()
        {
            assert(!m_empty);
            if (!r.empty)
                r.popFront();
            if (r.empty)
            {
                ror.popFront();
                while (!ror.empty && ror.front.empty)
                    ror.popFront();
                if (ror.empty)
                    m_empty = true;
                else
                    r = ror.front();
            }
        }

        bool empty()
        {
            return m_empty;
        }

        typeof(this) save()
        {
            return FlatChainResult(ror, r, m_empty);
        }
    }
    return FlatChainResult(ror);
}


unittest
{
    int[] a = [1, 2, 3];
    int[] b = [4, 5];
    auto res = flatten([a, b]);
    assert(equal(res, [1, 2, 3, 4, 5]));
}


import std.digest.murmurhash;

// get hash of the range of elements, usefull to compare ordered arrays of pointers
int sethash(SetElTR)(SetElTR setrange)
{
    MurmurHash3!32 hasher;
    foreach (el; setrange)
    {
        static assert (el.sizeof == size_t.sizeof);
        hasher.put(*(cast(ubyte[size_t.sizeof]*) &el));
    }
    ubyte[4] fin = hasher.finish();
    return *(cast(int*) &fin);
}


struct HashSet(T, alias h = "a")
{
    alias fun = unaryFun!(h);
    alias HashKey = typeof(fun(T.init));
    pragma(msg, HashKey);
    private T[HashKey] map;

    this(R)(R range)
        if (isInputRange!R)
    {
        foreach (el; range)
            insert(el);
    }

    bool insert(T v)
    {
        auto key = fun(v);
        if (!(key in map))
        {
            map[key] = v;
            return true;
        }
        return false;
    }

    int unionn(R)(R r)
        if (isForwardRange!R)
    {
        int cter = 0;
        foreach (v; r)
            if (insert(v))
                cter++;
        return cter;
    }

    bool remove(const T v)
    {
        auto key = fun(v);
        return map.remove(v);
    }

    const bool contains(const T v)
    {
        auto key = fun(v);
        return (key in map) != null;
    }

    const bool contains(R)(R r)
        if (isForwardRange!R)
    {
        foreach (v; r)
            if (!contains(v))
                return false;
        return true;
    }

    auto opSlice()
    {
        return map.byValue;
    }

    const bool opBinaryRight(string op)(T v)
        if (op == "in")
    {
        return this.contains(v);
    }

    auto byValue()
    {
        return this[];
    }

    const auto length()
    {
        return map.length;
    }

    const bool opEquals(const HashSet rhs)
    {
        return (rhs.contains(this.map.byValue) &&
            this.contains(rhs.map.byValue));
    }
}
