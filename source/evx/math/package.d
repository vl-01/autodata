module evx.math;

public: 
	import std.math;
	import std.algorithm: min, max;
	import evx.math.logic;
	import evx.math.functional;
	import evx.math.constants;
	import evx.math.units;
	import evx.math.vectors;
	import evx.math.geometry;
	import evx.math.analysis;
	import evx.math.statistics;
	import evx.math.probability;
	import evx.math.combinatorics;
	import evx.math.arithmetic;
	import evx.math.ordinal;
	import evx.math.algebra;

template MathToolkit ()
	{/*...}*/
		enum MathToolkit = q{
			mixin(FunctionalToolkit!());
			mixin(AnalysisToolkit!());
			mixin(ArithmeticToolkit!());
		};
	}