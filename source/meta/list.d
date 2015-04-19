module autodata.meta.list;

private {/*import}*/
	import std.typetuple;
	import std.typecons;

	import autodata.meta.lambda;
	import autodata.meta.predicate;
}

////
alias Cons = TypeTuple;

alias Iota (size_t n) = staticIota!(0,n);
alias Iota (size_t l, size_t r) = staticIota!(l,r);

alias Repeat (size_t n, T...) = Cons!(T, Repeat!(n-1, T));
alias Repeat (size_t n : 0, T...) = Cons!();

////
template Map (alias F, T...)
	if (T.length == 0)
	{/*...}*/
		alias Map = Cons!();
	}
template Map (alias F, T...)
	if (T.length > 0)
	{/*...}*/
		alias Map = Cons!(F!(Unpack!(T[0])), Map!(F, T[1..$]));
	}

alias Ordinal (T...) = Iota!(T.length);

alias Enumerate (T...) = Zip!(TList!(Ordinal!T), TList!T);

template Sort (alias compare, T...)
	{/*...}*/
		static if (T.length > 1)
			{/*...}*/
				alias Remaining = Cons!(T[0..$/2], T[$/2 +1..$]);
				enum is_before (U...) = compare!(U[0], T[$/2]);

				alias Sort = Cons!(
					Sort!(compare, Filter!(is_before, Remaining)),
					T[$/2],
					Sort!(compare, Filter!(Not!is_before, Remaining)),
				);
			}
		else alias Sort = T;
	}
	unittest {/*...}*/
		static assert (Sort!(λ!q{(T...) = T[0] < T[1]}, 5,4,2,7,4,3,1) == Cons!(1,2,3,4,4,5,7));
	}

////
template All (alias cond, T...)
	if (T.length == 0)
	{/*...}*/
		enum All = true;
	}
template All (alias cond, T...)
	if (T.length > 0)
	{/*...}*/
		enum All = cond!(Unpack!(T[0])) && All!(cond, T[1..$]);
	}
template Any (alias cond, T...)
	if (T.length == 0)
	{/*...}*/
		enum Any = false;
	}
template Any (alias cond, T...)
	if (T.length > 0)
	{/*...}*/
		enum Any = cond!(Unpack!(T[0])) || Any!(cond, T[1..$]);
	}

template Filter (alias cond, T...)
	if (T.length == 0)
	{/*...}*/
		alias Filter = Cons!();
	}
template Filter (alias cond, T...)
	if (T.length > 0)
	{/*...}*/
		static if (cond!(Unpack!(T[0])))
			alias Filter = Cons!(T[0], Filter!(cond, T[1..$]));
		else alias Filter = Filter!(cond, T[1..$]);
	}

alias NoDuplicates = std.typetuple.NoDuplicates;

template Reduce (alias f, T...)
	if (T.length > 1)
	{/*...}*/
		static if (T.length == 2)
			alias Reduce = f!T;

		else alias Reduce = f!(T[0], Reduce!(f, T[1..$]));
	}

template Scan (alias f, T...)
	{/*...}*/
		template Sweep (size_t i)
			{/*...}*/
				static if (i == 0)
					alias Sweep = Cons!(T[i]);

				else alias Sweep = Reduce!(f, T[0..i+1]);
			}

		alias Scan = Map!(Sweep, Ordinal!T);
	}
	unittest {/*...}*/
		static assert (Scan!(Sum, 0,1,2,3,4,5) == Cons!(0,1,3,6,10,15));
	}

alias Sum (T...) = Reduce!(λ!q{(long a, long b) = a + b}, T);
	unittest {/*...}*/
		static assert (Sum!(0,1,2,3,4,5) == 15);
	}

////
alias IndexOf = staticIndexOf;

enum Contains (T...) = IndexOf!(T[0], T[1..$]) > -1;

////
template Zip (TLists...)
	{/*...}*/
		enum n = TLists.length;
		enum length = TLists[0].length;

		enum CheckLength (uint i) = TLists[i].length == TLists[0].length;

		static assert (All!(Map!(CheckLength, Iota!n)));

		template ToTList (uint i)
			{/*...}*/
				alias ExtractAt (uint j) = Cons!(TLists[j].Unpack[i]);

				alias ToTList = TList!(Map!(ExtractAt, Iota!n));
			}

		alias Zip = Map!(ToTList, Iota!length);
	}

struct TList (T...)
	{/*...}*/
		alias Unpack = T;
		alias Unpack this;
		enum length = T.length;
	}

template Unpack (T...)
	//if (T.length == 1) BUG this seems to turn Unpack from an alias into its own symbol, SUPER WEIRD, and then some Match!es get false negatives
	{/*...}*/
		static if (__traits(compiles, T[0].Unpack))
			alias Unpack = Cons!(T[0].Unpack);
		else alias Unpack = T;
	}

template InterleaveNLists (uint n, T...)
	if (T.length % n == 0)
	{/*...}*/
		template Group (uint i)
			{/*...}*/
				alias Item (uint j) = Cons!(T[($/n)*j + i]);

				alias Group = Map!(Item, Iota!n);
			}

		alias InterleaveNLists = Map!(Group, Iota!(T.length/n));
	}
	unittest {/*...}*/
		static assert (InterleaveNLists!(2, 0,1,2,3,4,5) == Cons!(0,3,1,4,2,5));
		static assert (InterleaveNLists!(3, 0,1,2,3,4,5) == Cons!(0,2,4,1,3,5));
	}

alias DeinterleaveNLists (uint n, T...) = InterleaveNLists!(T.length/n, T);
	unittest {/*...}*/
		static assert (DeinterleaveNLists!(2, 0,3,1,4,2,5) == Cons!(0,1,2,3,4,5));
		static assert (DeinterleaveNLists!(3, 0,2,4,1,3,5) == Cons!(0,1,2,3,4,5));
	}

alias Interleave (T...) = InterleaveNLists!(2,T);
alias Deinterleave (T...) = DeinterleaveNLists!(2,T);

template Extract (string member, T...)
	{/*...}*/
		static if (T.length == 0)
			alias Extract = Cons!();
		else mixin(q{
			alias Extract = Cons!(T[0].} ~member~ q{, Extract!(member, T[1..$]));
		});
	}
