/////////////////////////////////  MIT LICENSE  ////////////////////////////////

//  Copyright (C) 2022 Alex Gunter <akg7634@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.


/*
 *  This is a minimalist shader for changing the aspect ratio of your game.
 *
 *  It's primarily designed for games that stretch to fill the screen.
 *  For example, if you try to run some games at 2560x1440 on a 3440x1440 monitor,
 *  the game will stretch itself horizontally to fill the entire scren.
 *
 *  This shader lets you "unstretch" the game, so it has the correct aspect ratio
 *  on any monitor. You can also shift the output side-to-side if you want.
 */


#include "ReShade.fxh"

#define macro_max(c, d) (c) * ((int) ((c) >= (d))) + (d) * ((int) ((c) < (d)))

static const int2 BUFFER_SIZE = int2(BUFFER_WIDTH, BUFFER_HEIGHT);

uniform uint2 display_resolution <
	ui_label = "Displayed Resolution";
	ui_tooltip = "The true size of the game's window. Set to your monitor's resolution if in fullscreen.";
	ui_type = "input";
	ui_min = 1;
	ui_step = 1;
> = BUFFER_SIZE;

uniform float2 content_aspect_ratio <
	ui_label = "Desired Aspect Ratio";
	ui_tooltip = "The aspect ratio you want to downscale to.";
	ui_type = "input";
	ui_min = 1;
> = float2(16, 9);

uniform bool rescale_y_axis <
	ui_label = "Rescale Y Axis";
	ui_tooltip = "Toggles between unstretching horizontally or vertically";
> = false;

uniform int output_offset < 
	ui_label = "Offset Output";
	ui_tooltip = "Shifts the output if desired";

	ui_type = "drag";
	ui_step = 1;
	ui_min = -macro_max(BUFFER_WIDTH, BUFFER_HEIGHT)/2;
	ui_max = macro_max(BUFFER_WIDTH, BUFFER_HEIGHT)/2;
> = 0;


void unstretchPS(
	in const float4 pos : SV_Position,
	in const float2 texcoord : TEXCOORD0,

	out float4 color : SV_Target
) {
	float2 offset_xy = (rescale_y_axis ? float2(0, 1) : float2(1, 0)) * output_offset * rcp(BUFFER_SIZE);
	float2 source_coord = texcoord - offset_xy;

	float dr = float(display_resolution.x) / float(display_resolution.y);
	float cr = content_aspect_ratio.x / content_aspect_ratio.y;

	float is_in_boundary;
	float2 texcoord_uncropped;
	[branch]
	if (rescale_y_axis) {
		float scaling_factor = dr / cr;

		float upper_bound = (1 - scaling_factor) * 0.5;
		float lower_bound = 1 - upper_bound;

		is_in_boundary = float(source_coord.y >= upper_bound && source_coord.y <= lower_bound);
		float coord_adj = (source_coord.y - 0.5) / scaling_factor + 0.5;
		texcoord_uncropped = float2(source_coord.x, coord_adj);
	}
	else {
		float scaling_factor = cr / dr;

		float left_bound = (1 - scaling_factor) * 0.5;
		float right_bound = 1 - left_bound;

		is_in_boundary = float(source_coord.x >= left_bound && source_coord.x <= right_bound);
		float coord_adj = (source_coord.x - 0.5) / scaling_factor + 0.5;
		texcoord_uncropped = float2(coord_adj, source_coord.y);
	}

	float4 raw_color = tex2D(ReShade::BackBuffer, texcoord_uncropped);
	color = lerp(float4(0, 0, 0, 1), raw_color, is_in_boundary);
}

technique Unstretch
{
	pass unstretchPass
	{
		VertexShader = PostProcessVS;
		PixelShader = unstretchPS;
	}
}