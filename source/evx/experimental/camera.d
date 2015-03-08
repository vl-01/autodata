module evx.camera;
version (none):

private {/*imports}*/
	import std.traits;

	import evx.math;
	import evx.dynamics;
	import evx.graphics;
}

struct Camera
	{/*...}*/
		alias Capture = SpatialId;
		alias World = SpatialDynamics;

		public {/*controls}*/
			void set_program (void delegate(Capture) program)
				{/*...}*/
					this.program = program;
				}
			void center_at (Position pos)
				{/*...}*/
					world_center = pos;
				}
			void pan (Displacement δ)
				{/*...}*/
					world_center += δ;
				}
			void zoom (float z)
				in {/*...}*/
					assert (z >= 0, `attempted negative zoom`);
				}
				body {/*...}*/
					_zoom_factor *= z;
				}
			auto capture ()
				in {/*...}*/
					assert (world !is null, `world has not been instantiated`);
				}
				body {/*...}*/
					auto capture = Stack!(Capture[], OnOverflow.reallocate);

					world.box_query (view_bounds, capture);

					if (program) foreach (x; capture)
						program (x);
					return capture;
				}
		}
		@property {/*}*/
			auto zoom_factor ()
				{/*...}*/
					return _zoom_factor;
				}
		}
		public {/*ctor}*/
			this (World world, Display display)
				{/*...}*/
					this.world = world;
					this.display = display;
					this.program = program;
				}
		}
		private:
		private {/*program}*/
			void delegate(Capture) program;
		}
		private {/*properties}*/
			double _zoom_factor = 1.0;
			Position world_center = zero!Position;
			vec world_scale ()
				{/*...}*/
					return display.dimensions / _zoom_factor;
				}
			vec _world_scale = unity!vec;

			Position[2] view_bounds ()
				{/*...}*/
					alias c = world_center;
					immutable s = world_scale[].map!meters.Position;

					return [c+s, c-s];
				}
		}
		private {/*services}*/
			World world;
			Display display;
		}
	}

static if (0) // TODO broken unittest
unittest
	{/*...}*/
		alias Id = SpatialDynamics.Id;
		auto world = new SpatialDynamics;
		auto display = new Display;

		world.start; scope (exit) world.stop;
		display.start; scope (exit) display.stop;

		auto cam = new Camera (world, display);

		auto frame = cam.capture;
		assert (frame.length == 0);

		auto triangle = [vec(0), vec(1), vec(1,0)]
			.map!(v => Position (v.x.meters, v.y.meters));

		auto handle = Id (0);

		with (world) add (new_body (handle)
			.position (100.meters.vector!2)
			.mass (1.kilogram)
			.shape (triangle.map!(v => v - triangle.mean))
		);
		world.expedite_uploads;

		auto x = world.get_body (handle);

		frame = cam.capture;
		assert (frame.length == 1);
		assert (frame[0] == handle);

		cam.zoom (1000);
		frame = cam.capture;
		assert (frame.length == 0);
	}