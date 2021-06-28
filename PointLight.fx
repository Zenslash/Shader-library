

/*******************Resources********************/

#define FLIP_TEXTURE_Y 1

cbuffer CBufferPerFrame
{
	float4 AmbientColor : AMBIENT <
		string UIName = "Ambient Light";
		string UIWidget = "Color";
	> = {1.0f, 1.0f, 1.0f, 1.0f};
	
	float4 LightColor : COLOR <
		string Object = "LightColor0";
		string UIName = "Light Color";
		string UIWidget = "Color";
	> = {1.0f, 1.0f, 1.0f, 1.0f};
	
	float3 LightPosition : POSITION <
		string Object = "PointLight0";
		string UIName = "Light Position";
		string Space = "World";
	> = {0.0f, 0.0f, -1.0f};
	
	float LightRadius <
		string UIName = "Light Radius";
		string UIWidget = "slider";
		float UIMin = 0.0;
		float UIMax = 100.0;
		float UIStep = 1.0;
	> = {10.0f};
	
	float3 CameraPosition : CAMERAPOSITION < 
		string UIWidget = "None"; > ;
}

cbuffer CBufferPerObject
{
	float4x4 WorldViewProjection : WORLDVIEWPROJECTION< string UIWidget = "None";>;
	float4x4 World : WORLD < string UIWidget = "None"; >;
	
	float4 SpecularColor : SPECULAR <
		string UIName = "Specular Color";
		string UIWidget = "Color";
	> = {1.0f, 1.0f, 1.0f, 1.0f};
	float SpecularPower : SPECULARPOWER <
		string UINname = "Specular Power";
		string UIWidget = "slider";
		float UIMin = 1.0;
		float UIMax = 255.0;
		float UIStep = 1.0;
	> = {25.0f};
}

RasterizerState DisableCulling
{
	CullMode = NONE;
};

Texture2D ColorTexture <
	string ResourceName = "default_color.dds";
	string UIName = "Color Texture";
	string ResourceType = "2D";
>;

SamplerState ColorSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = WRAP;
	AddressV = WRAP;
};

/**********************Structs**************************/

struct VS_INPUT
{
	float4 ObjectPosition : POSITION;
	float2 TextureCoordinate : TEXCOORD;
	float3 Normal : NORMAL;
};
struct VS_OUTPUT
{
	float4 Position : SV_Position;
	float3 Normal : NORMAL;
	float2 TextureCoordinate : TEXCOORD;
	float4 LightDirection : TEXCOORD1;
	float3 ViewDirection : TEXCOORD2;
};

/***********************Utility Funcs*******************/
float2 get_corrected_texture_coordinate(float2 textureCoordinate)
{
	#if FLIP_TEXTURE_Y
		return float2(textureCoordinate.x, 1.0 - textureCoordinate.y);
	#else
		return textureCoordinate;
	#endif
}

float3 get_vector_color_contribution(float4 light, float3 color)
{
	return light.rgb * light.a * color;
}
float3 get_scalar_color_contribution(float4 light, float color)
{
	return light.rgb * light.a * color;
}

/***********************Vertex shader*******************/
VS_OUTPUT vertex_shader(VS_INPUT IN)
{
	VS_OUTPUT OUT = (VS_OUTPUT)0;
	
	OUT.Position = mul(IN.ObjectPosition, WorldViewProjection);
	OUT.TextureCoordinate = get_corrected_texture_coordinate(IN.TextureCoordinate);
	OUT.Normal = normalize(mul(float4(IN.Normal, 0), World).xyz);
	
	float3 worldPosition = mul(IN.ObjectPosition, World).xyz;
	float3 lightDirection = LightPosition - worldPosition;
	OUT.ViewDirection = normalize(CameraPosition - worldPosition);
	OUT.LightDirection.xyz = normalize(lightDirection);
	OUT.LightDirection.w = saturate(1.0f - (length(lightDirection) / LightRadius));
	
	return OUT;
}
float4 pixel_shader(VS_OUTPUT IN) : SV_Target
{
	float4 OUT = (float4)0;
	
	float3 normal = normalize(IN.Normal);
	float3 lightDirection = normalize(IN.LightDirection);
	float3 viewDirection = normalize(IN.ViewDirection);
	float n_dot_l = dot(lightDirection, normal);
	float3 halfVector = normalize(lightDirection + viewDirection);
	float n_dot_h = dot(normal, halfVector);
	
	float4 color = ColorTexture.Sample(ColorSampler, IN.TextureCoordinate);
	float4 lightCoef = lit(n_dot_l, n_dot_h, SpecularPower);
	
	float3 ambient = get_vector_color_contribution(AmbientColor, color.rgb);
	
	float3 diffuse = get_vector_color_contribution(LightColor, lightCoef.y * color.rgb) * IN.LightDirection.w;
	float3 specular = get_scalar_color_contribution(SpecularPower, min(lightCoef.z, color.w)) * IN.LightDirection.w;
	
	OUT.rgb = ambient + diffuse + specular;
	OUT.a = color.a;
	
	return OUT;
}

technique10 main10
{
	pass p0
	{
		SetVertexShader(CompileShader(vs_4_0, vertex_shader()));
		SetGeometryShader(NULL);
		SetPixelShader(CompileShader(ps_4_0, pixel_shader()));
		
		SetRasterizerState(DisableCulling);
	}
}