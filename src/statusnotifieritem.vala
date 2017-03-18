/*
 * xfce4-snw-plugin
 * Copyright (C) 2015-2016 Alexey Rochev <equeim@gmail.com>
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

namespace StatusNotifier {
    private struct IconPixmap {
        int width;
        int height;
        uint8[] bytes;
    }

    private struct ToolTip {
        string icon_name;
        IconPixmap[] icon_pixmaps;
        string title;
        string description;
    }

    private IconPixmap[] unbox_pixmaps(Variant variant) {
        IconPixmap[] pixmaps = { };

        VariantIter pixmap_iterator = variant.iterator();
        Variant pixmap_variant = pixmap_iterator.next_value();
        while (pixmap_variant != null) {
            var pixmap = IconPixmap();

            pixmap_variant.get_child(0, "i", &pixmap.width);
            pixmap_variant.get_child(1, "i", &pixmap.height);

            Variant bytes_variant = pixmap_variant.get_child_value(2);
            uint8[] bytes = { };
            VariantIter bytes_iterator = bytes_variant.iterator();
            uint8 byte = 0;
            while (bytes_iterator.next("y", &byte)) {
                bytes += byte;
            }
            pixmap.bytes = bytes;

            pixmaps += pixmap;

            pixmap_variant = pixmap_iterator.next_value();
        }

        return pixmaps;
    }

    private ToolTip unbox_tooltip(Variant variant) {
        var tooltip = ToolTip();

        variant.get_child(0, "s", &tooltip.icon_name);

        tooltip.icon_pixmaps = unbox_pixmaps(variant.get_child_value(1));

        variant.get_child(2, "s", &tooltip.title);
        variant.get_child(3, "s", &tooltip.description);

        return tooltip;
    }

    private class ItemProxy : Object {
        private const string INTERFACE_NAME = "org.kde.StatusNotifierItem";

        private DBusConnection dbus_connection;
        private string bus_name;
        private string object_path;
        private uint[] signal_ids;

        public string id { get; private set; }

        public signal void new_title();
        public signal void new_icon();
        public signal void new_overlay_icon();
        public signal void new_attention_icon();
        public signal void new_tooltip();
        public signal void new_status(string status);

        public ItemProxy(DBusConnection connection, string bus_name, string object_path) throws Error {
            dbus_connection = connection;
            this.bus_name = bus_name;
            this.object_path = object_path;

            id = get_dbus_property("Id").get_string();

            subscribe_dbus_signal("NewTitle", () => new_title());
            subscribe_dbus_signal("NewIcon", () => new_icon());
            subscribe_dbus_signal("NewOverlayIcon", () => new_overlay_icon());
            subscribe_dbus_signal("NewAttentionIcon", () => new_attention_icon());
            subscribe_dbus_signal("NewToolTip", () => new_tooltip());
            subscribe_dbus_signal("NewStatus", new_status_callback);
        }

        //
        // DBus properties
        //
        public string get_title() throws Error {
            return get_dbus_property("Title").get_string();
        }

        public string get_status() throws Error {
            return get_dbus_property("Status").get_string();
        }

        public string get_icon_name() throws Error {
            return get_dbus_property("IconName").get_string();
        }

        public IconPixmap[] get_icon_pixmaps() throws Error {
            return unbox_pixmaps(get_dbus_property("IconPixmap"));
        }

        public string get_overlay_icon_name() throws Error {
            return get_dbus_property("OverlayIconName").get_string();
        }

        public IconPixmap[] get_overlay_icon_pixmaps() throws Error {
            return unbox_pixmaps(get_dbus_property("OverlayIconPixmap"));
        }

        public string get_attention_icon_name() throws Error {
            return get_dbus_property("AttentionIconName").get_string();
        }

        public IconPixmap[] get_attention_icon_pixmaps() throws Error {
            return unbox_pixmaps(get_dbus_property("AttentionIconPixmap"));
        }

        public ToolTip get_tooltip() throws Error {
            return unbox_tooltip(get_dbus_property("ToolTip"));
        }

        //
        // Not in specification
        //
        public string get_icon_theme_path() throws Error {
            return get_dbus_property("IconThemePath").get_string();
        }

        public string get_menu() throws Error {
            return get_dbus_property("Menu").get_string();
        }

        //
        // DBus methods
        //
        public void activate(int x, int y) {
            call_dbus_method("Activate", new Variant("(ii)", x, y));
        }

        public void secondary_activate(int x, int y) {
            call_dbus_method("SecondaryActivate", new Variant("(ii)", x, y));
        }

        public void scroll(int delta, string orientation) {
            call_dbus_method("Scroll", new Variant("(is)", delta, orientation));
        }

        //
        // Methods
        //
        public static void check_existence(DBusConnection connection, string bus_name, string object_path) throws Error {
            connection.call_sync(
                bus_name,
                object_path,
                "org.freedesktop.DBus.Properties",
                "Get",
                new Variant("(ss)", INTERFACE_NAME, "Id"),
                null,
                DBusCallFlags.NONE,
                -1,
                null
            );
        }

        public void unsubscribe_signals() {
            foreach (var id in signal_ids) {
                dbus_connection.signal_unsubscribe(id);
            }
        }

        private Variant get_dbus_property(string property_name) throws Error {
            return dbus_connection.call_sync(
                bus_name,
                object_path,
                "org.freedesktop.DBus.Properties",
                "Get",
                new Variant("(ss)", INTERFACE_NAME, property_name),
                null,
                DBusCallFlags.NONE,
                -1,
                null
            ).get_child_value(0).get_variant();
        }

        private void subscribe_dbus_signal(string signal_name, owned DBusSignalCallback callback) {
            signal_ids += dbus_connection.signal_subscribe(
                bus_name,
                INTERFACE_NAME,
                signal_name,
                object_path,
                null,
                DBusSignalFlags.NONE,
                (owned) callback
            );
        }
        private void new_status_callback(DBusConnection connection,
                                 string bus_name,
                                 string object_path,
                                 string interface_name,
                                 string signal_name,
                                 Variant parameters) {
            new_status(parameters.get_child_value(0).get_string());
        }

        private void call_dbus_method(string method_name, Variant parameters) {
            dbus_connection.call.begin(
                bus_name,
                object_path,
                INTERFACE_NAME,
                method_name,
                parameters,
                null,
                DBusCallFlags.NONE,
                -1,
                null
            );
        }
    }
}

