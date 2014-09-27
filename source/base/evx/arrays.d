module evx.arrays;

private {/*imports}*/
	private {/*std}*/
		import std.traits; 
		import std.range;
		import std.algorithm; 
		import std.typetuple; 
		import std.typecons; 
		import std.conv; 
		import std.c.stdlib; 
		import std.array;
	}
	private {/*evx}*/
		import evx.functional;
		import evx.utils;
		import evx.range;
		import evx.move;
		import evx.traits;
		import evx.search;
		import evx.meta;
		import evx.math;
	}

	mixin(FunctionalToolkit!());

	alias sum = evx.arithmetic.sum;
	alias allocate_array = std.range.array;
}

version (benchmarked)
	{/*...}*/
		import std.stdio;

		void print_results (R)(size_t test_size, string[] test_names, ref R results)
			{/*...}*/
				auto minimum = results[]
					.map!(r => r.length)
					.reduce!min;

				writeln (test_size.text~ `: `,
					zip (test_names, results[])
						.sort!((a,b) => a[1] < b[1])
						.map!(a => a[0]~ ` ` ~((100*a[1].length.to!double/minimum).round/100).text[0..min(5,$)]~ ``)
				);
			}

		unittest
			{/*dynamic array allocation/destruction}*/
				void fixed   (size_t test_size)() {auto x = Dynamic!(int[test_size])();}
				void malloc  (size_t test_size)() {auto x = Dynamic!(Array!int)(test_size);}
				void gc_heap (size_t test_size)() {auto x = Dynamic!(int[])(new int[test_size]);}

				void run_benchmarks (size_t size)()
					{/*...}*/
						import std.datetime: benchmark;

						auto tests = [`fixed`, `malloc`, `gc_heap`];
						auto results = benchmark!(
							fixed!size, malloc!size, gc_heap!size,
						)(1000);

						print_results (size, tests, results);
					}
				import std.typecons: staticIota;

				writeln (`n_elements: [fastest..slowest]`);
				foreach (i; staticIota!(2,14))
					run_benchmarks!(2^^i);
			}
		unittest
			{/*appendable array comparison}*/
				static void run_sequential_benchmarks (int size)()
					{/*...}*/
						static void append_to_mine ()
							{/*...}*/
								auto x = Appendable!(Array!int)(size);

								foreach (i; 0..size)
									x ~= i;
							}
						static void append_to_theirs ()
							{/*...}*/
								auto x = new int[size];

								foreach (i; 0..size)
									x ~= i;
							}

						import std.datetime: benchmark;

						auto tests = [`mine`, `theirs`];
						auto results = benchmark!(
							append_to_mine,
							append_to_theirs,
						)(10_000);

						print_results (size, tests, results);
					}
				static void run_chunked_benchmarks (int size, int block_size)()
					{/*...}*/
						static void append_to_mine ()
							{/*...}*/
								auto x = Appendable!(Array!int)(size);

								foreach (i; 0..size/block_size)
									x ~= iota (block_size*i, block_size*(i+1));
							}
						static void append_to_theirs_by_copy ()
							{/*...}*/
								int[] x;

								foreach (i; 0..size/block_size)
									{/*...}*/
										x.length += block_size;
										iota (block_size*i, block_size*(i+1)).copy (x[$-block_size..$]);
									}
							}
						static void append_to_theirs_by_array ()
							{/*...}*/
								int[] x;

								foreach (i; 0..size/block_size)
									x ~= iota (block_size*i, block_size*(i+1)).array;
							}

						import std.datetime: benchmark;

						auto tests = [`mine`, `theirs (copy)`, `theirs (array)`];
						auto results = benchmark!(
							append_to_mine,
							append_to_theirs_by_copy,
							append_to_theirs_by_array,
						)(100);

						print_results (size, tests, results);
					}
				import std.typecons: staticIota;

				writeln (`sequential: [fastest..slowest]`);
				foreach (i; staticIota!(2,16))
					run_sequential_benchmarks!(2^^i);

				foreach (j; staticIota!(0,3))
					{/*...}*/
						writeln (`chunked[` ~(10^^j).text~ `]: [fastest..slowest]`);
						foreach (i; staticIota!(8,12))
							run_chunked_benchmarks!(2^^i, 10^^j);
					}

			}
		unittest
			{/*associative array comparison}*/
				import std.datetime: benchmark;
				void test_insert (int size)()
					{/*...}*/
						void test_mine_insert ()
							{/*...}*/
								auto mine = Associative!(Array!int, int)(size);

								foreach (i; 0..size)
									mine.insert (i, i^^2);
							}
						void test_theirs_insert ()
							{/*...}*/
								int[int] theirs;

								foreach (i; 0..size)
									theirs[i] = i^^2;
							}

						auto tests = [`mine_insert`, `theirs_insert`];
						auto results = benchmark!(
							test_mine_insert,
							test_theirs_insert,
						)(10_000);

						print_results (size, tests, results);
					}
				void test_get (int size)()
					{/*...}*/
						void test_mine_get ()
							{/*...}*/
								auto mine = Associative!(Array!int, int)(size);

								foreach (i; 0..size)
									mine.insert (i, i+ 2);
								foreach (_; 0..10)
									foreach (i; 0..size)
										mine.get (i);
							}
						void test_theirs_get ()
							{/*...}*/
								int[int] theirs;

								foreach (i; 0..size)
									theirs[i] = i^^2;
								foreach (_; 0..10)
									foreach (i; 0..size)
										if (theirs[i] == i^^2)
											continue;
							}

						auto tests = [`mine_get`, `theirs_get`];
						auto results = benchmark!(
							test_mine_get,
							test_theirs_get,
						)(10_000);

						print_results (size, tests, results);
					}
				void test_remove (int size)()
					{/*...}*/
						void test_mine_remove ()
							{/*...}*/
								auto mine = Associative!(Array!int, int)(size);

								foreach (i; 0..size)
									mine.insert (i, i^^2);
								foreach (_; 0..10)
									foreach (i; 0..size)
										mine.remove (i);
							}
						void test_theirs_remove ()
							{/*...}*/
								int[int] theirs;

								foreach (i; 0..size)
									theirs[i] = i^^2;

								foreach (_; 0..10)
									foreach (i; 0..size)
										theirs.remove (i);
							}

						auto tests = [`mine_remove`, `theirs_remove`];
						auto results = benchmark!(
							test_mine_remove,
							test_theirs_remove,
						)(10_000);

						print_results (size, tests, results);
					}

				import std.typecons: staticIota;
				foreach (i; staticIota!(0, 10))
					test_insert!(2^^i);
				foreach (i; staticIota!(0, 10))
					test_get!(2^^i);
				foreach (i; staticIota!(0, 10))
					test_remove!(2^^i);
			}
	}

public {/*traits}*/
	template is_array (T)
		{/*...}*/
			enum is_array = __traits(compiles, 
				T.init[0..1],
				T.init.length == 0,
				T.init.ptr == null
			);
		}
	template is_dynamic_array (T)
		{/*...}*/
			enum is_dynamic_array = __traits(compiles, 
				T.init.grow (1), 
				T.init.shrink (1),
				T.init.empty == true,
				T.init.length == 0,
				T.init.capacity == 0,
				T.init.clear,
			);
		}
	template is_appendable_array (T)
		{/*...}*/
			enum is_appendable_array = __traits(compiles, 
				T.init.put (ElementType!T.init),
				T.init.append (ElementType!T.init),
				T.init ~= ElementType!T.init
			);
		}
	template is_ordered_array (T)
		{/*...}*/
			enum is_ordered_array = __traits(compiles, 
				T.init.insert (ElementType!T.init),
				T.init.remove (ElementType!T.init),
				T.init.remove_at (0)
			);
		}
}
public {/*policies}*/
	/* specify when to destroy elements erased from a Dynamic array 
	*/
	enum Destruction 
		{/*...}*/
			immediate,
			/* shrinking the array calls the destructor for erased elements 
				elements will also be destroyed in the same cases as in deferred destruction
			*/

			deferred,
			/* elements are only destroyed on assignment or Dynamic array destruction 
			*/
		}

	/* specify Dynamic array behavior on overflow 
	*/
	enum Reallocation
		{/*...}*/
			permitted,
			/* on overflow, reallocate if possible; otherwise throw an assert error 
			*/

			forbidden,
			/* throw an assert error on overflow 
			*/
		}

	/* specify Appendable array behavior on overflow
	*/
	enum Overflow
		{/*...}*/
			/* pass the overflow to the underlying buffer, and let it deal with the condition
			*/
			propagated,

			/* silently abort the append 
			*/
			blocked
		}
}

/* dynamic array over any type equipped with an array interface 
	a dynamic array implements the grow and shrink primitives
	constructors will propagate from the backing type
*/
struct Dynamic (Array, PolicyList...)
	{/*...}*/
		private mixin PolicyAssignment!(
			Policies!(
				`destruction`, Destruction.deferred,
				`reallocation`, Reallocation.permitted
			),
			PolicyList
		);

		public:
		public {/*[┄]}*/
			mixin ArrayInterface!(array, dynamic_length);
		}
		public {/*mutation}*/
			void grow (size_t n)
				in {/*...}*/
					static if (reallocation is Reallocation.forbidden)
						assert (dynamic_length + n <= capacity, Array.stringof~ ` capacity ` ~capacity.text~ ` exceeded during ` ~n.text~ ` allocation`);
				}
				body {/*...}*/
					static if (reallocation is Reallocation.permitted)
						{/*...}*/
							if (dynamic_length + n > capacity)
								{/*...}*/
									auto new_size = capacity == 0? 
										n: max (2*array.length, array.length + n);

									static if (supports_reallocation!Array)
										array.reallocate (new_size);
									else static if (isDynamicArray!Array)
										array.length = new_size;
									else assert (0,
										Array.stringof~ ` capacity ` ~capacity.text~ ` exceeded during ` ~n.text~ ` allocation`
									);
								}
						}

					dynamic_length += n;
				}

			void shrink (size_t n)
				in {/*...}*/
					assert (n <= dynamic_length);
				}
				body {/*...}*/
					static if (destruction is Destruction.immediate)
						foreach (ref item; this[$-n..$])
							item.destroy;
						
					dynamic_length -= n;
				}

			void clear ()
				{/*...}*/
					shrink (length);
				}
		}
		const @property {/*}*/
			size_t length ()
				{/*...}*/
					return dynamic_length;
				}

			size_t capacity ()
				{/*...}*/
					return array.length;
				}
				
			bool empty ()
				{/*...}*/
					return length == 0;
				}
		}
		public {/*ctor}*/
			this (R)(auto ref R range)
				if (isInputRange!R)
				{/*...}*/
					static if (__traits(compiles, Array (range)))
						array = Array (range);
					else static if (hasLength!R)
						{/*...}*/
							static if (isDynamicArray!Array)
								{/*...}*/
									array.length = range.length;
									range.copy (array[]);
								}
							else static if (isStaticArray!Array)
								range.copy (array[]);
						}
					else array = range;

					dynamic_length = range.length;
				}

			this (Args...)(auto ref Args args)
				{/*...}*/
					static if (__traits(compiles, Array (args)))
						array = Array (args);
					else static if (__traits(compiles, new ElementType!Array[args]))
						array = new ElementType!Array[args];
					else array = args;
				}
		}
		private:
		private {/*data}*/
			Array array;
			size_t dynamic_length;
		}
		invariant (){/*}*/
			assert (array.length >= dynamic_length, Dynamic.stringof~ ` length ` ~dynamic_length.text~ ` exceeded capacity ` ~array.length.text);
		}
		static assert (is_dynamic_array!Dynamic);
	}
	unittest {/*...}*/
		void basic_usage (Array)()
			{/*...}*/
				import std.exception: assertThrown;

				debug auto x = Dynamic!(Array, Reallocation.forbidden) ([1,2,3]);
				auto cap = x.capacity;

				assert (x[].equal ([1,2,3]));

				x.clear;
				assert (x.empty);
				assert (x.length == 0);

				x.grow (1);
				assert (x.empty.not);
				assert (x.length == 1);

				x.grow (2);
				assert (x.length == 3);
				assertThrown!Error (x.grow (cap));

				assert (x[].sum == 6);

				x[0] = 2;
				x[1] = 4;
				x[2] = 6;

				assert (x[].sum == 12);

				x.shrink (1);
				assert (x.empty.not);
				assert (x.length == 2);
				assertThrown!Error (x.shrink (3));

				x.clear;
				assert (x.empty);
				assert (x.capacity == cap);
			}

		basic_usage!(int[3]);
		basic_usage!(Array!int);
		basic_usage!(int[]);

		{/*destruction policy}*/
			static bool destroyed = false;
			struct Test {~this () {destroyed = true;}}

			auto y = Dynamic!(Test[1], Destruction.deferred)();
			y.grow (1);
			assert (not (destroyed));
			y.shrink (1);
			assert (not (destroyed));

			auto z = Dynamic!(Test[1], Destruction.immediate)();
			z.grow (1);
			assert (not (destroyed));
			z.shrink (1);
			assert (destroyed);
		}
		{/*reallocation policy}*/
			auto x = Dynamic!(Array!(int, Reallocation.permitted))(3);

			assert (x.length == 0);
			assert (x.capacity == 3);

			x.grow (3);

			assert (x.length == 3);
			assert (x.capacity == 3);

			x.grow (1);

			assert (x.length == 4);
			assert (x.capacity > 3);
		}
	}

/* dynamic array with appending 
	appendable arrays define the append primitive, which is equivalent to put and ~=
	appending creates no temporary copies of either lvalues or rvalues
*/
struct Appendable (Array, PolicyList...)
	if (__traits(compiles, Dynamic!Array)
	&& not (is_ordered_array!Array))
	{/*...}*/
		private mixin PolicyAssignment!(
			Policies!(
				`overflow`, Overflow.propagated,
			),
			PolicyList
		);

		public {/*aliasing}*/
			static if (is_dynamic_array!Array)
				alias ArrayType = Array;
			else alias ArrayType = Dynamic!Array;

			alias T = ElementType!ArrayType;

			alias array this;
		}
		public:
		public {/*append}*/
			void append (ref T item)
				{/*...}*/
					ref_append (item);
				}
			void append (scope lazy T item)
				{/*...}*/
					lazy_append (item);
				}
			void append (R)(R range)
				{/*...}*/
					range_append (range);
				}
		}
		public {/*put}*/
			alias put = append;
		}
		public {/*~=}*/
			template opOpAssign (string op: `~`)
				{alias opOpAssign = append;}
		}
		public {/*qualified}*/
			void ref_append (ref T item)
				{/*...}*/
					static if (overflow is Overflow.blocked)
						{/*...}*/
							if (array.length + 1 > array.capacity)
								return;
						}

					array.grow (1);
					array[$-1] = item;
				}
			void lazy_append (scope lazy T item)
				{/*...}*/
					static if (overflow is Overflow.blocked)
						{/*...}*/
							if (array.length + 1 > array.capacity)
								return;
						}

					array.grow (1);
					array[$-1] = item;
				}
			void range_append (R)(R range)
				if (isForwardRange!R)
				{/*...}*/
					static if (overflow is Overflow.blocked)
						{/*...}*/
							if (array.length + range.length > array.capacity)
								return;
						}

					auto start = array.length;

					array.grow (range.length);

					range.move (array[start..$]);
				}
		}
		public {/*ctor}*/
			mixin ForwardConstructor!array;
		}
		public {/*data}*/
			ArrayType array;
		}
		const {/*text}*/
			auto text ()
				{/*...}*/
					return array.text;
				}
		}
		static assert (isOutputRange!(Appendable, T));
	}
	unittest {/*...}*/
		import std.range:
			only;

		void basic_usage (Array)()
			{/*...}*/
				auto x = Appendable!Array ([-1,-2,-3]);

				assert (x[].equal ([-1,-2,-3]));
				x.clear;

				x ~= 1;
				assert (x.length == 1);
				x.put (only (2,3));
				assert (x.length == 3);
				assert (x[].equal ([1,2,3]));
				assert (x.length == x.capacity);

				x.clear;
				assert (x.length == 0);

				x.append (12);
				assert (x[0] == 12);

				x.shrink (1);

				static assert (not (__traits(compiles, x.ref_append (1))));
				static assert (__traits(compiles, x.lazy_append (1)));
				int y = 1;
				static assert (__traits(compiles, x.ref_append (y)));
				static assert (__traits(compiles, x.lazy_append (y)));
			}

		basic_usage!(Dynamic!(int[]));
		basic_usage!(Dynamic!(int[3]));
		basic_usage!(Dynamic!(Array!int));

		basic_usage!(int[]);
		basic_usage!(int[3]);
		basic_usage!(Array!int);

		{/*destruction policy}*/
			static bool destroyed = false;
			struct Test
				{/*...}*/
					bool temp = true;
					~this () {if (not (temp)) destroyed = true;}
					this(this) {assert (0, `array does not copy the input`);}
				}

			immutable not_temp = false;

			auto x = Appendable!(Dynamic!(Test[1], Destruction.deferred))();
			x ~= Test (not_temp);
			assert (not (destroyed), `array does not destroy or copy the input`);
			x.clear;
			assert (not (destroyed));

			auto y = Appendable!(Dynamic!(Test[1], Destruction.immediate))();
			y ~= Test (not_temp);
			assert (not (destroyed));
			y.clear;
			assert (destroyed);
		}
	}

/* auto-sorting dynamic array 
	sorts with <, can be overridden with custom comparator
*/
struct Ordered (Array, Sorting...)
	if ((__traits(compiles, Dynamic!Array)
		&& not (is_appendable_array!Array)
	) && ((Sorting.length == 0 && is_comparable!(ElementType!Array)) 
		|| (Sorting.length == 1 && allSatisfy!(is_comparison_function, Sorting))))
	{/*...}*/
		public {/*aliasing}*/
			static if (is_dynamic_array!Array)
				alias ArrayType = Array;
			else alias ArrayType = Dynamic!Array;

			alias T = ElementType!ArrayType;

			alias array this;

			static if (Sorting.length == 0)
				alias compare = less_than!T;
			else alias compare = Sorting[0];
		}
		public:
		public {/*insert}*/
			auto ref insert ()(auto ref T item)
				{/*...}*/
					auto result = array[].binary_search!compare (item);

					array.shift_up_from (result.position);

					array[result.position] = item;

					return array[result.position];
				}
			void insert (R)(R range)
				{/*...}*/
					range_insert (range);
				}
		}
		public {/*remove}*/
			void remove ()(auto ref T item)
				{/*...}*/
					auto result = array[].binary_search!compare (item);

					remove_at (result.position);
				}
			void remove (R)(R range)
				{/*...}*/
					range_remove (range);
				}
			void remove_at ()(size_t index)
				{/*...}*/
					array.shift_down_on (index);
				}
		}
		public {/*put}*/
			alias put = insert;
		}
		public {/*qualified}*/
			void range_insert (R)(R range)
				if (isForwardRange!R)
				{/*...}*/
					foreach (ref item; range)
						insert (item);
				}
			void range_remove (R)(R range)
				if (isInputRange!R)
				{/*...}*/
					foreach (ref item; range)
						remove (item);
				}
		}
		public {/*ctor}*/
			this (R)(R range)
				if (isInputRange!R)
				{/*...}*/
					static if (appears_manually_allocated!Array)
						{/*allocate}*/
							array = ArrayType (range.length);
						}
					else static if (isDynamicArray!Array)
						{/*copy and clear}*/
							this.array = allocate_array (range);
							this.array.clear;
						}

					assert (array.capacity >= range.length);

					insert (range);
				}
			this (Args...)(Args args)
				{/*...}*/
					array = ArrayType (args);
				}
		}
		public {/*data}*/
			ArrayType array;
		}
		const {/*text}*/
			auto text ()
				{/*...}*/
					return array.text;
				}
		}
		private:
		@disable {/*grow}*/
			auto ref grow ()(size_t)
				{/*...}*/
					static assert (0, `cannot explicitly grow Ordered array`);
				}
		}
		invariant (){/*}*/
			assert (this[].isSorted!compare);
		}
		static assert (isOutputRange!(Ordered, T));
	}
	unittest {/*...}*/
			import std.exception: assertThrown;

			void basic_usage (Array, Args...)(Args args)
				{/*...}*/
					auto x = Array (args);
					static assert (not (__traits(compiles, x.grow (1))));
					static assert (__traits(compiles, x.shrink (1)));

					x.clear;
					assert (x.empty);

					x.insert (7);
					x.insert (1);
					x.insert (-99);
					assert (x[].equal ([-99, 1, 7]));

					x.remove (-99);
					assert (x[].equal ([1, 7]));

					x.remove_at (1);
					assert (x[].equal ([1]));

					x.clear;
					assert (x.empty, `failed to clear ` ~Array.stringof);
				}
			void initial_sort_and_basic_usage (Array, Args...)(Args args)
				{/*...}*/
					auto x = Array (args);
					assert (x[].equal (args.sort));

					basic_usage!Array (args);
				}
			void custom_comparator (Array, Args...)(Args args)
				{/*...}*/
					auto x = Array (args);
					assert (x[].equal (args.sort!(Array.compare)));
				}

			initial_sort_and_basic_usage!(Ordered!(int[3]))([3,2,1]);
			initial_sort_and_basic_usage!(Ordered!(Array!int))([3,2,1]);
			initial_sort_and_basic_usage!(Ordered!(int[]))([3,2,1]);

			basic_usage!(Ordered!(Array!int))(4);

			custom_comparator!(Ordered!(Array!int, (int a, int b) => b < a))([1,2,3]);
		}

/* no-gc associative array 
	keys are generated from value.toHash by default
	this can be overriden with a custom hashing function or a key type,
	in which case the key must be explicitly supplied to insert an item
*/
struct Associative (Array, Lookup...)
	if ((__traits(compiles, Dynamic!Array)
		&& not (anySatisfy!(Or!(is_appendable_array, is_ordered_array), Array))
	) && ((Lookup.length == 0 && __traits(compiles, ElementType!Array.init.toHash))
		|| (Lookup.length == 1 && allSatisfy!(Or!(is_comparable, is_hashing_function!(ElementType!Array)), Lookup))))
	{/*...}*/
		public:
		public {/*definitions}*/
			public {/*lookup policy}*/
				static if (Lookup.length == 0)									enum lookup = `by internal hash`;
				else static if (allSatisfy!(is_hashing_function!Item, Lookup)) 	enum lookup = `by external hash`;
				else static if (allSatisfy!(is_comparable, Lookup)) 			enum lookup = `by key`;
				else static assert (0);
			}
			public {/*hash function}*/
				static if (lookup is `by internal hash`)
					{/*...}*/
						static auto hash (ref Item item)
							{return item.toHash;}
					}
				else static if (lookup is `by external hash`)
					{/*...}*/
						alias hash = Lookup[0];
					}
				else static if (lookup is `by key`)
					{/*...}*/
						static auto hash (ref Item args)
							{return Lookup[0].init;}
					}
			}

			alias Key = ReturnType!hash;
			alias Item = ElementType!Array;
			alias Pair = Tuple!(Key, Item);

			struct Index
				{/*...}*/
					Tuple!(Key, size_t) index;

					@property key () const
						{/*...}*/
							return index[0];
						}

					ref @property position_in_array ()
						{/*...}*/
							return index[1];
						}

					this (Key key)
						{/*...}*/
							index[0] = key;
						}
					this (typeof(index) index)
						{/*...}*/
							this.index = index;
						}

					mixin CompareBy!key;

					bool opEquals (const ref Index that) const
						{/*...}*/
							return this.key == that.key;
						}
				}

			mixin(q{
				alias Keyring = } ~replace_in_template!(Array, Item, Index)~ q{;
			});
		}
		public {/*insert}*/
			static if (lookup is `by key`)
				{/*...}*/
					void insert (R)(R pairs)
						if (is (ElementType!R == Pair))
						{/*...}*/
							foreach (ref pair; pairs)
								insert (pair);
						}
					auto ref insert ()(auto ref Pair pair)
						{/*...}*/
							return ref_insert (pair[0], pair[1]);
						}
					auto ref insert (Key key, scope lazy Item item)
						{/*...}*/
							return lazy_insert (key, item);
						}
					auto ref insert ()(Key key, ref Item item)
						{/*...}*/
							return ref_insert (key, item);
						}
				}
			else {/*...}*/
				void insert (R)(R items)
					if (is (ElementType!R == Item))
					{/*...}*/
						foreach (ref item; items)
							insert (item);
					}
				auto ref insert (scope lazy Item item)
					{/*...}*/
						return lazy_insert (item);
					}
				auto ref insert (ref Item item)
					{/*...}*/
						return ref_insert (item);
					}

			}
		}
		public {/*remove}*/
			void remove ()(Key key)
				in {/*...}*/
					assert (this.contains (key), `key ` ~key.text~ ` does not exist in Associative ` ~Array.stringof);
				}
				body {/*...}*/
					auto result = keyring[].binary_search (Index(key));

					items.shift_down_on (result.found.position_in_array);

					keyring.remove_at (result.position);

					foreach (ref Index K; keyring)
						if (K.position_in_array > result.position)
							--K.position_in_array;
				}
		}
		public {/*qualified}*/
			static if (lookup is `by key`)
				{/*...}*/
					auto ref lazy_insert ()(Key key, scope lazy Item item)
						{/*...}*/
							items ~= item;
							keyring.insert (Index(τ(key, items.length - 1)));

							return items.back;
						}
					auto ref ref_insert ()(Key key, ref Item item)
						{/*...}*/
							items ~= item;
							keyring.insert (Index(τ(key, items.length - 1)));

							return items.back;
						}
				}
			else {/*...}*/
				auto ref lazy_insert (scope lazy Item item)
					{/*...}*/

						items ~= item;
						debug scope (failure) 
							items.shrink (1);

						auto key = hash (items.back);

						assert (not (keyring[].binary_search (Index (key)).found),
							`duplicate item in Associative ` ~Array.stringof
						);

						keyring.insert (Index(τ(key, items.length - 1)));

						return items.back;
					}
				auto ref ref_insert (ref Item item)
					in {/*...}*/
						assert (not (keyring[].binary_search (Index (hash (item))).found),
							`duplicate item in Associative ` ~Array.stringof
						);
					}
					body {/*...}*/
						items ~= item;
						keyring.insert (Index(τ(hash (item), items.length - 1)));

						return items.back;
					}
			}
		}
		public {/*search}*/
			auto find (Key key)
				{/*...}*/
					auto result = keyring[].binary_search (Index(key));

					if (result.found)
						return &items[result.found.position_in_array];
					else return null;
				}
			auto ref get (Key key)
				in {/*...}*/
					assert (this.contains (key));
				}
				body {/*...}*/
					return *find (key);
				}
			bool contains (Key key)
				{/*...}*/
					return find (key)? true:false;
				}
			Item* opBinaryRight (string op = `in`)(Key key)
				{/*...}*/
					return find (key);
				}

			alias opIndex = get;
		}
		public {/*clear}*/
			void clear ()
				{/*...}*/
					items.clear;
					keyring.clear;
				}
		}
		const @property {/*size}*/
			auto size ()
				{/*...}*/
					return items.length;
				}
		}
		public {/*ctors}*/
			this (R)(R pairs)
				if (is (ElementType!R == Pair))
				{/*...}*/
					initialize_arrays (pairs.length);

					insert (pairs);
				}
			this ()(size_t capacity)
				if (anySatisfy!(Or!(isDynamicArray, appears_manually_allocated), Array))
				{/*...}*/
					initialize_arrays (capacity);
				}
		}
		const {/*text}*/
			auto text ()
				{/*...}*/
					string text;

					foreach (ref pair; zip (keyring[], items[]))
						text ~= pair[0].text~ `: ` ~pair[1].text~ `, `;

					if (text.empty)
						return `[]`;
					else return `[` ~text[0..$-2]~ `]`;
				}
		}
		public {/*iteration}*/
			int opApply (scope int delegate(ref Item dynamic_body) op)
				{/*...}*/
					int result;

					foreach (ref element; items[])
						{/*...}*/
							result = op (element);

							if (result) 
								break;
						}

					return result;
				}
			int opApply (scope int delegate(Key, ref Item dynamic_body) op)
				{/*...}*/
					int result;

					for (auto i = 0; i < size; ++i)
						{/*...}*/
							auto index = keyring[i];

							result = op (index.key, items[index.position_in_array]);

							if (result) 
								break;
						}

					return result;
				}
		}
		private:
		private {/*data}*/
			Appendable!Array items;
			Ordered!Keyring keyring;

			void initialize_arrays (size_t capacity)
				{/*...}*/
					static if (appears_manually_allocated!Array)
						{/*...}*/
							items = typeof(items)(capacity);
							keyring = typeof(keyring)(capacity);
						}
					else static if (isDynamicArray!Array)
						{/*...}*/
							items = typeof(items)(new Item[capacity]);
							items.clear;

							keyring = typeof(keyring)(new Index[capacity]);
							keyring.clear;
						}
				}
		}
		invariant (){/*}*/
			assert (items.length == keyring.length,
				`items.length == ` ~items.length.text~
				`, keyring.length == ` ~keyring.length.text
			);
		}
	}
	unittest {/*...}*/
			import std.exception: assertThrown;

			void test (Array, Args...)(Args ctor_args)
				if (is (ElementType!Array == int))
				{/*...}*/
					auto x = Associative!(Array, char)(ctor_args);

					x.insert ('a', 1);

					assert (x.size == 1);
					assert (x.contains ('a'));
					assert ('a' in x);

					assert (x.get ('a') == 1);

					assert (not (x.contains ('b')));
					assert (x.find ('b') == null);
					assertThrown!Error (x.get ('b'));

					x.insert ('b', 6);
					assert (x.contains ('b'));
					assert (x.find ('b') != null);
					assert (*x.find ('b') == 6);
					assert (x.get ('b') == 6);

					assert (x.size == 2);

					x.remove ('a');
					assert (x.size == 1);

					assert (not ('a' in x));
					assert ('b' in x);

					x.clear;
					assert (x.size == 0);
					assert (not ('b' in x));
				}
			
			{/*key}*/
				test!(int[8]);
				test!(int[])(8);
				test!(Array!int)(8);
			}
			{/*internal hash}*/
				import std.range: only;

				struct Test
					{/*...}*/
						size_t root;
						@property size_t toHash () const nothrow
							{/*...}*/
								return root^^2;
							}
					}
				Associative!(Test[4]) x;

				x.insert (Test (2));
				x.insert (only (
					Test(3), Test (4)
				));

				assert (x.size == 3);
				assert (4 in x);
				assert (9 in x);
				assert (16 in x);

				assertThrown!Error (x.insert (Test (2)));
				assertThrown!Error (x.remove (7));

				x.remove (9);

				assert (x.size == 2);
				assert (not (9 in x));

				x.clear;
			}
			{/*external hash}*/
				struct NoHash
					{string word;}

				static auto hash (ref NoHash x)
					{return x.word.length;}

				auto x = Associative!(NoHash[3], hash)();

				x.insert (NoHash (`one`));
				assertThrown!Error (x.insert (NoHash (`two`)));
				x.insert (NoHash (`three`));
			}
			{/*destruction policy}*/
				bool destroyed = false;
				struct Destroyer 
					{/*...}*/
						bool temp = true;
						~this () {if (not (temp)) destroyed = true;}
					}

				immutable not_temp = false;

				Associative!(Dynamic!(Destroyer[1], Destruction.deferred), int) x;
				x.insert (0, Destroyer (not_temp));
				assert (not (destroyed));
				x.remove (0);
				assert (not (destroyed));

				Associative!(Dynamic!(Destroyer[1], Destruction.immediate), int) y;
				y.insert (0, Destroyer (not_temp));
				assert (not (destroyed));
				y.remove (0);
				assert (destroyed);
			}
		}

///////////////

/* mallocated array 
*/
version (DMD_SEGFAULT) // OUTSIDE BUG
	struct Array (T, Reallocation reallocation = Reallocation.forbidden)
		{/*...}*/
			T* ptr;
			size_t length;

			mixin ArrayInterface!(ptr, length);

			static if (reallocation is Reallocation.permitted)
				void reallocate (size_t new_length)
					{/*...}*/
						auto new_ptr = cast(T*)malloc (new_length * T.sizeof);

						this[].move (new_ptr[0..length]);

						free (this.ptr);

						this.ptr = new_ptr;
						this.length = new_length;
					}

			this (size_t length)
				{/*...}*/
					this.length = length;

					ptr = cast(T*)malloc (length * T.sizeof);
				}
			this (R)(R range) // XXX the bug has something to do with this constructor
				if (is (ElementType!R == T))
				{/*...}*/
					this.length = range.length;

					ptr = cast(T*)malloc (length * T.sizeof);

					range[].copy (this[]);
				}
			~this ()
				{/*...}*/
					free (cast(void*)ptr);
				}
			@disable this (this);

			void opAssign (Array that)
				{/*...}*/
					this.ptr = that.ptr;
					this.length = that.length;

					that.ptr = null;
					that.length = 0;
				}
		}
else struct Array (T, Reallocation reallocation = Reallocation.permitted)
	{/*...}*/
		T[] data;
		alias data this;

		this (size_t L)
			{/*...}*/
				data = new T[L];
			}
		this (T[] that)
			{/*...}*/
				data = that;
			}
		this (R)(R range)
			{/*...}*/
				data = new T[range.length];
				range.copy (data);
			}

		void reallocate (size_t new_length)
			{/*...}*/
				data.length = new_length;
			}
	}

///////////////

private:
private {/*traits}*/
	template appears_manually_allocated (T)
		{/*...}*/
			enum appears_manually_allocated = __traits(compiles, T (size_t.init));
		}

	template supports_reallocation (T)
		{/*...}*/
			enum supports_reallocation = __traits(compiles, (){T array; array.reallocate (size_t.init);});
		}
}
