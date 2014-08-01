module evx.ordering;

private {/*import evx}*/
	import evx.functional: sequence;
}

pure nothrow:

/* the set¹ of natural numbers 
	1. actually a subset of cardinality 2⁶⁴
*/
immutable ℕ = 0.sequence!((n,i) => n + i);

/* a < b 
*/ 
bool less_than (T)(auto ref in T a, auto ref in T b)
	{/*...}*/
		return a < b;
	}

/* a == b && b == c && ...
*/
bool all_equal (Args...)(Args args)
	if (Args.length > 1)
	{/*...}*/
		foreach (i,_; args[0..$-1])
			if (args[i] != args[i+1])
				return false;
		return true;
	}

/* ¬(a < b || b < a) ⇒ a == b 
*/
bool antisymmetrically_equivalent (alias compare, T, U)(auto ref in T a, auto ref in U b)
	if (__traits(compiles, compare (a, b)))
	{/*...}*/
		return not (compare (a,b) || compare (b,a));
	}
bool antisymmetrically_equivalent (T,U)(auto ref in T a, auto ref in U b)
	if (__traits(compiles, a < b))
	{/*...}*/
		return not (a < b || b < a);
	}