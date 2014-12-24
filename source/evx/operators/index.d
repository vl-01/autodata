module evx.operators.index;

/* generate an indexing operator from an access function and a set of index limits
	access must be a non-template function which returns an element of type E

	limits must be aliases to single variables or arrays of two,
	whose types (or element types, if any are arrays), given in order, 
	match the argument types for access
*/
template IndexOps (alias access, limits...)
	{/*...}*/
		private {/*imports}*/
			import std.conv;
			import std.traits;

			import evx.operators.limit;
			import evx.operators.error;
			import evx.math.intervals;
			import evx.misc.overload;
		}

		auto ref ReturnType!access opIndex (ParameterTypeTuple!access selected)
			in {/*...}*/
				version (all)
					{/*error messages}*/
						enum error_header = typeof(this).stringof ~ `: `;

						enum array_error = error_header ~ `limit types must be singular or arrays of two`
						`: ` ~ Map!(ExprType, limits).stringof;

						enum type_error = error_header ~ `limit base types must match access parameter types`
						`: ` ~ Map!(ExprType, limits).stringof
						~ ` !→ ` ~ ParameterTypeTuple!access.stringof;

						auto bounds_inverted_error (LimitType)(LimitType limit) 
							{return error_header ~ `bounds inverted! ` ~ limit.left.text ~ ` > ` ~ limit.right.text;}

						auto out_of_bounds_error (LimitType, U)(LimitType arg, U limit) 
							{return error_header ~ `bounds exceeded! ` ~ arg.text ~ ` not in ` ~ limit.text;}
					}

				foreach (i, limit; limits)
					{/*type check}*/
						static assert  (limits.length == ParameterTypeTuple!access.length,
							type_error
						);

						static if (is (typeof(limit.identity) == LimitType[n], LimitType, size_t n))
							static assert (n == 2, 
								array_error
							);

						static if (is (LimitType))
							static assert (is (ParameterTypeTuple!access[i] == LimitType),
								type_error
							);

						else static assert (is (ParameterTypeTuple!access[i] == Unqual!(typeof(limit.identity))), 
							type_error
						);
					}

				foreach (i, limit; limits)
					{/*bounds check}*/
						static if (is (typeof(limit.identity) == LimitType[2], LimitType))
							assert (limit.left <= limit.right, bounds_inverted_error (limit));

						static if (is (LimitType))
							assert (
								limit.left == limit.right? (
									selected[i] == limit.left
								) : (
									selected[i] >= limit.left
									&& selected[i] < limit.right
								),
								out_of_bounds_error (selected[i], limit)
							);
						else assert (
							limit == zero!(typeof(limit.identity))? (
								selected[0] == zero!(typeof(limit.identity))
							) : (
								selected[i] >= zero!(typeof(limit.identity))
								&& selected[i] < limit
							),
							out_of_bounds_error (selected[i], [zero!(typeof(limit.identity)), limit])
						);
					}
			}
			body {/*...}*/
				return access (selected);
			}

		mixin LimitOps!limits;
	}
	unittest {/*...}*/
		import evx.misc.test;

		static struct Basic
			{/*...}*/
				auto access (size_t) {return true;}
				size_t length = 100;

				mixin IndexOps!(access, length);
			}
		assert (Basic()[40]);
		error (Basic()[101]);
		assert (Basic()[$-1]);
		assert (Basic()[~$]);
		error (Basic()[$]);

		static struct RefAccess
			{/*...}*/
				enum size_t length = 256;

				int[length] data;

				ref access (size_t i)
					{/*...}*/
						return data[i];
					}

				mixin IndexOps!(access, length);
			}
		RefAccess ref_access;

		assert (ref_access[0] == 0);
		ref_access[0] = 1;
		assert (ref_access[0] == 1);

		static struct LengthFunction
			{/*...}*/
				auto access (size_t) {return true;}
				size_t length () {return 100;}

				mixin IndexOps!(access, length);
			}
		assert (LengthFunction()[40]);
		error (LengthFunction()[101]);
		assert (LengthFunction()[$-1]);
		assert (LengthFunction()[~$]);
		error (LengthFunction()[$]);

		static struct NegativeIndex
			{/*...}*/
				auto access (int) {return true;}

				int[2] bounds = [-99, 100];

				mixin IndexOps!(access, bounds);
			}
		assert (NegativeIndex()[-25]);
		error (NegativeIndex()[-200]);
		assert (NegativeIndex()[$-25]);
		assert (NegativeIndex()[~$]);
		error (NegativeIndex()[$]);

		static struct FloatingPointIndex
			{/*...}*/
				auto access (float) {return true;}

				float[2] bounds = [-1,1];

				mixin IndexOps!(access, bounds);
			}
		assert (FloatingPointIndex()[0.5]);
		error (FloatingPointIndex()[-2.0]);
		assert (FloatingPointIndex()[$-0.5]);
		assert (FloatingPointIndex()[~$]);
		error (FloatingPointIndex()[$]);

		static struct StringIndex
			{/*...}*/
				auto access (string) {return true;}

				string[2] bounds = [`aardvark`, `zebra`];

				mixin IndexOps!(access, bounds);
			}
		assert (StringIndex()[`monkey`]);
		error (StringIndex()[`zzz`]);
		assert (StringIndex()[$[1..$]]);
		assert (StringIndex()[~$]);
		error (StringIndex()[$]);

		static struct MultiIndex
			{/*...}*/
				auto access_one (float) {return true;}
				auto access_two (size_t) {return true;}

				float[2] bounds_one = [-5, 5];
				size_t length_two = 8;

				mixin IndexOps!(access_one, bounds_one) A;
				mixin IndexOps!(access_two, length_two) B;

				mixin(function_overload_priority!(
					`opIndex`, B, A)
				);

				alias opDollar = B.opDollar; // TODO until MultiLimit is ready, have to settle for a manual $ selection
			}
		assert (MultiIndex()[5]);
		assert (MultiIndex()[-1.0]);
		assert (MultiIndex()[$-1]);
		error (MultiIndex()[$-1.0]);
		assert (MultiIndex()[~$]);
		error (MultiIndex()[$]);

		static struct LocalOverload
			{/*...}*/
				auto access (size_t) {return true;}

				size_t length = 100;

				mixin IndexOps!(access, length) 
					mixed_in;

				auto opIndex () {return true;}

				mixin(function_overload_priority!(
					`opIndex`, mixed_in)
				);
			}
		assert (LocalOverload()[]);
		assert (LocalOverload()[1]);
		assert (LocalOverload()[$-1]);
		error (LocalOverload()[$]);

		static struct MultiDimensional
			{/*...}*/
				auto access (size_t, size_t) {return true;}

				size_t rows = 3;
				size_t columns = 3;

				mixin IndexOps!(access, rows, columns);
			}
		assert (MultiDimensional()[1,2]);
		assert (MultiDimensional()[$-1, 2]);
		assert (MultiDimensional()[1, $-2]);
		assert (MultiDimensional()[$-1, $-2]);
		assert (MultiDimensional()[~$, ~$]);
		error (MultiDimensional()[$, 2]);
		error (MultiDimensional()[1, $]);
		error (MultiDimensional()[$, $]);
	}
