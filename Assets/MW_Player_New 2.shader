Shader "MW/Player_New2" {
    Properties {
        _MainTex ("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)	//贴图变色
		_BumpScale("BumpScale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5 //光泽度(1-Roughness)，与常见的粗糙度等价，只是数值上更为直观，值越小越粗糙
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0 //金属度，这两个值只有在没有_MetallicGlossMap贴图的情况下生效
		//_MetallicGlossMap("Metallic", 2D) = "white" {}	//金属度与光泽度贴图，金属度在r通道上，光泽度在a通道上

		_MetallicMap("Metallic", 2D) = "white" {}	
		_GlossMap("Smoothness", 2D) = "white" {}	

		_EmissionColor("Color", Color) = (1,1,1)
		_EmissionMap("Emission", 2D) = "white" {}
		_FresnelScale ("Fresnel Scale", Range(0, 1)) = 0.5
		_FresnelPower ("Fresnel Power", Range(0, 1)) = 0.2
		_Cubemap ("Reflection CubeMap", Cube) = "_SkyBox" {} 
		//这边的输出 = (PBSResult * _Realistic + Texture * _RawTexture) * _Power
		//通过控制Realistic来调节物理渲染的影响程度，控制RawTexture来提亮整体的颜色，提高对比度
		//Realistic = 1，RawTexture = 0时为纯物理渲染的结果
		//Realistic = 0，RawTexture = 1时为原始贴图的颜色                                                                                                                                                                                                                                                                                                                                                                                                                                                        
		_Realistic("Realistic(物理渲染比例)", Range(0.0, 2.0)) = 1.0
		_RawTexture("RawTex(原始贴图比例)", Range(0.0, 1.0)) = 1.0
		_Power("Power(整体提亮)", Range(1.0, 2.0)) = 1.0
		_SpecularPower("SpecularPower", Range(1.0, 5.0)) = 1.0
    }

	CGINCLUDE
		#pragma multi_compile_fog

		#include "UnityCG.cginc"
		#include "AutoLight.cginc"
		#include "UnityStandardBRDF.cginc"
		#include "UnityGlobalIllumination.cginc"
		//PBR所需的参数
		sampler2D   _MainTex;
		float4		_MainTex_ST;
		sampler2D	_BumpMap;
		half		_BumpScale;

		half4		_Color;

		sampler2D	_MetallicMap;
		sampler2D	_GlossMap;
		//sampler2D	_MetallicGlossMap;

		half		_Metallic;
		half		_Glossiness;

		//sampler2D	_OcclusionMap;
		//half		_OcclusionStrength;

		half4 		_EmissionColor;
		sampler2D	_EmissionMap;

		fixed _FresnelScale;
		fixed _FresnelPower;
		samplerCUBE _Cubemap;

		half _Realistic;
		half _RawTexture;
		half _Power;
		half _SpecularPower;
		//顶点着色器输入
		struct VertexInput
		{
			float4 vertex	: POSITION;
			half3 normal	: NORMAL;
			float2 uv0		: TEXCOORD0;
			float2 uv1		: TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
			float2 uv2		: TEXCOORD2;
#endif
			half4 tangent	: TANGENT;
		};
		//顶点输出到像素着色器
		struct VertexOutputForwardBase
		{
			float4 pos							: SV_POSITION;
			float4 tex							: TEXCOORD0;
			half3 eyeVec 						: TEXCOORD1;
			half4 tangentToWorldAndParallax[3]	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax]
			half4 ambientOrLightmapUV			: TEXCOORD5;	// SH or Lightmap UV
			SHADOW_COORDS(6)
			UNITY_FOG_COORDS(7)
			half3 reflUVW				: TEXCOORD8;
		};

		half3 Albedo(float4 texcoords)
		{
			half3 albedo = _Color.rgb * tex2D (_MainTex, texcoords.xy).rgb;
			return albedo;
		}
			
		//
		half2 MetallicGloss(float2 uv)
		{
			half2 mg;
		//#ifdef _METALLICGLOSSMAP
			//mg.xy = tex2D(_MetallicGlossMap, uv.xy).ra;

			mg.x = tex2D(_MetallicMap, uv.xy).r;
			mg.y = (1 - tex2D(_GlossMap, uv.xy).r) * _Glossiness;
			//mg.y = _Glossiness;
		//#yuyaaa
			//mg = half2(_Metallic, _Glossiness);
		//#endif
			//mg = half2(_Metallic, _Glossiness);

			return mg;
		}

		half3 Emission(float2 uv)
		{
		//#ifndef _EMISSION
		//	return 0;
		//#else
			return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
		//#endif
		}

		//ShaderLab中片段着色器用来传递数据的通用结构
		struct FragmentCommonData
		{
			half3 diffColor, specColor;
			// Note: oneMinusRoughness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
			// Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
			half oneMinusReflectivity, oneMinusRoughness;
			half3 normalWorld, eyeVec, posWorld;
			half alpha;
			half3 reflUVW;

		#if UNITY_STANDARD_SIMPLE
			half3 tangentSpaceNormal;
		#endif
		};

		#define UNITY_SETUP_BRDF_INPUT MetallicSetup
		inline FragmentCommonData MetallicSetup (float4 i_tex)
		{
			half2 metallicGloss = MetallicGloss(i_tex.xy);
			half metallic = metallicGloss.x;
			half oneMinusRoughness = metallicGloss.y;		// this is 1 minus the square root of real roughness m.

			half oneMinusReflectivity;
			half3 specColor;
			half3 diffColor = DiffuseAndSpecularFromMetallic (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

			FragmentCommonData o = (FragmentCommonData)0;
			o.diffColor = diffColor;
			o.specColor = specColor;
			o.oneMinusReflectivity = oneMinusReflectivity;
			o.oneMinusRoughness = oneMinusRoughness;
			return o;
		} 

		inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
		{
			UnityGI o_gi;
			ResetUnityGI(o_gi);
			o_gi.light = light;
			o_gi.light.color *= atten;
			return o_gi;
		}

		inline UnityGI FragmentGI(FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light)
		{
			return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
		}

		//-------------------------------------------------------------------------------------
		// counterpart for NormalizePerPixelNormal
		// skips normalization per-vertex and expects normalization to happen per-pixel
		// 这里不进行标准化而放到逐像素中处理
		half3 NormalizePerVertexNormal(float3 n) // takes float to avoid overflow
		{
			return n; // will normalize per-pixel instead
		}
		//像素着色器中对法线进行标准化
		half3 NormalizePerPixelNormal(half3 n)
		{
			return normalize(n);
		}

#define IN_VIEWDIR4PARALLAX(i) half3(0,0,0)
#define IN_VIEWDIR4PARALLAX_FWDADD(i) half3(0,0,0)
#define IN_WORLDPOS(i) half3(0,0,0)

#define FRAGMENT_SETUP(x) FragmentCommonData x = FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndParallax, IN_WORLDPOS(i));

		half Alpha(float2 uv)
		{
			return tex2D(_MainTex, uv).a * _Color.a;
		}

		half3 NormalInTangentSpace(float4 texcoords)
		{
			half3 normalTangent = UnpackScaleNormal(tex2D(_BumpMap, texcoords.xy), _BumpScale);
			return normalTangent;
		}

		half3 PerPixelWorldNormal(float4 i_tex, half4 tangentToWorld[3])
		{
			half3 tangent = tangentToWorld[0].xyz;
			half3 binormal = tangentToWorld[1].xyz;
			half3 normal = tangentToWorld[2].xyz;

			half3 normalTangent = NormalInTangentSpace(i_tex);
			half3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
			return normalWorld;
		}

		inline FragmentCommonData FragmentSetup(float4 i_tex, half3 i_eyeVec, half3 i_viewDirForParallax, half4 tangentToWorld[3], half3 i_posWorld)
		{
			//i_tex = Parallax(i_tex, i_viewDirForParallax);
			half alpha = Alpha(i_tex.xy);
//#if defined(_ALPHATEST_ON)
//				clip(alpha - _Cutoff);
//#endif
			FragmentCommonData o = UNITY_SETUP_BRDF_INPUT(i_tex);
			o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
			o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
			o.posWorld = i_posWorld;

			// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
			o.diffColor = PreMultiplyAlpha(o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
			return o;
		}
// ------------------------------------------------------------------
//  Base forward pass (directional light, emission, lightmaps, ...)
		float4 TexCoords(VertexInput v)
		{
			float4 texcoord;
			texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
			//texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
			return texcoord;
		}

		VertexOutputForwardBase vertForwardBase(VertexInput v)
		{
			VertexOutputForwardBase o;
			UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o);

			float4 posWorld = mul(_Object2World, v.vertex);
#if UNITY_SPECCUBE_BOX_PROJECTION
			o.posWorld = posWorld.xyz;
#endif
			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
			o.tex = TexCoords(v);
			o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);

			float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

			float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
			o.tangentToWorldAndParallax[0].xyz = tangentToWorld[0];
			o.tangentToWorldAndParallax[1].xyz = tangentToWorld[1];
			o.tangentToWorldAndParallax[2].xyz = tangentToWorld[2];

			//We need this for shadow receving
			TRANSFER_SHADOW(o);

			o.ambientOrLightmapUV = 0;//VertexGIForward(v, posWorld, normalWorld);
			o.reflUVW = reflect(o.eyeVec, normalWorld);

			UNITY_TRANSFER_FOG(o, o.pos);
			return o;
		}

		UnityLight MainLight(half3 normalWorld)
		{
			UnityLight l;
			l.color = _LightColor0.rgb;
			l.dir = _WorldSpaceLightPos0.xyz;
			l.ndotl = LambertTerm(normalWorld, l.dir);
			return l;
		}

		half Occlusion(float2 uv)
		{
			return 1.0f;
//#if (SHADER_TARGET < 30)
//				// SM20: instruction count limitation
//				// SM20: simpler occlusion
//				return tex2D(_OcclusionMap, uv).g;
//#else
//				half occ = tex2D(_OcclusionMap, uv).g;
//				return LerpOneTo(occ, _OcclusionStrength);
//#endif
		}

		#define UNITY_BRDF_PBS BRDF3_Unity_PBS

		half4 fragForwardBase(VertexOutputForwardBase i)  
		{
			FRAGMENT_SETUP(s)
			s.reflUVW = i.reflUVW;
			UnityLight mainLight = MainLight(s.normalWorld);
			half atten = SHADOW_ATTENUATION(i);
			half occlusion = Occlusion(i.tex.xy);
			UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
			//return fixed4(gi.light.color, 1.0f);
			//return half4(s.specColor, 1);
			half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
			//添加cubeMap模拟环境反射
			fixed3 reflection = texCUBE(_Cubemap, s.reflUVW).rgb * _Glossiness * _Metallic;

			fixed fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(-s.eyeVec, s.normalWorld), 5);
			c.rgb += reflection*saturate(fresnel)*_FresnelPower;//saturate(fresnel)
			//return c;
			//这里如果_Realistic = 0,_Power = 1,则结果为默认的PBS渲染结果
			//叠加这个原贴图来整体提亮	
			half4 tex = tex2D(_MainTex, i.tex.xy);
			c = (c * _Realistic + tex * _RawTexture) * _Power;
			UNITY_APPLY_FOG(i.fogCoord, c.rgb);
			half3 emission = Emission(i.tex.xy);

			half4 final = half4(emission + c.rgb, 1);
			return final;
		}

		half4 fragForwardAdd(VertexOutputForwardBase i)  
		{
			FRAGMENT_SETUP(s)
			s.reflUVW = i.reflUVW;
			UnityLight mainLight = MainLight(s.normalWorld);
			half atten = SHADOW_ATTENUATION(i);
			half occlusion = Occlusion(i.tex.xy);
			UnityGI gi = FragmentGI(s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
			//return fixed4(gi.light.color, 1.0f);
			half4 c = UNITY_BRDF_PBS(s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
			return c;
		}

		VertexOutputForwardBase vertBase(VertexInput v) 
		{ 
			return vertForwardBase(v); 
		}

		half4 fragBase(VertexOutputForwardBase i) : SV_Target
		{ 
			return fragForwardBase(i); 
		}		

		half4 fragAdd(VertexOutputForwardBase i) : SV_Target
		{ 
			return fragForwardAdd(i); 
		}	
	ENDCG

    SubShader {
		//普通显示
		Pass{
			Tags 
			{
				"LightMode" = "ForwardBase"
			}
			CGPROGRAM
			//#pragma vertex vert
			//#pragma fragment frag
			#pragma vertex vertBase
			#pragma fragment fragBase
			ENDCG
		}
		Pass{
			Tags 
			{
				"LightMode" = "ForwardAdd"
			}
			Blend One One//通过这种混合方式消去ForwardBase的影响 
			CGPROGRAM
			//#pragma vertex vert
			//#pragma fragment frag
			#pragma vertex vertBase
			#pragma fragment fragAdd
			ENDCG
		}
		// Pass to render object as a shadow caster, required to write to depth texture
		Pass 
		{
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
		}
    }

	CustomEditor "StandardShaderGUI"
}
