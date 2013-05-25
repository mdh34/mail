/* Copyright 2011-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Defined by CMake build script.
extern const string _VERSION;

errordomain CommandException {
    USAGE,
    STATE
}

class ImapConsole : Gtk.Window {
    public const string VERSION = _VERSION;
    
    private static const int KEEPALIVE_SEC = 60 * 10;
    
    private Gtk.TextView console = new Gtk.TextView();
    private Gtk.Entry cmdline = new Gtk.Entry();
    private Gtk.Statusbar statusbar = new Gtk.Statusbar();
    
    private uint statusbar_ctx = 0;
    private uint statusbar_msg_id = 0;
    
    private Geary.Imap.ClientConnection? cx = null;
    
    public ImapConsole() {
        title = "IMAP Console";
        destroy.connect(() => { Gtk.main_quit(); });
        set_default_size(800, 600);
        
        Gtk.Box layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        
        console.editable = false;
        Gtk.ScrolledWindow scrolled_console = new Gtk.ScrolledWindow(null, null);
        scrolled_console.add(console);
        scrolled_console.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
        layout.pack_start(scrolled_console, true, true, 0);
        
        cmdline.activate.connect(on_activate);
        layout.pack_start(cmdline, false, false, 0);
        
        statusbar_ctx = statusbar.get_context_id("status");
        layout.pack_end(statusbar, false, false, 0);
        
        add(layout);
        
        cmdline.grab_focus();
    }
    
    private void on_activate() {
        exec(cmdline.buffer.text);
        cmdline.buffer.delete_text(0, -1);
    }
    
    private void clear_status() {
        if (statusbar_msg_id == 0)
            return;
        
        statusbar.remove(statusbar_ctx, statusbar_msg_id);
        statusbar_msg_id = 0;
    }
    
    private void status(string text) {
        clear_status();
        
        string msg = text;
        if (!msg.has_suffix(".") && !msg.has_prefix("usage"))
            msg += ".";
        
        statusbar_msg_id = statusbar.push(statusbar_ctx, msg);
    }
    
    private void exception(Error err) {
        status(err.message);
    }
    
    private static string[] cmdnames = {
        "noop",
        "nop",
        "capabililties",
        "caps",
        "connect",
        "disconnect",
        "login",
        "logout",
        "id",
        "bye",
        "list",
        "xlist",
        "examine",
        "fetch",
        "uid-fetch",
        "fetch-fields",
        "help",
        "exit",
        "quit",
        "gmail",
        "yahoo",
        "keepalive",
        "status",
        "preview",
        "close"
    };
    
    private void exec(string input) {
        string[] lines = input.strip().split(";");
        foreach (string line in lines) {
            string[] tokens = line.strip().split(" ");
            if (tokens.length == 0)
                continue;
            
            string cmd = tokens[0].strip().down();
            
            string[] args = new string[0];
            for (int ctr = 1; ctr < tokens.length; ctr++) {
                string arg = tokens[ctr].strip();
                if (!Geary.String.is_empty(arg))
                    args += arg;
            }
            
            clear_status();
            
            // TODO: Need to break out the command delegates into their own objects with the
            // human command-names and usage and exec()'s and such; this isn't a long-term approach
            try {
                switch (cmd) {
                    case "noop":
                    case "nop":
                        noop(cmd, args);
                    break;
                    
                    case "capabilities":
                    case "caps":
                        capabilities(cmd, args);
                    break;
                    
                    case "connect":
                        connect_cmd(cmd, args);
                    break;
                    
                    case "disconnect":
                        disconnect_cmd(cmd, args);
                    break;
                    
                    case "login":
                        login(cmd, args);
                    break;
                    
                    case "logout":
                    case "bye":
                    case "kthxbye":
                        logout(cmd, args);
                    break;
                    
                    case "id":
                        id(cmd, args);
                    break;
                    
                    case "list":
                    case "xlist":
                        list(cmd, args);
                    break;
                    
                    case "examine":
                        examine(cmd, args);
                    break;
                    
                    case "fetch":
                    case "uid-fetch":
                        fetch(cmd, args);
                    break;
                    
                    case "close":
                        close(cmd, args);
                    break;
                    
                    case "fetch-fields":
                        fetch_fields(cmd, args);
                    break;
                    
                    case "help":
                        foreach (string cmdname in cmdnames)
                            print_console_line(cmdname);
                    break;
                    
                    case "exit":
                    case "quit":
                        quit(cmd, args);
                    break;
                    
                    case "gmail":
                        string[] fake_args = new string[1];
                        fake_args[0] = "imap.gmail.com:993";
                        connect_cmd("connect", fake_args);
                    break;
                    
                    case "yahoo":
                        string[] fake_args = new string[1];
                        fake_args[0] = "imap.mail.yahoo.com:993";
                        connect_cmd("connect", fake_args);
                    break;
                    
                    case "keepalive":
                        keepalive(cmd, args);
                    break;
                    
                    case "status":
                        folder_status(cmd, args);
                    break;
                    
                    case "preview":
                        preview(cmd, args);
                    break;
                    
                    default:
                        status("Unknown command \"%s\"".printf(cmd));
                    break;
                }
            } catch (Error ce) {
                status(ce.message);
            }
        }
    }
    
    private void check_args(string cmd, string[] args, int count, string? usage) throws CommandException {
        if (args.length != count)
            throw new CommandException.USAGE("usage: %s %s", cmd, usage != null ? usage : "");
    }
    
    private void check_connected(string cmd, string[] args, int count, string? usage) throws CommandException {
        if (cx == null)
            throw new CommandException.STATE("'connect' required");
        
        check_args(cmd, args, count, usage);
    }
    
    private void check_min_args(string cmd, string[] args, int min_count, string? usage) throws CommandException {
        if (args.length < min_count)
            throw new CommandException.USAGE("usage: %s %s", cmd, usage != null ? usage : "");
    }
    
    private void check_min_connected(string cmd, string[] args, int min_count, string? usage) throws CommandException {
        if (cx == null)
            throw new CommandException.STATE("'connect' required");
        
        check_min_args(cmd, args, min_count, usage);
    }
    
    private void capabilities(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        cx.send_async.begin(new Geary.Imap.CapabilityCommand(), null, on_capabilities);
    }
    
    private void on_capabilities(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Success");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void noop(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        cx.send_async.begin(new Geary.Imap.NoopCommand(), null, on_noop);
    }
    
    private void on_noop(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Success");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void connect_cmd(string cmd, string[] args) throws Error {
        if (cx != null)
            throw new CommandException.STATE("'logout' required");
        
        check_args(cmd, args, 1, "hostname[:port]");
        
        cx = new Geary.Imap.ClientConnection(
            new Geary.Endpoint(args[0], Geary.Imap.ClientConnection.DEFAULT_PORT_SSL,
                Geary.Endpoint.Flags.SSL | Geary.Endpoint.Flags.GRACEFUL_DISCONNECT,
                Geary.Imap.ClientConnection.DEFAULT_TIMEOUT_SEC));
        
        cx.sent_command.connect(on_sent_command);
        cx.received_status_response.connect(on_received_status_response);
        cx.received_server_data.connect(on_received_server_data);
        cx.received_bad_response.connect(on_received_bad_response);
        
        status("Connecting to %s...".printf(args[0]));
        cx.connect_async.begin(null, on_connected);
    }
    
    private void on_connected(Object? source, AsyncResult result) {
        try {
            cx.connect_async.end(result);
            status("Connected");
        } catch (Error err) {
            cx = null;
            
            exception(err);
        }
    }
    
    private void disconnect_cmd(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        status("Disconnecting...");
        cx.disconnect_async.begin(null, on_disconnected);
    }
    
    private void on_disconnected(Object? source, AsyncResult result) {
        try {
            cx.disconnect_async.end(result);
            status("Disconnected");
            
            cx.sent_command.disconnect(on_sent_command);
            cx.received_status_response.disconnect(on_received_status_response);
            cx.received_server_data.connect(on_received_server_data);
            cx.received_bad_response.disconnect(on_received_bad_response);
            
            cx = null;
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void login(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 2, "user pass");
        
        status("Logging in...");
        cx.send_async.begin(new Geary.Imap.LoginCommand(args[0], args[1]), null, on_logged_in);
    }
    
    private void on_logged_in(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Login completed");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void logout(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        status("Logging out...");
        cx.send_async.begin(new Geary.Imap.LogoutCommand(), null, on_logout);
    }
    
    private void on_logout(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Logged out");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void id(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        status("Retrieving ID...");
        
        Gee.HashMap<string, string> fields = new Gee.HashMap<string, string>();
        fields.set("name", "geary-console");
        fields.set("version", VERSION);
        
        cx.send_async.begin(new Geary.Imap.IdCommand(fields), null, on_id);
    }
    
    private void on_id(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Retrieved ID");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void list(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 2, "<reference> <mailbox>");
        
        status("Listing...");
        cx.send_async.begin(new Geary.Imap.ListCommand.wildcarded(args[0],
            new Geary.Imap.MailboxParameter(args[1]), (cmd.down() == "xlist")), null, on_list);
    }
    
    private void on_list(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Listed");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void examine(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 1, "<mailbox>");
        
        status("Opening %s read-only".printf(args[0]));
        cx.send_async.begin(new Geary.Imap.ExamineCommand(new Geary.Imap.MailboxParameter(args[0])),
            null, on_examine);
    }
    
    private void on_examine(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Opened read-only");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void fetch(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<message-span> <data-item...>");
        
        status("Fetching %s".printf(args[0]));
        
        Geary.Imap.MessageSet msg_set = (cmd.down() == "fetch")
            ? new Geary.Imap.MessageSet.custom(args[0])
            : new Geary.Imap.MessageSet.uid_custom(args[0]);
        
        Gee.ArrayList<Geary.Imap.FetchDataType> data_items = new Gee.ArrayList<Geary.Imap.FetchDataType>();
        for (int ctr = 1; ctr < args.length; ctr++) {
            Geary.Imap.FetchDataType data_type = Geary.Imap.FetchDataType.decode(args[ctr]);
            data_items.add(data_type);
        }
        
        cx.send_async.begin(new Geary.Imap.FetchCommand(msg_set, data_items, null), null, on_fetch);
    }
    
    private void fetch_fields(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<message-span> <field-name...>");
        
        status("Fetching fields %s".printf(args[0]));
        
        Geary.Imap.FetchBodyDataType fields = new Geary.Imap.FetchBodyDataType(
            Geary.Imap.FetchBodyDataType.SectionPart.HEADER_FIELDS, null, -1, -1, args[1:args.length]);
            
        Gee.List<Geary.Imap.FetchBodyDataType> list = new Gee.ArrayList<Geary.Imap.FetchBodyDataType>();
        list.add(fields);
        
        cx.send_async.begin(new Geary.Imap.FetchCommand(
            new Geary.Imap.MessageSet.custom(args[0]), null, list), null, on_fetch);
    }
    
    private void on_fetch(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Fetched");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void close(string cmd, string[] args) throws Error {
        check_connected(cmd, args, 0, null);
        
        status("Closing");
        
        cx.send_async.begin(new Geary.Imap.CloseCommand(), null, on_closed);
    }
    
    private void on_closed(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Closed");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void folder_status(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 2, "<folder> <data-item...>");
        
        status("Status %s".printf(args[0]));
        
        Geary.Imap.StatusDataType[] data_items = new Geary.Imap.StatusDataType[0];
        for (int ctr = 1; ctr < args.length; ctr++)
            data_items += Geary.Imap.StatusDataType.decode(args[ctr]);
        
        cx.send_async.begin(new Geary.Imap.StatusCommand(new Geary.Imap.MailboxParameter(args[0]),
            data_items), null, on_get_status);
    }
    
    private void on_get_status(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Get status");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void preview(string cmd, string[] args) throws Error {
        check_min_connected(cmd, args, 1, "<message-span>");
        
        status("Preview %s".printf(args[0]));
        
        Geary.Imap.FetchBodyDataType preview_data_type = new Geary.Imap.FetchBodyDataType.peek(
            Geary.Imap.FetchBodyDataType.SectionPart.NONE, { 1 }, 0, Geary.Email.MAX_PREVIEW_BYTES,
            null);
        
        Gee.ArrayList<Geary.Imap.FetchBodyDataType> list = new Gee.ArrayList<Geary.Imap.FetchBodyDataType>();
        list.add(preview_data_type);
        
        cx.send_async.begin(new Geary.Imap.FetchCommand(
            new Geary.Imap.MessageSet.custom(args[0]), null, list), null, on_preview_completed);
    }
    
    private void on_preview_completed(Object? source, AsyncResult result) {
        try {
            cx.send_async.end(result);
            status("Preview fetched");
        } catch (Error err) {
            exception(err);
        }
    }
    
    private void quit(string cmd, string[] args) throws Error {
        Gtk.main_quit();
    }
    
    private bool keepalive_on = false;
    
    private void keepalive(string cmd, string[] args) throws Error {
        if (keepalive_on) {
            status("Keepalive already active.");
            
            return;
        }
        
        check_connected(cmd, args, 0, null);
        
        keepalive_on = true;
        Timeout.add_seconds(KEEPALIVE_SEC, on_keepalive);
        
        status("Keepalive on.");
    }
    
    private bool on_keepalive() {
        try {
            noop("noop", new string[0]);
        } catch (Error err) {
            status("Keepalive failed, halted: %s".printf(err.message));
            
            keepalive_on = false;
        }
        
        return keepalive_on;
    }
    
    private void print_console_line(string text) {
        append_to_console("[C] ");
        append_to_console(text);
        append_to_console("\n");
    }
    
    private void on_sent_command(Geary.Imap.Command cmd) {
        append_to_console("[L] ");
        append_to_console(cmd.to_string());
        append_to_console("\n");
    }
    
    private void on_received_status_response(Geary.Imap.StatusResponse status_response) {
        append_to_console("[R] ");
        append_to_console(status_response.to_string());
        append_to_console("\n");
    }
    
    private void on_received_server_data(Geary.Imap.ServerData server_data) {
        append_to_console("[D] ");
        append_to_console(server_data.to_string());
        append_to_console("\n");
    }
    
    private void on_received_bad_response(Geary.Imap.RootParameters root, Geary.ImapError err) {
        append_to_console("[E] ");
        append_to_console(err.message);
        append_to_console(": ");
        append_to_console(root.to_string());
        append_to_console("\n");
    }
    
    private void append_to_console(string text) {
        Gtk.TextIter iter;
        console.buffer.get_iter_at_offset(out iter, -1);
        console.buffer.insert(ref iter, text, -1);
    }
}

void main(string[] args) {
    Gtk.init(ref args);
    
    ImapConsole console = new ImapConsole();
    console.show_all();
    
    Gtk.main();
}

