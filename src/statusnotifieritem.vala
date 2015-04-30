/*
 * xfce4-snw-plugin
 * Copyright (C) 2015 Alexey Rochev <equeim@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

struct IconPixmap {
    int width;
    int height;
    uint8[] bytes;
}

struct ToolTip {
    string icon_name;
    IconPixmap[] pixmap;
    string title;
    string description;
}

[DBus (name = "org.kde.StatusNotifierItem")]
interface StatusNotifierItem : Object {
    public abstract string category { owned get; }
    public abstract string id { owned get; }
    public abstract string title { owned get; }
    public abstract string status { owned get; }
    public abstract int window_id { owned get; }
    public abstract string icon_name { owned get; }
    public abstract IconPixmap[] icon_pixmap { owned get; }
    public abstract string icon_theme_path { owned get; }
    public abstract string overlay_icon_name { owned get; }
    public abstract IconPixmap[] overlay_icon_pixmap { owned get; }
    public abstract string attention_icon_name { owned get; }
    public abstract IconPixmap[] attention_icon_pixmap { owned get; }
    public abstract ToolTip tool_tip { owned get; }
    public abstract GLib.ObjectPath menu { owned get; }

    public abstract void activate(int x, int y) throws IOError;
    public abstract void secondary_activate(int x, int y) throws IOError;
    public abstract void scroll(int delta, string orientation) throws IOError;

    public signal void new_title();
    public signal void new_icon();
    public signal void new_attention_icon();
    public signal void new_overlay_icon();
    public signal void new_tool_tip();
    public signal void new_status(string status);
}
