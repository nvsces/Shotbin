#!/usr/bin/env python3
"""Генерирует Recall.xcodeproj из содержимого папки Recall/. Запускать после добавления файлов."""
import os, uuid

SRC = "Recall"
files = sorted(f for f in os.listdir(SRC) if f.endswith(".swift"))
def oid(seed): return uuid.uuid5(uuid.NAMESPACE_DNS, "recall." + seed).hex[:24].upper()

ids = {k: oid(k) for k in ["project","target","product","mainGroup","srcGroup","productsGroup","sourcesPhase",
                           "resourcesPhase","frameworksPhase","configList","projConfigList","debugCfg","releaseCfg",
                           "targetDebug","targetRelease","assets_fr","assets_bf","plist_fr"]}
file_refs, build_files, children, sources = [], [], [], []
for f in files:
    fr, bf = oid("fr."+f), oid("bf."+f)
    file_refs.append(f'\t\t{fr} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};')
    build_files.append(f'\t\t{bf} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {f} */; }};')
    children.append(f'\t\t\t\t{fr} /* {f} */,')
    sources.append(f'\t\t\t\t{bf} /* {f} in Sources */,')

settings_common = '''				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Recall/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Recall;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.nvsces.recall;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
'''
pbx = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
		{ids["assets_bf"]} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids["assets_fr"]} /* Assets.xcassets */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
		{ids["assets_fr"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{ids["plist_fr"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{ids["product"]} /* Recall.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Recall.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{ids["frameworksPhase"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{ids["mainGroup"]} = {{
			isa = PBXGroup;
			children = (
				{ids["srcGroup"]} /* Recall */,
				{ids["productsGroup"]} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids["srcGroup"]} /* Recall */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(children)}
				{ids["assets_fr"]} /* Assets.xcassets */,
				{ids["plist_fr"]} /* Info.plist */,
			);
			path = Recall;
			sourceTree = "<group>";
		}};
		{ids["productsGroup"]} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids["product"]} /* Recall.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids["target"]} /* Recall */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids["configList"]};
			buildPhases = (
				{ids["sourcesPhase"]} /* Sources */,
				{ids["frameworksPhase"]} /* Frameworks */,
				{ids["resourcesPhase"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Recall;
			productName = Recall;
			productReference = {ids["product"]} /* Recall.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids["project"]} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {ids["projConfigList"]};
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids["mainGroup"]};
			productRefGroup = {ids["productsGroup"]} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids["target"]} /* Recall */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids["resourcesPhase"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids["assets_bf"]} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids["sourcesPhase"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join(sources)}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{ids["debugCfg"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{ids["releaseCfg"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			}};
			name = Release;
		}};
		{ids["targetDebug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{settings_common}			}};
			name = Debug;
		}};
		{ids["targetRelease"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{settings_common}			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids["projConfigList"]} = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["debugCfg"]} /* Debug */,
				{ids["releaseCfg"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids["configList"]} = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["targetDebug"]} /* Debug */,
				{ids["targetRelease"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {ids["project"]} /* Project object */;
}}
'''
os.makedirs("Recall.xcodeproj/xcshareddata/xcschemes", exist_ok=True)
open("Recall.xcodeproj/project.pbxproj","w").write(pbx)
open("Recall.xcodeproj/xcshareddata/xcschemes/Recall.xcscheme","w").write(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ids["target"]}" BuildableName = "Recall.app" BlueprintName = "Recall" ReferencedContainer = "container:Recall.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ids["target"]}" BuildableName = "Recall.app" BlueprintName = "Recall" ReferencedContainer = "container:Recall.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
''')
print("проект:", len(files), "файлов")
