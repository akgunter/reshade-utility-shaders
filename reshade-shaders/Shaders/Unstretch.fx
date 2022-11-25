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


#include "ReShade.fxh"

uniform uint2 display_resolution <
	ui_label = "Displayed Resolution";
	ui_tooltip = "The true size of the game's window. Set to your monitor's resolution if in fullscreen.";
	ui_type = "input";
	ui_min = 1;
	ui_step = 1;
> = uint2(BUFFER_WIDTH, BUFFER_HEIGHT);

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


void unstretchPS(
    in const float4 pos : SV_Position,
    in const float2 texcoord : TEXCOORD0,

    out float4 color : SV_Target
) {
	float dr = float(display_resolution.x) / float(display_resolution.y);
	float cr = content_aspect_ratio.x / content_aspect_ratio.y;
	
	float is_in_boundary;
	float2 texcoord_uncropped;
	[branch]
	if (rescale_y_axis) {
		float scaling_factor = dr / cr;
		
		float upper_bound = (1 - scaling_factor) * 0.5;
		float lower_bound = 1 - upper_bound;
	
		is_in_boundary = float(texcoord.y >= upper_bound && texcoord.y <= lower_bound);
		float coord_adj = (texcoord.y - 0.5) / scaling_factor + 0.5;
		texcoord_uncropped = float2(texcoord.x, coord_adj);
	}
	else {
		float scaling_factor = cr / dr;
		
		float left_bound = (1 - scaling_factor) * 0.5;
		float right_bound = 1 - left_bound;

		is_in_boundary = float(texcoord.x >= left_bound && texcoord.x <= right_bound);
		float coord_adj = (texcoord.x - 0.5) / scaling_factor + 0.5;
		texcoord_uncropped = float2(coord_adj, texcoord.y);
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