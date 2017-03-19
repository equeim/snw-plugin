/*
 * xfce4-snw-plugin
 * Copyright (C) 2015-2017 Alexey Rochev <equeim@gmail.com>
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
    private delegate void GotPropertyCallback(Variant property);

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

        private const string DBUS_ID = "Id";
        private const string DBUS_TITLE = "Title";
        private const string DBUS_ICON_NAME = "IconName";
        private const string DBUS_ICON_PIXMAP = "IconPixmap";
        private const string DBUS_OVERLAY_ICON_NAME = "OverlayIconName";
        private const string DBUS_OVERLAY_ICON_PIXMAP = "OverlayIconPixmap";
        private const string DBUS_ATTENTION_ICON_NAME = "AttentionIconName";
        private const string DBUS_ATTENTION_ICON_PIXMAP = "AttentionIconPixmap";
        private const string DBUS_ICON_THEME_PATH = "IconThemePath";
        private const string DBUS_TOOLTIP = "ToolTip";
        private const string DBUS_STATUS = "Status";
        private const string DBUS_MENU = "Menu";

        private DBusConnection dbus_connection;
        private string bus_name;
        private string object_path;
        private uint[] signal_ids;

        public string id { get; private set; }
        public string title { get; private set; }

        public string icon_name { get; private set; }
        private bool icon_name_updated = false;
        public IconPixmap[] icon_pixmaps { get; private set; }
        private bool icon_pixmaps_updated = false;

        public string overlay_icon_name { get; private set; }
        private bool overlay_icon_name_updated = false;
        public IconPixmap[] overlay_icon_pixmaps { get; private set; }
        private bool overlay_icon_pixmaps_updated = false;

        public string attention_icon_name { get; private set; }
        private bool attention_icon_name_updated = false;
        public IconPixmap[] attention_icon_pixmaps { get; private set; }
        private bool attention_icon_pixmaps_updated = false;

        public string icon_theme_path { get; private set; }

        public ToolTip tooltip { get; private set; }
        public string status { get; private set; }
        public string menu { get; private set; }

        public signal void got_all_properties();

        public signal void new_title();
        public signal void new_icon();
        public signal void new_overlay_icon();
        public signal void new_attention_icon();
        public signal void new_tooltip();
        public signal void new_status();

        public ItemProxy(DBusConnection connection, string bus_name, string object_path) throws Error {
            dbus_connection = connection;
            this.bus_name = bus_name;
            this.object_path = object_path;

            get_all_properties();

            subscribe_dbus_signal("NewTitle", dbus_get_title);
            subscribe_dbus_signal("NewIcon", dbus_get_icon);
            subscribe_dbus_signal("NewOverlayIcon", dbus_get_overlay_icon);
            subscribe_dbus_signal("NewAttentionIcon", dbus_get_attention_icon);
            subscribe_dbus_signal("NewToolTip", dbus_get_tooltip);
            subscribe_dbus_signal("NewStatus", new_status_callback);
        }

        public void activate(int x, int y) {
            call_dbus_method("Activate", new Variant("(ii)", x, y));
        }

        public void secondary_activate(int x, int y) {
            call_dbus_method("SecondaryActivate", new Variant("(ii)", x, y));
        }

        public void scroll(int delta, string orientation) {
            call_dbus_method("Scroll", new Variant("(is)", delta, orientation));
        }

        public void unsubscribe_signals() {
            foreach (var id in signal_ids) {
                dbus_connection.signal_unsubscribe(id);
            }
        }

        private void dbus_get_title() {
            get_dbus_property(DBUS_TITLE, (property) => {
                title = property.get_string();
                new_title();
            });
        }

        private void dbus_get_icon() {
            icon_name_updated = false;
            icon_pixmaps_updated = false;
            dbus_get_icon_name();
            dbus_get_icon_pixmaps();
        }

        private void dbus_get_icon_name() {
            get_dbus_property(DBUS_ICON_NAME, (property) => {
                icon_name = property.get_string();
                icon_name_updated = true;
                if (icon_pixmaps_updated) {
                    new_icon();
                }
            });
        }

        private void dbus_get_icon_pixmaps()  {
            get_dbus_property(DBUS_ICON_PIXMAP, (property) => {
                icon_pixmaps = unbox_pixmaps(property);
                icon_pixmaps_updated = true;
                if (icon_name_updated) {
                    new_icon();
                }
            });
        }

        private void dbus_get_overlay_icon() {
            overlay_icon_name_updated = false;
            overlay_icon_pixmaps_updated = false;
            dbus_get_overlay_icon_name();
            dbus_get_overlay_icon_pixmaps();
        }

        private void dbus_get_overlay_icon_name()  {
            get_dbus_property(DBUS_OVERLAY_ICON_NAME, (property) => {
                overlay_icon_name = property.get_string();
                overlay_icon_name_updated = true;
                if (overlay_icon_pixmaps_updated) {
                    new_overlay_icon();
                }
            });
        }

        private void dbus_get_overlay_icon_pixmaps()  {
            get_dbus_property(DBUS_OVERLAY_ICON_PIXMAP, (property) => {
                overlay_icon_pixmaps = unbox_pixmaps(property);
                overlay_icon_pixmaps_updated = true;
                if (overlay_icon_name_updated) {
                    new_overlay_icon();
                }
            });
        }

        private void dbus_get_attention_icon() {
            attention_icon_name_updated = false;
            attention_icon_pixmaps_updated = false;
            dbus_get_attention_icon_name();
            dbus_get_attention_icon_pixmaps();
        }

        private void dbus_get_attention_icon_name()  {
            get_dbus_property(DBUS_ATTENTION_ICON_NAME, (property) => {
                attention_icon_name = property.get_string();
                attention_icon_name_updated = true;
                if (attention_icon_pixmaps_updated) {
                    new_attention_icon();
                }
            });
        }

        private void dbus_get_attention_icon_pixmaps()  {
            get_dbus_property(DBUS_ATTENTION_ICON_PIXMAP, (property) => {
                attention_icon_pixmaps = unbox_pixmaps(property);
                attention_icon_pixmaps_updated = true;
                if (attention_icon_name_updated) {
                    new_attention_icon();
                }
            });
        }

        private void dbus_get_tooltip()  {
            get_dbus_property(DBUS_TOOLTIP, (property) => {
                tooltip = unbox_tooltip(property);
                new_tooltip();
            });
        }

        private void new_status_callback(DBusConnection connection,
                                         string bus_name,
                                         string object_path,
                                         string interface_name,
                                         string signal_name,
                                         Variant parameters) {
            status = parameters.get_child_value(0).get_string();
            new_status();
        }

        private void get_dbus_property(string property_name, GotPropertyCallback callback) {
            dbus_connection.call.begin(
                bus_name,
                object_path,
                "org.freedesktop.DBus.Properties",
                "Get",
                new Variant("(ss)", INTERFACE_NAME, property_name),
                null,
                DBusCallFlags.NONE,
                -1,
                null,
                (object, result) => {
                    try {
                        callback(dbus_connection.call.end(result).get_child_value(0).get_variant());
                    } catch (Error error) {
                        print_error(error.message);
                    }
                }
            );
        }

        private void get_all_properties() {
            dbus_connection.call.begin(
                bus_name,
                object_path,
                "org.freedesktop.DBus.Properties",
                "GetAll",
                new Variant("(s)", INTERFACE_NAME),
                null,
                DBusCallFlags.NONE,
                -1,
                null,
                (object, result) => {
                    try {
                        var properties = dbus_connection.call.end(result).get_child_value(0);
                        foreach (Variant property in properties) {
                            string key = property.get_child_value(0).get_string();
                            Variant value = property.get_child_value(1).get_variant();
                            switch (key) {
                                case DBUS_ID:
                                    id = value.get_string();
                                    break;
                                case DBUS_TITLE:
                                    title = value.get_string();
                                    break;
                                case DBUS_ICON_NAME:
                                    icon_name = value.get_string();
                                    break;
                                case DBUS_ICON_PIXMAP:
                                    icon_pixmaps = unbox_pixmaps(value);
                                    break;
                                case DBUS_OVERLAY_ICON_NAME:
                                    overlay_icon_name = value.get_string();
                                    break;
                                case DBUS_OVERLAY_ICON_PIXMAP:
                                    overlay_icon_pixmaps = unbox_pixmaps(value);
                                    break;
                                case DBUS_ATTENTION_ICON_NAME:
                                    attention_icon_name = value.get_string();
                                    break;
                                case DBUS_ATTENTION_ICON_PIXMAP:
                                    attention_icon_pixmaps = unbox_pixmaps(value);
                                    break;
                                case DBUS_ICON_THEME_PATH:
                                    icon_theme_path = value.get_string();
                                    break;
                                case DBUS_STATUS:
                                    status = value.get_string();
                                    break;
                                case DBUS_TOOLTIP:
                                    tooltip = unbox_tooltip(value);
                                    break;
                                case DBUS_MENU:
                                    menu = value.get_string();
                                    break;
                            }
                        }
                        got_all_properties();
                    } catch (Error error) {
                        print_error(error.message);
                    }
                }
            );
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
    }
}

