module spacecadet.patterns.id;

/* generate Id, a unique (up to host type) identifier type 
*/
mixin template TypeUniqueId (uint bit = 0)
	{/*...}*/
		static assert (is(typeof(this)), `mixin requires host struct`);

		import spacecadet.core;

		struct Id
			{/*...}*/
				static auto opCall ()
					{/*...}*/
						typeof(this) new_id = {id : ++generator};

						return new_id;
					}

				private {/*data}*/
					static if (bit == 64)
						ulong id;
					else static if (bit == 32)
						uint id;
					else static if (bit == 16)
						ushort id;
					else static if (bit == 8)
						ubyte id;
					else static if (bit == 0)
						size_t id;
					else static assert (0);
					__gshared typeof(id) generator;
				}

				auto opCmp ()(Id that) const
					{/*...}*/
						return compare (this.id, that.id);
					}
			}
	}
	unittest {
		debug {/*TypeUniqueId () cannot be made pure}*/
			struct Test { mixin TypeUniqueId; }

			auto x = Test.Id ();

			assert (x == x);
			assert (x != Test.Id ());
			assert (Test.Id () != Test.Id ());
		}
	}