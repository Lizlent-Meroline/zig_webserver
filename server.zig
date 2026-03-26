const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const address = try std.net.Address.parseIp4("127.0.0.1", 8080);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.debug.print("Server listening on 127.0.0.1:8080...\n", .{});

    while (true) {
        const conn = try server.accept();
        defer conn.stream.close();

        var read_buf: [4096]u8 = undefined;
        var write_buf: [4096]u8 = undefined;

        var reader = conn.stream.reader(&read_buf).file_reader;
        var writer = conn.stream.writer(&write_buf).file_writer;

        var http_server = std.http.Server.init(&reader.interface, &writer.interface);
        var req = try http_server.receiveHead();
        
        const path = req.head.target;

        // Log the request to see what the browser is asking for
        std.debug.print("Request: {s}\n", .{path});

        if (std.mem.eql(u8, path, "/")) {
            // 1. SERVE HTML
            const html = std.fs.cwd().readFileAlloc(allocator, "index.html", 1024 * 1024) catch {
                try req.respond("index.html not found\n", .{ .status = .not_found });
                continue;
            };
            defer allocator.free(html);

            // FIX: Set Content-Type so the browser RENDERS the page
            try req.respond(html, .{
                .extra_headers = &.{ .{ .name = "Content-Type", .value = "text/html" } },
            });

        } else if (std.mem.startsWith(u8, path, "/icons/")) {
            // 2. SERVE LOGO
            const local_path = path[1..]; // removes leading '/'
            const img = std.fs.cwd().readFileAlloc(allocator, local_path, 5 * 1024 * 1024) catch {
                try req.respond("Logo not found\n", .{ .status = .not_found });
                continue;
            };
            defer allocator.free(img);

            // FIX: Set Content-Type so the browser SHOWS the image
            try req.respond(img, .{
                .extra_headers = &.{ .{ .name = "Content-Type", .value = "image/png" } },
            });

        } else {
            try req.respond("404 - Not Found\n", .{ .status = .not_found });
        }
    }
}
