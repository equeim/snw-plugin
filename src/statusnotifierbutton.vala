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
        ERROR
    }

    public class Button : Gtk.Button {
        Xfce.PanelPlugin plugin;

        StatusNotifier.Item.Proxy proxy;

        DbusmenuGtk.Menu menu;

        Gtk.Image icon;
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

            icon = new Gtk.Image();
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
            } catch (GLib.DBusError error) {
                GLib.stderr.printf("%s\n", error.message);
                show();
            }
        }

        public void change_size(int size) {
            update_icon();
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
            if (event.button == 1) {
                proxy.activate((int) event.x_root, (int) event.y_root);
            } else if (event.button == 2) {
                proxy.secondary_activate((int) event.x_root, (int) event.y_root);
            }
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

            if (tooltip_icon_name == null) {
                if (tooltip_icon_pixbuf != null) {
                    tooltip.set_icon(tooltip_icon_pixbuf);
                }
            } else {
                tooltip.set_icon_from_icon_name(tooltip_icon_name, Gtk.IconSize.DIALOG);
            }

            return true;
        }

        void update_icon() {
            int icon_size = plugin.size - 2;
            if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                icon_size -= 2 * style.ythickness;
            } else {
                icon_size -= 2 * style.xthickness;
            }

            int overlay_icon_size = icon_size / 2;

            Gdk.Pixbuf icon_pixbuf = null;
            icon_theme.rescan_if_needed();

            try {
                if (proxy.get_status() == "NeedsAttention") {
                    string attention_icon_name = proxy.get_attention_icon_name();
                    if (attention_icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmap(proxy.get_attention_icon_pixmap());
                    } else {
                        icon_pixbuf = load_icon_from_theme(attention_icon_name,
                                                           icon_size);
                    }
                } else {
                    string icon_name = proxy.get_icon_name();

                    Gdk.Pixbuf overlay_icon_pixbuf = null;
                    try {
                        string overlay_icon_name = proxy.get_overlay_icon_name();
                        if (overlay_icon_name.length == 0) {
                            overlay_icon_pixbuf = pixbuf_from_pixmap(proxy.get_overlay_icon_pixmap());
                        } else {
                            overlay_icon_pixbuf = load_icon_from_theme(overlay_icon_name,
                                                                       overlay_icon_size);
                        }
                    } catch (GLib.Error error) {}

                    if (icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmap(proxy.get_icon_pixmap());
                    } else {
                        icon_pixbuf = load_icon_from_theme(icon_name,
                                                           icon_size);
                    }

                    if (overlay_icon_pixbuf != null) {
                        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                            if (overlay_icon_pixbuf.height > overlay_icon_size) {
                                overlay_icon_pixbuf = overlay_icon_pixbuf.scale_simple(
                                    (int) (overlay_icon_pixbuf.width * ((float) overlay_icon_size / overlay_icon_pixbuf.height)),
                                    overlay_icon_size,
                                    Gdk.InterpType.BILINEAR
                                );
                            }
                        } else {
                            if (overlay_icon_pixbuf.width > overlay_icon_size) {
                                overlay_icon_pixbuf = overlay_icon_pixbuf.scale_simple(
                                    overlay_icon_size,
                                    (int) (overlay_icon_pixbuf.height * ((float) overlay_icon_size / overlay_icon_pixbuf.width)),
                                    Gdk.InterpType.BILINEAR
                                );
                            }
                        }

                        int x = icon_pixbuf.width - overlay_icon_pixbuf.width;
                        int y = icon_pixbuf.height - overlay_icon_pixbuf.height;

                        overlay_icon_pixbuf.composite(icon_pixbuf,
                                                      x,
                                                      y,
                                                      overlay_icon_pixbuf.width,
                                                      overlay_icon_pixbuf.height,
                                                      x,
                                                      y,
                                                      1,
                                                      1,
                                                      Gdk.InterpType.BILINEAR,
                                                      255);
                    }
                }
            } catch (GLib.Error error) {
                try {
                    icon_pixbuf = load_icon_from_theme("image-missing", icon_size);
                } catch (GLib.Error error) {
                    GLib.stderr.printf("%s\n", error.message);
                    return;
                }
                GLib.stderr.printf("%s\n", error.message);
            }

            if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                if (icon_pixbuf.height > icon_size) {
                    icon_pixbuf = icon_pixbuf.scale_simple(
                        (int) (icon_pixbuf.width * ((float) icon_size / icon_pixbuf.height)),
                        icon_size,
                        Gdk.InterpType.BILINEAR
                    );
                }
                if (icon_pixbuf.height >= icon_pixbuf.width) {
                    set_size_request(plugin.size, plugin.size);
                } else {
                    set_size_request(icon_pixbuf.width + 2 + 2*style.xthickness, plugin.size);
                }
            } else {
                if (icon_pixbuf.width > icon_size) {
                    icon_pixbuf = icon_pixbuf.scale_simple(
                        icon_size,
                        (int) (icon_pixbuf.height * ((float) icon_size / icon_pixbuf.width)),
                        Gdk.InterpType.BILINEAR
                    );
                }
                if (icon_pixbuf.width >= icon_pixbuf.height) {
                    set_size_request(plugin.size, plugin.size);
                } else {
                    set_size_request(plugin.size, icon_pixbuf.height + 2 + 2*style.ythickness);
                }
            }

            icon.set_from_pixbuf(icon_pixbuf);
        }

        void update_status(string status) {
            if (status == "Passive") {
                hide();
            }
            show();
        }

        void update_tooltip() {
            StatusNotifier.Item.ToolTip tool_tip;
            try {
                tool_tip = proxy.get_tool_tip();
            } catch (GLib.DBusError error) {
                set_generic_tooltip();
                GLib.stderr.printf("%s\n", error.message);
                return;
            }

            if (tool_tip.title.length == 0) {
                set_generic_tooltip();
            } else {
                string tooltip_tmp = tool_tip.title;
                if (tool_tip.description.length != 0) {
                    tooltip_tmp += "<br>" + tool_tip.description;
                }

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

            if (tool_tip.icon_name.length == 0) {
                try {
                    tooltip_icon_pixbuf = pixbuf_from_pixmap(tool_tip.icon_pixmap);
                } catch (PixmapError error) {}
            } else {
                tooltip_icon_name = tool_tip.icon_name;
            }
        }

        void set_generic_tooltip() {
            tooltip_icon_name = null;
            tooltip_icon_pixbuf = null;
            try {
                string title = proxy.get_title();
                if (title.length == 0) {
                    tooltip_markup = proxy.id;
                } else {
                    tooltip_markup = title;
                }
            } catch (GLib.DBusError error) {
                tooltip_markup = proxy.id;
            }
        }

        Gdk.Pixbuf load_icon_from_theme(string icon_name, int size) throws GLib.Error {
            if ((size >= 16) && (size < 22)) {
                size = 16;
            } else if (size < 24) {
                size = 22;
            } else if (size < 32) {
                size = 24;
            } else if (size < 48) {
                size = 32;
            } else if (size < 64) {
                size = 48;
            } else if (size < 96) {
                size = 96;
            }

            Gdk.Pixbuf icon_pixbuf = icon_theme.load_icon(icon_name, size, 0);

            if (icon_pixbuf.width > icon_pixbuf.height &&
                    plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                icon_pixbuf = icon_theme.load_icon(icon_name,
                                                   (int) (size * ((float) icon_pixbuf.width / icon_pixbuf.height)),
                                                   0);
            } else if (icon_pixbuf.height > icon_pixbuf.width &&
                    plugin.orientation == Gtk.Orientation.VERTICAL) {
                 icon_pixbuf = icon_theme.load_icon(icon_name,
                                                   (int) (size * ((float) icon_pixbuf.height / icon_pixbuf.width)),
                                                   0);
            }

            return icon_pixbuf;
        }

        Gdk.Pixbuf pixbuf_from_pixmap(StatusNotifier.Item.IconPixmap[] icon_pixmap) throws PixmapError {
            if (icon_pixmap.length == 0) {
                throw new PixmapError.ERROR("No pixmaps");
            }

            if (icon_pixmap[0].bytes.length == 0) {
                throw new PixmapError.ERROR("First pixmap is empty");
            }

            uint[] new_bytes = (uint[]) icon_pixmap[0].bytes;
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
                                            icon_pixmap[0].width,
                                            icon_pixmap[0].height,
                                            Cairo.Format.ARGB32.stride_for_width(icon_pixmap[0].width));
        }

    }
}

