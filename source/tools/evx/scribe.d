module evx.scribe;

private {/*imports}*/
	private {/*std}*/
		import std.traits;
		import std.datetime;
		import std.concurrency;
		import std.exception;
		import std.stdio;
		import std.ascii;
		import std.algorithm;
		import std.range;
		import std.array;
		import std.string;
		import std.conv;
	}
	private {/*evx}*/
		import evx.utils;
		import evx.colors;
		import evx.math;
		import evx.meta;
		import evx.allocators;
		import evx.arrays;
		import evx.display;
	}

	alias map = evx.functional.map;
	alias zip = evx.functional.zip;
	alias reduce = evx.functional.reduce;
}

static if (0) version = from_file; //TEMP until i figure out whats going on with this lib

final class Scribe
	{/*...}*/
		public:
		public {/*interface}*/
			Text write (T)(T text)
				{/*...}*/
					return Text (this, text.to!dstring)
						.color (black)
						.size (font_sizes[0])
						.inside (only (-1.vec, 1.vec))
						.wrap_width (-1)
						.rotate (0.0)
						.translate (0.vec)
						.scale (1.0)
						.align_to (Alignment.top_left);
				}

			shared Glyph glyph (Args...) (Args args)
				{/*↓}*/
					return (cast(Scribe)this).glyph (args);
				}
			Glyph glyph (dchar code, size_t size = 0, Color glyph_color = black)
				in {/*...}*/
					assert (font !is null);
					assert (size == 0 || size in font);
				}
				body {/*...}*/
					if (size == 0)
						size = font_sizes[0];

					auto font = font[size];
					auto glyph = texture_font_get_glyph (font, code);

					float s0 = glyph.s0;
					float t0 = glyph.t0;
					float s1 = glyph.s1;
					float t1 = glyph.t1;

					size_t width  = glyph.width;
					size_t height = glyph.height;

					int offset_x = glyph.offset_x;
					int offset_y = glyph.offset_y;

					Glyph g;
					with (g) {/*...}*/
						symbol = code;
						texture = atlas.id;
						roi = [vec(s0, t0), vec(s1, t1)];
						offset = ivec(offset_x, offset_y);
						dims = uvec(width, height);
						advance = glyph.advance_x;
						color = glyph_color;
					}
					return g;
				}

			auto font_height (size_t size)
				in {/*...}*/
					assert (size in font);
				}
				body {/*...}*/
					auto scale = font[size].height.vec / display.dimensions;
					return scale[].reduce!max;
				}

			auto available_sizes ()
				{/*...}*/
					return font_sizes;
				}

			void connect_to (Display display)
				in {/*...}*/
					assert (display);
				}
				body {/*...}*/
					alias received_before = receiveTimeout;

					display.access_rendering_context 
						((){texture_atlas_upload (atlas);});

					this.display = display;
						display.on_stop (&reset);
				}
		}
		public {/*ctor}*/
			this (size_t[] sizes = [12])
				{/*...}*/
					load_library;
					font_sizes = sizes;

					auto atlas_size = uvec(64, 64);

					void load_texture_atlas ()
						{/*...}*/

							atlas = texture_atlas_new (atlas_size.x, atlas_size.y, 1);

							foreach (size; font_sizes)
								{/*...}*/
									version(from_file)
									font[size] = texture_font_new_from_file (atlas, size, font_path); 
									else
									font[size] = texture_font_new (atlas, font_path, size);

									assert (font[size] !is null, `couldn't load font from ` ~font_path);

									auto missed_glyphs = texture_font_load_glyphs (font[size], Unicode.ptr);

									if (missed_glyphs > 0)
										{/*...}*/
											reset;

											if (atlas_size.y == 2*atlas_size.x)
												atlas_size.x *= 2;
											else atlas_size.y *= 2;

											load_texture_atlas ();
											break;
										}
								}
						}
					
					mixin(error_suppression);
					load_texture_atlas ();
				}
			this (Display display, size_t[] sizes = [12])
				in {/*...}*/
					assert (display);
				}
				body {/*...}*/
					this (sizes);
					connect_to (display);
				}
		}
		private:
		private {/*ops}*/
			void output (Text order)
				in {/*...}*/
					assert (display, "tried to write but scribe has no display");
				}
				body {/*...}*/
					alias writeln = evx.utils.writeln;
					auto text = order.text;
					auto color = order.color;
					auto size = order.size;
					if (text.empty) return;
					
					auto glyphs = text.map!(c => glyph (c, size, color));

					auto cards = typeset (glyphs, order);

					for (int i = 0; i < glyphs.length; ++i)
					//foreach (i, glyph; glyphs) BUG cannot infer argument types
						{/*...}*/
							auto glyph = glyphs[i]; // HACK workaround
							auto geometry = cards[4*i..4*i+4];
							auto tex_coords = glyph.roi[].bounding_box[].flip!`vertical`;

							display.draw (glyph.texture, geometry, tex_coords, glyph.color);
						}
				}

			auto typeset (R)(R glyphs, Text order)
				if (is (ElementType!R == Glyph))
				in {/*...}*/
					assert (order.size in font);
				}
				body {/*...}*/
					Appendable!(size_t[2^^8]) newline_positions;
					auto cards = Appendable!(vec[])(new vec[4*text.length]);

					auto size = order.size;
					auto font = this.font[size];

					vec pen = vec(0, -font.ascender);

					auto bounds = order.bounds;
					auto draw_box = bounds[].from_extended_space.to_pixel_space (display).bounding_box;

					immutable rotation = order.rotate;
					auto wrap_width = order.wrap_width;

					if (wrap_width < 0) 
						wrap_width = draw_box.width;
					else wrap_width = (wrap_width * î.vec.rotate (rotation)).from_extended_space.to_pixel_space (display).norm;

					newline_positions ~= 0;
					//foreach (i, glyph; glyphs) BUG cannot infer argument types
					for (int i = 0; i < glyphs.length; ++i)
						{/*set card coordinates in pen-space}*/
							auto glyph  = glyphs[i]; // HACK workaround
							auto offset = glyph.offset;
							auto dims   = glyph.dims;

							cards ~= [
								pen,
								pen + vec(dims.x, 0),
								pen + dims,
								pen + vec(0, dims.y)
							];

							if (pen.x + dims.x > wrap_width)
								{/*word wrap}*/
									auto length = glyphs[0..i+1].retro.countUntil!(g => g.symbol.isWhite);
									if (length < 0)
										length = i+1;
									auto cutoff = i+1 - length;
										
									auto word = ℕ[0..length]
										.map!(j => j + cutoff)
										.map!(j => cards[4*j..4*(j+1)]);

									auto Δx = word.empty? 
										pen.x + glyph.advance - glyph.offset.x
										: word[0][0].x - glyph.offset.x;
									auto carriage_return = (vec v) => v - vec(Δx, font.height);

									foreach (ref letter; word)
										letter.map!carriage_return.copy (letter);

									pen = carriage_return (pen);

									newline_positions ~= i - word.length + 1;
								}

							cards[$-4..$] = cards[$-4..$].map!(v => v - vec(-offset.x, dims.y - offset.y));

							pen.x += glyph.advance;
						}
					newline_positions ~= glyphs.length;

					auto card_box = cards[].bounding_box;
					auto alignment = order.alignment;

					foreach (i, line_start; newline_positions[0..$-1])
						{/*justify lines}*/
							auto line_stop  = newline_positions[i+1];

							if (line_stop == line_start)
								continue;

							auto line_box = cards[4*line_start..4*line_stop].bounding_box;

							auto justification = line_box.offset_to (alignment, card_box).x;

							cards[4*line_start..4*line_stop] += vec(justification, 0);
						}

					immutable scale = order.scale;
					auto translation = order.translate;

					immutable p = pen;
					pure transform (vec v) { return scale*((v-p/2).rotate (rotation) + p/2);}

					card_box = card_box[].map!transform.bounding_box;

					cards[] = cards[].map!transform
						.map!(v => v + card_box.offset_to (alignment, draw_box))
						.map!(v => v.from_pixel_space.to_draw_space (display) + translation);

					return cards;
				}

			void reset ()
				{/*...}*/
					if (atlas !is null)
						texture_atlas_delete (atlas);

					foreach (f; font)
						texture_font_delete (f);

					font = null;
				}
		}
		private {/*data}*/
			texture_atlas_t* atlas;
			texture_font_t*[size_t] font;
		}
		private {/*settings}*/
			enum font_path = "./font/DejaVuSansMono.ttf";
			const size_t[] font_sizes;
		}
		private {/*services}*/
			Display display;
		}
		extern (C):
		extern (C) {/*services}*/
			texture_atlas_t* function (const size_t width, const size_t height, const size_t depth)
				texture_atlas_new;
			void function (texture_atlas_t* self)
				texture_atlas_delete;

			version(from_file)
			texture_font_t* function (texture_atlas_t* atlas, const float size, const char* filename)
				texture_font_new_from_file;
			else
			texture_font_t* function (texture_atlas_t* atlas, const char* filename, const float size)
				texture_font_new;

			size_t function (texture_font_t* self, const dchar* charcodes) 
				texture_font_load_glyphs;
			void function (texture_font_t* self)
				texture_font_delete;
 			void function (texture_atlas_t* self)
				texture_atlas_upload;
			texture_glyph_t* function (texture_font_t* self, dchar charcode)
				texture_font_get_glyph;
		}
		extern (C) {/*definitions}*/
			struct texture_atlas_t
				{/*...}*/
					void* nodes; // Allocated nodes 
					size_t width; //  Width (in pixels) of the underlying texture 
					size_t height; // Height (in pixels) of the underlying texture 
					size_t depth; // Depth (in bytes) of the underlying texture 
					size_t used; // Allocated surface size 
					uint id; // Texture identity (OpenGL) 
					ubyte* data; // Atlas data 
				}
			struct texture_font_t
				{/*...}*/
					void* glyphs; // Vector of glyphs contained in this font. 
					texture_atlas_t* atlas; // Atlas structure to store glyphs data. 
					char* filename; // Font filename 
					float size; // Font size 
					int hinting; // Whether to use autohint when rendering font 
					int outline_type; // Outline type (0 = None, 1 = line, 2 = inner, 3 = outer) 
					float outline_thickness; // Outline thickness 
					int filtering; //  Whether to use our own lcd filter.
					int kerning; // Whether to use kerning if available 
					ubyte lcd_weights[5]; // LCD filter weights 
					float height; // This field is simply used to compute a default line spacing (i.e., the baseline-to-baseline distance) when writing text with this font. Note that it usually is larger than the sum of the ascender and descender taken as absolute values. There is also no guarantee that no glyphs extend above or below subsequent baselines when using this distance.
					float linegap; // This field is the distance that must be placed between two lines of text. The baseline-to-baseline distance should be computed as: ascender - descender + linegap 
					float ascender; // The ascender is the vertical distance from the horizontal baseline to the highest 'character' coordinate in a font face. Unfortunately, font formats define the ascender differently. For some, it represents the ascent of all capital latin characters (without accents), for others it is the ascent of the highest accented character, and finally, other formats define it as being equal to bbox.yMax. 
					float descender; // The descender is the vertical distance from the horizontal baseline to the lowest 'character' coordinate in a font face. Unfortunately, font formats define the descender differently. For some, it represents the descent of all capital latin characters (without accents), for others it is the ascent of the lowest accented character, and finally, other formats define it as being equal to bbox.yMin. This field is negative for values below the baseline. 
					float underline_position; // The position of the underline line for this face. It is the center of the underlining stem. Only relevant for scalable formats. 
					float underline_thickness; // The thickness of the underline for this face. Only relevant for scalable formats. 
				}
			struct texture_glyph_t
				{/*...}*/
					dchar charcode; // Wide character this glyph represents
					uint id; // Glyph id (used for display lists) 
					size_t width; // Glyph's width in pixels. 
					size_t height; // Glyph's height in pixels. 
					int offset_x; // Glyph's left bearing expressed in integer pixels. 
					int offset_y; // Glyphs's top bearing expressed in integer pixels. Remember that this is the distance from the baseline to the top-most glyph scanline, upwards y coordinates being positive.
					float advance_x; // For horizontal text layouts, this is the horizontal distance (in fractional pixels) used to increment the pen position when the glyph is drawn as part of a string of text.
					float advance_y; // For vertical text layouts, this is the vertical distance (in fractional pixels) used to increment the pen position when the glyph is drawn as part of a string of text.
					float s0; // First draw texture coordinate (x) of top-left corner 
					float t0; // Second draw texture coordinate (y) of top-left corner 
					float s1; // First draw texture coordinate (x) of bottom-right corner 
					float t1; // Second draw texture coordinate (y) of bottom-right corner 
					void* kerning; // A vector of kerning pairs relative to this glyph. 
					int outline_type; // Glyph outline type (0 = None, 1 = line, 2 = inner, 3 = outer) 
					float outline_thickness; // Glyph outline thickness 
				}
		}
		private {/*imports}*/
			mixin DynamicLibrary;
		}
	}

struct Glyph
	{/*...}*/
		dchar symbol;
		TextureId texture;
		vec[2] roi;
		Color color = black;

		@("pixel") ivec offset;
		@("pixel") uvec dims;
		@("pixel") float advance;
	}
struct Text
	{/*...}*/
		public:
		@property {/*font settings}*/
			mixin Builder!(
				Color, `color`,
				size_t, `size`
			);
		}
		@property {/*alignment}*/
			auto inside (T)(T bounds)
				if (is_geometric!T)
				{/*...}*/
					this.bounds[] = [
						bounds[].reduce!((u,v) => vec(min(u.x,v.x), min(u.y,v.y))), 
						bounds[].reduce!((u,v) => vec(max(u.x,v.x), max(u.y,v.y)))
					];
					return this;
				}
			auto align_to (Alignment alignment)
				{/*...}*/
					this.alignment = alignment;
					return this;
				}
			mixin Builder!(
				double, `wrap_width`,
			);
		}
		@property {/*transformation}*/
			mixin Builder!(
				double, `rotate`,
				vec, 	`translate`,
				double, `scale`,
			);
		}
		@property {/*fulfillment}*/
			void opCall ()
				{/*...}*/
					scribe.output (this);
				}
		}
		private:
		private {/*data}*/
			Scribe scribe;
			dstring text;
			vec[2] bounds;
			Alignment alignment;
		}
		private {/*ctor}*/
			this (Scribe scribe, dstring text)
				{/*...}*/
					this.scribe = scribe;
					this.text = text;
				}
		}
	}
struct Table
	{/*...}*/
		struct Entry
			{/*...}*/
				string label;
				string value;
			}
		Entry[] entries;
		Color borders;
	}

struct Unicode
	{/*...}*/
		__gshared: 
		const {/*character maps}*/
			dchar[] ascii;
			dchar[string] arrow;
			dchar[string] symbol;
		}
		const {/*aliasing}*/
			dchar[] all;
			alias all this;
		}
		private {/*☀}*/
			shared static this ()
				{/*...}*/
					{/*ascii}*/
						ascii = 
						` !"#$%&'()*+,-./0123456789:;<=>?`
						`@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`
						"`abcdefghijklmnopqrstuvwxyz{|}~"
						;
					}
					{/*arrow}*/
						arrow = [
							`left`		:'←',
							`up`		:'↑',
							`right`		:'→',
							`down`		:'↓',
							`left_right`:'↔',
							`up_down`	:'↕',
							`left_2`	:'↞',
							`up_2`		:'↟',
							`right_2`	:'↠',
							`down_2`	:'↡',
							`back_left`	:'↩',
							`back_right`:'↪',
							`loop_left`	:'↫',
							`loop_right`:'↬',
							`over_left`	:'↶',
							`over_right`:'↷',
							`ccw`		:'↺',
							`cw`		:'↻',
							`bi_horiz`	:'⇄',
							`bi_vert`	:'⇅',
							`2_left`	:'⇇',
							`2_up`		:'⇈',
							`2_right`	:'⇉',
							`2_down`	:'⇊',
							`bi_harpoon`:'⇋',
							`dash_left`	:'⇠',
							`dash_up`	:'⇡',
							`dash_right`:'⇢',
							`dash_down`	:'⇣',
							`compass`	:'➢',
							`head`		:'➤',
							`halo`		:'➲',
						];
					}
					{/*symbol}*/
						symbol = [
							`lightning`	:'⚡',
							`warning`	:'⚠',
							`white_flag`:'⚐',
							`black_flag`:'⚑',
							`hammers`	:'⚒',
							`anchor`	:'⚓',
							`swords`	:'⚔',
							`medicine`	:'⚕',
							`scales`	:'⚖',
							`alembic`	:'⚗',
							`flower`	:'⚘',
							`gear`		:'⚙',
							`commerce`	:'⚚',
							`atom`		:'⚛',
							`fleur`		:'⚜',
							`skull`		:'☠',
							`caution`	:'☡',
							`nuke`		:'☢',
							`biohazard`	:'☣',
							`hermes`	:'☤',
							`communism`	:'☭',
							`peace`		:'☮',
							`yinyang`	:'☯',
							`x` 		:'✕',
							`(+)`		:'⊕',
							`(-)`		:'⊖',
							`(x)`		:'⊗',
							`(/)`		:'⊘',
							`(.)`		:'⊙',
							`(o)`		:'⊚',
							`(*)`		:'⊛',
							`(=)`		:'⊜',
							`[+]`		:'⊞',
							`[-]`		:'⊟',
							`[x]`		:'⊠',
							`[.]`		:'⊡',
							`box_empty`	:'☐',
							`box_check`	:'☑',
							`box_cross`	:'☒',
							`flash_on`	:'☀',
							`flash_off`	:'☼',
							`crosshair`	:'✛',
						];
					}
					all = chain (ascii, arrow.byValue, symbol.byValue).array;
				}
			@disable this();
		}
	}

void main () {/*...}*/
	import core.thread;
	import std.datetime;

	static immutable hold_time = 1.seconds;

	static void test ()
		{/*...}*/
			scope (success) ownerTid.send (true);

			scope display = new Display (800, 600);
			display.start; scope (exit) display.stop;

			auto scribe = new Scribe (display, [14, 18]);
			auto stuff (float x) 
				{/*...}*/
					auto upper = [vec(-1.5*x+0.2, -x), vec(2*x+0.2, x)];
					auto lower = [vec(x, -x - 0.1), vec(-x, x - 0.1)];
					scribe.write ("The sky above the port was the color of television,")
						.size (18)
						.color (white)
						.inside (upper)
					();
					scribe.write ("tuned to a dead channel.")
						.size (14)
						.color (white)
						.rotate (π/4)
						.align_to (Alignment.top_right)
						.inside (lower)
					();
					display.draw ((blue*white).alpha (0.2), upper.bounding_box[].from_extended_space);
					display.draw ((blue*white).alpha (0.2), lower.bounding_box[].from_extended_space);
				}
			stuff (0.7);

			{/*alignment test}*/
				auto bb = [vec(0.6,-0.6), 0.vec];
				scribe.write ("top_left")
					.scale (0.75)
					.color (white)
					.align_to (Alignment.top_left)
					.inside (bb)
				();
				scribe.write ("center_left")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.center_left)
					.inside (bb)
				();
				scribe.write ("bottom left")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.bottom_left)
					.inside (bb)
				();
				scribe.write ("top_center")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.top_center)
					.inside (bb)
				();
				scribe.write ("center")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.center)
					.inside (bb)
				();
				scribe.write ("bottom_center")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.bottom_center)
					.inside (bb)
				();
				scribe.write ("top_right")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.top_right)
					.inside (bb)
				();
				scribe.write ("center_right")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.center_right)
					.inside (bb)
				();
				scribe.write ("bottom_right")
					.color (white)
					.scale (0.75)
					.align_to (Alignment.bottom_right)
					.inside (bb)
				();

				display.draw (red.alpha (0.3), bb.bounding_box[].from_extended_space);
			}
			{/*word wrap test}*/
				auto bounds = [-0.8.vec, vec(-0.2,0)];
				scribe.write (`stop hustling and you sank without a trace,`
					` but move a little too swiftly and you break the fragile`
					` surface tension of the black market. either way, you were gone,`
					` with nothing left of you but some vague memory in the mind`
					` of a fixture, like ratz. though your heart, or lungs, or kidneys`
					` might survive in the service of some stranger with new yen`
					` for the clinic tanks.`)
					.inside (bounds)
					.color (yellow.alpha (0.2)*green.alpha(0.5))
				();
				display.draw (orange.alpha (0.2), bounds.bounding_box[].from_extended_space);
			}

			display.render;
			Thread.sleep (hold_time);
			display.stop;
		}

	spawn (&test);
	assert (receiveTimeout (2*hold_time, (bool _){}));
}
