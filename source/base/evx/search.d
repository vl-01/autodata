module evx.search;

private {/*imports}*/
	private {/*std}*/
		import std.traits;
		import std.range;
	}
	private {/*evx}*/
		import evx.traits;
		import evx.ordinal;
	}
}

pure nothrow:

/* specify how elements are compared for equivalence
*/
enum Equivalence
	{/*...}*/
		/*
			use ==, if it is defined.
			otherwise, elements are tested for antisymmetric equivalence 
			i.e. ¬(a < b || b < a) ⇒ a == b
		*/  
		intrinsic, 
		/*
			ignore == and always test for antisymmetric equivalence.
		*/
		antisymmetric
	}

/* result of a binary search over a sorted, indexable range.
	if the element was found, BinarySearchResult holds a pointer to the element and the element's position.
	otherwise, it holds a null pointer and the position that the element would occupy if it were in the range.
*/
struct BinarySearchResult (T)
	{/*...}*/
		T* found;
		size_t position;
	}

/* perform a binary search which assumes the range is ordered by the < operator
*/
auto binary_search (R, T = ElementType!R)(R range, T element)
	{/*...}*/
		return range.binary_search!(less_than!T) (element);
	}

/* perform a custom policy-based binary search.
	by default, binary search compares elements with the < operator. 
	this can be overridden by supplying a comparison function as a template parameter. 
	the	range is assumed to be ordered according to the comparison function.
	
	equivalence checking is intrinsic by default, but can be changed via the Equivalence policy
*/
template binary_search (alias compare, Equivalence equivalence = Equivalence.intrinsic)
	if (is_comparison_function!compare)
	{/*...}*/
		auto binary_search (R, T = ElementType!R)(R range, T element)
			if (hasLength!R && is_indexable!R)
			in {/*...}*/
				debug try assert (range.isSorted!compare);
				catch (Exception) assert (0, `sort check failed`);
			}
			body {/*...}*/
				if (range.empty)
					return BinarySearchResult!T (null, 0);

				size_t min = 0;
				size_t max = range.length;

				static if (equivalence is Equivalence.intrinsic)
					bool equal_to (ref const T that)
						{/*...}*/
							 return element == that;
						}
				else static if (equivalence is Equivalence.antisymmetric)
					bool equal_to (ref const T that)
						{/*...}*/
							return element.antisymmetrically_equivalent!compare (that);
						}
				else static assert (0);

				debug auto counter = 0;

				while (min < max)
					{/*...}*/
						alias sorted = compare;

						auto mid = (max + min)/2;

						if (equal_to (range[mid]))
							return BinarySearchResult!T (&range[mid], mid);
						else if (sorted (element, range[mid]))
							max = mid;
						else if (sorted (range[mid], element))
							min = mid + 1;

						debug {/*...}*/
							import std.conv;

							try assert (++counter <= range.length,
								`error: search for` ~element.text~ `in` ~R.stringof~ `failed to terminate!`
							);
							catch (Exception ex) assert (0, 
								`error: search for` ~T.stringof~ `in` ~R.stringof~ `failed to terminate!`
							);
						}
					}

				if (min < range.length && equal_to (range[min]))
					return BinarySearchResult!T (&range[min], min);
				else return BinarySearchResult!T (null, min);
			}
	}

unittest {/*...}*/
	auto x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

	auto result = x.binary_search (1);
	assert (result.position == 0);
	assert (result.found == &x[0]);

	result = x.binary_search (8);
	assert (result.position == 7);
	assert (result.found == &x[7]);
}
unittest {/*...}*/
	import evx.meta: CompareBy;

	debug struct Test {int x; mixin CompareBy!x;}
	auto S = [Test(1), Test(2), Test(3), Test(4), Test(5), Test(6), Test(7), Test(8), Test(9), Test(10)];

	auto result = S.binary_search (Test(1));
	assert (result.position == 0);
	assert (result.found == &S[0]);

	result = S.binary_search (Test(5));
	assert (result.position == 4);
	assert (result.found == &S[4]);
}
