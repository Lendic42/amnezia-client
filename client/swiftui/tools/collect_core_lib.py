#!/usr/bin/env python3
import os
import re
import subprocess
import sys

QT_SEED_MODULES = [
    "Core",
    "Gui",
    "Network",
    "Xml",
    "RemoteObjects",
    "Quick",
    "Svg",
    "QuickControls2",
    "Core5Compat",
    "Concurrent",
    "ShaderTools",
]

IOS_FRAMEWORKS = [
    "AuthenticationServices",
    "UIKit",
    "AVFoundation",
    "Foundation",
    "StoreKit",
    "UserNotifications",
    "NetworkExtension",
]

CONAN_ARCHIVES = {
    "libagw.a": "libagw",
    "libssl.a": "openssl",
    "libcrypto.a": "openssl",
    "libssh.a": "libssh",
    "libz.a": "zlib",
}

BUILTIN_ARCHIVES = [
    "libSortFilterProxyModel.a",
    "libqt6keychain.a",
]


def fail(message):
    print(f"collect_core_lib: error: {message}", file=sys.stderr)
    sys.exit(1)


def read_prl_libs(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    text = re.sub(r"\\\n", " ", text)
    match = re.search(r"^QMAKE_PRL_LIBS\s*=\s*(.*)$", text, re.MULTILINE)
    if not match:
        return []
    return match.group(1).split()


def qt_module_paths(qt_lib_dir, module):
    framework_dir = os.path.join(qt_lib_dir, f"Qt{module}.framework")
    framework_prl = os.path.join(framework_dir, f"Qt{module}.prl")
    framework_binary = os.path.join(framework_dir, f"Qt{module}")
    if os.path.isfile(framework_prl) and os.path.isfile(framework_binary):
        return framework_prl, framework_binary
    prl_path = os.path.join(qt_lib_dir, f"libQt6{module}.prl")
    archive = os.path.join(qt_lib_dir, f"libQt6{module}.a")
    if os.path.isfile(prl_path) and os.path.isfile(archive):
        return prl_path, archive
    fail(f"missing Qt module {module}: no {framework_prl} and no {prl_path}")


def qt_framework_exists(qt_lib_dir, module):
    return os.path.isdir(os.path.join(qt_lib_dir, f"Qt{module}.framework"))


def resolve_qt_closure(qt_lib_dir):
    archives = {}
    frameworks = set()
    link_flags = set()
    queue = list(QT_SEED_MODULES)
    seen = set()
    while queue:
        module = queue.pop(0)
        if module in seen:
            continue
        seen.add(module)
        prl_path, archive = qt_module_paths(qt_lib_dir, module)
        archives[module] = archive
        tokens = read_prl_libs(prl_path)
        index = 0
        while index < len(tokens):
            token = tokens[index]
            if token == "-framework" and index + 1 < len(tokens):
                name = tokens[index + 1]
                if name.startswith("Qt"):
                    dep = name[2:]
                    if dep.startswith("6"):
                        dep = dep[1:]
                    if qt_framework_exists(qt_lib_dir, dep):
                        queue.append(dep)
                    else:
                        frameworks.add(name)
                else:
                    frameworks.add(name)
                index += 2
            elif token.startswith("-lQt6"):
                queue.append(token[5:])
                index += 1
            elif token.startswith("-l"):
                link_flags.add(token)
                index += 1
            elif token.endswith(".a") and os.path.isabs(token):
                archives[os.path.basename(token)] = token
                index += 1
            else:
                index += 1
    return archives, frameworks, link_flags


def find_archive(root, name, package):
    matches = []
    for dirpath, _dirnames, filenames in os.walk(root):
        if name not in filenames:
            continue
        parts = dirpath.split(os.sep)
        if package and not any(part.startswith(package) for part in parts):
            continue
        matches.append(os.path.join(dirpath, name))
    if not matches:
        fail(f"archive {name} not found under {root}")
    matches.sort()
    return matches[0]


def find_builtin_archive(build_dir, name):
    matches = []
    for dirpath, _dirnames, filenames in os.walk(build_dir):
        if name in filenames:
            matches.append(os.path.join(dirpath, name))
    if not matches:
        fail(f"archive {name} not found under {build_dir}")
    matches.sort()
    return matches[0]


def main():
    build_dir = sys.argv[1]
    qt_ios_dir = sys.argv[2]
    out_dir = sys.argv[3]
    conan_home = os.environ.get("CONAN_HOME", os.path.expanduser("~/.conan2"))

    core_archive = None
    for dirpath, _dirnames, filenames in os.walk(build_dir):
        if "libAmneziaCore.a" in filenames:
            core_archive = os.path.join(dirpath, "libAmneziaCore.a")
            break
    if not core_archive:
        fail(f"libAmneziaCore.a not found under {build_dir}")

    qt_lib_dir = os.path.join(qt_ios_dir, "lib")
    qt_archives, frameworks, link_flags = resolve_qt_closure(qt_lib_dir)

    platform_plugin = os.path.join(qt_ios_dir, "plugins", "platforms", "libqios.a")
    if not os.path.isfile(platform_plugin):
        fail(f"missing Qt iOS platform plugin: {platform_plugin}")

    conan_archives = []
    for name, package in CONAN_ARCHIVES.items():
        conan_archives.append(find_archive(conan_home, name, package))

    builtin_archives = [find_builtin_archive(build_dir, name) for name in BUILTIN_ARCHIVES]

    all_archives = [core_archive, platform_plugin]
    all_archives.extend(sorted(qt_archives.values()))
    all_archives.extend(sorted(conan_archives))
    all_archives.extend(sorted(builtin_archives))
    all_archives = sorted(set(all_archives))

    os.makedirs(out_dir, exist_ok=True)
    merged = os.path.join(out_dir, "libAmneziaCore.a")
    subprocess.run(["libtool", "-static", "-o", merged] + all_archives, check=True)

    frameworks.update(IOS_FRAMEWORKS)
    lines = ["OTHER_LDFLAGS = $(inherited)"]
    for framework in sorted(frameworks):
        lines.append(f"OTHER_LDFLAGS += -framework {framework}")
    for flag in sorted(link_flags):
        lines.append(f"OTHER_LDFLAGS += {flag}")
    xcconfig = os.path.join(out_dir, "CoreLibLink.xcconfig")
    with open(xcconfig, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")

    print(f"merged {len(all_archives)} archives into {merged}")
    for archive in all_archives:
        print(f"  {archive}")
    print(f"frameworks: {', '.join(sorted(frameworks))}")
    print(f"link flags: {', '.join(sorted(link_flags)) or '(none)'}")
    print(f"wrote {xcconfig}")


if __name__ == "__main__":
    main()
