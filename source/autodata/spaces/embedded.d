module autodata.spaces.embedded;

private { // imports
	import autodata.traits;
	import autodata.operators;
	import autodata.spaces.orthotope;
	import evx.meta;
	import evx.interval;
}

// TODO doc
struct Embedded (Outer, Inner)
{
	Outer outer;
	Inner inner;

	auto access (CoordinateType!Outer coord)
	{
		return coord in inner.orthotope?
			inner[coord]
			: outer[coord];
	}
	auto limit (uint i)() const
	{
		return outer.limit!i;
	}

	mixin AdaptorOps!(access, Map!(limit, Iota!(dimensionality!Outer)));
}
auto embed (Outer, Inner)(Outer outer, Inner inner)
{
	foreach (i; Iota!(dimensionality!Outer))
		static assert (
			is (CoordinateType!Inner[i] : CoordinateType!Outer[i]),
			`coordinate type mismatch`
		);
	
	return Embedded!(Outer, Inner)(outer, inner);
}
unittest {
	import autodata.functional;

	auto x = ortho (interval (-1f, 1f), interval (-1f, 1f))
		.embed (
			map!((x,y) => tuple(2*x, 2*y))(
				ortho (interval (0f, 0.5f), interval (0f, 0.5f))
			)
		);

	assert (x[-0.1f, -0.1f] == tuple(-0.1f, -0.1f));
	assert (x[0.4f, 0.4f] == tuple(0.8f, 0.8f));
	assert (x[0.6f, 0.6f] == tuple(0.6f, 0.6f));
}