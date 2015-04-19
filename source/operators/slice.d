module autodata.operators.slice;
// TODO document: Diagnostic 
/* generate slicing operators with IndexOps

	Requires:
		IndexOps requirements.
		In order to use indexing on sliced structures (referred to as Sub structures), 
			the measure type must form a group under addition (i.e. + and - operators are supported, and return a value of the measure type)

	Optional:
		A set of uninstantiated, parameterless templates to extend the Sub structure.
		Templates which resolve to a string upon instantiation will be mixed in as strings,
		otherwise they are mixed in as templates.
		Since symbols defined by string mixins have a higher resolution priority than template mixins,
		this can be used to gain an additional degree of control over the semantics of the Sub structure.
*/
template SliceOps (alias access, LimitsAndExtensions...)
	{/*...}*/
		private {/*imports}*/
			import autodata.operators.index;
			import autodata.meta;
		}
		public:
		public {/*opIndex}*/
			mixin IndexOps!(access, limits) indexing;

			auto ref opIndex (Selected...)(Selected selected)
				in {/*...}*/
					alias Error = ErrorMessages!(Source, Tuple!Selected, limits);

					static if (Selected.length > 0)
						{/*type check}*/
							static assert (Selected.length == limits.length, 
								Error.type_mismatch
							);

							static assert (
								All!(is_implicitly_convertible,
									Zip!(
										TList!(Map!(Error.Element, Selected)),
										TList!(Domain!access)
									)
								), Error.type_mismatch
							);
						}

					foreach (i,_; selected)
						{/*bounds check}*/
							alias T = Unqual!(ExprType!(limits[i]));

							static if (is (ElementType!T == void))
								auto boundary = interval (T(0), limits[i]);
							else auto boundary = interval (limits[i]);

							alias U = ElementType!(typeof(boundary));

							assert (
								boundary.width > U(0),
								Error.zero_width_boundary!i ~ ` (in)`
							);
							assert (
								selected[i].is_contained_in (boundary),
								Error.out_of_bounds (selected[i], boundary)
								~ ` (in)`
							);
						}
				}
				out (result) {/*...}*/
					alias Error = ErrorMessages!(Source, Tuple!Selected, limits);

					static if (is (typeof(result) == Sub!T, T...))
						{/*...}*/
							foreach (i, limit; selected)
								static if (is (typeof(limit) == Interval!U, U...))
									assert (limit == result.bounds[i],
										Error.out_of_bounds (limit, result.bounds[i])
										~ ` (out)`
									);
								else assert (
									limit == result.bounds[i].left
									&& limit == result.bounds[i].right,
									Error.out_of_bounds (limit, result.bounds[i])
									~ ` (out)`
								);
						}
				}
				body {/*...}*/
					mixin LambdaCapture;

					enum is_proper_sub = Any!(λ!q{(T) = is (T == Interval!U, U...)}, Selected);
					enum is_trivial_sub = Selected.length == 0;

					static if (is_proper_sub || is_trivial_sub)
						{/*...}*/
							alias Subspace = Sub!(
								Map!(Dimension,
									Enumerate!(
										Select!(is_proper_sub,
											TList!Selected, 
											/*else*/
											TList!(Map!(
												Λ!q{(T) = typeof(T.init.interval)}, 
												Map!(ExprType, limits)
											))
										).Unpack
									)
								)
							);

							typeof(Subspace.bounds) bounds;

							foreach (i, limit; Unpack!(Select!(is_proper_sub,
								TList!selected, /*else*/ TList!limits
							)))
								static if (is_trivial_sub && is (ElementType!(ExprType!limit) == void))
									bounds[i] = interval (ExprType!limit(0), limit);
								else bounds[i] = interval (limit);

							auto local_access ()() {return Subspace (&this, bounds);}
							auto static_access ()() {return Subspace (null, bounds);}

							return Match!(local_access, static_access);
						}
					else return indexing.opIndex (selected);
				}
		}
		public {/*opSlice}*/
			static auto opSlice (size_t d, T,U)(T i, U j)
				{/*...}*/
					import std.conv: to;

					alias Bounds = typeof(Source.init[].bounds[d]);

					return interval (i.to!(Bounds.Left), j.to!(Bounds.Right));
				}
		}
		public {/*Sub}*/
			struct Sub (Dimensions...)
				{/*...}*/
					mixin SubGenerator!(Filter!(λ!q{(Dim) = Dim.is_free}, Dimensions))
						sub;

					alias Element = Codomain!access;

					static extensions ()
						{/*...}*/
							import std.conv: to;
							import std.range: join;

							string[] code;

							foreach (i, extension; Filter!(Not!has_identity, LimitsAndExtensions))
								static if (is (typeof(extension!().identity) == string))
									code ~= q{
										mixin(} ~ __traits(identifier, extension) ~ q{!());
									};
								else code ~= q{
									mixin } ~ __traits(identifier, extension) ~ q{;
								};

							return code.join.to!string;
						}

					mixin(extensions);
				}

			template SubGenerator (FreeDimensions...)
				{/*...}*/
					mixin LambdaCapture;

					public {/*source}*/
						Source* source;
					}
					public {/*bounds}*/
						Extract!(q{Interval}, 
							Sort!(λ!q{(T,U) = T.index < U.index},
								Cons!(
									FreeDimensions,
									Filter!(λ!q{(Dim) = not (Contains!(Dim.index, Extract!(`index`, FreeDimensions)))},
										Map!(Dimension,
											Enumerate!(Domain!access)
										),
									)
								)
							)
						)
							bounds;
					}
					public {/*limits}*/
						auto limit (size_t dim)() const
							{/*...}*/
								alias T = Unqual!(ElementType!(typeof(bounds[FreeDimensions[dim].index])));

								auto multi ()() {return -origin[(FreeDimensions[dim].index)];}
								auto uni   ()() {return -origin;}
								auto zero  ()() {return T(0);}

								auto left = Match!(multi, uni, zero);
								auto right = left + bounds[FreeDimensions[dim].index].width;

								return interval (left, right);

							}
						auto limit ()() const if (FreeDimensions.length == 1) {return limit!0;}

						auto opDollar (size_t i)() const
							{/*...}*/
								return Limit!(typeof(limit!i.tupleof))(limit!i);
							}
					}
					public {/*opIndex}*/
						typeof(this) opIndex ()
							{/*...}*/
								return this;
							}
						auto ref opIndex (Selected...)(Selected selected)
							in {/*...}*/
								alias Error = ErrorMessages!(Source, Tuple!Selected, limits);

								version (all)
									{/*type check}*/
										static if (Selected.length > 0)
											static assert (Selected.length == FreeDimensions.length,
												Error.type_mismatch
											);

										static assert (
											All!(is_implicitly_convertible,
												Zip!(
													TList!(Map!(Error.Element, Selected)),
													TList!(Extract!(q{Point}, FreeDimensions))
												)
											), Error.type_mismatch
										);
									}

								foreach (i,_; selected)
									{/*bounds check}*/
										assert (
											selected[i].is_contained_in (limit!i),
											Error.out_of_bounds (selected[i], limit!i)
										);
									}
							}
							body {/*...}*/
								static if (Any!(λ!q{(T) = is (T == Interval!U, U...)}, Selected))
									{/*...}*/
										auto bounds = this.bounds;

										foreach (i, j; Extract!(q{index}, FreeDimensions))
											bounds[j] = selected[i] - limit!i.left + bounds[j].left;

										return Sub!(
											Map!(
												Λ!q{(uint i, T) = Dimension!(FreeDimensions[i].index, T)},
												Enumerate!Selected
											)
										)(source, bounds);
									}
								else {/*...}*/
									Domain!access point;

									foreach (i,_; typeof(bounds))
										point[i] = bounds[i].left;

									foreach (i,j; Map!(λ!q{(uint k) = FreeDimensions[k].index}, Ordinal!Selected))
										point[j] += selected[i] - limit!i.left;

									return source.opIndex (point);
								}
							}
					}
					public {/*opSlice}*/
						auto opSlice (size_t d, T,U)(T i, U j)
							{/*...}*/
								return source.opSlice!d (i,j);
							}
					}
					public {/*ctor}*/
						this (typeof(source) source, typeof(bounds) bounds)
							{/*...}*/
								this.source = source;
								this.bounds = bounds;
							}
						@disable this ();
					}
				}
		}
		public {/*diagnostic}*/
			template Diagnostic ()
				{/*...}*/
					pragma(msg, `slice diagnostic: `, typeof(this));

					auto index_test ()
						{/*...}*/
							pragma(msg, "\t", typeof(this), `[] → `, typeof(this.opIndex ()));
							pragma(msg, "\t", typeof(this), `[][] → `, typeof(this.opIndex ().opIndex ()));
						}
				}
		}
		private:
		private {/*aliases}*/
			alias Source = typeof(this);
			alias limits = Filter!(has_identity, LimitsAndExtensions);

			struct Dimension (uint dim_index, Selected)
				{/*...}*/
					enum index = dim_index;

					alias Point = Domain!access[index];

					alias Bound (bool is_infinite) = Select!(
						is_infinite, Infinite!Point, /*else*/ Point
					);

					alias Interval = autodata.core.interval.Interval!(
						Bound!(is (Selected.Left == Infinite!V, V)),
						Bound!(is (Selected.Right == Infinite!V, V)),
					);

					enum is_free = not (is (Selected : Point));
				}
		}
	}
	unittest {/*...}*/
		import autodata.meta.test;
		import autodata.core;
		import autodata.operators.multilimit;

		static struct Basic
			{/*...}*/
				auto access (size_t i)
					{/*...}*/
						return true;
					}

				size_t length = 100;

				mixin SliceOps!(access, length);
			}

		assert (Basic()[0]);
		assert (Basic()[][0]);
		assert (Basic()[0..10][0]);
		assert (Basic()[][0..10][0]);
		assert (Basic()[~$..$][0]);
		assert (Basic()[~$..$][~$]);
		error (Basic()[~$..2*$][0]);

		static struct RefAccess
			{/*...}*/
				enum size_t length = 256;

				int[length] data;

				ref access (size_t i)
					{/*...}*/
						return data[i];
					}

				mixin SliceOps!(access, length);
			}
		RefAccess ref_access;
		assert (ref_access[5] == 0);
		ref_access[3..10][2] = 1;
		assert (ref_access[5] == 1);

		static struct LengthFunction
			{/*...}*/
				auto access (size_t) {return true;}
				size_t length () const {return 100;}

				mixin SliceOps!(access, length);
			}
		assert (LengthFunction()[0]);
		assert (LengthFunction()[][0]);
		assert (LengthFunction()[0..10][0]);
		assert (LengthFunction()[][0..10][0]);
		assert (LengthFunction()[~$..$][0]);
		assert (LengthFunction()[~$..$][~$]);
		error (LengthFunction()[~$..2*$][0]);

		static struct NegativeIndex
			{/*...}*/
				auto access (int) {return true;}

				int[2] bounds = [-99, 100];

				mixin SliceOps!(access, bounds);
			}
		assert (NegativeIndex()[-99]);
		assert (NegativeIndex()[-40..10][0]);
		assert (NegativeIndex()[][0]);
		assert (NegativeIndex()[][0..199][0]);
		assert (NegativeIndex()[~$..$][~$]);
		error (NegativeIndex()[~2*$..$][0]);

		static struct FloatingPointIndex
			{/*...}*/
				auto access (float) {return true;}

				float[2] bounds = [-1,1];

				mixin SliceOps!(access, bounds);
			}
		assert (FloatingPointIndex()[-0.5]);
		assert (FloatingPointIndex()[-0.2..1][0]);
		assert (FloatingPointIndex()[][0.0]);
		assert (FloatingPointIndex()[][0.0..0.8][0]);
		assert (FloatingPointIndex()[~$..$][~$]);
		error (FloatingPointIndex()[2*~$..2*$][~$]);

		// REVIEW disabled by 0-width check
		version (none) {/*}*/
			static struct StringIndex
				{/*...}*/
					auto access (string) {return true;}

					string[2] bounds = [`aardvark`, `zebra`];

					mixin SliceOps!(access, bounds);
				}
			assert (StringIndex()[`monkey`]);
			assert (is (typeof(StringIndex()[`fox`..`rabbit`])));
			assert (not (is (typeof(StringIndex()[`fox`..`rabbit`][`kitten`]))));
			assert (is (typeof(StringIndex()[~$..$])));
			assert (not (is (typeof(StringIndex()[~$..$][~$]))));
		}

		version(none) {/*}*/
		static struct MultiIndex // TODO: proper multi-index support once multiple alias this allowed
			{/*...}*/
				auto access_one (float) {return true;}
				auto access_two (size_t) {return true;}

				float[2] bounds_one = [-5, 5];
				size_t length_two = 8;

				mixin SliceOps!(access_one, bounds_one) A;
				mixin SliceOps!(access_two, length_two) B;
				mixin MultiLimitOps!(0, length_two, bounds_one) C; 

				mixin(function_overload_priority!(
					`opIndex`, B, A
				));
				mixin(template_function_overload_priority!(
					`opSlice`, B, A
				));

				alias opDollar = C.opDollar;
			}
		assert (MultiIndex()[5]);
		assert (MultiIndex()[-1.0]);

		assert (MultiIndex()[][7]);
		assert (not (is (typeof(MultiIndex()[][-5.0]))));

		assert (MultiIndex()[-0.2..1][0.0]);
		assert (MultiIndex()[-0.2..1][0]);
		assert (not (is (typeof(MultiIndex()[2..4][0.0]))));
		assert (MultiIndex()[2..4][0]);

		assert (MultiIndex()[~$]);
		assert (MultiIndex()[~$ + 7]);
		error (MultiIndex()[~$ + 8]);
		assert (MultiIndex()[~$ + 9.999]);
		error (MultiIndex()[~$ + 10.0]);
		assert (MultiIndex()[float(~$)]);
		assert (is (typeof(MultiIndex()[cast(size_t)(~$)..cast(size_t)($)])));
		assert (is (typeof(MultiIndex()[cast(float)(~$)..cast(float)($)])));
		assert (not (is (typeof(MultiIndex()[cast(int)(~$)..cast(int)($)]))));
		}

		static struct MultiDimensional
			{/*...}*/
				auto access (size_t, size_t) {return true;}

				size_t rows = 3;
				size_t columns = 3;

				mixin SliceOps!(access, rows, columns);
			}
		assert (MultiDimensional()[1,2]);
		assert (MultiDimensional()[][1,2]);
		assert (MultiDimensional()[][][1,2]);
		assert (MultiDimensional()[0..3, 1..2][1,0]);
		assert (MultiDimensional()[0..3, 1][1]);
		assert (MultiDimensional()[0, 2..3][0]);
		assert (MultiDimensional()[][0..3, 1..2][1,0]);
		assert (MultiDimensional()[][0..3, 1][1]);
		assert (MultiDimensional()[][0, 2..3][0]);
		assert (MultiDimensional()[0..3, 1..2][1..3, 0..1][1,0]);
		assert (MultiDimensional()[0..3, 1][1..3][1]);
		assert (MultiDimensional()[0, 2..3][0..1][0]);
		assert (MultiDimensional()[~$..$, ~$..$][~$, ~$]);
		assert (MultiDimensional()[~$..$, ~$][~$]);
		assert (MultiDimensional()[~$, ~$..$][~$]);

		static struct ExtendedSub
			{/*...}*/
				auto access (size_t i)
					{/*...}*/
						return true;
					}

				size_t length = 100;

				template Length ()
					{/*...}*/
						@property length () const
							{/*...}*/
								return bounds[0].right - bounds[0].left;
							}
					}

				mixin SliceOps!(access, length,	Length);
			}
		assert (ExtendedSub()[].length == 100);
		assert (ExtendedSub()[][].length == 100);
		assert (ExtendedSub()[0..10].length == 10);
		assert (ExtendedSub()[10..20].length == 10);
		assert (ExtendedSub()[~$/2..$/2].length == 50);
		assert (ExtendedSub()[][0..10].length == 10);
		assert (ExtendedSub()[][10..20].length == 10);
		assert (ExtendedSub()[][~$/2..$/2].length == 50);

		static struct SubOrigin
			{/*...}*/
				auto access (double i)
					{/*...}*/
						return true;
					}

				double measure = 10;

				template Origin ()
					{/*...}*/
						@property origin () const
							{/*...}*/
								return bounds.width/2;
							}
					}

				mixin SliceOps!(access, measure, Origin);
			}
		assert (SubOrigin()[].origin == 5);
		assert (SubOrigin()[].limit == [-5,5]);
		assert (SubOrigin()[][-5]);
		assert (SubOrigin()[0..3].origin == 1.5);
		assert (SubOrigin()[0..3].limit == [-1.5, 1.5]);
		assert (SubOrigin()[0..3][-1.5]);
		assert (SubOrigin()[][0..3].origin == 1.5);
		assert (SubOrigin()[][0..3].limit == [-1.5, 1.5]);
		assert (SubOrigin()[][0..3][-1.5]);
		assert (SubOrigin()[~$..$][-$]);

		static struct IntervalSub
			{/*...}*/
				auto access (size_t i)
					{/*...}*/
						return true;
					}

				auto bounds = interval!size_t (50, 75);

				mixin SliceOps!(access, bounds);
			}
		assert (IntervalSub()[].limit!0.width == 25);

		static struct InfiniteSub
			{/*...}*/
				auto access (size_t i)
					{/*...}*/
						return true;
					}

				auto bounds = interval (0UL, infinity); // BUG IT DOESNT LIKE THIS, IT SEES THE INFINITY BUT IT TURNS IT INTO THE BASE TYPE ANYWAY

				mixin SliceOps!(access, bounds);
			}
		assert (InfiniteSub()[].limit!0.width == infinity);

		version (none) {/*}*/
		static struct MultiIndexSub // TODO: proper multi-index support once multiple alias this allowed
			{/*...}*/
				auto access_one (float) {return true;}
				auto access_two (size_t) {return true;}

				float[2] bounds_one = [-5, 5];
				size_t length_two = 8;

				enum LimitRouting () = 
					q{float[2] float_limits (){return [limit!0.left * 5/4. - 5, limit!0.right * 5/4. - 5];}}
					q{size_t[2] size_t_limits (){return limit!0;}}
					q{mixin MultiLimitOps!(0, size_t_limits, float_limits) C;}
					q{alias opDollar = C.opDollar;}
				;

				template IndexMap () {auto opIndex (float) {return true;}}
				enum IndexRouting () = 
					q{mixin IndexMap mapping;}
					q{mixin(function_overload_priority!(`opIndex`, sub, mapping));}
				;

				mixin SliceOps!(access_one, bounds_one) A;
				mixin SliceOps!(access_two, length_two, IndexRouting, LimitRouting) B;
				mixin MultiLimitOps!(0, length_two, bounds_one) C; 

				mixin(function_overload_priority!(
					`opIndex`, B, A)
				);
				mixin(template_function_overload_priority!(
					`opSlice`, B, A)
				);
				alias opDollar = C.opDollar;
			}
		assert (MultiIndexSub()[][7]);
		assert (MultiIndexSub()[][-5.0]);
		assert (MultiIndexSub()[2..4][0.0]);
		assert (MultiIndexSub()[~$..$][0.0]);
		assert (MultiIndexSub()[2..4].bounds[0] == [2, 4]);
		assert (MultiIndexSub()[~$..4].bounds[0] == [0, 4]);
		assert (MultiIndexSub()[~$..1.0].bounds[0] == [0, 1]);
		assert (MultiIndexSub()[cast(float)~$..1.0].bounds[0] == [-5, 1]);
		assert (MultiIndexSub()[cast(float)~$..$].bounds[0] == [-5, 0]);
		assert (MultiIndexSub()[cast(float)~$..cast(float)$].bounds[0] == [-5, -5]);
		//assert (MultiIndexSub()[cast(size_t)(~$)..cast(size_t)$][cast(size_t)(~$)]);
		}
	}

package {/*error}*/
	struct ErrorMessages (This, Selected, limits...)
		{/*...}*/
			import std.conv;
			import autodata.meta;

			alias Element (T) = Select!(is (ElementType!T == void), T, /*else*/ ElementType!T);

			enum error_header = This.stringof~ `: `;

			enum type_mismatch = error_header
				~Map!(Element, Selected.Types).stringof~ ` does not convert to ` ~Map!(Element, Map!(ExprType, limits)).stringof;

			static out_of_bounds (T, U)(T arg, U limit) 
				{return error_header~ `bounds exceeded! ` ~arg.text~ ` not in ` ~limit.text;}

			enum zero_width_boundary (size_t dim) = error_header~ ` dimension ` ~dim.text~ ` has zero width`;
		}
}
