// calendar-mcp: MCP server (stdio) for macOS Calendar events and Reminders. It
// lists them (list_events, and list_reminders for one list with its sections),
// creates new ones (create_event, create_reminder), and edits an event's dates,
// title, location, notes or url (update_event) or a reminder's title, notes, url
// or due date (update_reminder). It never deletes or completes anything, and
// changes nothing else of an existing event or reminder.
//
// macOS grants calendar access only to an app whose Info.plist declares it, and
// charges a child process to its parent app: spawned by an MCP client, it
// borrows the client's app (for Claude Code, the terminal), and when that app's
// Info.plist does not declare it, EventKit refuses without even prompting. So
// the server relaunches its own bundle through `open`, which runs it as an app
// of its own with its own permission, and reads the result back from a file.
//
//   calendar-mcp                            MCP server on stdin/stdout
//   calendar-mcp --query START END          one query, JSON on stdout (run by `open`)
//   calendar-mcp --create-event JSON        one creation, JSON on stdout (run by `open`)
//   calendar-mcp --create-reminder JSON
//   calendar-mcp --update-event JSON
//   calendar-mcp --list-reminders JSON
//   calendar-mcp --update-reminder JSON

import EventKit
import Foundation

let day = DateFormatter()
day.locale = Locale(identifier: "en_US_POSIX")
day.dateFormat = "yyyy-MM-dd"
let iso = ISO8601DateFormatter()
iso.timeZone = .current
let localTime = DateFormatter()
localTime.locale = Locale(identifier: "en_US_POSIX")
localTime.dateFormat = "yyyy-MM-dd'T'HH:mm"

func json(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
}

// Blocks on an EventKit callback. Only the relaunched process does this, and it
// has nothing else to do in the meantime.
func wait<T>(_ call: (@escaping (T) -> Void) -> Void) -> T {
    let done = DispatchSemaphore(value: 0)
    var result: T!
    call { result = $0; done.signal() }
    done.wait()
    return result
}

// EventKit can return "" rather than nil for an empty field (seen on reminder notes).
func nonEmpty(_ text: String?) -> String? {
    text?.isEmpty == false ? text : nil
}

func granted(_ request: (@escaping (Bool, Error?) -> Void) -> Void) -> Bool {
    wait { done in request { ok, _ in done(ok) } }
}

let accessDenied: [String: Any] = ["error": "Calendar or Reminders access denied. Allow calendar-mcp in System Settings > Privacy & Security."]

// A day (YYYY-MM-DD), or a time: ISO 8601 with an offset, or local without one
// (YYYY-MM-DDTHH:MM, seconds ignored). dateOnly tells which it was.
func parseTime(_ text: String) -> (date: Date, dateOnly: Bool)? {
    if text.count == 10 { return day.date(from: text).map { ($0, true) } }
    return (iso.date(from: text) ?? localTime.date(from: String(text.prefix(16)))).map { ($0, false) }
}

// The calendar (or reminder list) named `name`, or the macOS default for new
// items when no name is given. A name shared by several writable calendars, on
// different accounts, is refused rather than guessed.
struct Refusal: Error { let reason: String }

func target(_ store: EKEventStore, _ type: EKEntityType, _ name: String?) throws -> EKCalendar {
    guard let name else {
        let fallback = type == .event ? store.defaultCalendarForNewEvents : store.defaultCalendarForNewReminders()
        guard let fallback else { throw Refusal(reason: "no default calendar is set") }
        return fallback
    }
    let matches = store.calendars(for: type).filter { $0.title == name && $0.allowsContentModifications }
    switch matches.count {
    case 1: return matches[0]
    case 0: throw Refusal(reason: "no writable calendar or list named \"\(name)\"")
    default: throw Refusal(reason: "\"\(name)\" names several calendars, on \(matches.map(\.source.title).joined(separator: ", ")); omit it to use the default")
    }
}

func eventInfo(_ e: EKEvent) -> [String: Any] {
    let alerts = (e.alarms ?? []).filter { $0.absoluteDate == nil }.map { Int(-$0.relativeOffset / 60) }
    return [
        "id": e.eventIdentifier as Any?,
        "title": e.title ?? "",
        "start": e.isAllDay ? day.string(from: e.startDate) : iso.string(from: e.startDate),
        "end": e.isAllDay ? day.string(from: e.endDate) : iso.string(from: e.endDate),
        "all_day": e.isAllDay,
        "calendar": e.calendar.title,
        "location": nonEmpty(e.location) as Any?,
        "notes": nonEmpty(e.notes) as Any?,
        "url": e.url?.absoluteString as Any?,
        "alerts": alerts.isEmpty ? nil : alerts as Any?,
    ].compactMapValues { $0 }
}

func reminderInfo(_ r: EKReminder, now: Date = Date()) -> [String: Any] {
    let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
    // A due date without a time is overdue only once its day has passed.
    let dateOnly = r.dueDateComponents?.hour == nil
    return [
        "id": r.calendarItemIdentifier,
        "title": r.title ?? "",
        "list": r.calendar.title,
        "due": due.map { dateOnly ? day.string(from: $0) : iso.string(from: $0) } as Any?,
        "overdue": due.map { dateOnly ? $0 < Calendar.current.startOfDay(for: now) : $0 < now } ?? false,
        "notes": nonEmpty(r.notes) as Any?,
        "url": r.url?.absoluteString as Any?,
    ].compactMapValues { $0 }
}

// Events between START and END (both days inclusive), plus every incomplete
// reminder that is due by END, overdue, or has no due date: an undated
// reminder is a task to do as soon as possible, so it shows until completed.
func query(_ startDay: String, _ endDay: String) -> [String: Any] {
    guard let start = day.date(from: startDay), let lastDay = day.date(from: endDay), lastDay >= start else {
        return ["error": "start and end must be YYYY-MM-DD dates, with start <= end"]
    }
    let end = Calendar.current.date(byAdding: .day, value: 1, to: lastDay)!
    let store = EKEventStore()
    guard granted(store.requestFullAccessToEvents), granted(store.requestFullAccessToReminders) else {
        return accessDenied
    }

    let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        .sorted { $0.startDate < $1.startDate }
        .map(eventInfo)

    let now = Date()
    let pending: [EKReminder] = wait { done in
        store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { done($0 ?? []) }
    }
    let reminders = pending
        .map { r in (r, r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }) }
        .filter { _, due in due.map { $0 < end } ?? true }
        .sorted { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
        .map { r, _ in reminderInfo(r, now: now) }
    return ["events": events, "reminders": reminders]
}

// The dates of an event from the input's start, end and all_day: days for an
// all-day event (end inclusive, the start day by default), times otherwise
// (end 1 hour after the start by default).
func timing(_ input: [String: Any]) -> Result<(start: Date, end: Date, allDay: Bool), Refusal> {
    let allDay = input["all_day"] as? Bool ?? false
    guard let start = (input["start"] as? String).flatMap(parseTime), start.dateOnly == allDay else {
        return .failure(Refusal(reason: allDay ? "an all-day event needs start as YYYY-MM-DD" : "start must be a time, YYYY-MM-DDTHH:MM"))
    }
    var end = allDay ? start.date : start.date.addingTimeInterval(3600)
    if let endText = input["end"] as? String {
        guard let parsed = parseTime(endText), parsed.dateOnly == allDay, parsed.date >= start.date else {
            return .failure(Refusal(reason: "end must have the same form as start, and not come before it"))
        }
        end = parsed.date
    }
    return .success((start.date, end, allDay))
}

func createEvent(_ input: [String: Any]) -> [String: Any] {
    guard let title = nonEmpty(input["title"] as? String) else { return ["error": "title is required"] }
    let when: (start: Date, end: Date, allDay: Bool)
    switch timing(input) {
    case .success(let t): when = t
    case .failure(let refusal): return ["error": refusal.reason]
    }
    let store = EKEventStore()
    guard granted(store.requestFullAccessToEvents) else { return accessDenied }
    let calendar: EKCalendar
    do { calendar = try target(store, .event, input["calendar"] as? String) } catch let refusal as Refusal { return ["error": refusal.reason] } catch { return ["error": "\(error)"] }

    let event = EKEvent(eventStore: store)
    event.calendar = calendar
    event.title = title
    event.isAllDay = when.allDay
    event.startDate = when.start
    event.endDate = when.end
    event.location = input["location"] as? String
    event.notes = input["notes"] as? String
    event.url = (input["url"] as? String).flatMap(URL.init(string:))
    for minutes in input["alerts"] as? [Int] ?? [] {
        event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
    }
    do { try store.save(event, span: .thisEvent, commit: true) } catch { return ["error": "cannot save the event: \(error.localizedDescription)"] }
    return ["created": eventInfo(event)]
}

// Edits the event `id` (from list_events): its dates when start is given, and
// each of title, location, notes and url that is given. An empty location, notes
// or url clears it. A recurring event changes only in the occurrence that id
// names.
func updateEvent(_ input: [String: Any]) -> [String: Any] {
    guard let id = nonEmpty(input["id"] as? String) else { return ["error": "id is required"] }
    let fields = ["start", "title", "location", "notes", "url"]
    guard fields.contains(where: { input[$0] != nil }) else { return ["error": "give at least one of \(fields.joined(separator: ", "))"] }
    if input["title"] != nil, nonEmpty(input["title"] as? String) == nil { return ["error": "title cannot be empty"] }
    var when: (start: Date, end: Date, allDay: Bool)?
    if input["start"] != nil {
        switch timing(input) {
        case .success(let t): when = t
        case .failure(let refusal): return ["error": refusal.reason]
        }
    } else if input["end"] != nil || input["all_day"] != nil {
        return ["error": "end and all_day need start"]
    }
    let store = EKEventStore()
    guard granted(store.requestFullAccessToEvents) else { return accessDenied }
    guard let event = store.event(withIdentifier: id) else { return ["error": "no event with id \(id)"] }
    guard event.calendar.allowsContentModifications else { return ["error": "the calendar \"\(event.calendar.title)\" is read-only"] }

    if let when {
        event.isAllDay = when.allDay
        event.startDate = when.start
        event.endDate = when.end
    }
    if let title = input["title"] as? String { event.title = title }
    if let location = input["location"] as? String { event.location = nonEmpty(location) }
    if let notes = input["notes"] as? String { event.notes = nonEmpty(notes) }
    if let url = input["url"] as? String { event.url = nonEmpty(url).flatMap(URL.init(string:)) }
    do { try store.save(event, span: .thisEvent, commit: true) } catch { return ["error": "cannot save the event: \(error.localizedDescription)"] }
    return ["updated": eventInfo(event)]
}

// A due time also sets an alert at that time, as the Reminders app does:
// without one, EventKit saves a reminder that never notifies.
func createReminder(_ input: [String: Any]) -> [String: Any] {
    guard let title = nonEmpty(input["title"] as? String) else { return ["error": "title is required"] }
    var due: (date: Date, dateOnly: Bool)?
    if let dueText = input["due"] as? String {
        guard let parsed = parseTime(dueText) else { return ["error": "due must be YYYY-MM-DD or YYYY-MM-DDTHH:MM"] }
        due = parsed
    }
    let store = EKEventStore()
    guard granted(store.requestFullAccessToReminders) else { return accessDenied }
    let list: EKCalendar
    do { list = try target(store, .reminder, input["list"] as? String) } catch let refusal as Refusal { return ["error": refusal.reason] } catch { return ["error": "\(error)"] }

    let reminder = EKReminder(eventStore: store)
    reminder.calendar = list
    reminder.title = title
    reminder.notes = input["notes"] as? String
    reminder.url = (input["url"] as? String).flatMap(URL.init(string:))
    if let due { setDue(reminder, due) }
    do { try store.save(reminder, commit: true) } catch { return ["error": "cannot save the reminder: \(error.localizedDescription)"] }
    return ["created": reminderInfo(reminder)]
}

// Sets a reminder's due date, nil to clear it. The alert at the due time goes
// with it: absolute-date alerts are the due-time ones this server adds, and
// the Reminders app adds the same.
func setDue(_ reminder: EKReminder, _ due: (date: Date, dateOnly: Bool)?) {
    for alarm in reminder.alarms ?? [] where alarm.absoluteDate != nil { reminder.removeAlarm(alarm) }
    guard let due else { reminder.dueDateComponents = nil; return }
    var components = Calendar.current.dateComponents(due.dateOnly ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute], from: due.date)
    if !due.dateOnly {
        components.timeZone = .current
        reminder.addAlarm(EKAlarm(absoluteDate: due.date))
    }
    reminder.dueDateComponents = components
}

// Edits the reminder `id` (from list_events or list_reminders): each of title,
// notes, url and due that is given. An empty notes, url or due clears it.
func updateReminder(_ input: [String: Any]) -> [String: Any] {
    guard let id = nonEmpty(input["id"] as? String) else { return ["error": "id is required"] }
    let fields = ["title", "notes", "url", "due"]
    guard fields.contains(where: { input[$0] != nil }) else { return ["error": "give at least one of \(fields.joined(separator: ", "))"] }
    if input["title"] != nil, nonEmpty(input["title"] as? String) == nil { return ["error": "title cannot be empty"] }
    var due: (date: Date, dateOnly: Bool)?
    if let dueText = nonEmpty(input["due"] as? String) {
        guard let parsed = parseTime(dueText) else { return ["error": "due must be YYYY-MM-DD or YYYY-MM-DDTHH:MM"] }
        due = parsed
    }
    let store = EKEventStore()
    guard granted(store.requestFullAccessToReminders) else { return accessDenied }
    guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return ["error": "no reminder with id \(id)"] }
    guard reminder.calendar.allowsContentModifications else { return ["error": "the list \"\(reminder.calendar.title)\" is read-only"] }

    if let title = input["title"] as? String { reminder.title = title }
    if let notes = input["notes"] as? String { reminder.notes = nonEmpty(notes) }
    if let url = input["url"] as? String { reminder.url = nonEmpty(url).flatMap(URL.init(string:)) }
    if input["due"] != nil { setDue(reminder, due) }
    do { try store.save(reminder, commit: true) } catch { return ["error": "cannot save the reminder: \(error.localizedDescription)"] }
    return ["updated": reminderInfo(reminder)]
}

// The rows of a query on an SQLite database, opened read-only by macOS's own
// sqlite3, as JSON objects; none when it cannot be read.
func sqlite(_ path: String, _ sql: String) -> [[String: Any]] {
    let run = Process()
    run.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    run.arguments = ["-readonly", "-json", path, sql]
    let out = Pipe()
    run.standardOutput = out
    run.standardError = FileHandle.nullDevice
    guard (try? run.run()) != nil else { return [] }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    run.waitUntilExit()
    return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
}

// The sections of the Reminders lists named `name`, and the section of each of
// their reminders, keyed by the reminder's external identifier. EventKit has
// no sections, so they come from the Reminders app's own databases, opened
// read-only: an undocumented schema (macOS 14 to 26), so anything unreadable
// leaves the sections out rather than failing. Reading them needs Full Disk
// Access for the app (System Settings > Privacy & Security), which macOS never
// prompts for. Sections come in creation order.
// shortcut: creation order, not the order set by dragging (stored in
// ZSECTIONIDSORDERINGASDATA); read that if sections get reordered by hand.
func sections(ofList name: String) -> (names: [String], byReminder: [String: String]) {
    let stores = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Group Containers/group.com.apple.reminders/Container_v1/Stores")
    var names: [String] = []
    var byReminder: [String: String] = [:]
    for file in (try? FileManager.default.contentsOfDirectory(atPath: stores.path)) ?? []
    where file.hasPrefix("Data-") && file.hasSuffix(".sqlite") {
        let db = stores.appendingPathComponent(file).path
        var byGroup: [String: String] = [:]
        for row in sqlite(db, """
            SELECT l.ZNAME AS list, s.ZCKIDENTIFIER AS id, s.ZDISPLAYNAME AS name
            FROM ZREMCDBASESECTION s JOIN ZREMCDBASELIST l ON s.ZLIST = l.Z_PK
            WHERE l.ZMARKEDFORDELETION = 0 AND s.ZMARKEDFORDELETION = 0 ORDER BY s.ZCREATIONDATE
            """) where row["list"] as? String == name {
            guard let id = row["id"] as? String, let section = row["name"] as? String else { continue }
            byGroup[id] = section
            names.append(section)
        }
        // {"memberships": [{"groupID": section, "memberID": reminder, "modifiedOn": seconds}]};
        // a reminder moved between sections can be listed more than once, the latest wins.
        for row in sqlite(db, """
            SELECT ZNAME AS list, CAST(ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA AS TEXT) AS memberships
            FROM ZREMCDBASELIST WHERE ZMARKEDFORDELETION = 0 AND ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA IS NOT NULL
            """) where row["list"] as? String == name {
            let text = Data((row["memberships"] as? String ?? "").utf8)
            let memberships = ((try? JSONSerialization.jsonObject(with: text)) as? [String: Any])?["memberships"] as? [[String: Any]] ?? []
            for m in memberships.sorted(by: { ($0["modifiedOn"] as? Double ?? 0) < ($1["modifiedOn"] as? Double ?? 0) }) {
                if let member = m["memberID"] as? String, let group = m["groupID"] as? String, let section = byGroup[group] {
                    byReminder[member] = section
                }
            }
        }
    }
    return (names, byReminder)
}

// The incomplete reminders of the list `list`, oldest first, each with its
// section when it is in one, and the list's sections.
func listReminders(_ input: [String: Any]) -> [String: Any] {
    guard let name = nonEmpty(input["list"] as? String) else { return ["error": "list is required"] }
    let store = EKEventStore()
    guard granted(store.requestFullAccessToReminders) else { return accessDenied }
    let lists = store.calendars(for: .reminder).filter { $0.title == name }
    guard !lists.isEmpty else { return ["error": "no Reminders list named \"\(name)\""] }
    let pending: [EKReminder] = wait { done in
        store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: lists)) { done($0 ?? []) }
    }
    let (names, byReminder) = sections(ofList: name)
    let now = Date()
    let reminders = pending
        .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        .map { r in
            var info = reminderInfo(r, now: now)
            info["section"] = r.calendarItemExternalIdentifier.flatMap { byReminder[$0] }
            return info
        }
    return ["list": name, "sections": names, "reminders": reminders]
}

let args = CommandLine.arguments
if args.count == 4, args[1] == "--query" {
    FileHandle.standardOutput.write(json(query(args[2], args[3])))
    exit(0)
}
let operations = [
    "--create-event": createEvent, "--create-reminder": createReminder, "--update-event": updateEvent,
    "--list-reminders": listReminders, "--update-reminder": updateReminder,
]
if args.count == 3, let run = operations[args[1]] {
    let input = (try? JSONSerialization.jsonObject(with: Data(args[2].utf8))) as? [String: Any] ?? [:]
    FileHandle.standardOutput.write(json(run(input)))
    exit(0)
}

// Runs one operation as its own app (see the top of this file) and returns its JSON.
func relaunch(_ operation: [String]) -> Data {
    let out = FileManager.default.temporaryDirectory.appendingPathComponent("calendar-mcp-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: out) }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-W", "-g", "-n", "--stdout", out.path, Bundle.main.bundlePath, "--args"] + operation
    open.standardOutput = FileHandle.nullDevice // stdout is the MCP channel
    do { try open.run() } catch { return json(["error": "cannot run open: \(error)"]) }
    open.waitUntilExit()
    // Not open's exit status: when the operation exits before `open -W` gets hold
    // of it, open fails ("Unable to block on application") yet the output is there.
    guard let data = try? Data(contentsOf: out), !data.isEmpty else {
        return json(["error": "the calendar-mcp app failed to run (open exited with \(open.terminationStatus))"])
    }
    return data
}

let timeFormat = "a time, YYYY-MM-DDTHH:MM in local time (or ISO 8601 with an offset)"
let tools: [[String: Any]] = [
    [
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
    ],
    [
        "name": "create_event",
        "description": """
            Create a new macOS Calendar event, in the default calendar for new events unless \
            `calendar` names another. Returns the event as saved.
            """,
        "inputSchema": [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "start": ["type": "string", "description": "Start: \(timeFormat); YYYY-MM-DD for an all-day event."],
                "end": ["type": "string", "description": "End, same form as start. Defaults to 1 hour after start, or to the start day for an all-day event (inclusive)."],
                "all_day": ["type": "boolean", "description": "Defaults to false."],
                "location": ["type": "string"],
                "notes": ["type": "string"],
                "url": ["type": "string"],
                "alerts": ["type": "array", "items": ["type": "integer"], "description": "Alerts, in minutes before the start, e.g. [120]."],
                "calendar": ["type": "string", "description": "Calendar name. Omit to use the default calendar."],
            ],
            "required": ["title", "start"],
        ],
    ],
    [
        "name": "update_event",
        "description": """
            Edit an existing macOS Calendar event. Takes the event's id from list_events, \
            and any of: new dates (start, end and all_day as create_event does; end and \
            all_day need start), title, location, notes, url. An empty location, notes or \
            url clears it. Changes nothing else of the event. Returns the event as saved.
            """,
        "inputSchema": [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "The event's id, from list_events."],
                "start": ["type": "string", "description": "Start: \(timeFormat); YYYY-MM-DD for an all-day event."],
                "end": ["type": "string", "description": "End, same form as start. Defaults to 1 hour after start, or to the start day for an all-day event (inclusive)."],
                "all_day": ["type": "boolean", "description": "Defaults to false."],
                "title": ["type": "string"],
                "location": ["type": "string"],
                "notes": ["type": "string"],
                "url": ["type": "string"],
            ],
            "required": ["id"],
        ],
    ],
    [
        "name": "create_reminder",
        "description": """
            Create a new reminder, in the default Reminders list unless `list` names another. \
            A due time also sets an alert at that time. Returns the reminder as saved.
            """,
        "inputSchema": [
            "type": "object",
            "properties": [
                "title": ["type": "string"],
                "due": ["type": "string", "description": "Due day, YYYY-MM-DD, or \(timeFormat). Omit for no due date."],
                "notes": ["type": "string"],
                "url": ["type": "string"],
                "list": ["type": "string", "description": "Reminders list name. Omit to use the default list."],
            ],
            "required": ["title"],
        ],
    ],
    [
        "name": "list_reminders",
        "description": """
            List the incomplete reminders of one Reminders list, oldest first, with the \
            list's sections (in creation order) and each reminder's section, absent when it \
            is in none. Sections are read from the Reminders app's database and may be \
            missing if macOS changes it; they cannot be set.
            """,
        "inputSchema": [
            "type": "object",
            "properties": [
                "list": ["type": "string", "description": "Reminders list name."],
            ],
            "required": ["list"],
        ],
    ],
    [
        "name": "update_reminder",
        "description": """
            Edit an existing reminder. Takes the reminder's id from list_events or \
            list_reminders, and any of: title, notes, url, due (as create_reminder takes it). \
            An empty notes, url or due clears it. Changes nothing else: it cannot complete, \
            delete, or move a reminder to another list or section. Returns the reminder as saved.
            """,
        "inputSchema": [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "The reminder's id, from list_events or list_reminders."],
                "title": ["type": "string"],
                "notes": ["type": "string"],
                "url": ["type": "string"],
                "due": ["type": "string", "description": "Due day, YYYY-MM-DD, or \(timeFormat). Empty to clear."],
            ],
            "required": ["id"],
        ],
    ],
]

func send(_ message: [String: Any]) {
    FileHandle.standardOutput.write(json(message) + Data("\n".utf8))
}

// The relaunch arguments for a tool call, or nil for an unknown tool.
func operation(_ name: String?, _ input: [String: Any]) -> [String]? {
    switch name {
    case "list_events":
        let start = input["start"] as? String ?? day.string(from: Date())
        return ["--query", start, input["end"] as? String ?? start]
    case "create_event":
        return ["--create-event", String(decoding: json(input), as: UTF8.self)]
    case "create_reminder":
        return ["--create-reminder", String(decoding: json(input), as: UTF8.self)]
    case "update_event":
        return ["--update-event", String(decoding: json(input), as: UTF8.self)]
    case "list_reminders":
        return ["--list-reminders", String(decoding: json(input), as: UTF8.self)]
    case "update_reminder":
        return ["--update-reminder", String(decoding: json(input), as: UTF8.self)]
    default:
        return nil
    }
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
            "serverInfo": ["name": "calendar-mcp", "version": "1.3"],
        ]
    case "ping":
        result = [:]
    case "tools/list":
        result = ["tools": tools]
    case "tools/call":
        guard let operation = operation(params["name"] as? String, params["arguments"] as? [String: Any] ?? [:]) else {
            send(["jsonrpc": "2.0", "id": id, "error": ["code": -32602, "message": "Unknown tool"]])
            continue
        }
        let data = relaunch(operation)
        let failed = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] != nil
        result = ["content": [["type": "text", "text": String(decoding: data, as: UTF8.self)]], "isError": failed]
    default:
        send(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found"]])
        continue
    }
    send(["jsonrpc": "2.0", "id": id, "result": result])
}
