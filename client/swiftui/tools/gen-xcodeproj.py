#!/usr/bin/env python3
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SWIFTUI_DIR = os.path.join(ROOT, "client", "swiftui")
PROJ_DIR = os.path.join(SWIFTUI_DIR, "AmneziaVPN-SwiftUI.xcodeproj")


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def esc(value):
    return value.replace("\\", "\\\\").replace('"', '\\"')


class Objects:
    def __init__(self):
        self.items = []

    def add(self, uid_value, isa, fields):
        self.items.append((uid_value, isa, fields))

    def render(self):
        out = ["// !$*UTF8*$!", "{"]
        out.append("\tarchiveVersion = 1;")
        out.append("\tclasses = {")
        out.append("\t};")
        out.append("\tobjectVersion = 77;")
        out.append("\tobjects = {")
        for uid_value, isa, fields in self.items:
            out.append(f"\t\t{uid_value} = {{")
            out.append(f"\t\t\tisa = {isa};")
            for key, value in fields:
                out.append(f"\t\t\t{key} = {value};")
            out.append("\t\t};")
        out.append("\t};")
        out.append(f"\trootObject = {uid('project')};")
        out.append("}")
        return "\n".join(out) + "\n"


def string_list(values):
    return "(" + ", ".join(f'"{esc(v)}"' for v in values) + ")"


def ref_list(ids):
    return "(" + ", ".join(ids) + ")"


APP_SWIFT = [
    "App/AmneziaVPNApp.swift",
    "App/AppState.swift",
    "App/BuildConfig.swift",
    "App/Theme.swift",
    "App/Core/Logger.swift",
    "App/Core/LocalCore.swift",
    "App/Core/Models.swift",
    "App/Core/ServerStore.swift",
    "App/Core/SettingsStore.swift",
    "App/Core/SplitTunnelingStore.swift",
    "App/Core/Importer.swift",
    "App/Core/VPNKeyDecoder.swift",
    "App/Core/VPNKeyEncoder.swift",
    "App/Core/WGConfigBuilder.swift",
    "App/Views/Controls.swift",
    "App/Views/RootView.swift",
    "App/Views/HomeView.swift",
    "App/Views/ServerInfoView.swift",
    "App/Views/ServerDataView.swift",
    "App/Views/SettingsView.swift",
    "App/Views/ConnectionView.swift",
    "App/Views/ApplicationView.swift",
    "App/Views/AboutView.swift",
    "App/Views/SplitTunnelingView.swift",
    "App/Views/LoggingView.swift",
    "App/Views/SetupWizardView.swift",
    "App/Views/QrReaderView.swift",
    "App/Views/ShareView.swift",
]

EXT_SWIFT = [
    "Extension/PacketTunnelProvider.swift",
    "Extension/WGConfig.swift",
    "Extension/WgQuickConfig.swift",
]

APP_RESOURCES = [
    ("App/Assets.xcassets", "folder.assetcatalog"),
    ("../ios/app/AmneziaVPNLaunchScreen.storyboard", "file.storyboard"),
    ("../ios/app/launch.png", "image.png"),
    ("../ios/app/PrivacyInfo.xcprivacy", "text.plist.xcprivacy"),
    ("../images/AppIcon.icon", "folder.icon"),
]

EXT_RESOURCES = [
    ("../ios/networkextension/PrivacyInfo.xcprivacy", "text.plist.xcprivacy"),
]

BRIDGE_FILES = [
    ("Bridge/AmneziaCoreBridge.h", "sourcecode.c.h"),
    ("Bridge/AmneziaCoreBridge.mm", "sourcecode.cpp.objcpp"),
]


def file_type(path):
    if path.endswith(".swift"):
        return "sourcecode.swift"
    if path.endswith(".plist"):
        return "text.plist.xml"
    if path.endswith(".entitlements"):
        return "text.plist.entitlements"
    return "text"


def main():
    objects = Objects()

    def file_ref(path, explicit_type=None):
        ref_id = uid("fileref:" + path)
        name = os.path.basename(path)
        ftype = explicit_type or file_type(path)
        objects.add(ref_id, "PBXFileReference", [
            ("lastKnownFileType", ftype),
            ("name", f'"{esc(name)}"'),
            ("path", f'"{esc(path)}"'),
            ("sourceTree", '"<group>"'),
        ])
        return ref_id

    def build_file(path, target=""):
        ref_id = uid("fileref:" + path)
        build_id = uid("buildfile:" + target + ":" + path)
        objects.add(build_id, "PBXBuildFile", [("fileRef", ref_id)])
        return build_id

    def group(name, path, children, source_tree="<group>"):
        group_id = uid("group:" + name + ":" + (path or ""))
        fields = [("children", ref_list(children))]
        if name:
            fields.append(("name", f'"{esc(name)}"'))
        if path:
            fields.append(("path", f'"{esc(path)}"'))
        fields.append(("sourceTree", f'"{source_tree}"'))
        objects.add(group_id, "PBXGroup", fields)
        return group_id

    app_source_builds = [build_file(p, "app") for p in APP_SWIFT]
    ext_source_builds = [build_file(p, "ext") for p in EXT_SWIFT]
    ext_source_builds = [build_file("App/BuildConfig.swift", "ext")] + ext_source_builds
    app_resource_builds = [build_file(p, "app") for p, _ in APP_RESOURCES]
    ext_resource_builds = [build_file(p, "ext") for p, _ in EXT_RESOURCES]

    for p in APP_SWIFT + EXT_SWIFT:
        file_ref(p)
    file_ref("App/Info.plist")
    file_ref("Extension/Info.plist")
    for p, ftype in APP_RESOURCES + EXT_RESOURCES:
        file_ref(p, ftype)
    for p, ftype in BRIDGE_FILES:
        file_ref(p, ftype)

    app_product_ref = uid("fileref:product:AmneziaVPN.app")
    objects.add(app_product_ref, "PBXFileReference", [
        ("explicitFileType", "wrapper.application"),
        ("includeInIndex", "0"),
        ("path", '"AmneziaVPN.app"'),
        ("sourceTree", "BUILT_PRODUCTS_DIR"),
    ])
    ext_product_ref = uid("fileref:product:AmneziaVPNNetworkExtension.appex")
    objects.add(ext_product_ref, "PBXFileReference", [
        ("explicitFileType", "wrapper.app-extension"),
        ("includeInIndex", "0"),
        ("path", '"AmneziaVPNNetworkExtension.appex"'),
        ("sourceTree", "BUILT_PRODUCTS_DIR"),
    ])

    network_extension_ref = uid("fileref:framework:NetworkExtension")
    objects.add(network_extension_ref, "PBXFileReference", [
        ("lastKnownFileType", "wrapper.framework"),
        ("name", '"NetworkExtension.framework"'),
        ("path", '"System/Library/Frameworks/NetworkExtension.framework"'),
        ("sourceTree", "SDKROOT"),
    ])
    app_framework_build = uid("buildfile:framework:NetworkExtension:app")
    objects.add(app_framework_build, "PBXBuildFile", [("fileRef", network_extension_ref)])
    ext_framework_build = uid("buildfile:framework:NetworkExtension:ext")
    objects.add(ext_framework_build, "PBXBuildFile", [("fileRef", network_extension_ref)])

    package_ref = uid("package:amneziawg-apple")
    objects.add(package_ref, "XCLocalSwiftPackageReference", [
        ("relativePath", '"../3rd/amneziawg-apple"'),
    ])
    package_product = uid("packageproduct:WireGuardKit")
    objects.add(package_product, "XCSwiftPackageProductDependency", [
        ("package", package_ref),
        ("productName", '"WireGuardKit"'),
    ])
    package_build = uid("buildfile:packageproduct:WireGuardKit")
    objects.add(package_build, "PBXBuildFile", [("productRef", package_product)])

    ext_embed_build = uid("buildfile:embed:appex")
    objects.add(ext_embed_build, "PBXBuildFile", [
        ("fileRef", ext_product_ref),
        ("settings", "{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }"),
    ])

    def phase(isa, uid_value, files, extra=None):
        fields = [
            ("buildActionMask", "2147483647"),
            ("files", ref_list(files)),
            ("runOnlyForDeploymentPostprocessing", "0"),
        ]
        if extra:
            fields.extend(extra)
        objects.add(uid_value, isa, fields)

    app_sources_phase = uid("phase:app:sources")
    phase("PBXSourcesBuildPhase", app_sources_phase, app_source_builds)
    app_resources_phase = uid("phase:app:resources")
    phase("PBXResourcesBuildPhase", app_resources_phase, app_resource_builds)
    app_frameworks_phase = uid("phase:app:frameworks")
    phase("PBXFrameworksBuildPhase", app_frameworks_phase, [app_framework_build])
    app_embed_phase = uid("phase:app:embed")
    objects.add(app_embed_phase, "PBXCopyFilesBuildPhase", [
        ("buildActionMask", "2147483647"),
        ("dstPath", '""'),
        ("dstSubfolderSpec", "13"),
        ("files", ref_list([ext_embed_build])),
        ("name", '"Embed App Extensions"'),
        ("runOnlyForDeploymentPostprocessing", "0"),
    ])

    wg_script = (
        "set -euo pipefail\n"
        "WG_GO_DIR=\"${SRCROOT}/../3rd/amneziawg-apple/Sources/WireGuardKitGo\"\n"
        "cd \"${WG_GO_DIR}\"\n"
        "make build version-header ARCHS=\"${ARCHS}\" PLATFORM_NAME=\"${PLATFORM_NAME}\" "
        "SDKROOT=\"${SDKROOT}\" CONFIGURATION_BUILD_DIR=\"${WG_GO_DIR}/out\" "
        "CONFIGURATION_TEMP_DIR=\"${WG_GO_DIR}/.tmp\" "
        "DEPLOYMENT_TARGET_CLANG_FLAG_NAME=miphoneos-version-min "
        "DEPLOYMENT_TARGET_CLANG_ENV_NAME=IPHONEOS_DEPLOYMENT_TARGET "
        "IPHONEOS_DEPLOYMENT_TARGET=\"${IPHONEOS_DEPLOYMENT_TARGET}\"\n"
    )
    ext_script_phase = uid("phase:ext:script")
    objects.add(ext_script_phase, "PBXShellScriptBuildPhase", [
        ("buildActionMask", "2147483647"),
        ("files", "()"),
        ("inputPaths", "()"),
        ("name", '"Build libwg-go.a"'),
        ("outputPaths", "()"),
        ("runOnlyForDeploymentPostprocessing", "0"),
        ("shellPath", "/bin/sh"),
        ("shellScript", f'"{esc(wg_script)}"'),
    ])
    ext_sources_phase = uid("phase:ext:sources")
    phase("PBXSourcesBuildPhase", ext_sources_phase, ext_source_builds)
    ext_resources_phase = uid("phase:ext:resources")
    phase("PBXResourcesBuildPhase", ext_resources_phase, ext_resource_builds)
    ext_frameworks_phase = uid("phase:ext:frameworks")
    phase("PBXFrameworksBuildPhase", ext_frameworks_phase, [ext_framework_build, package_build])

    def config(name, owner, settings):
        config_id = uid("config:" + owner + ":" + name)
        settings_str = "{\n" + "".join(
            f"\t\t\t\t{k} = {v};\n" for k, v in settings
        ) + "\t\t\t}"
        objects.add(config_id, "XCBuildConfiguration", [
            ("buildSettings", settings_str),
            ("name", f'"{name}"'),
        ])
        return config_id

    project_debug = config("Debug", "project", [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION", "YES_AGGRESSIVE"),
        ("CLANG_CXX_LANGUAGE_STANDARD", '"gnu++20"'),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER", "YES"),
        ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("IPHONEOS_DEPLOYMENT_TARGET", "16.0"),
        ("LOCALIZATION_PREFS", '""'),
        ("MARKETING_VERSION", "5.1.1.9"),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
        ("MTL_FAST_MATH", "YES"),
        ("ONLY_ACTIVE_ARCH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_VERSION", "5.0"),
    ])
    project_release = config("Release", "project", [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION", "YES_AGGRESSIVE"),
        ("CLANG_CXX_LANGUAGE_STANDARD", '"gnu++20"'),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER", "YES"),
        ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("COPY_PHASE_STRIP", "NO"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("IPHONEOS_DEPLOYMENT_TARGET", "16.0"),
        ("LOCALIZATION_PREFS", '""'),
        ("MARKETING_VERSION", "5.1.1.9"),
        ("MTL_ENABLE_DEBUG_INFO", "NO"),
        ("MTL_FAST_MATH", "YES"),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_VERSION", "5.0"),
    ])
    app_debug = config("Debug", "app", [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("CODE_SIGN_ENTITLEMENTS", '"../ios/app/main.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("INFOPLIST_FILE", '"App/Info.plist"'),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", "org.amnezia.AmneziaVPN"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
    ])
    app_release = config("Release", "app", [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("CODE_SIGN_ENTITLEMENTS", '"../ios/app/main.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("INFOPLIST_FILE", '"App/Info.plist"'),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", "org.amnezia.AmneziaVPN"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
    ])
    ext_debug = config("Debug", "ext", [
        ("APPLICATION_EXTENSION_API_ONLY", "YES"),
        ("CODE_SIGN_ENTITLEMENTS", '"../ios/networkextension/AmneziaVPNNetworkExtension.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("INFOPLIST_FILE", '"Extension/Info.plist"'),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/../../Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", "org.amnezia.AmneziaVPN.network-extension"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SKIP_INSTALL", "YES"),
        ("SWIFT_OPTIMIZATION_LEVEL", '"-Onone"'),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
    ])
    ext_release = config("Release", "ext", [
        ("APPLICATION_EXTENSION_API_ONLY", "YES"),
        ("CODE_SIGN_ENTITLEMENTS", '"../ios/networkextension/AmneziaVPNNetworkExtension.entitlements"'),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("INFOPLIST_FILE", '"Extension/Info.plist"'),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/../../Frameworks"'),
        ("PRODUCT_BUNDLE_IDENTIFIER", "org.amnezia.AmneziaVPN.network-extension"),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SKIP_INSTALL", "YES"),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
    ])

    def config_list(name, debug_id, release_id):
        list_id = uid("configlist:" + name)
        objects.add(list_id, "XCConfigurationList", [
            ("buildConfigurations", ref_list([debug_id, release_id])),
            ("defaultConfigurationIsVisible", "0"),
            ("defaultConfigurationName", "Release"),
        ])
        return list_id

    project_list = config_list("project", project_debug, project_release)
    app_list = config_list("app", app_debug, app_release)
    ext_list = config_list("ext", ext_debug, ext_release)

    app_target = uid("target:app")
    ext_target = uid("target:ext")
    proxy = uid("proxy:ext")
    objects.add(proxy, "PBXContainerItemProxy", [
        ("containerPortal", uid("project")),
        ("proxyType", "1"),
        ("remoteGlobalIDString", ext_target),
        ("remoteInfo", '"AmneziaVPNNetworkExtension"'),
    ])
    dep = uid("dependency:ext")
    objects.add(dep, "PBXTargetDependency", [
        ("target", ext_target),
        ("targetProxy", proxy),
    ])
    objects.add(app_target, "PBXNativeTarget", [
        ("buildConfigurationList", app_list),
        ("buildPhases", ref_list([app_sources_phase, app_frameworks_phase, app_resources_phase, app_embed_phase])),
        ("buildRules", "()"),
        ("dependencies", ref_list([dep])),
        ("name", '"AmneziaVPN"'),
        ("productName", '"AmneziaVPN"'),
        ("productReference", app_product_ref),
        ("productType", '"com.apple.product-type.application"'),
    ])
    objects.add(ext_target, "PBXNativeTarget", [
        ("buildConfigurationList", ext_list),
        ("buildPhases", ref_list([ext_script_phase, ext_sources_phase, ext_frameworks_phase, ext_resources_phase])),
        ("buildRules", "()"),
        ("dependencies", "()"),
        ("name", '"AmneziaVPNNetworkExtension"'),
        ("packageProductDependencies", ref_list([package_product])),
        ("productName", '"AmneziaVPNNetworkExtension"'),
        ("productReference", ext_product_ref),
        ("productType", '"com.apple.product-type.app-extension"'),
    ])

    def subgroup(name, files):
        children = [uid("fileref:" + f) for f in files]
        return group(name, None, children)

    core_group = subgroup("Core", [
        "App/Core/Logger.swift",
        "App/Core/LocalCore.swift",
        "App/Core/Models.swift",
        "App/Core/ServerStore.swift",
        "App/Core/SettingsStore.swift",
        "App/Core/SplitTunnelingStore.swift",
        "App/Core/Importer.swift",
        "App/Core/VPNKeyDecoder.swift",
        "App/Core/VPNKeyEncoder.swift",
        "App/Core/WGConfigBuilder.swift",
    ])
    views_group = subgroup("Views", [
        "App/Views/Controls.swift",
        "App/Views/RootView.swift",
        "App/Views/HomeView.swift",
        "App/Views/ServerInfoView.swift",
        "App/Views/ServerDataView.swift",
        "App/Views/SettingsView.swift",
        "App/Views/ConnectionView.swift",
        "App/Views/ApplicationView.swift",
        "App/Views/AboutView.swift",
        "App/Views/SplitTunnelingView.swift",
        "App/Views/LoggingView.swift",
        "App/Views/SetupWizardView.swift",
        "App/Views/QrReaderView.swift",
        "App/Views/ShareView.swift",
    ])
    app_group = group("App", None, [
        uid("fileref:App/AmneziaVPNApp.swift"),
        uid("fileref:App/AppState.swift"),
        uid("fileref:App/BuildConfig.swift"),
        uid("fileref:App/Theme.swift"),
        uid("fileref:App/Info.plist"),
        uid("fileref:App/Assets.xcassets"),
        core_group,
        views_group,
    ])
    ext_group = group("Extension", None, [
        uid("fileref:Extension/PacketTunnelProvider.swift"),
        uid("fileref:Extension/WGConfig.swift"),
        uid("fileref:Extension/WgQuickConfig.swift"),
        uid("fileref:Extension/Info.plist"),
    ])
    bridge_group = group("Bridge", None, [
        uid("fileref:Bridge/AmneziaCoreBridge.h"),
        uid("fileref:Bridge/AmneziaCoreBridge.mm"),
    ])
    resources_group = group("Resources", None, [
        uid("fileref:../ios/app/AmneziaVPNLaunchScreen.storyboard"),
        uid("fileref:../ios/app/launch.png"),
        uid("fileref:../ios/app/PrivacyInfo.xcprivacy"),
        uid("fileref:../ios/networkextension/PrivacyInfo.xcprivacy"),
        uid("fileref:../images/AppIcon.icon"),
    ])
    products_group = group("Products", None, [app_product_ref, ext_product_ref])
    main_group = group("", None, [app_group, ext_group, bridge_group, resources_group, products_group])

    objects.add(uid("project"), "PBXProject", [
        ("attributes", "{LastUpgradeCheck = 2600; TargetAttributes = {" + app_target + " = {CreatedOnToolsVersion = 26.0; }; " + ext_target + " = {CreatedOnToolsVersion = 26.0; }; }; }"),
        ("buildConfigurationList", project_list),
        ("compatibilityVersion", '"Xcode 16.0"'),
        ("developmentRegion", "en"),
        ("hasScannedForEncodings", "0"),
        ("knownRegions", "(en, )"),
        ("mainGroup", main_group),
        ("packageReferences", ref_list([package_ref])),
        ("productRefGroup", products_group),
        ("projectDirPath", '""'),
        ("projectRoot", '""'),
        ("targets", ref_list([app_target, ext_target])),
    ])

    os.makedirs(PROJ_DIR, exist_ok=True)
    with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as f:
        f.write(objects.render())
    print("wrote", os.path.join(PROJ_DIR, "project.pbxproj"))


if __name__ == "__main__":
    main()

