module lexer.utils;

import std.algorithm;
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
