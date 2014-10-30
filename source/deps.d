import std.stdio;
import std.range;
import std.process;
import std.conv;
import std.array;
import std.string;
import std.random;
import std.algorithm;
import std.file;

import evx.graphics.color; // REVIEW
import evx.math;//import evx.math.logic; // REVIEW
import evx.patterns.id; // REVIEW
import evx.patterns.builder; // REVIEW
import evx.misc.string; // REVIEW
import evx.range;//import evx.range.traversal;
import evx.math;//import evx.math.functional;

// TODO flags (uses builder) struct... also status mixins, with conditions like traits
struct Flags {mixin Builder!(typeof(null), `_`);}
struct Status (string name, string condition, Etc...) {}

mixin(FunctionalToolkit!());
alias count = evx.range.traversal.count; // TODO make count like std.algorithm count except by default it takes TRUE and just counts up all the elements

///////////////////

class Module
	{/*...}*/
		mixin TypeUniqueId;

		Id id;

		mixin Builder!(
			string, `path`,
			string, `name`,
			bool, `is_package`,
			Color, `color`,
		);

		string[] imports;
		Module[] imported_modules;
		Module enclosing_package;

		@property dot ()
			{/*...}*/
				return Dot ()
					.node (`m`~ id.to!string.extract_number)
					.label (`[label="` ~name~ `"]`)
					.shape (this.is_package? `[shape=ellipse]`:`[shape=box]`)
					.color (`[fillcolor="#` ~color.to_hex~ `"]`)
					.style (`[style=filled]`)
					;
			}

		struct Dot
			{/*...}*/
				mixin Builder!(
					string, `node`,
					string, `label`,
					string, `shape`,
					string, `color`,
					string, `style`,
				);
			}

		this (File source)
			{/*...}*/
				this.path (source.name)
					.name (source.module_name)
					.is_package (source.is_package);

				this.id = Id.create;

				foreach (import_name; source.imports)
					if (this.imports.contains (import_name))
						continue;
					else this.imports ~= import_name;

				color = grey (0.5);
			}

		bool opEquals (Module that) const
			{/*...}*/
				return this.id == that.id;
			}
	}
bool is_package (Module mod)
	{/*...}*/
		return mod.path.contains (`package`);
	}
bool has_cyclic_dependencies (Module root)
	{/*...}*/
		return root.find_minimal_cycle.not!empty;
	}
Module[] find_minimal_cycle (Module node, Module[] path = [])
	{/*...}*/
		if (path.contains (node))
			return path;

		else return node.imported_modules
			.map!(mod => mod.find_minimal_cycle (path ~ node))
			.array.filter!(not!empty) // TODO .buffer.filter... to say do this, then buffer it, then do that.. and someday, map!(...).parallel_buffer.filter!(...)
			.select!(cycles => cycles.empty? [] : cycles.reduce!shortest);
	}
string connect_to (Module from, Module to, string append)
	{/*...}*/
		return "\t" ~from.dot.node~ ` -> ` ~to.dot.node~ append~ `;`"\n";
	}

auto module_name (File file)
	{/*...}*/
		auto module_decl = file.byLine.front.to!string;

		if (module_decl.not!startsWith (`module`))
			return file.name.retro.findSplitBefore (`/`)[0].text.retro.text;
		else return module_decl
			.findSplitAfter (`module `)[1]
			.findSplitBefore (`;`)[0]
			.to!string;
	}
auto imports (File file)
	{/*...}*/
		string tabs;
		string[] imports;
		bool in_unittest_block = false;

		foreach (line; file.byLine)
			{/*...}*/
				if (not!in_unittest_block && line.contains (`unittest`))
					{/*...}*/
						in_unittest_block = true;
						tabs = line.findSplitBefore (`in_unittest`)[0].to!string;
					}
				else if (in_unittest_block)
					{/*...}*/
						if (line.contains (tabs~ `}`))
							{/*...}*/
								tabs = ``;
								in_unittest_block = false;
							}
					}
				else if (line.contains (`import `))
					imports ~= line
						.findSplitAfter (`import`)[1]
						.findSplitBefore (`;`)[0]
						.findSplitBefore (`:`)[0]
						.strip
						.to!string;
			}
		
		return imports;
	}
bool is_package (File file)
	{/*...}*/
		return file.name.contains (`package`);
	}

auto source_files (string root_directory)
	{/*...}*/
		return dirEntries (root_directory, SpanMode.depth)
			.map!(entry => entry.name)
			.filter!(name => name.endsWith (`.d`));
	}
auto dependency_graph (string root_directory)
	{/*...}*/
		Module[] modules;

		auto files = source_files (root_directory).array;
		files.randomShuffle;

		foreach (path; files)
			modules ~= new Module (File (path, "r"));
			
		foreach (mod; modules)
			{/*connect imports}*/
				foreach (name; mod.imports)
					mod.imported_modules ~= modules.filter!(m => name == m.name).array;

				if (not (mod.is_package)) // BUG mod.not!is_package doesn't work, why?
					mod.enclosing_package = modules
						.filter!(mod => mod.is_package)
						.filter!(pack => mod.name.contains (pack.name))
						.select!(
							modules => modules.empty? null
							: modules.reduce!((a,b) => a.name.length > b.name.length? a:b)
						);
			}

		return modules;
	}

///////////////////

auto shortest (R,S)(R r, S s) // REFACTOR
	if (allSatisfy!(hasLength, R, S))
	{/*...}*/
		return r.length < s.length? r:s;
	}

auto concatenate (R,S)(R r, S s) // REFACTOR
	if (allSatisfy!(isInputRange, R, S))
	{/*...}*/
		return r ~ s;
	}

///////////////////

version (generate_dependency_graph) void main ()
	{/*...}*/
		auto modules = dependency_graph (`./source/`);

		{/*assign colors}*/
			auto packages = modules.filter!(mod => mod.is_package);
			auto n_colors = packages.count;

			foreach (pkg, color; zip (packages, rainbow (n_colors)))
				{/*...}*/
					pkg.color = color;

					foreach (mod; modules
						.filter!(mod => mod.enclosing_package is pkg)
					)
						mod.color = color.alpha (0.5);

				}
		}
		{/*write .dot file}*/
			string dot_file = `digraph dependencies {`"\n";

			foreach (mod; modules)
				{/*...}*/
					void write_node_property (string property)
						{/*...}*/
							dot_file ~= "\t" ~mod.dot.node ~ property~ `;` "\n";
						}

					with (mod.dot)
						{/*...}*/
							write_node_property (label);
							write_node_property (color);
							write_node_property (style);
							write_node_property (shape);
						}

					foreach (dep; mod.imported_modules)
						if (dep.has_cyclic_dependencies)
							dot_file ~= dep.connect_to (mod, `[color="#88000066"]`);
						else dot_file ~= dep.connect_to (mod, `[color="#000000"]`);
				}

			dot_file ~= modules.map!(mod => mod.find_minimal_cycle)
				.filter!(not!empty)
				.array.select!(cycles => cycles.empty? [] : cycles.reduce!shortest)
				.adjacent_pairs.map!((a,b) => a.connect_to (b, `[color="#ff0000", penwidth=6]`))
				.array.reduce!concatenate (``);
			
			dot_file ~= `}`;

			File (`temp.dot`, `w`).write (dot_file);
		}
		{/*view graph}*/
			executeShell (`dot -Tpdf temp.dot -o dependencies.pdf`);
			executeShell (`rm temp.dot`);
			executeShell (`zathura dependencies.pdf`);
			//executeShell (`rm dependencies.pdf`);
		}
	}
