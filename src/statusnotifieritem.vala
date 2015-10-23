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

namespace StatusNotifier {
    namespace Item {
        public struct IconPixmap {
            int width;
            int height;
            uint8[] bytes;
        }

        public struct ToolTip {
            string icon_name;
            IconPixmap[] icon_pixmap;
            string title;
            string description;
        }

        public class Proxy : GLib.Object {
            const string INTERFACE_NAME = "org.kde.StatusNotifierItem";

            string bus_name;
            string object_path;
            uint[] signal_ids;

            public string id { get; private set; }

            public signal void new_title();
            public signal void new_icon();
            public signal void new_overlay_icon();
            public signal void new_attention_icon();
            public signal void new_tool_tip();
            public signal void new_status(string status);

            public Proxy(string bus_name, string object_path) throws GLib.DBusError {
                this.bus_name = bus_name;
                this.object_path = object_path;

                id = get_dbus_property("Id").get_string();

                subscribe_dbus_signal("NewTitle", new_title_callback);
                subscribe_dbus_signal("NewIcon", new_icon_callback);
                subscribe_dbus_signal("NewOverlayIcon", new_overlay_icon_callback);
                subscribe_dbus_signal("NewAttentionIcon", new_attention_icon_callback);
                subscribe_dbus_signal("NewToolTip", new_tool_tip_callback);
                subscribe_dbus_signal("NewStatus", new_status_callback);
            }

            ~Proxy() {
                foreach (uint id in signal_ids)
                    StatusNotifier.DBusConnection.signal_unsubscribe(id);
            }

            //
            // DBus properties
            //
            public string get_title() throws GLib.DBusError {
                return get_dbus_property("Title").get_string();
            }

            public string get_status() throws GLib.DBusError {
                return get_dbus_property("Status").get_string();
            }

            public string get_icon_name() throws GLib.DBusError {
                return get_dbus_property("IconName").get_string();
            }

            public IconPixmap[] get_icon_pixmap() throws GLib.DBusError {
                return unbox_pixmap(get_dbus_property("IconPixmap"));
            }

            public string get_overlay_icon_name() throws GLib.DBusError {
                return get_dbus_property("OverlayIconName").get_string();
            }

            public IconPixmap[] get_overlay_icon_pixmap() throws GLib.DBusError {
                return unbox_pixmap(get_dbus_property("OverlayIconPixmap"));
            }

            public string get_attention_icon_name() throws GLib.DBusError {
                return get_dbus_property("AttentionIconName").get_string();
            }

            public IconPixmap[] get_attention_icon_pixmap() throws GLib.DBusError {
                return unbox_pixmap(get_dbus_property("AttentionIconPixmap"));
            }

            public ToolTip get_tool_tip() throws GLib.DBusError {
                return unbox_tool_tip(get_dbus_property("ToolTip"));
            }

            //
            // Not in specification
            //
            public string get_icon_theme_path() throws GLib.DBusError {
                return get_dbus_property("IconThemePath").get_string();
            }

            public string get_menu() throws GLib.DBusError {
                return get_dbus_property("Menu").get_string();
            }

            //
            // DBus methods
            //
            public void activate(int x, int y) {
                call_dbus_method("Activate", new GLib.Variant("(ii)", x, y));
            }

            public void secondary_activate(int x, int y) {
                call_dbus_method("SecondaryActivate", new GLib.Variant("(ii)", x, y));
            }

            public void scroll(int delta, string orientation) {
                call_dbus_method("Scroll", new GLib.Variant("(is)", delta, orientation));
            }

            //
            // Private methods
            //
            GLib.Variant get_dbus_property(string property_name) throws GLib.DBusError {
                try {
                    return StatusNotifier.DBusConnection.call_sync(
                        bus_name,
                        object_path,
                        "org.freedesktop.DBus.Properties",
                        "Get",
                        new Variant("(ss)", INTERFACE_NAME, property_name),
                        null,
                        GLib.DBusCallFlags.NONE,
                        -1,
                        null
                    ).get_child_value(0).get_variant();
                } catch (GLib.DBusError error) {
                    GLib.stderr.printf("get_dbus_property: %s\n", error.message);
                    throw error;
                }
            }

            IconPixmap[] unbox_pixmap(GLib.Variant variant) {
                IconPixmap[] pixmap = {};

                GLib.VariantIter pixmap_iterator = variant.iterator();
                GLib.Variant pixmap_variant = pixmap_iterator.next_value();
                while (pixmap_variant != null) {
                    IconPixmap pixmap_struct = IconPixmap();

                    pixmap_variant.get_child(0, "i", &pixmap_struct.width);
                    pixmap_variant.get_child(1, "i", &pixmap_struct.height);

                    GLib.Variant bytes_variant = pixmap_variant.get_child_value(2);
                    uint8[] bytes = {};
                    GLib.VariantIter bytes_iterator = bytes_variant.iterator();
                    uint8 byte = 0;
                    while (bytes_iterator.next("y", &byte))
                        bytes += byte;
                    pixmap_struct.bytes = (owned) bytes;

                    pixmap += (owned) pixmap_struct;

                    pixmap_variant = pixmap_iterator.next_value();
                }

                return pixmap;
            }

            ToolTip unbox_tool_tip(GLib.Variant variant) {
                ToolTip tool_tip = ToolTip();

                variant.get_child(0, "s", &tool_tip.icon_name);
 
                tool_tip.icon_pixmap = unbox_pixmap(variant.get_child_value(1));

                variant.get_child(2, "s", &tool_tip.title);
                variant.get_child(3, "s", &tool_tip.description);

                return tool_tip;
            }

            void subscribe_dbus_signal(string signal_name, GLib.DBusSignalCallback callback) {
                signal_ids += StatusNotifier.DBusConnection.signal_subscribe(
                    bus_name,
                    INTERFACE_NAME,
                    signal_name,
                    object_path,
                    null,
                    GLib.DBusSignalFlags.NONE,
                    callback
                );
            }

            void new_title_callback() {
                new_title();
            }

            void new_icon_callback() {
                new_icon();
            }

            void new_overlay_icon_callback() {
                new_overlay_icon();
            }

            void new_attention_icon_callback() {
                new_attention_icon();
            }

            void new_tool_tip_callback() {
                new_tool_tip();
            }

            void new_status_callback(GLib.DBusConnection connection,
                                     string bus_name,
                                     string object_path,
                                     string interface_name,
                                     string signal_name,
                                     GLib.Variant parameters) {
                new_status(parameters.get_child_value(0).get_string());
            }

            void call_dbus_method(string method_name, GLib.Variant parameters) {
                StatusNotifier.DBusConnection.call(
                    bus_name,
                    object_path,
                    INTERFACE_NAME,
                    method_name,
                    parameters,
                    null,
                    GLib.DBusCallFlags.NONE,
                    -1,
                    null
                );
            }
        }
    }
}

