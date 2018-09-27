
struct VS_PARTICLE {
	float3 Origin : ORIGIN;
	float3 Velocity : VELOCITY;
	float3 Acceleration : ACCELERATION;
	float Time : TIME;
	int Color : COLOR;
	float Alpha : ALPHA;
};

struct GS_PARTICLE {
	float3 Origin : ORIGIN;
	float4 Color : COLOR;
};

struct VS_DRAWSPRITE {
	float2 XYOffset : XYOFFSET;
};

struct PS_DRAWSPRITE {
	float4 Position : SV_POSITION;
	float2 TexCoord : TEXCOORD;
};

struct PS_PARTICLE {
	float4 Position : SV_POSITION;
	float4 Color : COLOUR;
	float2 Offsets : OFFSETS;
};

struct PS_NULL {
	float4 Position : SV_POSITION;
	float3 Normal : NORMAL;
};

#ifdef VERTEXSHADER
static const float2 SpriteTexCoords[4] = {float2 (0, 1), float2 (0, 0), float2 (1, 0), float2 (1, 1)};

PS_DRAWSPRITE SpriteVS (VS_DRAWSPRITE vs_in, uint vertexId : SV_VertexID)
{
	PS_DRAWSPRITE vs_out;

	vs_out.Position = mul (mvpMatrix, float4 ((viewRight * vs_in.XYOffset.y) + (viewUp * vs_in.XYOffset.x) + SpriteOrigin, 1.0f));
	vs_out.TexCoord = SpriteTexCoords[vertexId];

	return vs_out;
}

GS_PARTICLE ParticleVS (VS_PARTICLE vs_in)
{
	GS_PARTICLE vs_out;

	// move the particle in a framerate-independent manner
	vs_out.Origin = vs_in.Origin + (vs_in.Velocity + vs_in.Acceleration * vs_in.Time) * vs_in.Time;

	// copy over colour
	vs_out.Color = float4 (QuakePalette.Load (vs_in.Color).rgb, vs_in.Alpha);

	return vs_out;
}

float4 BeamVS (float4 Position: POSITION) : SV_POSITION
{
	return mul (LocalMatrix, Position);
}

PS_NULL NullVS (float3 Position : POSITION, float3 Normal : NORMAL)
{
	PS_NULL vs_out;

	vs_out.Position = mul (LocalMatrix, float4 (Position * 16.0f, 1));
	vs_out.Normal = Normal;

	return vs_out;
}
#endif


#ifdef GEOMETRYSHADER
PS_PARTICLE GetParticleVert (point GS_PARTICLE gs_in, float2 Offsets, float ScaleUp)
{
	PS_PARTICLE gs_out;

	// compute new particle origin
	float3 Position = gs_in.Origin + (viewRight * Offsets.x + viewUp * Offsets.y) * ScaleUp;

	// and write it out
	gs_out.Position = mul (mvpMatrix, float4 (Position, 1.0f));
	gs_out.Color = gs_in.Color;
	gs_out.Offsets = Offsets;

	return gs_out;
}

void ParticleCommonGS (point GS_PARTICLE gs_in, inout TriangleStream<PS_PARTICLE> gs_out, float TypeScale, float HackUp)
{
	// hack a scale up to keep particles from disapearing
	float ScaleUp = (1.0f + dot (gs_in.Origin - viewOrigin, viewForward) * HackUp) * TypeScale;

	gs_out.Append (GetParticleVert (gs_in, float2 (-1, -1), ScaleUp));
	gs_out.Append (GetParticleVert (gs_in, float2 (-1,  1), ScaleUp));
	gs_out.Append (GetParticleVert (gs_in, float2 ( 1, -1), ScaleUp));
	gs_out.Append (GetParticleVert (gs_in, float2 ( 1,  1), ScaleUp));
}

[maxvertexcount (4)]
void ParticleCircleGS (point GS_PARTICLE gs_in[1], inout TriangleStream<PS_PARTICLE> gs_out)
{
	ParticleCommonGS (gs_in[0], gs_out, 0.666f, 0.002f);
}


[maxvertexcount (4)]
void ParticleSquareGS (point GS_PARTICLE gs_in[1], inout TriangleStream<PS_PARTICLE> gs_out)
{
	ParticleCommonGS (gs_in[0], gs_out, 0.5f, 0.002f);
}
#endif


#ifdef PIXELSHADER
float4 SpritePS (PS_DRAWSPRITE ps_in) : SV_TARGET0
{
	float4 diff = GetGamma (mainTexture.Sample (mainSampler, ps_in.TexCoord));
	return float4 (diff.rgb, diff.a * SpriteAlpha);
}

float4 ParticleCirclePS (PS_PARTICLE ps_in) : SV_TARGET0
{
	// procedurally generate the particle dot for good speed and per-pixel accuracy at any scale
	return GetGamma (float4 (ps_in.Color.rgb, saturate (ps_in.Color.a * (1.0f - dot (ps_in.Offsets, ps_in.Offsets)))));
}

float4 ParticleSquarePS (PS_PARTICLE ps_in) : SV_TARGET0
{
	// procedurally generate the particle dot for good speed and per-pixel accuracy at any scale
	return GetGamma (ps_in.Color);
}

float4 BeamPS (float4 Position: SV_POSITION) : SV_TARGET0
{
	return GetGamma (float4 (ShadeColor, AlphaVal));
}

float4 NullPS (PS_NULL ps_in) : SV_TARGET0
{
	float shadedot = dot (normalize (ps_in.Normal), normalize (float3 (1.0f, 1.0f, 1.0f)));
	return GetGamma (float4 (ShadeColor * max (shadedot + 1.0f, (shadedot * 0.2954545f) + 1.0f), AlphaVal));
}
#endif

