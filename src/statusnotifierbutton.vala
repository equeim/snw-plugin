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
    public errordomain PixmapError {
        EMPTY
    }

    public class Button : Gtk.Button {
        Xfce.PanelPlugin plugin;

        StatusNotifier.Item.Proxy proxy;

        DbusmenuGtk.Menu menu;

        Xfce.PanelImage icon;
        Gtk.IconTheme icon_theme;
        bool custom_icon_theme;

        string tooltip_icon_name;
        Gdk.Pixbuf tooltip_icon_pixbuf;

        public Button(string bus_name, string object_path, Xfce.PanelPlugin plugin) {
            this.plugin = plugin;

            set_relief(Gtk.ReliefStyle.NONE);
            set_size_request(plugin.size, plugin.size);

            try {
                proxy = new StatusNotifier.Item.Proxy(bus_name, object_path);
            } catch (GLib.DBusError error) {}

            try {
                string menu_path = proxy.get_menu();
                if (menu_path.length != 0) {
                    menu = new DbusmenuGtk.Menu(bus_name, menu_path);
                    menu.attach_to_widget(this, null);
                }
            } catch (GLib.DBusError error) {}

            icon = new Xfce.PanelImage();
            add(icon);
            icon.show();

            icon_theme = Gtk.IconTheme.get_default();
            custom_icon_theme = false;
            try {
                string icon_theme_path = proxy.get_icon_theme_path();
                if (icon_theme_path.length != 0) {
                    icon_theme.prepend_search_path(icon_theme_path);
                    custom_icon_theme = true;
                }
            } catch (GLib.DBusError error) {}
 
            button_press_event.connect(button_pressed);
            button_release_event.connect(button_released);
            scroll_event.connect(wheel_rotated);
            query_tooltip.connect(tooltip_requested);

            proxy.new_title.connect(update_tooltip);
            proxy.new_icon.connect(update_icon);
            proxy.new_attention_icon.connect(update_icon);
            proxy.new_overlay_icon.connect(update_icon);
            proxy.new_tool_tip.connect(update_tooltip);
            proxy.new_status.connect(update_status);

            update_icon();
            update_tooltip();

            try {
                update_status(proxy.get_status());
            } catch (GLib.DBusError error) {}
        }

        public void change_size(int size) {
            if (icon.source == null)
                update_icon();
            else
                set_size_request(size, size);
        }

        bool button_pressed(Gdk.EventButton event) {
            if (event.button == 3) {
                if (menu != null) {
                    if (menu.get_children().length() != 0)
                        menu.popup(null,
                                   null,
#if VALA_0_28
                                   (menu, ref x, ref y, out push_in) => {
#else
                                   (menu, out x, out y, out push_in) => {
#endif
                                       Xfce.PanelPlugin.position_menu(menu, out x, out y, out push_in, plugin);
                                   },
                                   event.button,
                                   event.time);
                }
                return true;
            }
            return false;
        }

        bool button_released(Gdk.EventButton event) {
            if (event.button == 1)
                proxy.activate((int) event.x_root, (int) event.y_root);
            else if (event.button == 2)
                proxy.secondary_activate((int) event.x_root, (int) event.y_root);
            return false;
        }

        bool wheel_rotated(Gdk.EventScroll event) {
            switch (event.direction) {
                case Gdk.ScrollDirection.LEFT:
                    proxy.scroll(-120, "horizontal");
                    break;
                case Gdk.ScrollDirection.RIGHT:
                    proxy.scroll(120, "horizontal");
                    break;
                case Gdk.ScrollDirection.DOWN:
                    proxy.scroll(-120, "vertical");
                    break;
                case Gdk.ScrollDirection.UP:
                    proxy.scroll(120, "vertical");
                    break;
            }
            return false;
        }

        bool tooltip_requested(int x, int y, bool keyboard, Gtk.Tooltip tooltip) {
            tooltip.set_markup(tooltip_markup);

            if (tooltip_icon_name.length != 0)
                tooltip.set_icon_from_icon_name(tooltip_icon_name, Gtk.IconSize.DIALOG);
            else if (tooltip_icon_pixbuf != null)
                tooltip.set_icon(tooltip_icon_pixbuf);

            return true;
        }

        void update_icon() {
            int thickness;
            if (plugin.orientation == Gtk.Orientation.HORIZONTAL)
                thickness = 2 * style.ythickness;
            else
                thickness = 2 * style.xthickness;

            int icon_size = plugin.size - thickness;
            int overlay_icon_size = icon_size / 2;

            Gdk.Pixbuf icon_pixbuf = null;

            try {
                if (proxy.get_status() == "NeedsAttention") {
                    string attention_icon_name = proxy.get_attention_icon_name();
                    if (attention_icon_name.length == 0) {
                        StatusNotifier.Item.IconPixmap[] attention_icon_pixmap = proxy.get_attention_icon_pixmap();

                        bool has_attention_icon_pixmap = false;
                        if (attention_icon_pixmap.length != 0)
                            if (attention_icon_pixmap[0].bytes.length != 0)
                                has_attention_icon_pixmap = true;

                        if (has_attention_icon_pixmap)
                            icon_pixbuf = pixbuf_from_pixmap(attention_icon_pixmap[0]);
                        else
                            throw new PixmapError.EMPTY("AttentionIconPixmap is empty");
                    } else {
                        if (custom_icon_theme) {
                            icon_theme.rescan_if_needed();
                            icon_pixbuf = icon_theme.load_icon(attention_icon_name,
                                                               icon_size,
                                                               0);
                        } else {
                            icon.set_from_source(attention_icon_name);
                        }
                    }
                } else {
                    string icon_name = proxy.get_icon_name();

                    string overlay_icon_name = "";
                    StatusNotifier.Item.IconPixmap[] overlay_icon_pixmap = {};

                    try {
                        overlay_icon_name = proxy.get_overlay_icon_name();
                        overlay_icon_pixmap = proxy.get_overlay_icon_pixmap();
                    } catch (GLib.DBusError error) {}

                    bool has_overlay_icon_name = false;
                    if (overlay_icon_name.length != 0)
                        has_overlay_icon_name = true;

                    bool has_overlay_icon_pixmap = false;
                    if (overlay_icon_pixmap.length != 0)
                        if (overlay_icon_pixmap[0].bytes.length != 0)
                            has_overlay_icon_pixmap = true;

                    if (icon_name.length == 0) {
                        StatusNotifier.Item.IconPixmap[] icon_pixmap = proxy.get_icon_pixmap();

                        bool has_icon_pixmap = false;
                        if (icon_pixmap.length != 0)
                            if (icon_pixmap[0].bytes.length != 0)
                                has_icon_pixmap = true;

                        if (has_icon_pixmap)
                            icon_pixbuf = pixbuf_from_pixmap(icon_pixmap[0]);
                        else
                            throw new PixmapError.EMPTY("IconPixmap is empty");
                    } else {
                        if (custom_icon_theme ||
                                has_overlay_icon_name ||
                                has_overlay_icon_pixmap)
                            icon_pixbuf = icon_theme.load_icon(icon_name,
                                                               icon_size,
                                                               0);
                        else
                            icon.set_from_source(icon_name);
                    }

                    Gdk.Pixbuf overlay_icon_pixbuf = null;

                    if (has_overlay_icon_name)
                        overlay_icon_pixbuf = icon_theme.load_icon(overlay_icon_name,
                                                                   overlay_icon_size,
                                                                   0);
                    else if (has_overlay_icon_pixmap)
                        overlay_icon_pixbuf = pixbuf_from_pixmap(overlay_icon_pixmap[0]);

                    if (overlay_icon_pixbuf != null) {
                        if (overlay_icon_pixbuf.height > overlay_icon_size) {
                            overlay_icon_pixbuf = overlay_icon_pixbuf.scale_simple(overlay_icon_size,
                                                                                   overlay_icon_size,
                                                                                   Gdk.InterpType.BILINEAR);
                        }

                        int x = icon_pixbuf.width - overlay_icon_pixbuf.width;
                        int y = icon_pixbuf.height - overlay_icon_pixbuf.height;

                        overlay_icon_pixbuf.composite(icon_pixbuf,
                                                      x,
                                                      y,
                                                      overlay_icon_size,
                                                      overlay_icon_size,
                                                      x,
                                                      y,
                                                      1,
                                                      1,
                                                      Gdk.InterpType.BILINEAR,
                                                      255);
                    }
                }
            } catch (GLib.Error error) {
                icon.set_from_source("image-missing");
                if ( !(error is GLib.DBusError) )
                    GLib.stderr.printf("%s\n", error.message);
            }

            if (icon_pixbuf == null) {
                set_size_request(plugin.size, plugin.size);
            } else {
                icon.set_from_pixbuf(icon_pixbuf);

                if (icon_pixbuf.width > icon_pixbuf.height &&
                        plugin.orientation == Gtk.Orientation.HORIZONTAL)
                    set_size_request(plugin.size * (icon_pixbuf.width / icon_pixbuf.height),
                                     plugin.size);
                else if (icon_pixbuf.height > icon_pixbuf.width &&
                        plugin.orientation == Gtk.Orientation.VERTICAL)
                    set_size_request(plugin.size,
                                     plugin.size * (icon_pixbuf.height / icon_pixbuf.width));
                else
                    set_size_request(plugin.size, plugin.size);
            }
        }

        void update_status(string status) {
            switch (status) {
            case "Passive":
                hide();
                break;
            case "Active":
                show();
                break;
            }
        }

        void update_tooltip() {
            StatusNotifier.Item.ToolTip tool_tip;
            try {
                tool_tip = proxy.get_tool_tip();
            } catch (GLib.DBusError error) {
                return;
            }

            if (tool_tip.title.length == 0) {
                string title = "";
                try {
                    title = proxy.get_title();
                } catch (GLib.DBusError error) {}

                if (title.length == 0)
                    tooltip_markup = proxy.id;
                else
                    tooltip_markup = title;
            } else {
                string tooltip_tmp = tool_tip.title;
                if (tool_tip.description.length != 0)
                    tooltip_tmp += "<br>" + tool_tip.description;

                try {
                    Pango.parse_markup(tooltip_tmp, -1, '\0', null, null, null);
                    tooltip_markup = tooltip_tmp;
                } catch (GLib.Error error) {
                    tooltip_tmp = "<markup>" + tooltip_tmp + "</markup>";
                    QRichTextParser parser = new QRichTextParser(tooltip_tmp);
                    parser.translate_markup();
                    tooltip_markup = parser.pango_markup;
                }
            }

            tooltip_icon_name = tool_tip.icon_name;
            if (tooltip_icon_name.length == 0) {
                if (tool_tip.icon_pixmap.length != 0)
                    if (tool_tip.icon_pixmap[0].bytes.length != 0)
                        tooltip_icon_pixbuf = pixbuf_from_pixmap(tool_tip.icon_pixmap[0]);
            }
        }

        Gdk.Pixbuf pixbuf_from_pixmap(StatusNotifier.Item.IconPixmap icon_pixmap) {
            uint[] new_bytes = (uint[]) icon_pixmap.bytes;
            for (int i = 0; i < new_bytes.length; i++) {
                new_bytes[i] = new_bytes[i].to_big_endian();
            }

            uint8[] new_bytes8 = (uint8[]) new_bytes;
            for (int i = 0; i < new_bytes8.length; i = i + 4) {
                uint8 red = new_bytes8[i];
                new_bytes8[i] = new_bytes8[i + 2];
                new_bytes8[i + 2] = red;
            }

            return new Gdk.Pixbuf.from_data(new_bytes8,
                                            Gdk.Colorspace.RGB,
                                            true,
                                            8,
                                            icon_pixmap.width,
                                            icon_pixmap.height,
                                            Cairo.Format.ARGB32.stride_for_width(icon_pixmap.width));
        }

    }
}

