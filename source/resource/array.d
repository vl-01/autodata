module resource.array;

import std.c.stdlib;

import meta;

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
	template appears_manually_allocated (T)
		{/*...}*/
			enum appears_manually_allocated = __traits(compiles, T (size_t.init));
		}

	export template is_hashing_function (T)
		{/*...}*/
			template is_hashing_function (U...)
				if (U.length == 1)
				{/*...}*/
					static if (is_unary_function!(U[0]))
						{/*...}*/
							alias Function = U[0];

							enum is_hashing_function = 
								is (ParameterTypeTuple!Function == TypeTuple!T)
								&& is_comparable!(ReturnType!Function);
						}
					else enum is_hashing_function = false;
				}
		}
}
public {/*policies}*/
	enum Destruction 
		{/*...}*/
			/* shrinking the array calls the destructor for expelled elements */
			immediate,
			/* elements are destroyed only if they are overwritten and reassignment is destructive */
			deferred
		}
}
public {/*mixins}*/
	mixin template ForwardConstructor (alias recipient)
		{/*...}*/
			static if (hasMember!(typeof(recipient), `__ctor`))
				this (Args...)(Args args)
					{/*...}*/
						recipient = typeof(recipient)(args);
					}
			else this (T)(T value)
					{/*...}*/
						recipient = value;
					}
		}
	mixin template ArrayInterface (alias pointer, alias length)
		if (is_sliceable!(typeof(pointer)))
		{/*...}*/
			public:
			public {/*[┄]}*/
				ref auto opIndex (size_t i)
					in {/*...}*/
						assert (i < length, `access out of bounds`);
					}
					body {/*...}*/
						return pointer[i];
					}
				auto opSlice (size_t i, size_t j)
					in {/*...}*/
						assert (i <= j && j <= length);
					}
					body {/*...}*/
						return pointer[i..j];
					}
				auto opSlice ()
					{/*...}*/
						return this[0..$];
					}
				auto opDollar () const
					{/*...}*/
						return length;
					}
			}
			public {/*range}*/
				ref auto front ()
					in {/*...}*/
						assert (length);
					}
					body {/*...}*/
						import std.range;
						return this[].front;
					}
				ref auto back ()
					in {/*...}*/
						assert (length);
					}
					body {/*...}*/
						import std.range;
						return this[].back;
					}
			}
			const {/*[┄]}*/
				ref auto opIndex (size_t i)
					{/*...}*/
						return (cast()this)[i];
					}
				auto opSlice (size_t i, size_t j)
					{/*...}*/
						return (cast()this)[i..j];
					}
				auto opSlice ()
					{/*...}*/
						return (cast()this)[0..$];
					}
			}
			const {/*range}*/
				ref auto front ()
					{/*...}*/
						import std.range;
						return (cast()this)[].front;
					}
				ref auto back ()
					{/*...}*/
						import std.range;
						return (cast()this)[].back;
					}
			}
			public {/*iteration}*/
				mixin IterateOver!opSlice;
			}
			const {/*text}*/
				auto toString ()
					{/*...}*/
						import std.conv: text;
						import std.range: empty;
						import std.traits: PointerTarget;

						static if (__traits(compiles, this[].text))
							return this[].text;
						else static if (__traits(compiles, this[0].text))
							{/*...}*/
								string output;

								foreach (element; 0..length)
									output ~= element.text ~ `, `;

								if (output.empty)
									return `[]`;
								else return `[` ~output[0..$-2]~ `]`;
							}
						else return `[` ~PointerTarget!(typeof(pointer)).stringof~ `...]`;
					}
				auto text ()
					{/*...}*/
						return toString;
					}
			}
		}
	mixin template IterateOver (alias range)
		{/*...}*/
			static assert (is(typeof(this)), `mixin requires host struct`);
			alias Applied = typeof(range[0]);

			int opApply ()(scope int delegate(ref Applied) op)
				{/*...}*/
					int result;

					foreach (ref element; range)
						{/*...}*/
							result = op (element);

							if (result) 
								break;
						}

					return result;
				}
			int opApply ()(scope int delegate(size_t, ref Applied) op)
				{/*...}*/
					int result;

					foreach (i, ref element; range)
						{/*...}*/
							result = op (i, element);

							if (result) 
								break;
						}

					return result;
				}
			int opApply ()(scope int delegate(ref const Applied) op) const
				{/*...}*/
					return (cast()this).opApply (cast(int delegate(ref Applied)) op);
				}
			int opApply ()(scope int delegate(const size_t, ref const Applied) op) const
				{/*...}*/
					return (cast()this).opApply (cast(int delegate(size_t, ref Applied)) op);
				}
		}
}
public {/*type processing}*/
	string rewrite_type (Type, Find, ReplaceWith)()
		{/*...}*/
			string type = Type.stringof;
			string find = Find.stringof;
			string repl = ReplaceWith.stringof;

			string left  = findSplit (type, find)[0];
			string right = findSplit (type, find)[2];

			return left ~ repl ~ right;
		}
}

struct Dynamic (Array, Destruction destruction = Destruction.deferred)
	{/*...}*/
		public:
		public {/*[‥]}*/
			mixin ArrayInterface!(array, dynamic_length);
		}
		public {/*mutation}*/
			void grow (size_t n)
				in {/*...}*/
					assert (dynamic_length + n <= capacity, `array capacity ` ~capacity.text~ ` exceeded during ` ~n.text~ ` allocation`);
				}
				body {/*...}*/
					dynamic_length += n;
				}
			void shrink (size_t n)
				in {/*...}*/
					assert (n <= dynamic_length);
				}
				body {/*...}*/
					static if (destruction == Destruction.immediate)
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
					static if (__traits(compiles, typeof(array)(range)))
						array = typeof(array)(range);
					else array = range;

					dynamic_length = array.length;
				}
			this (Args...)(auto ref Args args)
				{/*...}*/
					static if (__traits(compiles, typeof(array)(args)))
						array = typeof(array)(args);
					else array = args;
				}
		}
		private:
		private {/*data}*/
			Array array;
			size_t dynamic_length;
		}
		static assert (is_dynamic_array!Dynamic);
	}

// NOTE individual appends will use opAssign, allowing potential move semantics
// but range appends will use copy, which probably uses the copy semantics but TODO let me test this
struct Appendable (Array)
	if (__traits(compiles, Dynamic!Array)
	&& not (is_ordered_array!Array))
	{/*...}*/
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
					array.grow (1);
					array[$-1] = item;
				}
			void lazy_append (scope lazy T item)
				{/*...}*/
					array.grow (1);
					array[$-1] = item;
				}
			void range_append (R)(R range)
				if (isForwardRange!R)
				{/*...}*/
					auto saved = range.save;
					auto start = array.length;

					array.grow (saved.length);

					range.copy (array[start..$]);
				}
		}
		public {/*ctor}*/
			mixin ForwardConstructor!array;
		}
		public {/*data}*/
			ArrayType array;
		}
		static assert (isOutputRange!(Appendable, T));
	}


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

					array.grow (1);
					for (size_t i = array.length-1; i > result.position; --i)
						array[i] = array[i-1];

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
					for (auto i = index; i < array.length-1; ++i)
						array[i] = array[i+1];

					array.shrink (1);
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
					static if (appears_manually_allocated!(typeof(array)))
						{/*allocate}*/
							array = typeof(array)(range.length);
						}
					else static if (isDynamicArray!Array)
						{/*copy and clear}*/
							this.array = std.array.array (range);
							this.array.clear;
						}

					assert (array.capacity >= range.length);

					insert (range);
				}
			this (Args...)(Args args)
				{/*...}*/
					array = typeof(array)(args);
				}
		}
		private:
		@disable {/*grow}*/
			auto ref grow ()(size_t)
				{/*...}*/
					static assert (0, `cannot explicitly grow Ordered array`);
				}
		}
		private {/*data}*/
			ArrayType array;
		}
		invariant (){/*}*/
			assert (this[].isSorted!compare);
		}
		static assert (isOutputRange!(Ordered, T));
	}

struct Associative (Array, Lookup...)
	if ((__traits(compiles, Dynamic!Array)
		&& not (anySatisfy!(Or!(is_appendable_array, is_ordered_array), Array))
	) && ((Lookup.length == 0 && __traits(compiles, ElementType!Array.init.toHash)
		|| Lookup.length == 1 && allSatisfy!(Or!(is_comparable, is_hashing_function!(ElementType!Array)), Lookup))))
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
				alias Keyring = } ~rewrite_type!(Array, Item, Index)~ q{;
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
				in {/*,,,}*/
					assert (this.contains (key), `key ` ~key.text~ ` does not exist in Associative ` ~Array.stringof);
				}
				body {/*...}*/
					auto result = keyring[].binary_search (Index(key));

					keyring.remove_at (result.position);

					auto index = result.found.index[1];

					for (auto i = index; i < items.length-1; ++i)
						items[i] = items[i+1];
					items.shrink (1);

					foreach (ref Index K; keyring)
						if (K.index[1] > result.position)
							--K.index[1];
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
						return &items[result.found.index[1]];
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
			bool opBinaryRight (string op = `in`)(Key key)
				{/*...}*/
					return this.contains (key);
				}
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

///////////////

struct Array (T)
	{/*...}*/
		T* ptr;
		const size_t length;

		mixin ArrayInterface!(ptr, length);

		this (size_t length)
			{/*...}*/
				this.length = length;

				ptr = cast(T*)malloc (length * T.sizeof);
			}
		this (R)(R range)
			if (is (ElementType!R == T))
			{/*...}*/
				this.length = range.length;

				ptr = cast(T*)malloc (length * T.sizeof);

				range.copy (this[]);
			}
		~this ()
			{/*...}*/
				free (cast(void*)ptr);
			}
		@disable this (this);
	}


unittest
	{/*dynamic}*/
		mixin(report_test!`dynamic array`);

		void basic_usage (Array)()
			{/*...}*/
				import std.exception: assertThrown;

				auto x = Dynamic!Array ([1,2,3]);
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
}
unittest
	{/*appendable}*/
		mixin(report_test!`appendable array`);

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
unittest
	{/*ordered}*/
		import std.exception: assertThrown;
		mixin(report_test!`ordered array`);

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
unittest
	{/*associative}*/
		import std.exception: assertThrown;
		mixin(report_test!`associative array`);

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
			static bool destroyed = false;
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

version (benchmarked)
	static void print_results (R)(size_t test_size, string[] test_names, ref R results)
		{/*...}*/
			import std.math: round;

			auto minimum = results[]
				.map!(r => r.length)
				.reduce!min;

			writeln (test_size.text~ `: `,
				zip (test_names, results[])
					.sort!((a,b) => a[1] < b[1])
					.map!(a => a[0]~ ` ` ~((100*a[1].length.to!double/minimum).round/100).text[0..min(5,$)]~ ``)
			);
		}

version (benchmarked) unittest
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
version (benchmarked) unittest
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
version (benchmarked) unittest
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
						foreach (i; 0..size)
							mine.get (i);
					}
				void test_theirs_get ()
					{/*...}*/
						int[int] theirs;

						foreach (i; 0..size)
							theirs[i] = i^^2;
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
						foreach (i; 0..size)
							mine.remove (i);
					}
				void test_theirs_remove ()
					{/*...}*/
						int[int] theirs;

						foreach (i; 0..size)
							theirs[i] = i^^2;

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
