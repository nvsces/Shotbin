#!/usr/bin/env python3
"""Генерирует Shotbin.xcodeproj из содержимого папки Shotbin/. Запускать после добавления файлов."""
import os, uuid

SRC = "Shotbin"
files = sorted(f for f in os.listdir(SRC) if f.endswith(".swift"))
def oid(seed): return uuid.uuid5(uuid.NAMESPACE_DNS, "shotbin." + seed).hex[:24].upper()

ids = {k: oid(k) for k in ["strings_fr","strings_bf",
                           "project","target","product","mainGroup","srcGroup","productsGroup","sourcesPhase",
                           "resourcesPhase","frameworksPhase","configList","projConfigList","debugCfg","releaseCfg",
                           "targetDebug","targetRelease","assets_fr","assets_bf","plist_fr",
                           "uiTarget","uiProduct","uiGroup","uiSources","uiFrameworks","uiResources","uiConfigList","uiDebug","uiRelease","uiDep","uiProxy","uiTestFr","uiTestBf"]}
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
				INFOPLIST_FILE = Shotbin/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Shotbin;
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
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
'''
ui_settings = '''				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.nvsces.recall.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_TARGET_NAME = Shotbin;
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
		{ids["strings_bf"]} /* Localizable.xcstrings in Resources */ = {{isa = PBXBuildFile; fileRef = {ids["strings_fr"]} /* Localizable.xcstrings */; }};
		{ids["uiTestBf"]} /* ShotbinUITests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ids["uiTestFr"]} /* ShotbinUITests.swift */; }};
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{ids["uiProxy"]} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids["project"]} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids["target"]};
			remoteInfo = Shotbin;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
		{ids["assets_fr"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{ids["strings_fr"]} /* Localizable.xcstrings */ = {{isa = PBXFileReference; lastKnownFileType = text.json.xcstrings; path = Localizable.xcstrings; sourceTree = "<group>"; }};
		{ids["plist_fr"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{ids["product"]} /* Shotbin.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Shotbin.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{ids["uiProduct"]} /* ShotbinUITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ShotbinUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{ids["uiTestFr"]} /* ShotbinUITests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShotbinUITests.swift; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{ids["frameworksPhase"]} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids["uiFrameworks"]} /* Frameworks */ = {{
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
				{ids["srcGroup"]} /* Shotbin */,
				{ids["uiGroup"]} /* ShotbinUITests */,
				{ids["productsGroup"]} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids["srcGroup"]} /* Shotbin */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(children)}
				{ids["assets_fr"]} /* Assets.xcassets */,
				{ids["strings_fr"]} /* Localizable.xcstrings */,
				{ids["plist_fr"]} /* Info.plist */,
			);
			path = Shotbin;
			sourceTree = "<group>";
		}};
		{ids["uiGroup"]} /* ShotbinUITests */ = {{
			isa = PBXGroup;
			children = (
				{ids["uiTestFr"]} /* ShotbinUITests.swift */,
			);
			path = ShotbinUITests;
			sourceTree = "<group>";
		}};
		{ids["productsGroup"]} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids["product"]} /* Shotbin.app */,
				{ids["uiProduct"]} /* ShotbinUITests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids["target"]} /* Shotbin */ = {{
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
			name = Shotbin;
			productName = Shotbin;
			productReference = {ids["product"]} /* Shotbin.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids["uiTarget"]} /* ShotbinUITests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids["uiConfigList"]};
			buildPhases = (
				{ids["uiSources"]} /* Sources */,
				{ids["uiFrameworks"]} /* Frameworks */,
				{ids["uiResources"]} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{ids["uiDep"]} /* PBXTargetDependency */,
			);
			name = ShotbinUITests;
			productName = ShotbinUITests;
			productReference = {ids["uiProduct"]} /* ShotbinUITests.xctest */;
			productType = "com.apple.product-type.bundle.ui-testing";
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
			developmentRegion = ru;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				ru,
				Base,
			);
			mainGroup = {ids["mainGroup"]};
			productRefGroup = {ids["productsGroup"]} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids["target"]} /* Shotbin */,
				{ids["uiTarget"]} /* ShotbinUITests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids["resourcesPhase"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids["assets_bf"]} /* Assets.xcassets in Resources */,
				{ids["strings_bf"]} /* Localizable.xcstrings in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids["uiResources"]} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
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
		{ids["uiSources"]} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{ids["uiTestBf"]} /* ShotbinUITests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{ids["uiDep"]} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids["target"]} /* Shotbin */;
			targetProxy = {ids["uiProxy"]} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

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
		{ids["uiDebug"]} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{ui_settings}			}};
			name = Debug;
		}};
		{ids["uiRelease"]} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{ui_settings}			}};
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
		{ids["uiConfigList"]} = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids["uiDebug"]} /* Debug */,
				{ids["uiRelease"]} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {ids["project"]} /* Project object */;
}}
'''
os.makedirs("Shotbin.xcodeproj/xcshareddata/xcschemes", exist_ok=True)
open("Shotbin.xcodeproj/project.pbxproj","w").write(pbx)
open("Shotbin.xcodeproj/xcshareddata/xcschemes/Shotbin.xcscheme","w").write(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1600" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ids["target"]}" BuildableName = "Shotbin.app" BlueprintName = "Shotbin" ReferencedContainer = "container:Shotbin.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ids["uiTarget"]}" BuildableName = "ShotbinUITests.xctest" BlueprintName = "ShotbinUITests" ReferencedContainer = "container:Shotbin.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{ids["target"]}" BuildableName = "Shotbin.app" BlueprintName = "Shotbin" ReferencedContainer = "container:Shotbin.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
''')
print("проект:", len(files), "файлов")
