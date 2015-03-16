module spacecadet.topology.product;

private {/*import}*/
	import spacecadet.core;
	import spacecadet.meta;
	import spacecadet.operators;
	import std.typecons: tuple; 
}

struct CartesianProduct (Spaces...)
	{/*...}*/
		alias Offsets = Scan!(Sum, Map!(dimensionality, Spaces));

		Spaces spaces;

		auto limit (size_t d)() const
			{/*...}*/
				mixin LambdaCapture;

				alias LimitOffsets = Offsets[0..$ - Filter!(λ!q{(int i) = d < i}, Offsets).length + 1];
					
				enum i = LimitOffsets.length - 1;
				enum d = LimitOffsets[0] - 1;

				size_t[2] get_length ()() if (d == 0) {return [0, spaces[i].length];}
				auto get_limit ()() {return spaces[i].limit!d;}

				return Match!(get_limit, get_length);
			}

		auto access (Map!(CoordinateType, Spaces) point)
			in {/*...}*/
				static assert (typeof(point).length >= Spaces.length,
					`could not deduce coordinate type for ` ~Spaces.stringof
				);
			}
			body {/*...}*/
				template projection (size_t i)
					{/*...}*/
						auto π_i ()() {return spaces[i][point[0..Offsets[i]]];}
						auto π_n ()() {return spaces[i][point[Offsets[i-1]..Offsets[i]]];}

						alias projection = Match!(π_i, π_n);
					}

				return Map!(projection, Count!Spaces).tuple.flatten;
			}

		mixin SliceOps!(access, Map!(limit, Count!(Domain!access)), RangeOps);
	}

auto cartesian_product (S,R)(S left, R right)
	{/*...}*/
		static if (is (S == CartesianProduct!T, T...))
			return CartesianProduct!(T,R)(left.spaces, right);

		else return CartesianProduct!(S,R)(left, right);
	}
	unittest {/*...}*/
		import spacecadet.functional; 

		int[3] x = [1,2,3];
		int[3] y = [4,5,6];

		auto z = x[].by (y[]);

		assert (z.access (0,1) == tuple (1,5));
		assert (z.access (1,1) == tuple (2,5));
		assert (z.access (2,1) == tuple (3,5));

		auto w = z[].map!((a,b) => a * b);

		assert (w[0,0] == 4);
		assert (w[1,1] == 10);
		assert (w[2,2] == 18);

		auto p = w[].by (z[]);

		assert (p[0,0,0,0] == tuple (4,1,4));
		assert (p[1,1,0,1] == tuple (10,1,5));
		assert (p[2,2,2,1] == tuple (18,3,5));
	}

alias by = cartesian_product;