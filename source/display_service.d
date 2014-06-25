//	public {/*☀}*/
import std.exception;
import std.math;
import std.traits;
import std.range;
import std.variant;
import std.typetuple;
import std.array;
import utils;
import math;
import service;
import scheduler_service;

alias Texture_Id = GLuint;
enum Geometry_Mode: GLenum 
	{/*...}*/
		t_fan 	= derelict.opengl3.gl3.GL_TRIANGLE_FAN,
		t_strip = derelict.opengl3.gl3.GL_TRIANGLE_STRIP,
		lines 	= derelict.opengl3.gl3.GL_LINES,
		l_strip = derelict.opengl3.gl3.GL_LINE_STRIP,
		l_loop 	= derelict.opengl3.gl3.GL_LINE_LOOP
	}

struct Glyph
	{/*...}*/
		dchar symbol;
		GLuint texture;
		vec[2] roi;
		Color color = black;
		@("pixel") ivec offset;
		@("pixel") uvec dims;
		@("pixel") float advance;
	}

public {/*coordinate transformations}*/
	public {/*from}*/
		auto from_draw_space (T)(T geometry) pure nothrow
			if (is (T == vec) || is_geometric!T)
			{/*...}*/
				static if (is (T == vec))
					return Display.Coords (geometry, Display.Space.draw);
				else static if (is_geometric!T)
					return geometry.map!(v => Display.Coords (v, Display.Space.draw));
				else static assert (0);
			}
		auto from_extended_space (T)(T geometry) pure nothrow
			if (is (T == vec) || is_geometric!T)
			{/*...}*/
				static if (is (T == vec))
					return Display.Coords (geometry, Display.Space.extended);
				else static if (is_geometric!T)
					return geometry.map!(v => Display.Coords (v, Display.Space.extended));
				else static assert (0);
			}
		auto from_pixel_space (T)(T geometry) pure nothrow
			if (is (T == vec) || is_geometric!T)
			{/*...}*/
				static if (is (T == vec))
					return Display.Coords (geometry, Display.Space.pixel);
				else static if (is_geometric!T)
					return geometry.map!(v => Display.Coords (v, Display.Space.pixel));
				else static assert (0);
			}
	}
	public {/*to}*/
		public {/*element}*/
			vec to_draw_space (Display.Coords coords, Display display) pure nothrow
				{/*...}*/
					with (Display.Space) final switch (coords.space)
						{/*...}*/
							case draw:
								return coords.value;
							case extended:
								with (display.dimensions) 
									return coords.value*vec(min/x, min/y);
							case pixel:
								return 2*coords.value/display.dimensions - 1;
						}
				}
			vec to_extended_space (Display.Coords coords, Display display) pure nothrow
				{/*...}*/
					with (Display.Space) final switch (coords.space)
						{/*...}*/
							case draw:
								with (display.dimensions) 
									return coords.value*vec(x/min, y/min);
							case extended:
								return coords.value;
							case pixel:
								return coords.to_draw_space (display).from_draw_space.to_extended_space (display);
						}
				}
			vec to_pixel_space (Display.Coords coords, Display display) pure nothrow
				{/*...}*/
					with (Display.Space) final switch (coords.space)
						{/*...}*/
							case draw:
								return (coords.value+1)*display.dimensions/2;
							case extended:
								return coords.to_draw_space (display).from_draw_space.to_pixel_space (display);
							case pixel:
								return coords.value;
						}
				}
		}
		public {/*range}*/
			auto to_draw_space (T)(T geometry, Display display) nothrow
				if (is (ElementType!T == Display.Coords))
				{/*...}*/
					return geometry.map!(coords => coords.to_draw_space (display));
				}
			auto to_extended_space (T)(T geometry, Display display) nothrow
				if (is (ElementType!T == Display.Coords))
				{/*...}*/
					return geometry.map!(coords => coords.to_extended_space (display));
				}
			auto to_pixel_space (T)(T geometry, Display display) nothrow
				if (is (ElementType!T == Display.Coords))
				{/*...}*/
					return geometry.map!(coords => coords.to_pixel_space (display));
				}
		}
	}
}

final class Display: Service
	{/*...}*/
		private {/*imports}*/
			import std.file;
			import std.datetime;
			import std.algorithm;
			import derelict.glfw3.glfw3;
			import derelict.opengl3.gl3;
			import std.concurrency: Tid;
		}
		public:
		public {/*drawing}*/
			void draw (T) (Color color, T geometry, Geometry_Mode mode = Geometry_Mode.l_loop) 
				if (is_geometric!T)
				{/*↓}*/
					draw (0, geometry, geometry, color, mode);
				}
			void draw (T1, T2) (GLuint texture, T1 geometry, T2 tex_coords, Color color = black.alpha(0), Geometry_Mode mode = Geometry_Mode.t_fan)
				if (allSatisfy!(is_geometric, TypeTuple!(T1, T2)))
				in {/*...}*/
					assert (tex_coords.length == geometry.length, `geometry/texture coords length mismatched`);
				}
				body {/*...}*/
					if (geometry.length == 0) return;

					uint index  = cast(uint)vertices.length;
					uint length = cast(uint)geometry.length;
					auto data = Order!() (mode, index, length);

					auto order = Order!Basic (data);
					order.tex_id = texture;
					order.base = color;
			
					// TODO map them all to draw
					static if (isArray!T1)
						vertices.data ~= geometry; // TODO managed resource
					else vertices.data ~= std.array.array (geometry);
					static if (isArray!T2)
						texture_coords.data ~= tex_coords;
					else texture_coords.data ~= std.array.array (tex_coords);

					orders.data ~= Render_Order (order);
				}
		}
		public {/*controls}*/
			void render ()
				in {/*...}*/
					assert (this.is_running, "attempted to render while Display offline");
					assert (animation is null, "attempted to render manually while animating");
				}
				body {/*...}*/
					vertices.writer_swap ();
					texture_coords.writer_swap ();
					orders.writer_swap ();
					send (true);
				}
			GLuint upload_texture (T) (shared T bitmap, GLuint texture_id = uint.max)
				{/*...}*/
					GLsizei height = bitmap.height;
					GLvoid* data = bitmap.data;
					GLenum format = Upload.Format.rgba;
					GLsizei width = bitmap.width;

					Upload upload 
						= {/*...}*/
							height: height,
							width: width,
							data: data,
							format: format,
							texture_id: texture_id,
						};
					send (upload);
					receive ((GLuint tex_id) => upload.texture_id = tex_id);
					return upload.texture_id;
				}
			void access_rendering_context (T)(T request)
				if (isCallable!T)
				in {/*...}*/
					assert (this.is_running, "attempted to access rendering context while Display offline");
				}
				body {/*...}*/
					send (std.concurrency.thisTid, cast(shared) std.functional.toDelegate (request));
				}
		}
		public {/*coordinates}*/
			enum Space {draw, extended, pixel}
			struct Coords
				{/*...}*/
					Space space;
					vec value;
					alias value this;

					@disable this ();
					this (vec value, Space space) pure nothrow
						{/*...}*/
							this.value = value;
							this.space = space;
						}
				}
			@(Space.pixel) @property auto dimensions () pure nothrow
				{/*...}*/
					return screen_dims.vec;
				}
		}
		public {/*☀}*/
			this (uint width, uint height)
				{/*...}*/
					this (uvec(width, height));
				}
			this (uvec dims)
				{/*...}*/
					screen_dims = dims;
				}
			this (){}
		}
		protected:
		@Service shared override {/*interface}*/
			bool initialize ()
				{/*...}*/
					{/*GLFW}*/
						DerelictGLFW3.load ();
						glfwSetErrorCallback (&error_callback);
						enforce (glfwInit (), "glfwInit failed");
						window = glfwCreateWindow (screen_dims.x, screen_dims.y, "sup", null, null);
						enforce (window !is null);
						glfwMakeContextCurrent (window);
						glfwSwapInterval (0);
					}
					{/*GL}*/
						DerelictGL3.load ();
						DerelictGL3.reload ();
						gl.EnableVertexAttribArray (0);
						gl.EnableVertexAttribArray (1);
						gl.ClearColor (0.1, 0.1, 0.1, 1.0);
						gl.GenBuffers (1, &vertex_buffer);
						gl.GenBuffers (1, &texture_coord_buffer);
						gl.BindBuffer (GL_ARRAY_BUFFER, vertex_buffer);
						gl.VertexAttribPointer (0, 2, GL_FLOAT, GL_FALSE, 0, null);
						gl.BindBuffer (GL_ARRAY_BUFFER, texture_coord_buffer);
						gl.VertexAttribPointer (1, 2, GL_FLOAT, GL_FALSE, 0, null);
						// alpha
						gl.Enable (GL_BLEND);
						gl.BlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					}
					initialize_shaders (shaders);
					return true;
				}
			bool process ()
				{/*...}*/
					auto vertex_pool = vertices.back;
					auto texture_coord_pool = texture_coords.back;
					auto order_pool = orders.back;
					if (order_pool.length)
						{/*sort orders}*/
							template take_order (visual_T)
								{/*...}*/
									alias take_order = λ!(
										(Order!visual_T order) 
											{/*...}*/
												const auto i = staticIndexOf!(visual_T, Visual_Types);
												(cast(Shaders[i])shaders[i]).render_list ~= order;
											}
									);
								}
							foreach (order; order_pool)
								order.visit!(staticMap!(take_order, Visual_Types));
						}
					if (vertex_pool.length) 
						{/*render orders}*/
							gl.BindBuffer (GL_ARRAY_BUFFER, vertex_buffer);
							gl.BufferData (GL_ARRAY_BUFFER, 
								vec.sizeof * vertex_pool.length, vertex_pool.ptr,
								GL_STATIC_DRAW
							);
							gl.BindBuffer (GL_ARRAY_BUFFER, texture_coord_buffer);
							gl.BufferData (GL_ARRAY_BUFFER, 
								vec.sizeof * texture_coord_pool.length, texture_coord_pool.ptr,
								GL_STATIC_DRAW
							);
							foreach (i, shader; shaders)
								(cast(shared)shader).execute;
						}
					glfwPollEvents ();
					glfwSwapBuffers (window);
					gl.Clear (GL_COLOR_BUFFER_BIT);
					return true;
				}
			bool listen ()
				{/*...}*/
					bool listening = true;

					void render (bool _ = true)
						{/*...}*/
							vertices.reader_swap ();
							texture_coords.reader_swap ();
							orders.reader_swap ();
							listening = false;
							assert (texture_coords.back.length == vertices.back.length, `vertices and texture coords not 1-to-1`);
						}
					void upload_texture (Upload upload)
						{/*...}*/
							if (upload.exists)
								gl.BindTexture (GL_TEXTURE_2D, upload.texture_id);
							else {/*generate texture_id}*/
								gl.GenTextures (1, &(upload.texture_id));
								gl.BindTexture (GL_TEXTURE_2D, upload.texture_id);
								gl.TexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
								gl.TexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
								gl.TexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
								gl.TexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
								gl.PixelStorei (GL_UNPACK_ALIGNMENT, 1); // XXX this may need to be controlled
							}
							gl.TexImage2D (/*upload texture)*/
								GL_TEXTURE_2D, 0, upload.format,
								upload.width, upload.height,
								0, upload.format, GL_UNSIGNED_BYTE,
								cast(GLvoid*)upload.data
							);
							reply (upload.texture_id);
						}
					void access_rendering_context (Tid requestor, shared bool delegate() request)
						{/*...}*/
							std.concurrency.send (requestor, request ());
						}
						
					receive (
						&render, 
						&upload_texture, 
						&access_rendering_context,
						auto_sync!(animation, (){/*...})*/
							vertices.writer_swap ();
							vertices.reader_swap ();
							orders.writer_swap ();
							orders.reader_swap ();
							listening = false;
						}).expand
					);

					return listening;
				}
			bool terminate()
				{/*...}*/
					{/*GLFW}*/
						glfwMakeContextCurrent (null);
						glfwDestroyWindow (window);
						glfwTerminate ();
					}
					return true;
				}
			const string name ()
				{/*...}*/
					return "display";
				}
		}
		private:
		static {/*context}*/
			GLFWwindow* window;
			Shader_Interface[] shaders;
			GLuint vertex_buffer;
			GLuint texture_coord_buffer;
			Scheduler animation;
		}
		private {/*data}*/
			@(`pixel`) uvec screen_dims = uvec(800, 800);
			shared Triple_Buffer!vec vertices;
			shared Triple_Buffer!vec texture_coords;
			shared Triple_Buffer!Render_Order orders;
		}
		static:
		extern (C) {/*callbacks}*/
			void error_callback (int, const (char)* error) nothrow
				{/*...}*/
					import std.c.stdio: fprintf, stderr;
					fprintf (stderr, "error glfw: %s\n", error);
				}
		}
		unittest
			{/*animation}*/
				import std.algorithm;
				import std.range;
				import std.array;
				mixin (report_test!"display-animation sync");
				import core.thread: Thread, sleep;
				import std.concurrency;
				auto D = new Display;
				auto S = new Scheduler;

				static auto verts = [vec(0), vec(1), vec(1,0)];
				static auto animate (Display D)
					{/*...}*/
						static int t = 0;
						t++;
						D.draw (green, verts.map!(v => v-(0.02*t)));
					}

				// ways to animate:
				static void manual_test (shared Display sD, shared Scheduler sS)
					{/*manually sync the display with a scheduler}*/
						auto D = cast()sD;
						auto S = cast()sS;
						scope (exit) {D.stop (); S.stop (); ownerTid.prioritySend (true);}
						D.start ();
						S.start ();
						S.enqueue (30.msecs);
						int frames = 20;
						while (frames-- && received_before (100.msecs, 
							(Scheduler.Notification _) {animate (D); D.render (); if (frames) S.enqueue (30.msecs);}
						)){}
					}
				static void auto_test (shared Display sD, shared Scheduler sS)
					{/*automatically sync the display with a scheduler}*/
						auto D = cast()sD;
						auto S = cast()sS;
						scope (exit) {D.stop (); S.stop (); ownerTid.prioritySend (true);}
						verts = [vec(0), vec(1), vec(1,0)];
						D.start ();
						S.start ();
						S.enqueue (800.msecs); // this is our termination signal
						D.subscribe (); // to receive a service ID
						D.sync_with (S, 30); // 30 fps
						bool rendering = true;
						while (rendering && received_before (100.msecs, 
							(Scheduler.Notification _)
								{rendering = false;},
							(Service.Id id)
								{animate (D);}
						)){}
					}

				bool received;
				spawn (&manual_test, cast(shared)D, cast(shared)S);
				received = receiveTimeout (2.seconds, (bool _){});
				assert (received);
				spawn (&auto_test, cast(shared)D, cast(shared)S);
				received = receiveTimeout (2.seconds, (bool _){});
				assert (received);
			}
		unittest
			{/*coordinate transformation}*/
				scope gfx = new Display (800, 600);
				gfx.start; scope (exit) gfx.stop;
				{/*identity}*/
					assert (î.vec.approx (î.vec.from_draw_space.to_draw_space (gfx)));
					assert (î.vec.approx (î.vec.from_extended_space.to_extended_space (gfx)));
					assert (î.vec.approx (î.vec.from_pixel_space.to_pixel_space (gfx)));
				}
				{/*inverse}*/
					assert (î.vec.approx (
						î.vec.from_draw_space.to_extended_space (gfx)
							.from_extended_space.to_draw_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_draw_space.to_pixel_space (gfx)
							.from_pixel_space.to_draw_space (gfx)
					));

					assert (î.vec.approx (
						î.vec.from_extended_space.to_draw_space (gfx)
							.from_draw_space.to_extended_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_extended_space.to_pixel_space (gfx)
							.from_pixel_space.to_extended_space (gfx)
					));

					assert (î.vec.approx (
						î.vec.from_pixel_space.to_draw_space (gfx)
							.from_draw_space.to_pixel_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_pixel_space.to_extended_space (gfx)
							.from_extended_space.to_pixel_space (gfx)
					));
				}
				{/*cycle}*/
					assert (î.vec.approx (
						î.vec.from_draw_space.to_extended_space (gfx)
							.from_extended_space.to_pixel_space (gfx)
							.from_pixel_space.to_draw_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_draw_space.to_pixel_space (gfx)
							.from_pixel_space.to_extended_space (gfx)
							.from_extended_space.to_draw_space (gfx)
					));

					assert (î.vec.approx (
						î.vec.from_extended_space.to_draw_space (gfx)
							.from_draw_space.to_pixel_space (gfx)
							.from_pixel_space.to_extended_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_extended_space.to_pixel_space (gfx)
							.from_pixel_space.to_draw_space (gfx)
							.from_draw_space.to_extended_space (gfx)
					));

					assert (î.vec.approx (
						î.vec.from_pixel_space.to_draw_space (gfx)
							.from_draw_space.to_extended_space (gfx)
							.from_extended_space.to_pixel_space (gfx)
					));
					assert (î.vec.approx (
						î.vec.from_pixel_space.to_extended_space (gfx)
							.from_extended_space.to_draw_space (gfx)
							.from_draw_space.to_pixel_space (gfx)
					));
				}
			}
	}

alias Visual_Types = TypeTuple!(Basic);
private {/*shaders}*/
	template Shader_Name (visual_T) {mixin(q{alias Shader_Name = }~visual_T.stringof~q{_Shader;});}
	alias Shaders = staticMap!(Shader_Name, Visual_Types);
	struct Uniform {}
	private {/*protocols}*/
		template link_uniforms (T)
			{/*...}*/
				const string link_uniforms ()
					{/*...}*/
						string command;
						foreach (uniform; collect_members!(T, Uniform))
							command ~= uniform~` = gl.GetUniformLocation (program, "`~uniform~`"); `;
						return command;
					}
			}
		const string uniform_protocol ()
			{/*...}*/
				return q{	
					mixin (link_uniforms!(typeof (this)));
					protocol_check = true;
				};
			}
	}
	private {/*imports}*/
		import std.file;
		import std.conv;
		import std.algorithm;
		import derelict.opengl3.gl3;
	}
	private {/*interfaces}*/
		shared interface Shader_Interface
			{/*...}*/
				void execute ();
			}
		abstract class Shader (visual_T): Shader_Interface
			{/*...}*/
				protected alias visual_type = visual_T;
				public:
				public {/*render list}*/
					Order!visual_T[] render_list;
				}
				protected:
				shared final {/*shader interface}*/
					void execute ()
						in {/*...}*/
							assert (protocol_check, visual_T.stringof~" shader failed protocol");
						}
						body {/*...}*/
							gl.UseProgram (program);
							foreach (order; render_list) 
								{/*...}*/
									preprocess (order);
									gl.DrawArrays (order.mode, order.index, order.length);
								}
							render_list.clear ();
						}
				}
				shared {/*shader settings}*/
					void set_texture (GLuint texture)
						{/*...}*/
							gl.BindTexture (GL_TEXTURE_2D, texture);
						}
					void set_uniform (T) (GLint handle, Vec2!T vector)
						{/*...}*/
							static if (is (T == float))
								const string type = "f";
							static if (is (T == int))
								const string type = "i";
							static if (is (T == uint))
								const string type = "ui";
							mixin ("glUniform2"~type~" (handle, vector.x, vector.y);");
						}
					void set_uniform (GLint handle, Color color)
						{/*...}*/
							gl.Uniform4f (handle, color.r, color.g, color.b, color.a);
						}
					void set_uniform (Tn...) (GLint handle, Tn args)
						{/*...}*/
							static if (is (Tn[0] : bool))
								const string type = "i";
							else static if (is (Tn[0] : int))
								const string type = "i";
							else static if (is (Tn[0] : float))
								const string type = "f";
							const string length = to!string (Tn.length);
							mixin ("glUniform"~length~type~" (handle, args);");
						}
				}
				abstract shared {/*preprocessing}*/
					void preprocess (Order!visual_T);
				}
				protected {/*data}*/
					GLuint program;
					bool protocol_check;
				}
				protected {/*☀}*/
					this (string vertex_path, string fragment_path)
						{/*...}*/
							void verify (string object_type) (GLuint gl_object)
								{/*...}*/
									GLint status;
									const string glGet_iv = "glGet" ~ object_type ~ "iv";
									const string glGet_InfoLog = "glGet" ~ object_type ~ "InfoLog";
									const string glStatus = object_type == "Shader"? "COMPILE":"LINK";
									mixin (glGet_iv ~ " (gl_object, GL_" ~ glStatus ~ "_STATUS, &status);");
									if (status == GL_FALSE) 
										{/*error}*/
											GLchar[] error_log; 
											GLsizei log_length;
											mixin (glGet_iv ~ "(gl_object, GL_INFO_LOG_LENGTH, &log_length);");
											error_log.length = log_length;
											mixin (glGet_InfoLog ~ "(gl_object, log_length, null, error_log.ptr);");
											if (error_log.startsWith (`Vertex`))
												assert (null, vertex_path ~ " error: " ~ error_log);
											else assert (null, fragment_path ~ " error: " ~ error_log);
										}
								}
							auto build_shader (GLenum shader_type, string path)
								{/*...}*/
									path = "/home/vlad/Projects/active/tcr/engine_v7/glsl/" ~ path; // TEMP
									if (not (exists (path)))
										assert (null, "error: couldn't find " ~ path);
									GLuint shader = gl.CreateShader (shader_type);
									import std.string;
									auto source = readText (path);
									auto csrc = toStringz (source);
									gl.ShaderSource (shader, 1, &csrc, null);
									gl.CompileShader (shader);
									verify!"Shader" (shader);
									return shader;
								}
							GLuint vert_shader = build_shader (GL_VERTEX_SHADER, vertex_path);
							GLuint frag_shader = build_shader (GL_FRAGMENT_SHADER, fragment_path);
							program = gl.CreateProgram ();
							gl.AttachShader (program, vert_shader);
							gl.AttachShader (program, frag_shader);
							gl.LinkProgram (program); 
							verify!"Program" (program);
							gl.DeleteShader (vert_shader);
							gl.DeleteShader (frag_shader);
							gl.DetachShader (program, vert_shader);
							gl.DetachShader (program, frag_shader);
							gl.UseProgram (program);
						}
				}
			}
	}
	private {/*initialization}*/
		void initialize_shaders (ref Shader_Interface[] array)
			{/*...}*/
				array = new Shader_Interface[Shaders.length];
				foreach (shader_T; Shaders)
					array [staticIndexOf!(shader_T, Shaders)] = new shader_T;
			}
	}
	private {/*shaders}*/
		class Basic_Shader: Shader!Basic
			{/*...}*/
				public:
					this ()
						{/*...}*/
							super ("basic.vert", "basic.frag");
							mixin (uniform_protocol);
						}
				protected:
					override shared void preprocess (Order!Basic order)
						{/*...}*/
							enum: int {none = 0, basic = 1, text = 2, sprite = 3}
							auto shader_mode = none;
							if (order.tex_id != 0)
								{/*...}*/
									shader_mode = sprite;
									set_texture (order.tex_id);
								}
							if (order.base != Color (0,0,0,0))
								{/*...}*/
									if (shader_mode == sprite)
										shader_mode = text;
									else shader_mode = basic;
									set_uniform (color, order.base);
								}
							assert (shader_mode != none, shader_mode.to!string);
							set_uniform (mode, shader_mode);
						}
				private:
					@Uniform GLint color;
					@Uniform GLint mode;
			}
	}
}
private {/*orders}*/
	alias Order_Types = staticMap!(Order, Visual_Types);
	alias Render_Order = Algebraic!Order_Types;
	struct Basic
		{/*...}*/
			Color base = Color (0, 0, 0, 0);
			GLuint tex_id = 0;
		}
	struct Order (visual_T = byte)
		{/*...}*/
			public {/*standard}*/
				GLenum mode = int.max;
				uint index = 0;
				uint length = 0;
			}
			public {/*extended}*/
				visual_T visual;
				alias visual this;
			}
			public {/*☀}*/
				this (T) (T data)
					{/*...}*/
						this (data.mode, data.index, data.length);
						static if (is (T == Order))
							this.visual = data.visual;
					}
				this (GLenum mode, uint index, uint length)
					{/*...}*/
						this.mode = mode;
						this.index = index;
						this.length = length;
					}
			}
		}
}
private {/*uploads}*/
	struct Upload
		{/*...}*/
			GLuint texture_id = uint.max;
			GLsizei width;
			GLsizei height;
			shared GLvoid* data;
			GLenum format;
			enum Format: GLenum
				{/*...}*/
					rgba = GL_RGBA,
					bgra = GL_BGRA,
					gray = GL_ALPHA
				}
			@property bool exists () 
				{/*...}*/
					if (texture_id == uint.max)
						return false;
					else return true;
				}
		}
}
private {/*openGL}*/
	struct gl
		{/*...}*/
			import std.string;
			static auto ref opDispatch (string name, Args...) (Args args)
				{/*...}*/
					debug scope (exit) check_GL_error!name (args);
					static if (name == "GetUniformLocation")
						mixin ("return gl"~name~" (args[0], toStringz (args[1]));");
					else mixin ("return gl"~name~" (args);");
				}
			static void check_GL_error (string name, Args...) (Args args)
				{/*...}*/
					GLenum error;
					while ((error = glGetError ()) != GL_NO_ERROR)
						{/*...}*/
							string error_msg;
							final switch (error)
								{/*...}*/
									case GL_INVALID_ENUM:
										error_msg = "GL_INVALID_ENUM";
										break;
									case GL_INVALID_VALUE:
										error_msg = "GL_INVALID_VALUE";
										break;
									case GL_INVALID_OPERATION:
										error_msg = "GL_INVALID_OPERATION";
										break;
									case GL_INVALID_FRAMEBUFFER_OPERATION:
										error_msg = "GL_INVALID_FRAMEBUFFER_OPERATION";
										break;
									case GL_OUT_OF_MEMORY:
										error_msg = "GL_OUT_OF_MEMORY";
										break;
								}
							throw new Exception ("OpenGL error " ~to!string (error)~": "~error_msg~"\n"
								"	using gl"~function_call_to_string!name (args));
						}
				}
		}
}
