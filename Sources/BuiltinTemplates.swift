import Foundation

// The app's own dialog layouts (dialog units, same renderer as imported theme templates). Control ids are the
// functional contract with the screens; geometry and wording are original. A theme pack's dialogs.json overrides these.
enum Builtin {
    private static let push: UInt32 = 0x50010000, def: UInt32 = 0x50010001, check: UInt32 = 0x50010003, radio: UInt32 = 0x50000009
    private static let group: UInt32 = 0x50000007, edit: UInt32 = 0x50810080, pass: UInt32 = 0x508100a0, ctr: UInt32 = 0x50020001
    private static func S(_ t: String, _ x: Int, _ y: Int, _ w: Int, _ h: Int, id: Int = 65535, style: UInt32 = 0x50020000) -> Ctl { Ctl("Static", t, id: id, x, y, w, h, style: style) }
    private static func B(_ t: String, _ id: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ style: UInt32 = 0x50010000) -> Ctl { Ctl("Button", t, id: id, x, y, w, h, style: style) }
    private static func E(_ id: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int, _ style: UInt32 = 0x50810080) -> Ctl { Ctl("Edit", "", id: id, x, y, w, h, style: style) }
    private static func T(_ w: Int, _ h: Int, _ c: [Ctl]) -> Tpl { Tpl(w: dx(w), h: dy(h), ctls: c, pt: 8, face: "Helvetica") }

    static func template(_ key: String) -> Tpl? {
        let app = App.name
        switch key {
        case "1007": return T(170, 96, [
            S("Please enter your ID and password.", 6, 6, 158, 10, id: 1232),
            S("User:", 6, 24, 36, 10), S("", 52, 22, 110, 13, id: 1158),
            S("Password:", 6, 43, 40, 10), E(1159, 52, 41, 110, 12, pass),
            B("Save password", 1031, 52, 57, 70, 10, check),
            S("", 6, 71, 156, 1, style: 0x50001007),
            B("OK", 1, 62, 77, 46, 14, def), B("Cancel", 2, 114, 77, 46, 14)])
        case "1015": return T(240, 54, [
            S("", 36, 6, 196, 18, id: 1200), Ctl("Static", "", id: 65535, 8, 6, 20, 20, style: 0x50000003, ord: 1006),
            B("Yes", 1, 130, 34, 48, 14, def), B("No", 2, 184, 34, 48, 14)])
        case "2001": return T(236, 104, [
            S(app, 88, 6, 140, 10, id: 5082, style: 0x50020080), S("Version " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"), 88, 18, 140, 10, id: 1230),
            S("A retro-styled chat companion.", 88, 32, 140, 10, id: 5084), S("Coming soon: more features.", 88, 44, 140, 10, id: 5085),
            B("https://github.com", 1023, 88, 58, 120, 9), S("This program is not affiliated with any messenger service or its operators.", 6, 76, 224, 22, id: 5081),
            B("OK", 1, 196, 6, 34, 14, 0x50030001)])
        case "2064": return T(210, 100, [
            S("This message is shown to your contacts while this status is set. You can edit it.", 6, 4, 196, 22, id: 1242),
            Ctl("Edit", "", id: 1237, 6, 30, 198, 42, style: 0x50811044),
            B("Select Message", 1541, 6, 80, 64, 14), B("Closing", 1, 138, 80, 66, 14, def)])
        case "2012": return T(220, 170, [
            S("Find people to add to your contact list", 10, 4, 200, 10, style: ctr),
            S("Search by e-mail address:", 10, 20, 200, 10), B("", 1017, 10, 32, 10, 10, radio), E(1130, 24, 31, 186, 12),
            S("Search by name:", 10, 52, 200, 10), B("", 1015, 10, 64, 10, 10, radio),
            S("Nickname:", 24, 64, 44, 10), E(1131, 72, 62, 138, 12), S("First name:", 24, 80, 44, 10), E(1132, 72, 78, 138, 12), S("Last name:", 24, 96, 44, 10), E(1035, 72, 94, 138, 12),
            S("Search by ID number:", 10, 118, 200, 10), B("", 1016, 10, 130, 10, 10, radio), S("ID:", 24, 130, 44, 10), E(1133, 72, 128, 138, 12, 0x58810080)])
        case "2006": return T(220, 170, [
            S("Searching...", 20, 40, 180, 10, style: ctr), B("Retry", 1020, 92, 80, 36, 12, 0x58010000)])
        case "2018": return T(220, 170, [
            S("Done", 10, 8, 200, 12, style: ctr), S("You can add more people at any time from the main window.", 12, 28, 196, 24),
            S("Add another person now?", 12, 70, 196, 10),
            B("Yes", 1141, 20, 86, 100, 10, radio), B("No, later", 1142, 20, 102, 100, 10, radio)])
        case "3018": return T(272, 148, [
            B("Contact authorization", 8053, 2, 2, 176, 38, group), B("Anyone may add me to their contact list", 1364, 12, 14, 160, 10, 0x50020009), B("My authorization is required", 1365, 12, 26, 160, 10, radio),
            B("Change password", 8052, 2, 44, 176, 48, group), S("New password:", 8, 56, 56, 10, id: 8050), E(1366, 98, 54, 70, 12, 0x50810020),
            S("Repeat:", 8, 70, 56, 10, id: 8051), E(1367, 98, 68, 70, 12, 0x50810020), B("Save password", 1368, 98, 82, 70, 8, check),
            B("Publishing", 8057, 184, 2, 86, 38, group), S("Your address stays private.", 190, 14, 76, 22),
            B("Visibility", 8055, 184, 44, 86, 48, group), S("Others cannot see when you are online elsewhere.", 190, 56, 76, 30, id: 8056),
            B("Security level", 8054, 2, 94, 268, 52, group),
            B("Low: password is saved automatically", 1009, 10, 106, 240, 10, radio), B("Medium: password needed to change settings", 1008, 10, 119, 240, 10, radio),
            B("High: password needed to start", 1007, 10, 132, 240, 10, radio)])
        case "3036":
            var c: [Ctl] = [B("Sound events", 65535, 2, 2, 256, 244, group), B("Play the same sound file for all events", 1550, 8, 250, 150, 10, check)]
            let rows: [(String, Int, Int, Int, Int)] = [("Online", 1019, 1015, 1050, 1051), ("Message", 1053, 1054, 1055, 1056), ("Chat", 1020, 1058, 1059, 1060), ("Link", 1021, 1062, 1063, 1064),
                                                         ("File", 1030, 1066, 1067, 1068), ("External", 1022, 1070, 1071, 1072), ("Phone", 1026, 1074, 1075, 1076), ("Contact", 1027, 1077, 1078, 1079)]
            for (i, r) in rows.enumerated() {
                let y = 16 + i * 26
                c += [B(r.0, r.1, 10, y, 60, 10, check), E(r.2, 74, y - 2, 110, 14), B("Select", r.3, 190, y - 2, 30, 14), B("Test", r.4, 224, y - 2, 28, 14)]
            }
            c += [B("Cancel", 2, 152, 264, 50, 14), B("OK", 1, 208, 264, 50, 14)]
            return T(262, 284, c)
        default: return nil
        }
    }
}
