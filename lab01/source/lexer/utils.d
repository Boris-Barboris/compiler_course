module lab01.utils;


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
