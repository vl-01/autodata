module evx.graphics.shader.basic;

private {/*imports}*/
	import evx.graphics.shader.program;
	import evx.graphics.color;

	import evx.math;
}

alias BasicShader = ShaderProgram!(
	VertexShader!(
		Input!(
			fvec[], `position`,		Init!(0,0),
		), q{
			gl_Position.xy = position;
		}
	),
	FragmentShader!(
		Input!(
			Color,  `color`,		Init!(1,0,1,1),
		),
		Output!(
			Color[], `frag_color`,
		), q{
			frag_color = color;
		}
	),
);
