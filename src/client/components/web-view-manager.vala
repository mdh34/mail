// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

[DBus (name = "io.elementary.mail.WebKitExtension")]
public class WebViewManager {
    private static WebViewManager? _instance = null;
    private Gee.HashMap <uint64?, int> view_heights
        = new Gee.HashMap <uint64?, int> ((Gee.HashDataFunc)int64_hash, (Gee.EqualDataFunc)int64_equal);
    private Gee.HashMap <uint64?, bool> show_images
        = new Gee.HashMap <uint64?, bool> ((Gee.HashDataFunc)int64_hash, (Gee.EqualDataFunc)int64_equal);

    public signal void page_load_changed (uint64 page_id);
    public signal void image_loading_enabled (uint64 page_id);
    
    [DBus (visible = false)]
    public signal void page_height_updated (uint64 page_id);
    [DBus (visible = false)]
    public signal void image_load_blocked (uint64 page_id);

    public WebViewManager () {
        Bus.own_name(BusType.SESSION, "io.elementary.mail.WebKitExtension", BusNameOwnerFlags.NONE,
            on_bus_acquired, null, () => { warning("Could not aquire name"); });
    }

    [DBus (visible = false)]
    public int get_height (uint64 view) {
        return view_heights [view];
    }

    [DBus (visible = false)]
    public void set_load_images (uint64 view, bool load_images) {
        show_images [view] = load_images;
    }

    public bool get_load_images (uint64 view) {
        if (show_images.has_key (view)) {
            return show_images [view];
        } else {
            return false;
        }
    }

    public void fire_image_load_blocked (uint64 view) {
        image_load_blocked (view);
    }

    public void set_height (uint64 view, int height) {
        if (view_heights.has_key (view)) {
            if (height == view_heights [view]) {
                return;
            }
        }
        view_heights [view] = height;
        page_height_updated (view);
    }

    [DBus (visible = false)]
    public static WebViewManager get_default () {
        if (_instance == null) {
            _instance = new WebViewManager ();
        }
        return _instance;
    }

    private void on_bus_acquired (DBusConnection connection) {
        try {
            connection.register_object("/io/elementary/mail/WebKitExtension", this);
        } catch (IOError error) {
            warning("Could not register service: %s", error.message);
        }
    }
}
