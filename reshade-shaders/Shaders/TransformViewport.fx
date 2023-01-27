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
 *  This is a shader for shrinking, stretching, and shifting your game's content.
 *
 *  It's primarily designed to pair with CRT and Arcade overlays, so you can
 *  pair any game with any overlay.
 *
 *  Use the input_resolution and input_offset settings to grab the portion of
 *  your screen that contains your game, so you can crop out any letterboxing
 *  or overlays baked into the game.
 *
 *  Use the output_resolution and output_offset settings to stretch or shrink
 *  your game and position it wherever you'd like.
 */


#include "ReShade.fxh"


static const int2 BUFFER_SIZE = int2(BUFFER_WIDTH, BUFFER_HEIGHT);

#ifndef CONTENT_BOXES_VISIBLE
    #define CONTENT_BOXES_VISIBLE 0
#endif


uniform uint2 input_resolution <
    ui_label = "Input Resolution XY";
    ui_type = "drag";
    ui_min = 1;
    ui_step = 1;

> = BUFFER_SIZE;
uniform float2 input_offset <
	ui_label = "Input Offset XY";

	ui_type = "drag";
	ui_step = 1;
	ui_min = -0.5 * BUFFER_SIZE;
	ui_max = 0.5 * BUFFER_SIZE;

> = 0;

uniform uint2 output_resolution <
    ui_label = "Output Resolution XY";

    ui_type = "drag";
    ui_min = 1;
    ui_step = 1;
    
    ui_spacing = 2;
> = BUFFER_SIZE;
uniform float2 output_offset <
	ui_label = "Output Offset XY";

	ui_type = "drag";
	ui_step = 1;
	ui_min = -0.5 * BUFFER_SIZE;
	ui_max = 0.5 * BUFFER_SIZE;
> = 0;


void transformPS(
	in float4 pos : SV_Position,
	in float2 outcoord : TEXCOORD0,

	out float4 color : SV_Target
) {
    float2 output_scale = float2(output_resolution) / BUFFER_SIZE;

    float2 input_offset = float2(1, -1) * input_offset / BUFFER_SIZE;
    float2 output_offset = float2(1, -1) * output_offset / BUFFER_SIZE;
    float2 rescaling_factor = float2(input_resolution) / float2(output_resolution);

    float2 incoord = outcoord - output_offset;
    incoord = 2 * (incoord - 0.5);
    incoord *= rescaling_factor;
    incoord = incoord * 0.5 + 0.5;
    incoord += input_offset;

    float4 bounds;
    // x: left, y: right, z: upper, w: lower
    bounds.xz = (1 - output_scale) * 0.5;
    bounds.yw = 1 - bounds.xz;
    bounds += output_offset.xxyy;
    
	bool is_in_boundary = (
        outcoord.x >= bounds.x && outcoord.x <= bounds.y &&
        outcoord.y >= bounds.z && outcoord.y <= bounds.w
    );

	float4 raw_color = tex2D(ReShade::BackBuffer, incoord);
	color = lerp(float4(0, 0, 0, 1), raw_color, is_in_boundary);
}

#if CONTENT_BOXES_VISIBLE
    #ifndef CONTENT_BOX_INSCRIBED
        #define CONTENT_BOX_INSCRIBED 1
    #endif

    #ifndef CONTENT_BOX_THICKNESS
        #define CONTENT_BOX_THICKNESS 5
    #endif

    #ifndef CONTENT_BOX_COLOR_R
        #define CONTENT_BOX_COLOR_R 1.0
    #endif

    #ifndef CONTENT_BOX_COLOR_G
        #define CONTENT_BOX_COLOR_G 0.0
    #endif

    #ifndef CONTENT_BOX_COLOR_B
        #define CONTENT_BOX_COLOR_B 0.0
    #endif

    static const float2 line_thickness = float(CONTENT_BOX_THICKNESS) / BUFFER_SIZE;
    
    static const float4 input_box_color = float4(
        CONTENT_BOX_COLOR_R,
        CONTENT_BOX_COLOR_G,
        CONTENT_BOX_COLOR_B,
        1.0
    );
    static const float4 output_box_color = float4(1 - input_box_color.rgb, 1);

    void contentBoxPS(
        in float4 pos : SV_Position,
        in float2 texcoord : TEXCOORD0,

        out float4 color : SV_Target
    ) {
        float2 input_bounds_offset = float2(-1, 1) * input_offset / float2(BUFFER_SIZE);
        float2 input_radius = 0.5 * float2(input_resolution) / float2(BUFFER_SIZE);
        float4 input_bounds = float4(-1, 1, -1, 1) * input_radius.xxyy + 0.5 - input_bounds_offset.xxyy;

        float2 output_bounds_offset = float2(-1, 1) * output_offset / float2(BUFFER_SIZE);
        float2 output_radius = 0.5 * float2(output_resolution) / float2(BUFFER_SIZE);
        float4 output_bounds = float4(-1, 1, -1, 1) * output_radius.xxyy + 0.5 - output_bounds_offset.xxyy;

        #if CONTENT_BOX_INSCRIBED
            float4 in_outer_bounds = input_bounds;
            float4 in_inner_bounds = in_outer_bounds + float4(1, -1, 1, -1) * line_thickness.xxyy;
            float4 out_outer_bounds = output_bounds;
            float4 out_inner_bounds = out_outer_bounds + float4(1, -1, 1, -1) * line_thickness.xxyy;
        #else
            float4 in_inner_bounds = input_bounds;
            float4 in_outer_bounds = in_inner_bounds - float4(1, -1, 1, -1) * line_thickness.xxyy;
            float4 out_inner_bounds = output_bounds;
            float4 out_outer_bounds = out_inner_bounds - float4(1, -1, 1, -1) * line_thickness.xxyy;
        #endif

        bool is_inside_input_outerbound = (
            texcoord.x >= in_outer_bounds.x && texcoord.x <= in_outer_bounds.y &&
            texcoord.y >= in_outer_bounds.z && texcoord.y <= in_outer_bounds.w
        );
        bool is_outside_input_innerbound = (
            texcoord.x <= in_inner_bounds.x || texcoord.x >= in_inner_bounds.y ||
            texcoord.y <= in_inner_bounds.z || texcoord.y >= in_inner_bounds.w
        );
        bool is_inside_output_outerbound = (
            texcoord.x >= out_outer_bounds.x && texcoord.x <= out_outer_bounds.y &&
            texcoord.y >= out_outer_bounds.z && texcoord.y <= out_outer_bounds.w
        );
        bool is_outside_output_innerbound = (
            texcoord.x <= out_inner_bounds.x || texcoord.x >= out_inner_bounds.y ||
            texcoord.y <= out_inner_bounds.z || texcoord.y >= out_inner_bounds.w
        );


        if (is_inside_input_outerbound && is_outside_input_innerbound) {
            color = input_box_color;
        }
        else if (is_inside_output_outerbound && is_outside_output_innerbound) {
            color = output_box_color;
        }
        else {
            color = tex2D(ReShade::BackBuffer, texcoord);
        }
    }
#endif


technique TransformViewport
{
    #if CONTENT_BOXES_VISIBLE
        pass contentBoxPass
        {
            VertexShader = PostProcessVS;
            PixelShader = contentBoxPS;
        }
    #else
        pass unstretchPass
        {
            VertexShader = PostProcessVS;
            PixelShader = transformPS;
        }
    #endif
}