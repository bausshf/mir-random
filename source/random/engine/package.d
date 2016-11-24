/++
Uniform random engines.

Copyright: Ilya Yaroshenko 2016-.
License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Ilya Yaroshenko
+/
module random.engine;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

import std.traits;

import random.engine.mersenne_twister;

/// User Defined Attribute definition for uniform Random Engine.
enum RandomEngine;

/++
Test if T is a random engine.
+/
template isRandomEngine(T)
{
    private alias R = typeof(T.init());
    static if (hasUDA!(T, RandomEngine) && isUnsigned!R)
        enum isRandomEngine = is(typeof({
            enum max = T.max;
            static assert(is(typeof(T.max) == R));
            }));
    else enum isRandomEngine = false; 
}

/++
Test if T is a saturated random-bit generator.
A random number generator is saturated if `T.max == ReturnType!T.max`.
+/
template isSaturatedRandomEngine(T)
{
    static if (isRandomEngine!T)
        enum isSaturatedRandomEngine = T.max == ReturnType!T.max;
    else
        enum isSaturatedRandomEngine = false;
}

version(Darwin)
private
extern(C) nothrow @nogc
ulong mach_absolute_time();

/**
A "good" seed for initializing random number engines. Initializing
with $(D_PARAM unpredictableSeed) makes engines generate different
random number sequences every run.

Returns:
A single unsigned integer seed value, different on each successive call
*/
pragma(inline, true)
@property ulong unpredictableSeed() @trusted nothrow @nogc
{
    version(Windows)
    {
        ulong ticks = void;
        QueryPerformanceCounter(&ticks);
    }
    else
    version(Darwin)
    {
        ulong ticks = mach_absolute_time();
    }
    else
    version(Posix)
    {
        import core.sys.posix.time;
        timespec ts;
        if(clock_gettime(clockArg, &ts) != 0)
        {
            import core.internal.abort : abort;
            abort("Call to clock_gettime failed.");
        }
        ulong ticks = (cast(ulong) ts.tv_sec << 32) ^ ts.tv_nsec;
    }
    version(Posix)
    {
        import core.sys.posix.unistd;
        import core.sys.posix.pthread;
        auto pid = cast(uint) getpid;
        auto tid = cast(uint) pthread_self();
    }
    else
    version(Windows)
    {
        import core.sys.windows.windows;
        import core.sys.windows.winbase;
        auto pid = cast(uint) GetCurrentProcessId;
        auto tid = cast(uint) GetCurrentThreadId;
    }
    ulong k = ((cast(ulong)pid << 32) ^ tid) + ticks;
    k ^= k >> 33;
    k *= 0xff51afd7ed558ccd;
    k ^= k >> 33;
    k *= 0xc4ceb9fe1a85ec53;
    k ^= k >> 33;
    return k;
}

///
@safe unittest
{
    auto rnd = Random(cast(size_t)unpredictableSeed);
    auto n = rnd();
    static assert(is(typeof(n) == size_t));
}

/++
The "default", "favorite", "suggested" random number generator type on
the current platform. It is an alias for one of the
generators. You may want to use it if (1) you need to generate some
nice random numbers, and (2) you don't care for the minutiae of the
method being used.
+/
alias Random = Mt19937;

///
unittest
{
    import std.traits;
    static assert(isSaturatedRandomEngine!Random);
    static assert(is(ReturnType!Random == size_t));
}