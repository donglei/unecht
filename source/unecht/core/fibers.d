﻿module unecht.core.fibers;

public import core.thread:Fiber;
import core.thread:Thread;
import std.datetime:Duration;

alias UEFiberFunc = void function();
alias UEFiberDelegate = void delegate();

/// add child Fiber member to enable yield on child fibers (=wait for child fiber to finish)
final class UEFiber : Fiber
{
    private Fiber child;

    //TODO: make nothrow once we loose the dmd<2067 compat
    public this( void delegate() fn )
    {
        super(fn);

        UEFiber parent = cast(UEFiber)Fiber.getThis();
        if(parent)
        {
            assert(parent.child is null);
            parent.child = this;
        }
    }
}

/++
 + 
 + example:
 + UEFibers.yield(waitFiber(2.seconds));
 +/
UEFiberDelegate waitFiber(Duration d)
{
    import std.datetime;

    return {
        auto targetTime = Clock.currTime + d;
        while(Clock.currTime < targetTime)
            Fiber.yield;
    };
}

///
struct UEFibers
{
    private static UEFiber[] fibers; 
   
    ///
    public static void startFiber(UEFiberDelegate func)
    {
        UEFiber newFiber = findFreeFiber();

        if(newFiber)
        {
            newFiber.reset(func);
        }
        else
        {
            newFiber = new UEFiber(func);
            fibers ~= newFiber;
        }

        newFiber.call();
    }

    //TODO: use free list instead of linear search
    private static UEFiber findFreeFiber()
    {
        foreach(f; fibers)
        {
            if(f.state == Fiber.State.TERM)
                return f;
        }

        return null;
    }

    ///
    public static yield(UEFiberDelegate func)
    {
        assert(Fiber.getThis());

        startFiber(func);

        Fiber.yield();
    }

    ///
    public static void runFibers()
    {
        foreach(f; fibers)
        {
            if(f.state != Fiber.State.TERM)
            {
                if(!f.child)
                {
                    f.call();
                }
                else
                {
                    if(f.child.state == Fiber.State.TERM)
                    {
                        f.child = null;
                        f.call();
                    }
                }
            }
        }
    }
}

// basic testing
unittest
{
    int i=0;

    UEFibers.fibers.length=0;

    UEFibers.startFiber(
        {
            i++;
            Fiber.yield();
            i++;
        });

    assert(UEFibers.fibers.length == 1);

    assert(i==1);

    UEFibers.runFibers();

    assert(i==2);
}

// test yield on other fibers
unittest
{
    string log;

    UEFibers.fibers.length=0;

    auto f1 = {
        log ~= 'b';
        Fiber.yield();
        log ~= 'c';
    };

    UEFibers.startFiber(
        {
            log ~= 'a';
            UEFibers.yield(f1);
            log ~= 'd';
        });

    assert(UEFibers.fibers.length == 2);
    assert(log=="ab", log);
    
    UEFibers.runFibers();
    
    assert(log=="abc");

    UEFibers.runFibers();

    assert(log=="abcd");

    UEFibers.startFiber(
        {
            log ~= 'e';
        });

    assert(log=="abcde");

    assert(UEFibers.fibers.length == 2);
}


// test reusing fibers
unittest
{
    int i;
    
    UEFibers.fibers.length=0;
    
    auto f1 = {
        Fiber.yield();
        i++;
    };

    foreach(j; 0..5)
        UEFibers.startFiber(f1);
    
    assert(UEFibers.fibers.length == 5);
    assert(i == 0);
    
    UEFibers.runFibers();
    
    assert(i == 5);

    foreach(j; 0..5)
        UEFibers.startFiber(f1);

    assert(UEFibers.fibers.length == 5);
    assert(i == 5);
    
    UEFibers.runFibers();
    
    assert(i == 10);

    assert(UEFibers.fibers.length == 5);
}