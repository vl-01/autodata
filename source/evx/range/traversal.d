module evx.range.traversal;

private {/*imports}*/
	import std.range;
	import std.algorithm;
	import std.array;
	import std.conv;

	import evx.range.classification;
	import evx.math.sequence;
	import evx.math.logic;
}

/* buffer a range to an array 
*/
alias array = std.array.array;

/* check if a range contains a value 
*/
alias contains = std.algorithm.canFind;

/* check if any elements in a range meet a given criteria 
*/
alias any = std.algorithm.any;

/* construct a range from a repeated value 
*/
alias repeat = std.range.repeat;

/* chain a tuple of ranges into a single range 
*/
alias chain = std.range.chain;

/* join a range of ranges into a single range 
*/
struct Join (R)
	{/*...}*/
		public:
		@property {/*range}*/
			const length ()
				{/*...}*/
					import std.traits;
					auto s = cast(Unqual!R)ranges; // HACK to shed constness so that sum can operate
					return s.map!(r => r.length).sum + separator.length * max(0, ranges.length - 1);
				}

			auto ref front ()
				{/*...}*/
					if (at_separator)
						return separator[i];
					else return ranges[j][i];
				}
			void popFront ()
				{/*...}*/
					if (at_separator)
						{/*...}*/
							if (++i == separator.length)
								{/*...}*/
									i = 0;

									at_separator = false;
								}
						}
					else if (++i == ranges[j].length)
						{/*...}*/
							++j;
							i = 0;

							if (not (separator.empty || this.empty))
								at_separator = true;
						}
				}
			auto empty ()
				{/*...}*/
					return j >= ranges.length;
				}

			auto save ()
				{/*...}*/
					return this;
				}
			alias opIndex = save;
		}
		private:
		private {/*data}*/
			R ranges;
			ElementType!R separator;
			size_t i, j;
			bool at_separator;
		}
	}
auto join (R, S = ElementType!R)(R ranges, S separator = S.init)
	{/*...}*/
		return Join!R (ranges, separator.to!(ElementType!R));
	}
	unittest {/*join}*/
		int[2] x = [1,2];
		int[2] y = [3,4];
		int[2] z = [5,6];

		int[][] A = [x[], y[], z[]];

		assert (A.join.equal ([1,2,3,4,5,6]));
		assert (A.join ([0]).equal ([1, 2, 0, 3, 4, 0, 5, 6]));
	}

/* iterate a range in reverse 
*/
alias retro = std.range.retro;

/* traverse a range with elements rotated left by some number of positions 
*/
auto rotate_elements (R)(R range, int positions = 1)
	in {/*...}*/
		auto n = range.length;

		if (n > 0)
			assert ((positions + n) % n > 0);
	}
	body {/*...}*/
		auto n = range.length;

		if (n == 0)
			return typeof(range.cycle[0..0]).init;

		auto i = (positions + n) % n;
		
		return range.cycle[i..n+i];
	}

/* pair each element with its successor in the range, and the last element with the first 
*/
auto adjacent_pairs (R)(R range)
	{/*...}*/
		return evx.math.functional.zip (range, range.rotate_elements);
	}

/* generate a foreach index for a custom range 
	this exploits the automatic tuple foreach index unpacking trick which is obscure and under controversy
	reference: https://issues.dlang.org/show_bug.cgi?id=7361
*/
auto enumerate (R)(R range)
	if (is_input_range!R && has_length!R)
	{/*...}*/
		return ℕ[0..range.length].zip (range);
	}

/* explicitly count the number of elements in an input_range 
*/
size_t count (alias criteria = exists => true, R)(R range)
	if (is_input_range!R)
	{/*...}*/
		size_t count;

		foreach (_; range)
			++count;

		return count;
	}

/* iterate over a range, skipping a fixed number of elements each iteration 
*/
struct Stride (R)
	{/*...}*/
		R range;

		size_t stride;

		this (R range, size_t stride)
			{/*...}*/
				this.range = range;
				this.stride = stride;
			}

		const @property length ()
			{/*...}*/
				return range.length / stride;
			}

		static if (is_input_range!R)
			{/*...}*/
				auto ref front ()
					{/*...}*/
						return range.front;
					}
				void popFront ()
					{/*...}*/
						foreach (_; 0..stride)
							range.popFront;
					}
				bool empty () const
					{/*...}*/
						return range.length < stride;
					}

				static assert (is_input_range!Stride);
			}
		static if (is_forward_range!R)
			{/*...}*/
				@property save ()
					{/*...}*/
						return this;
					}

				static assert (is_forward_range!Stride);
			}
		static if (is_bidirectional_range!R)
			{/*...}*/
				auto ref back ()
					{/*...}*/
						return range.back;
					}
				void popBack ()
					{/*...}*/
						foreach (_; 0..stride)
							range.popBack;
					}

				static assert (is_bidirectional_range!Stride);
			}


		invariant() {/*}*/
			assert (stride != 0, `stride must be nonzero`);
		}
	}
auto stride (R,T)(R range, T stride)
	{/*...}*/
		return Stride!R (range, stride.to!size_t);
	}


/* verify that the length of a range is its true length 
*/
debug void verify_length (R)(R range)
	{/*...}*/
		auto length = range.length;
		auto count = range.count;

		if (length != count)
			assert (0, R.stringof~ ` length (` ~count.text~ `) doesn't match reported length (` ~length.text~ `)`);
	}
