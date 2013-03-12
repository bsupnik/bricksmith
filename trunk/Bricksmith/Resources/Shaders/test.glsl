#line 1

varying vec2	tex_coord;
varying float	tex_mix;

varying vec3	normal_eye;
varying vec4	position_eye;

#if VSHADER

	attribute	vec4	position;
	attribute	vec3	normal;
	attribute	vec4	color;

	attribute	vec4	transform_x;
	attribute	vec4	transform_y;
	attribute	vec4	transform_z;
	attribute	vec4	transform_w;
	attribute	vec4	color_current;
	attribute	vec4	color_compliment;
	attribute	float	texture_mix;
	
	void main (void)
	{
		vec4	pos_obj = vec4(
								dot(position, transform_x),
								dot(position, transform_y),
								dot(position, transform_z),
								dot(position, transform_w));

		vec3	norm_obj = vec3(
								dot(normal, transform_x.xyz),
								dot(normal, transform_y.xyz),
								dot(normal, transform_z.xyz));
	
				normal_eye = normalize(gl_NormalMatrix * norm_obj);
		vec4	eye_pos = gl_ModelViewMatrix * pos_obj;
		gl_Position = gl_ProjectionMatrix * eye_pos;
		position_eye = eye_pos;

		vec4	col = color;
		if (col.a == 0.0)
		{
			col = mix(color_current,color_compliment, col.r);
		}
		gl_FrontColor.a = col.a;
		gl_FrontColor.rgb = col.rgb;
				 
		if(normal == vec3(0))
			gl_FrontColor = col;
			
//		gl_FrontColor.rgb = norm_obj;

			vec4	eye_plane_s = gl_ObjectPlaneS[0];
			vec4	eye_plane_t = gl_ObjectPlaneT[0];
				 
		tex_coord = vec2(
					dot(eye_plane_s, position),
					dot(eye_plane_t, position));
					
		tex_mix = texture_mix;
	}

#endif

#if FSHADER

	uniform sampler2D	u_tex;

	void main()
	{
		vec3 normal = normalize(normal_eye);
		vec4 final_color = gl_Color;
		final_color.rgb *= 			
				(gl_LightSource[0].diffuse.rgb * max(0.0,dot(normal, gl_LightSource[0].position.xyz)) +
				 gl_LightSource[1].diffuse.rgb * max(0.0,dot(normal, gl_LightSource[1].position.xyz)) +
				 gl_LightModel.ambient.rgb);
	

//		float hdot = max(0.0,dot(gl_LightSource[0].position.xyz,normalize(
//				reflect(position_eye.xyz,normal)		
//				)));
//		final_color.rgb += pow(hdot,128.0);
	
	
	
	
	
		vec4 tex_color = texture2D(u_tex, tex_coord);
		gl_FragColor = 
			mix(
			final_color,
			vec4(mix(final_color.rgb,tex_color.rgb,tex_color.a),gl_Color.a),
			tex_mix);
	}

#endif
