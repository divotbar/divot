import AppKit
import DivotAppKit
import DivotCore

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
    if arguments.first == "config" {
        let outcome = ConfigurationCommand().run(Array(arguments.dropFirst()))
        print(outcome.output)
        exit(outcome.exitCode)
    }
    if arguments.first == "items" {
        let outcome = ItemsCommand().run(Array(arguments.dropFirst()))
        print(outcome.output)
        exit(outcome.exitCode)
    }
    if arguments.first == "theme" {
        let outcome = ThemeCommand().run(Array(arguments.dropFirst()))
        print(outcome.output)
        exit(outcome.exitCode)
    }
    if arguments.first == "status" {
        let outcome = StatusCommand(environment: .live).run(Array(arguments.dropFirst()))
        print(outcome.output)
        exit(outcome.exitCode)
    }
    if arguments.contains("--help") || arguments.contains("-h") {
        print("divot — persistent top/below bar shell")
        print("usage: divot [--report] [--widgets] [--bench [--json]] [config <subcommand>] [items <subcommand>] [theme <subcommand>] [status [--json]] [--help]")
        print("  --report   print the current display/menu-bar observation and exit")
        print("  --widgets  run the built-in providers briefly and print live values, then exit")
        print("  --bench    run the performance harness and print this run's measurements, then exit")
        print("             optional: --json, and --commit/--hardware/--displays/--appearance/--power facts")
        print("  config     inspect and edit the versioned configuration; run `divot config --help`")
        print("  items      list and reorder the bar's items; run `divot items --help`")
        print("  theme      read and set the theme family and mode; run `divot theme --help`")
        print("  status     report the app, permissions, workspace adapter, and config; --json for machines")
        return
    }

    let delegate = DivotAppDelegate()
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

run()
