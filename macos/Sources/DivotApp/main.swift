import AppKit
import DivotAppKit

@MainActor
private func run() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--report") {
        DivotAppReport.run()
        return
    }
    if arguments.contains("--widgets") {
        DivotAppWidgetReport.run()
        return
    }
    if arguments.contains("--bench") {
        DivotBench.run(arguments: arguments)
        return
    }
    if arguments.contains("--help") || arguments.contains("-h") {
        print("divot — persistent top/below bar shell")
        print("usage: divot [--report] [--widgets] [--bench [--json]] [--help]")
        print("  --report   print the current display/menu-bar observation and exit")
        print("  --widgets  run the built-in providers briefly and print live values, then exit")
        print("  --bench    run the performance harness and print this run's measurements, then exit")
        print("             optional: --json, and --commit/--hardware/--displays/--appearance/--power facts")
        return
    }

    let delegate = DivotAppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

run()
