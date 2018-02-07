Shader "MAD/StandardV2"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 2.0)) = 0.5
		[Gamma] _Metallic("Metallic", Range(0.0, 2.0)) = 0.0
		_MetallicGlossMap("Metallic", 2D) = "white" {}
		_GlossStrength("GlossStrength", 2D) = "white" {}

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

		//_Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
		//_ParallaxMap ("Height Map", 2D) = "black" {}

		_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		//_OcclusionMap("Occlusion", 2D) = "white" {}

		_EmissionColor("Color", Color) = (0,0,0)
		_EmissionMap("Emission", 2D) = "white" {}
		
		//_DetailMask("Detail Mask", 2D) = "white" {}

		//_DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
		//_DetailNormalMapScale("Scale", Float) = 1.0
		//_DetailNormalMap("Normal Map", 2D) = "bump" {}

		//[Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0


		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}

	CGINCLUDE
		#define UNITY_SETUP_BRDF_INPUT MetallicSetup
		//#define UNITY_STANDARD_SIMPLE	
		#include "UnityCG.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityStandardConfig.cginc"
		//#include "UnityStandardInput.cginc"
		//#include "UnityPBSLighting.cginc"
		#include "UnityStandardUtils.cginc"
		#include "UnityStandardBRDF.cginc"
		#include "UnityGlobalIllumination.cginc"
		#include "AutoLight.cginc"
		#if !defined(UNITY_BRDF_PBS_LIGHTMAP_INDIRECT)
			#define UNITY_BRDF_PBS_LIGHTMAP_INDIRECT BRDF3_Unity_PBS
		#endif
		#if !defined (UNITY_BRDF_GI)
			#define UNITY_BRDF_GI BRDF_Unity_Indirect
		#endif

		inline half3 GammaToLinearSpace1 (half3 sRGB)
		{
			// Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
			return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

			// Precise version, useful for debugging.
			//return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
		}

		inline half3 LinearToGammaSpace1 (half3 linRGB)
		{
			linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
			// An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
			return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
	
			// Exact version, useful for debugging.
			//return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
		}
		//---------------------------------------
		// Directional lightmaps & Parallax require tangent space too
		#define _TANGENT_TO_WORLD 1 
		//#if (_NORMALMAP || !DIRLIGHTMAP_OFF || _PARALLAXMAP)
		//	#define _TANGENT_TO_WORLD 1 
		//#endif

		//#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP)
		//	#define _DETAIL 1
		//#endif

		//---------------------------------------
		half4		_Color;
		half		_Cutoff;

		sampler2D	_MainTex;
		float4		_MainTex_ST;

		//sampler2D	_DetailAlbedoMap;
		//float4		_DetailAlbedoMap_ST;

		sampler2D	_BumpMap;
		half		_BumpScale;

		//sampler2D	_DetailMask;
		//sampler2D	_DetailNormalMap;
		//half		_DetailNormalMapScale;

		//sampler2D	_SpecGlossMap;
		sampler2D	_MetallicGlossMap;
		half		_Metallic;
		half		_Glossiness;

		//sampler2D	_OcclusionMap;
		half		_OcclusionStrength;

		//sampler2D	_ParallaxMap;
		//half		_Parallax;
		//half		_UVSec;

		half4 		_EmissionColor;
		sampler2D	_EmissionMap;

		//-------------------------------------------------------------------------------------
		// Input functions

		struct VertexInput
		{
			float4 vertex	: POSITION;
			half3 normal	: NORMAL;
			float2 uv0		: TEXCOORD0;
			float2 uv1		: TEXCOORD1;
		#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
			float2 uv2		: TEXCOORD2;
		#endif
		#ifdef _TANGENT_TO_WORLD
			half4 tangent	: TANGENT;
		#endif
		};

		float4 TexCoords(VertexInput v)
		{
			float4 texcoord = float4(0,0,0,0);
			texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0
			//texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
			return texcoord;
		}		

		//half DetailMask(float2 uv)
		//{
		//	return tex2D (_DetailMask, uv).a;
		//}

		half3 Albedo(float4 texcoords)
		{
			half3 albedo = _Color.rgb * tex2D (_MainTex, texcoords.xy).rgb;
		////remove 
		//#if _DETAIL
		//	#if (SHADER_TARGET < 30)
		//		// SM20: instruction count limitation
		//		// SM20: no detail mask
		//		half mask = 1; 
		//	#else
		//		half mask = DetailMask(texcoords.xy);
		//	#endif
		//	half3 detailAlbedo = tex2D (_DetailAlbedoMap, texcoords.zw).rgb;
		//	#if _DETAIL_MULX2
		//		albedo *= LerpWhiteTo (detailAlbedo * unity_ColorSpaceDouble.rgb, mask);
		//	#elif _DETAIL_MUL
		//		albedo *= LerpWhiteTo (detailAlbedo, mask);
		//	#elif _DETAIL_ADD
		//		albedo += detailAlbedo * mask;
		//	#elif _DETAIL_LERP
		//		albedo = lerp (albedo, detailAlbedo, mask);
		//	#endif
		//#endif

			//albedo = GammaToLinearSpace1(albedo);
			return albedo;
		}

		half Alpha(float2 uv)
		{
			return tex2D(_MainTex, uv).a * _Color.a;
		}		

		half Occlusion(float2 uv)
		{
			half occ = tex2D(_MetallicGlossMap, uv).g;
			return LerpOneTo (occ, _OcclusionStrength);
		}

		half2 MetallicGloss(float2 uv)
		{
			half2 mg;
		#ifdef _METALLICGLOSSMAP
			mg = tex2D(_MetallicGlossMap, uv.xy).ra;
			mg.x *= _Metallic;
			mg.y *= _Glossiness;
		#else
			mg = half2(_Metallic, _Glossiness);
		#endif
			return mg;
		}

		half3 Emission(float2 uv)
		{
		#ifndef _EMISSION
			return 0;
		#else
			return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
		#endif
		}

		//#ifdef _NORMALMAP
		half3 NormalInTangentSpace(float4 texcoords)
		{
			half3 normalTangent = UnpackScaleNormal(tex2D (_BumpMap, texcoords.xy), _BumpScale);
			return normalTangent;
		}
		//#endif

		float4 Parallax (float4 texcoords, half3 viewDir)
		{
			return texcoords;
		//for high option
		//#if !defined(_PARALLAXMAP) || (SHADER_TARGET < 30)
		//	// SM20: instruction count limitation
		//	// SM20: no parallax
		//	return texcoords;
		//#else
		//	half h = tex2D (_ParallaxMap, texcoords.xy).g;
		//	float2 offset = ParallaxOffset1Step (h, _Parallax, viewDir);
		//	return float4(texcoords.xy + offset, texcoords.zw + offset);
		//#endif
		}
		//-------------------------------------------------------------------------------------
		// counterpart for NormalizePerPixelNormal
		// skips normalization per-vertex and expects normalization to happen per-pixel
		half3 NormalizePerVertexNormal (half3 n)
		{
			#if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
				return normalize(n);
			#else
				return n; // will normalize per-pixel instead
			#endif
		}

		half3 NormalizePerPixelNormal (half3 n)
		{
			#if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
				return n;
			#else
				return normalize(n);
			#endif
		}

		//-------------------------------------------------------------------------------------
		UnityLight MainLight (half3 normalWorld)
		{
			UnityLight l;
			#ifdef LIGHTMAP_OFF
		
				l.color = _LightColor0.rgb;
				l.dir = _WorldSpaceLightPos0.xyz;
				l.ndotl = LambertTerm (normalWorld, l.dir);
			#else
				// no light specified by the engine
				// analytical light might be extracted from Lightmap data later on in the shader depending on the Lightmap type
				l.color = half3(0.f, 0.f, 0.f);
				l.ndotl  = 0.f;
				l.dir = half3(0.f, 0.f, 0.f);
			#endif

			return l;
		}

		UnityLight AdditiveLight (half3 normalWorld, half3 lightDir, half atten)
		{
			UnityLight l;

			l.color = _LightColor0.rgb;
			l.dir = lightDir;
			#ifndef USING_DIRECTIONAL_LIGHT
				l.dir = NormalizePerPixelNormal(l.dir);
			#endif
			l.ndotl = LambertTerm (normalWorld, l.dir);

			// shadow the light
			l.color *= atten;
			return l;
		}

		UnityLight DummyLight (half3 normalWorld)
		{
			UnityLight l;
			l.color = 0;
			l.dir = half3 (0,1,0);
			l.ndotl = LambertTerm (normalWorld, l.dir);
			return l;
		}

		UnityIndirect ZeroIndirect ()
		{
			UnityIndirect ind;
			ind.diffuse = 0;
			ind.specular = 0;
			return ind;
		}

		//-------------------------------------------------------------------------------------
		// Common fragment setup

		// deprecated
		half3 WorldNormal(half4 tan2world[3])
		{
			return normalize(tan2world[2].xyz);
		}

		// deprecated
		#ifdef _TANGENT_TO_WORLD
			half3x3 ExtractTangentToWorldPerPixel(half4 tan2world[3])
			{
				half3 t = tan2world[0].xyz;
				half3 b = tan2world[1].xyz;
				half3 n = tan2world[2].xyz;

			#if UNITY_TANGENT_ORTHONORMALIZE
				n = NormalizePerPixelNormal(n);

				// ortho-normalize Tangent
				t = normalize (t - n * dot(t, n));

				// recalculate Binormal
				half3 newB = cross(n, t);
				b = newB * sign (dot (newB, b));
			#endif

				return half3x3(t, b, n);
			}
		#else
			half3x3 ExtractTangentToWorldPerPixel(half4 tan2world[3])
			{
				return half3x3(0,0,0,0,0,0,0,0,0);
			}
		#endif

		half3 PerPixelWorldNormal(float4 i_tex, half4 tangentToWorld[3])
		{
		//#ifdef _NORMALMAP
			half3 tangent = tangentToWorld[0].xyz;
			half3 binormal = tangentToWorld[1].xyz;
			half3 normal = tangentToWorld[2].xyz;

			#if UNITY_TANGENT_ORTHONORMALIZE
				normal = NormalizePerPixelNormal(normal);

				// ortho-normalize Tangent
				tangent = normalize (tangent - normal * dot(tangent, normal));

				// recalculate Binormal
				half3 newB = cross(normal, tangent);
				binormal = newB * sign (dot (newB, binormal));
			#endif

			half3 normalTangent = NormalInTangentSpace(i_tex);
			half3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
		//#else
		//	half3 normalWorld = normalize(tangentToWorld[2].xyz);
		//#endif
			return normalWorld;
		}

		//#ifdef _PARALLAXMAP
		//	#define IN_VIEWDIR4PARALLAX(i) NormalizePerPixelNormal(half3(i.tangentToWorldAndParallax[0].w,i.tangentToWorldAndParallax[1].w,i.tangentToWorldAndParallax[2].w))
		//	#define IN_VIEWDIR4PARALLAX_FWDADD(i) NormalizePerPixelNormal(i.viewDirForParallax.xyz)
		//#else
			#define IN_VIEWDIR4PARALLAX(i) half3(0,0,0)
			#define IN_VIEWDIR4PARALLAX_FWDADD(i) half3(0,0,0)
		//#endif

		#if UNITY_SPECCUBE_BOX_PROJECTION
			#define IN_WORLDPOS(i) i.posWorld
		#else
			#define IN_WORLDPOS(i) half3(0,0,0)
		#endif

		#define IN_LIGHTDIR_FWDADD(i) half3(i.tangentToWorldAndLightDir[0].w, i.tangentToWorldAndLightDir[1].w, i.tangentToWorldAndLightDir[2].w)

		#define FRAGMENT_SETUP(x) FragmentCommonData x = \
			FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndParallax, IN_WORLDPOS(i));

		#define FRAGMENT_SETUP_FWDADD(x) FragmentCommonData x = \
			FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, half3(0,0,0));

		struct FragmentCommonData
		{
			half3 diffColor, specColor;
			// Note: oneMinusRoughness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
			// Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
			half oneMinusReflectivity, oneMinusRoughness;
			half3 normalWorld, eyeVec, posWorld;
			half alpha;

		#if UNITY_OPTIMIZE_TEXCUBELOD || UNITY_STANDARD_SIMPLE
			half3 reflUVW;
		#endif

		#if UNITY_STANDARD_SIMPLE
			half3 tangentSpaceNormal;
		#endif
		};

		//#ifndef UNITY_SETUP_BRDF_INPUT
		//	#define UNITY_SETUP_BRDF_INPUT SpecularSetup
		//#endif

		//inline FragmentCommonData SpecularSetup (float4 i_tex)
		//{
		//	half4 specGloss = SpecularGloss(i_tex.xy);
		//	half3 specColor = specGloss.rgb;
		//	half oneMinusRoughness = specGloss.a;

		//	half oneMinusReflectivity;
		//	half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular (Albedo(i_tex), specColor, /*out*/ oneMinusReflectivity);
	
		//	FragmentCommonData o = (FragmentCommonData)0;
		//	o.diffColor = diffColor;
		//	o.specColor = specColor;
		//	o.oneMinusReflectivity = oneMinusReflectivity;
		//	o.oneMinusRoughness = oneMinusRoughness;
		//	return o;
		//}
		inline half3 DiffuseAndSpecularFromMetallic1 (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
		{
			specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
			oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
			return albedo * oneMinusReflectivity;
		}

		inline FragmentCommonData MetallicSetup (float4 i_tex)
		{
			half2 metallicGloss = MetallicGloss(i_tex.xy);
			half metallic = metallicGloss.x;
			half oneMinusRoughness = metallicGloss.y;		// this is 1 minus the square root of real roughness m.

			half oneMinusReflectivity;
			half3 specColor;
			half3 diffColor = DiffuseAndSpecularFromMetallic1 (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

			FragmentCommonData o = (FragmentCommonData)0;
			o.diffColor = GammaToLinearSpace(diffColor);
			o.specColor = GammaToLinearSpace(specColor);
			o.oneMinusReflectivity = oneMinusReflectivity;
			o.oneMinusRoughness = oneMinusRoughness;
			return o;
		} 

		inline FragmentCommonData FragmentSetup (float4 i_tex, half3 i_eyeVec, half3 i_viewDirForParallax, half4 tangentToWorld[3], half3 i_posWorld)
		{
			i_tex = Parallax(i_tex, i_viewDirForParallax);

			half alpha = Alpha(i_tex.xy);
			#if defined(_ALPHATEST_ON)
				clip (alpha - _Cutoff);
			#endif

			FragmentCommonData o = UNITY_SETUP_BRDF_INPUT (i_tex);
			o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
			o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
			o.posWorld = i_posWorld;

			// NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
			o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
			return o;
		}

		inline UnityGI UnityGI_Base_MAD(UnityGIInput data, half occlusion, half3 normalWorld)
		{
			UnityGI o_gi;
			ResetUnityGI(o_gi);


			#if !defined(LIGHTMAP_ON)
				o_gi.light = data.light;
				o_gi.light.color *= data.atten;
			#endif

			#if UNITY_SHOULD_SAMPLE_SH
				o_gi.indirect.diffuse = ShadeSHPerPixel (normalWorld, data.ambient);
			#endif

			//#if defined(LIGHTMAP_ON)
			//	// Baked lightmaps
			//	fixed4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
			//	bakedColorTex.rgb = GammaToLinearSpace1(bakedColorTex.rgb);
			//	half3 bakedColor = DecodeLightmap(bakedColorTex);

			//	#ifdef DIRLIGHTMAP_OFF
			//		o_gi.indirect.diffuse = bakedColor;

			//		#ifdef SHADOWS_SCREEN
			//			o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			//		#endif // SHADOWS_SCREEN

			//	#elif DIRLIGHTMAP_COMBINED
			//		fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
			//		o_gi.indirect.diffuse = DecodeDirectionalLightmap (bakedColor, bakedDirTex, normalWorld);

			//		#ifdef SHADOWS_SCREEN
			//			o_gi.indirect.diffuse = MixLightmapWithRealtimeAttenuation (o_gi.indirect.diffuse, data.atten, bakedColorTex);
			//		#endif // SHADOWS_SCREEN

			//	#elif DIRLIGHTMAP_SEPARATE
			//		// Left halves of both intensity and direction lightmaps store direct light; right halves - indirect.

			//		// Direct
			//		fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
			//		o_gi.indirect.diffuse = DecodeDirectionalSpecularLightmap (bakedColor, bakedDirTex, normalWorld, false, 0, o_gi.light);

			//		// Indirect
			//		half2 uvIndirect = data.lightmapUV.xy + half2(0.5, 0);
			//		bakedColor = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, uvIndirect));
			//		bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, uvIndirect);
			//		o_gi.indirect.diffuse += DecodeDirectionalSpecularLightmap (bakedColor, bakedDirTex, normalWorld, false, 0, o_gi.light2);
			//	#endif
			//#endif

			//#ifdef DYNAMICLIGHTMAP_ON
			//	// Dynamic lightmaps
			//	fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
			//	half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);

			//	#ifdef DIRLIGHTMAP_OFF
			//		o_gi.indirect.diffuse += realtimeColor;

			//	#elif DIRLIGHTMAP_COMBINED
			//		half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
			//		o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);

			//	#elif DIRLIGHTMAP_SEPARATE
			//		half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
			//		half4 realtimeNormalTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicNormal, unity_DynamicLightmap, data.lightmapUV.zw);
			//		o_gi.indirect.diffuse += DecodeDirectionalSpecularLightmap (realtimeColor, realtimeDirTex, normalWorld, true, realtimeNormalTex, o_gi.light3);
			//	#endif
			//#endif

			o_gi.indirect.diffuse *= occlusion;
			return o_gi;
		}

		inline UnityGI UnityGlobalIlluminationMAD (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
		{
			//data.ambient.rgb = GammaToLinearSpace1(data.ambient.rgb);
			UnityGI o_gi = UnityGI_Base_MAD(data, occlusion, normalWorld);
			o_gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, normalWorld, glossIn);
			return o_gi;
		}

		inline UnityGI FragmentGI (FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
		{
			UnityGIInput d;
			d.light = light;
			//d.light.color = GammaToLinearSpace1(d.light.color);
			d.worldPos = s.posWorld;
			d.worldViewDir = -s.eyeVec;
			d.atten = atten;
			#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
				d.ambient = 0;
				d.lightmapUV = i_ambientOrLightmapUV;
			#else
				d.ambient = i_ambientOrLightmapUV.rgb;
				d.lightmapUV = 0;
			#endif
			d.boxMax[0] = unity_SpecCube0_BoxMax;
			d.boxMin[0] = unity_SpecCube0_BoxMin;
			d.probePosition[0] = unity_SpecCube0_ProbePosition;
			d.probeHDR[0] = unity_SpecCube0_HDR;

			d.boxMax[1] = unity_SpecCube1_BoxMax;
			d.boxMin[1] = unity_SpecCube1_BoxMin;
			d.probePosition[1] = unity_SpecCube1_ProbePosition;
			d.probeHDR[1] = unity_SpecCube1_HDR;

			Unity_GlossyEnvironmentData g;
			g.roughness		= 1 - s.oneMinusRoughness;
			g.reflUVW		= reflect(s.eyeVec, s.normalWorld);

			//这边由于在gamma空间下没有进行校正，需要手动将输出值进行转换
			UnityGI gi = UnityGlobalIlluminationMAD (d, occlusion, s.normalWorld, g);
			gi.indirect.diffuse = GammaToLinearSpace(gi.indirect.diffuse);
			gi.indirect.specular = GammaToLinearSpace(gi.indirect.specular);//
			return gi;

			//if(reflections)
			//{
			//	Unity_GlossyEnvironmentData g;
			//	g.roughness		= 1 - s.oneMinusRoughness;
			//#if UNITY_OPTIMIZE_TEXCUBELOD || UNITY_STANDARD_SIMPLE
			//	g.reflUVW 		= s.reflUVW;
			//#else
			//	g.reflUVW		= reflect(s.eyeVec, s.normalWorld);
			//#endif

			//	return UnityGlobalIllumination (d, occlusion, s.normalWorld, g);
			//}
			//else
			//{
			//	return UnityGlobalIllumination (d, occlusion, s.normalWorld);
			//}
		}

		inline UnityGI FragmentGI (FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light)
		{
			return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
		}


		//-------------------------------------------------------------------------------------
		half4 OutputForward (half4 output, half alphaFromSurface)
		{
			#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
				output.a = alphaFromSurface;
			#else
				UNITY_OPAQUE_ALPHA(output.a);
			#endif
			return output;
		}

		inline half4 VertexGIForward(VertexInput v, float3 posWorld, half3 normalWorld)
		{
			half4 ambientOrLightmapUV = 0;
			// Static lightmaps
			#ifndef LIGHTMAP_OFF
				ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				ambientOrLightmapUV.zw = 0;
			// Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
			#elif UNITY_SHOULD_SAMPLE_SH
				#ifdef VERTEXLIGHT_ON
					// Approximated illumination from non-important point lights
					ambientOrLightmapUV.rgb = Shade4PointLights (
						unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
						unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
						unity_4LightAtten0, posWorld, normalWorld);
				#endif

				ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, ambientOrLightmapUV.rgb);		
			#endif

			#ifdef DYNAMICLIGHTMAP_ON
				ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
			#endif

			return ambientOrLightmapUV;
		}

		half4 BRDF4_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness,
			half3 normal, half3 viewDir,
			UnityLight light, UnityIndirect gi)
		{
			half3 reflDir = reflect (viewDir, normal);

			half nl = light.ndotl;
			half nv = DotClamped (normal, viewDir);

			// Vectorize Pow4 to save instructions
			half2 rlPow4AndFresnelTerm = Pow4 (half2(dot(reflDir, light.dir), 1-nv));  // use R.L instead of N.H to save couple of instructions
			half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
			half fresnelTerm = rlPow4AndFresnelTerm.y;

			half grazingTerm = saturate(oneMinusRoughness + (1-oneMinusReflectivity));

			half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, oneMinusRoughness);
			color *= light.color * nl;
			color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
			//color = diffColor;
			//color = specColor;
			//color = gi.diffuse;
			//color = gi.specular;
			//color.rgb = i_ambientOrLightmapUV.rgb;
			color = LinearToGammaSpace1(color);
			return half4(color, 1);
		}
				//choose which mode to use
		#define UNITY_BRDF_PBS BRDF4_Unity_PBS

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)

		struct VertexOutputForwardBase
		{
			float4 pos							: SV_POSITION;
			float4 tex							: TEXCOORD0;
			half3 eyeVec 						: TEXCOORD1;
			half4 tangentToWorldAndParallax[3]	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:viewDirForParallax]
			half4 ambientOrLightmapUV			: TEXCOORD5;	// SH or Lightmap UV
			SHADOW_COORDS(6)
			UNITY_FOG_COORDS(7)

			// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
			#if UNITY_SPECCUBE_BOX_PROJECTION
				float3 posWorld					: TEXCOORD8;
			#endif

			#if UNITY_OPTIMIZE_TEXCUBELOD
				#if UNITY_SPECCUBE_BOX_PROJECTION
					half3 reflUVW				: TEXCOORD9;
				#else
					half3 reflUVW				: TEXCOORD8;
				#endif
			#endif
		};

		VertexOutputForwardBase vertForwardBase (VertexInput v)
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
			#ifdef _TANGENT_TO_WORLD
				float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

				float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
				o.tangentToWorldAndParallax[0].xyz = tangentToWorld[0];
				o.tangentToWorldAndParallax[1].xyz = tangentToWorld[1];
				o.tangentToWorldAndParallax[2].xyz = tangentToWorld[2];
			#else
				o.tangentToWorldAndParallax[0].xyz = 0;
				o.tangentToWorldAndParallax[1].xyz = 0;
				o.tangentToWorldAndParallax[2].xyz = normalWorld;
			#endif
			//We need this for shadow receving
			TRANSFER_SHADOW(o);

			o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);
	
			//#ifdef _PARALLAXMAP
			//	TANGENT_SPACE_ROTATION;
			//	half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
			//	o.tangentToWorldAndParallax[0].w = viewDirForParallax.x;
			//	o.tangentToWorldAndParallax[1].w = viewDirForParallax.y;
			//	o.tangentToWorldAndParallax[2].w = viewDirForParallax.z;
			//#endif

			#if UNITY_OPTIMIZE_TEXCUBELOD
				o.reflUVW 		= reflect(o.eyeVec, normalWorld);
			#endif

			UNITY_TRANSFER_FOG(o,o.pos);
			return o;
		}

		half4 fragForwardBaseInternal (VertexOutputForwardBase i)
		{
			FRAGMENT_SETUP(s)
		#if UNITY_OPTIMIZE_TEXCUBELOD
			s.reflUVW		= i.reflUVW;
		#endif

			UnityLight mainLight = MainLight (s.normalWorld);
			half atten = SHADOW_ATTENUATION(i);
			half occlusion = Occlusion(i.tex.xy);
			UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
			
			half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);	
			//c.rgb += UNITY_BRDF_GI (s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, occlusion, gi);
			c.rgb += Emission(i.tex.xy);
			//return fixed4(i.ambientOrLightmapUV.rgb,1);
			UNITY_APPLY_FOG(i.fogCoord, c.rgb);
			return OutputForward (c, s.alpha);
		}

		half4 fragForwardBase (VertexOutputForwardBase i) : SV_Target	// backward compatibility (this used to be the fragment entry function)
		{
			return fragForwardBaseInternal(i);
		}

		// ------------------------------------------------------------------
		//  Additive forward pass (one light per pass)

		struct VertexOutputForwardAdd
		{
			float4 pos							: SV_POSITION;
			float4 tex							: TEXCOORD0;
			half3 eyeVec 						: TEXCOORD1;
			half4 tangentToWorldAndLightDir[3]	: TEXCOORD2;	// [3x3:tangentToWorld | 1x3:lightDir]
			LIGHTING_COORDS(5,6)
			UNITY_FOG_COORDS(7)

			// next ones would not fit into SM2.0 limits, but they are always for SM3.0+
		//#if defined(_PARALLAXMAP)
		//	half3 viewDirForParallax			: TEXCOORD8;
		//#endif
		};

		VertexOutputForwardAdd vertForwardAdd (VertexInput v)
		{
			VertexOutputForwardAdd o;
			UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd, o);

			float4 posWorld = mul(_Object2World, v.vertex);
			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
			o.tex = TexCoords(v);
			o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
			float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			#ifdef _TANGENT_TO_WORLD
				float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

				float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
				o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0];
				o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1];
				o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2];
			#else
				o.tangentToWorldAndLightDir[0].xyz = 0;
				o.tangentToWorldAndLightDir[1].xyz = 0;
				o.tangentToWorldAndLightDir[2].xyz = normalWorld;
			#endif
			//We need this for shadow receiving
			TRANSFER_VERTEX_TO_FRAGMENT(o);

			float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
			#ifndef USING_DIRECTIONAL_LIGHT
				lightDir = NormalizePerVertexNormal(lightDir);
			#endif
			o.tangentToWorldAndLightDir[0].w = lightDir.x;
			o.tangentToWorldAndLightDir[1].w = lightDir.y;
			o.tangentToWorldAndLightDir[2].w = lightDir.z;

			//#ifdef _PARALLAXMAP
			//	TANGENT_SPACE_ROTATION;
			//	o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
			//#endif
	
			UNITY_TRANSFER_FOG(o,o.pos);
			return o;
		}

		half4 fragForwardAddInternal (VertexOutputForwardAdd i)
		{
			FRAGMENT_SETUP_FWDADD(s)

			UnityLight light = AdditiveLight (s.normalWorld, IN_LIGHTDIR_FWDADD(i), LIGHT_ATTENUATION(i));
			UnityIndirect noIndirect = ZeroIndirect ();

			half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.oneMinusRoughness, s.normalWorld, -s.eyeVec, light, noIndirect);
	
			UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
			return OutputForward (c, s.alpha);
		}

		half4 fragForwardAdd (VertexOutputForwardAdd i) : SV_Target		// backward compatibility (this used to be the fragment entry function)
		{
			return fragForwardAddInternal(i);
		}


		//
		// Old FragmentGI signature. Kept only for backward compatibility and will be removed soon
		//

		inline UnityGI FragmentGI(
			float3 posWorld,
			half occlusion, half4 i_ambientOrLightmapUV, half atten, half oneMinusRoughness, half3 normalWorld, half3 eyeVec,
			UnityLight light,
			bool reflections)
		{
			// we init only fields actually used
			FragmentCommonData s = (FragmentCommonData)0;
			s.oneMinusRoughness = oneMinusRoughness;
			s.normalWorld = normalWorld;
			s.eyeVec = eyeVec;
			s.posWorld = posWorld;
		#if UNITY_OPTIMIZE_TEXCUBELOD
			s.reflUVW = reflect(eyeVec, normalWorld);
		#endif
			return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, reflections);
		}
		inline UnityGI FragmentGI (
			float3 posWorld,
			half occlusion, half4 i_ambientOrLightmapUV, half atten, half oneMinusRoughness, half3 normalWorld, half3 eyeVec,
			UnityLight light)
		{
			return FragmentGI (posWorld, occlusion, i_ambientOrLightmapUV, atten, oneMinusRoughness, normalWorld, eyeVec, light, true);
		}



				//-------------------------------------------------------------------------------------
		inline half3 BRDF_Unity_Indirect (half3 baseColor, half3 specColor, half oneMinusReflectivity, half oneMinusRoughness, half3 normal, half3 viewDir, half occlusion, UnityGI gi)
		{
			half3 c = 0;
			#if defined(DIRLIGHTMAP_SEPARATE)
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;

				#ifdef LIGHTMAP_ON
					c += UNITY_BRDF_PBS_LIGHTMAP_INDIRECT (baseColor, specColor, oneMinusReflectivity, oneMinusRoughness, normal, viewDir, gi.light2, gi.indirect).rgb * occlusion;
				#endif
				#ifdef DYNAMICLIGHTMAP_ON
					c += UNITY_BRDF_PBS_LIGHTMAP_INDIRECT (baseColor, specColor, oneMinusReflectivity, oneMinusRoughness, normal, viewDir, gi.light3, gi.indirect).rgb * occlusion;
				#endif
			#endif
			return c;
		}

		VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
		VertexOutputForwardAdd vertAdd (VertexInput v) { return vertForwardAdd(v); }
		half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardBaseInternal(i); }
		half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragForwardAddInternal(i); }
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
		LOD 300
	

		// ------------------------------------------------------------------
		//  Base forward pass (directional light, emission, lightmaps, ...)
		Pass
		{
			Name "FORWARD" 
			Tags { "LightMode" = "ForwardBase" }

			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			CGPROGRAM
			#pragma target 3.0
			// TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
			#pragma exclude_renderers gles
			//#pragma shader_feature _NORMALMAP
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _EMISSION
			#pragma shader_feature _METALLICGLOSSMAP 
			//#pragma shader_feature ___ _DETAIL_MULX2
			//#pragma shader_feature _PARALLAXMAP

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			// -------------------------------------
			#pragma vertex vertBase
			#pragma fragment fragBase
			//#include "UnityStandardCoreForward.cginc"
			ENDCG
		}
		// ------------------------------------------------------------------
		//  Additive forward pass (one light per pass)
		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One
			Fog { Color (0,0,0,0) } // in additive pass fog should be black
			ZWrite Off
			ZTest LEqual

			CGPROGRAM
			#pragma target 3.0
			// GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
			#pragma exclude_renderers gles

			// -------------------------------------		
			//#pragma shader_feature _NORMALMAP
			#pragma shader_feature _NORMALMAP
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			//#pragma shader_feature _METALLICGLOSSMAP
			//#pragma shader_feature ___ _DETAIL_MULX2
			//#pragma shader_feature _PARALLAXMAP
			
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			#pragma vertex vertAdd
			#pragma fragment fragAdd
			//#include "UnityStandardCoreForward.cginc"

			ENDCG
		}
		// ------------------------------------------------------------------
		//  Shadow rendering pass
		//Pass {
		//	Name "ShadowCaster"
		//	Tags { "LightMode" = "ShadowCaster" } 
			
		//	ZWrite On ZTest LEqual

		//	CGPROGRAM
		//	#pragma target 3.0
		//	// TEMPORARY: GLES2.0 temporarily disabled to prevent errors spam on devices without textureCubeLodEXT
		//	#pragma exclude_renderers gles
		//	// -------------------------------------
		//	#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
		//	#pragma multi_compile_shadowcaster

		//	#pragma vertex vertShadowCaster
		//	#pragma fragment fragShadowCaster

		//	#include "UnityStandardShadow.cginc"

		//	ENDCG
		//}
	}

	//SubShader
	//{
	//	Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
	//	LOD 150

	//	// ------------------------------------------------------------------
	//	//  Base forward pass (directional light, emission, lightmaps, ...)
	//	Pass
	//	{
	//		Name "FORWARD" 
	//		Tags { "LightMode" = "ForwardBase" }

	//		Blend [_SrcBlend] [_DstBlend]
	//		ZWrite [_ZWrite]

	//		CGPROGRAM
	//		#pragma target 2.0
			
	//		#pragma shader_feature _NORMALMAP
	//		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
	//		#pragma shader_feature _EMISSION 
	//		#pragma shader_feature _METALLICGLOSSMAP 
	//		#pragma shader_feature ___ _DETAIL_MULX2
	//		// SM2.0: NOT SUPPORTED shader_feature _PARALLAXMAP

	//		#pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE

	//		#pragma multi_compile_fwdbase
	//		#pragma multi_compile_fog

	//		#pragma vertex vertBase
	//		#pragma fragment fragBase
	//		#include "UnityStandardCoreForward.cginc"

	//		ENDCG
	//	}
	//	// ------------------------------------------------------------------
	//	//  Additive forward pass (one light per pass)
	//	Pass
	//	{
	//		Name "FORWARD_DELTA"
	//		Tags { "LightMode" = "ForwardAdd" }
	//		Blend [_SrcBlend] One
	//		Fog { Color (0,0,0,0) } // in additive pass fog should be black
	//		ZWrite Off
	//		ZTest LEqual
			
	//		CGPROGRAM
	//		#pragma target 2.0

	//		#pragma shader_feature _NORMALMAP
	//		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
	//		#pragma shader_feature _METALLICGLOSSMAP
	//		#pragma shader_feature ___ _DETAIL_MULX2
	//		// SM2.0: NOT SUPPORTED shader_feature _PARALLAXMAP
	//		#pragma skip_variants SHADOWS_SOFT
			
	//		#pragma multi_compile_fwdadd_fullshadows
	//		#pragma multi_compile_fog
			
	//		#pragma vertex vertAdd
	//		#pragma fragment fragAdd
	//		#include "UnityStandardCoreForward.cginc"

	//		ENDCG
	//	}
	//	// ------------------------------------------------------------------
	//	//  Shadow rendering pass
	//	Pass {
	//		Name "ShadowCaster"
	//		Tags { "LightMode" = "ShadowCaster" }
			
	//		ZWrite On ZTest LEqual

	//		CGPROGRAM
	//		#pragma target 2.0

	//		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
	//		#pragma skip_variants SHADOWS_SOFT
	//		#pragma multi_compile_shadowcaster

	//		#pragma vertex vertShadowCaster
	//		#pragma fragment fragShadowCaster

	//		#include "UnityStandardShadow.cginc"

	//		ENDCG
	//	}
	//}


	FallBack "VertexLit"
	CustomEditor "MADStandardShaderGUI"
}
