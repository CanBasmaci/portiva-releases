#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_root="${BUILD_ROOT:-$project_root/build}"
products="$build_root/Build/Products/Release"
mkdir -p "$build_root/tests" "$build_root/TestModuleCache"
xcrun swiftc -module-cache-path "$build_root/TestModuleCache" "$project_root/Portiva/SerialConnection.swift" "$project_root/Tests/main.swift" -o "$build_root/tests/serial-tests"
"$build_root/tests/serial-tests"
if [ ! -f "$products/SwiftTerm.o" ]; then
    echo 'Build the Release scheme before running terminal tests.' >&2
    exit 1
fi
xcrun swiftc -module-cache-path "$build_root/TestModuleCache" -I "$products" "$project_root/Portiva/SerialConnection.swift" "$project_root/Portiva/TerminalHost.swift" "$project_root/Tests/Terminal/main.swift" "$products/SwiftTerm.o" -o "$products/PortivaTerminalTests"
"$products/PortivaTerminalTests"
xcrun swiftc -module-cache-path "$build_root/TestModuleCache" -I "$products" "$project_root/Portiva/SerialConnection.swift" "$project_root/Portiva/TerminalHost.swift" "$project_root/Portiva/Workspace.swift" "$project_root/Portiva/ConnectionSession.swift" "$project_root/Portiva/SessionRecorder.swift" "$project_root/Tests/Workspace/main.swift" "$products/SwiftTerm.o" -o "$products/PortivaWorkspaceTests"
"$products/PortivaWorkspaceTests" "$build_root/tests/workspace"
