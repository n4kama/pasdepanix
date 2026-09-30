// calendar-mcp: read-only MCP server (stdio) for macOS Calendar events and
// Reminders, exposing a single tool, list_events.
//
// macOS grants calendar access only to an app whose Info.plist declares it, and
// charges a child process to its parent app: spawned by Claude Desktop, whose
// Info.plist does not declare it, EventKit refuses without even prompting. So
// the server relaunches its own bundle through `open`, which runs it as an app
// of its own with its own permission, and reads the result back from a file.
//
//   calendar-mcp                      MCP server on stdin/stdout
//   calendar-mcp --query START END    one query, JSON on stdout (run by `open`)

import EventKit
import Foundation

let day = DateFormatter()
day.locale = Locale(identifier: "en_US_POSIX")
day.dateFormat = "yyyy-MM-dd"
let iso = ISO8601DateFormatter()
iso.timeZone = .current

func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
}

// Blocks on an EventKit callback. Only the --query process does this, and it
// has nothing else to do in the meantime.
func wait<T>(_ call: (@escaping (T) -> Void) -> Void) -> T {
    let done = DispatchSemaphore(value: 0)
    var result: T!
    call { result = $0; done.signal() }
    done.wait()
    return result
}

func granted(_ request: (@escaping (Bool, Error?) -> Void) -> Void) -> Bool {
    wait { done in request { ok, _ in done(ok) } }
}

// Events between START and END (both days inclusive), plus every incomplete
// reminder that is due by END, overdue, or has no due date: an undated
// reminder is a task to do as soon as possible, so it shows until completed.
func query(_ startDay: String, _ endDay: String) -> [String: Any] {
    guard let start = day.date(from: startDay), let lastDay = day.date(from: endDay), lastDay >= start else {
        return ["error": "start and end must be YYYY-MM-DD dates, with start <= end"]
    }
    let calendar = Calendar.current
    let end = calendar.date(byAdding: .day, value: 1, to: lastDay)!
    let store = EKEventStore()
    guard granted(store.requestFullAccessToEvents), granted(store.requestFullAccessToReminders) else {
        return ["error": "Calendar or Reminders access denied. Allow calendar-mcp in System Settings > Privacy & Security."]
    }

    let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        .sorted { $0.startDate < $1.startDate }
        .map { e -> [String: Any] in
            [
                "title": e.title ?? "",
                "start": e.isAllDay ? day.string(from: e.startDate) : iso.string(from: e.startDate),
                "end": e.isAllDay ? day.string(from: e.endDate) : iso.string(from: e.endDate),
                "all_day": e.isAllDay,
                "calendar": e.calendar.title,
                "location": e.location as Any?,
                "notes": e.notes as Any?,
            ].compactMapValues { $0 }
        }

    let now = Date()
    let today = calendar.startOfDay(for: now)
    let pending: [EKReminder] = wait { done in
        store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { done($0 ?? []) }
    }
    let reminders = pending
        .map { r in (r, r.dueDateComponents.flatMap { calendar.date(from: $0) }) }
        .filter { _, due in due.map { $0 < end } ?? true }
        .sorted { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
        .map { r, due -> [String: Any] in
            // A due date without a time is overdue only once its day has passed.
            let dateOnly = r.dueDateComponents?.hour == nil
            return [
                "title": r.title ?? "",
                "list": r.calendar.title,
                "due": due.map { dateOnly ? day.string(from: $0) : iso.string(from: $0) } as Any?,
                "overdue": due.map { dateOnly ? $0 < today : $0 < now } ?? false,
                "notes": r.notes as Any?,
            ].compactMapValues { $0 }
        }
    return ["events": events, "reminders": reminders]
}

let args = CommandLine.arguments
if args.count == 4, args[1] == "--query" {
    FileHandle.standardOutput.write(json(query(args[2], args[3])))
    exit(0)
}

// Runs the query as its own app (see the top of this file) and returns its JSON.
func relaunch(_ start: String, _ end: String) -> Data {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("calendar-mcp-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: out) }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-W", "-g", "-n", "--stdout", out.path, Bundle.main.bundlePath, "--args", "--query", start, end]
    open.standardOutput = FileHandle.nullDevice // stdout is the MCP channel
    do { try open.run() } catch { return json(["error": "cannot run open: \(error)"]) }
    open.waitUntilExit()
    // Not open's exit status: when the query exits before `open -W` gets hold of
    // it, open fails ("Unable to block on application") yet the output is there.
    guard let data = try? Data(contentsOf: out), !data.isEmpty else {
        return json(["error": "the query app failed to run (open exited with \(open.terminationStatus))"])
    }
    return data
}

let tool: [String: Any] = [
    "name": "list_events",
    "description": """
        List macOS Calendar events and Reminders between two dates, both inclusive. \
        Events include their notes (the description). Reminders are the incomplete ones \
        due by the end date, including overdue ones (flagged "overdue") and ones with no \
        due date. Times are ISO 8601 in local time; all-day events and date-only \
        reminders use YYYY-MM-DD.
        """,
    "inputSchema": [
        "type": "object",
        "properties": [
            "start": ["type": "string", "description": "First day, YYYY-MM-DD. Defaults to today."],
            "end": ["type": "string", "description": "Last day, YYYY-MM-DD. Defaults to start."],
        ],
    ],
]

func send(_ message: [String: Any]) {
    FileHandle.standardOutput.write(json(message) + Data("\n".utf8))
}

while let line = readLine() {
    // Notifications (no id) need no reply.
    guard let message = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
          let id = message["id"] else { continue }
    let params = message["params"] as? [String: Any] ?? [:]
    var result: [String: Any]
    switch message["method"] as? String {
    case "initialize":
        result = [
            "protocolVersion": params["protocolVersion"] ?? "2025-06-18",
            "capabilities": ["tools": [String: Any]()],
            "serverInfo": ["name": "calendar-mcp", "version": "1.0"],
        ]
    case "ping":
        result = [:]
    case "tools/list":
        result = ["tools": [tool]]
    case "tools/call" where params["name"] as? String == "list_events":
        let input = params["arguments"] as? [String: Any] ?? [:]
        let start = input["start"] as? String ?? day.string(from: Date())
        let data = relaunch(start, input["end"] as? String ?? start)
        let failed = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] != nil
        result = ["content": [["type": "text", "text": String(decoding: data, as: UTF8.self)]], "isError": failed]
    default:
        send(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found"]])
        continue
    }
    send(["jsonrpc": "2.0", "id": id, "result": result])
}
