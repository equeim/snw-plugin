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
    private errordomain PixmapError {
        ERROR
    }

    private class Button : Gtk.Button {
        private Plugin plugin;

        private ItemProxy proxy;

        private DbusmenuGtk.Menu menu;

        private Gtk.Image icon;
        private Gtk.IconTheme icon_theme;
        private bool custom_icon_theme;

        private string tooltip_icon_name;
        private Gdk.Pixbuf tooltip_icon_pixbuf;

        public Button(string bus_name, string object_path, Plugin plugin) throws Error {
            this.plugin = plugin;

            set_relief(Gtk.ReliefStyle.NONE);
            set_size_request(plugin.size, plugin.size);

            proxy = new ItemProxy(plugin.dbus_connection, bus_name, object_path);

            try {
                string menu_path = proxy.get_menu();
                if (menu_path.length != 0) {
                    menu = new DbusmenuGtk.Menu(bus_name, menu_path);
                    menu.attach_to_widget(this, null);
                }
            } catch { }

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
            } catch { }
 
            button_press_event.connect(button_pressed);
            button_release_event.connect(button_released);
            scroll_event.connect(wheel_rotated);
            query_tooltip.connect(tooltip_requested);

            proxy.new_title.connect(update_tooltip);
            proxy.new_icon.connect(update_icon);
            proxy.new_attention_icon.connect(update_icon);
            proxy.new_overlay_icon.connect(update_icon);
            proxy.new_tooltip.connect(update_tooltip);
            proxy.new_status.connect(update_status);

            update_icon();
            update_tooltip();
            update_status(proxy.get_status());
        }

        ~Button() {
            proxy.unsubscribe_signals();
        }

        public void change_size(int size) {
            update_icon();
        }

        private bool button_pressed(Gdk.EventButton event) {
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

        private bool button_released(Gdk.EventButton event) {
            if (event.button == 1) {
                proxy.activate((int) event.x_root, (int) event.y_root);
            } else if (event.button == 2) {
                proxy.secondary_activate((int) event.x_root, (int) event.y_root);
            }
            return false;
        }

        private bool wheel_rotated(Gdk.EventScroll event) {
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

        private bool tooltip_requested(int x, int y, bool keyboard, Gtk.Tooltip tooltip) {
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

        private void update_icon() {
            int icon_size = plugin.size - 2;
            if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                icon_size -= style.ythickness * 2;
            } else {
                icon_size -= style.xthickness * 2;
            }

            int overlay_icon_size = icon_size / 2;

            Gdk.Pixbuf icon_pixbuf = null;
            icon_theme.rescan_if_needed();

            try {
                if (proxy.get_status() == "NeedsAttention") {
                    string attention_icon_name = proxy.get_attention_icon_name();
                    if (attention_icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmaps(proxy.get_attention_icon_pixmaps());
                    } else {
                        icon_pixbuf = load_icon_from_theme(attention_icon_name,
                                                           icon_size);
                    }
                } else {
                    string icon_name = proxy.get_icon_name();
                    print("%s\n", icon_name);

                    Gdk.Pixbuf overlay_icon_pixbuf = null;
                    try {
                        string overlay_icon_name = proxy.get_overlay_icon_name();
                        if (overlay_icon_name.length == 0) {
                            overlay_icon_pixbuf = pixbuf_from_pixmaps(proxy.get_overlay_icon_pixmaps());
                        } else {
                            overlay_icon_pixbuf = load_icon_from_theme(overlay_icon_name,
                                                                       overlay_icon_size);
                        }
                    } catch { }

                    if (icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmaps(proxy.get_icon_pixmaps());
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
            } catch (Error error) {
                stderr.printf("666 %s\n", error.message);
                try {
                    icon_pixbuf = load_icon_from_theme("image-missing", icon_size);
                    print("123\n");
                } catch (Error error) {
                    stderr.printf("%s\n", error.message);
                    return;
                }
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

        private void update_status(string status) {
            if (status == "Passive") {
                hide();
            } else {
                show();
            }
        }

        private void update_tooltip() {
            ToolTip tooltip;
            try {
                tooltip = proxy.get_tooltip();
            } catch (Error error) {
                set_generic_tooltip();
                stderr.printf("%s\n", error.message);
                return;
            }

            if (tooltip.title.length == 0) {
                set_generic_tooltip();
            } else {
                string tooltip_string = tooltip.title;
                if (tooltip.description.length != 0) {
                    tooltip_string += "<br>";
                    tooltip_string += tooltip.description;
                }

                try {
                    Pango.parse_markup(tooltip_string, -1, '\0', null, null, null);
                    tooltip_markup = tooltip_string;
                } catch {
                    tooltip_string = "<markup>" + tooltip_string + "</markup>";
                    var parser = new QRichTextParser(tooltip_string);
                    parser.translate_markup();
                    tooltip_markup = parser.pango_markup;
                }
            }

            if (tooltip.icon_name.length == 0) {
                try {
                    tooltip_icon_pixbuf = pixbuf_from_pixmaps(tooltip.icon_pixmaps);
                } catch (PixmapError error) { }
            } else {
                tooltip_icon_name = tooltip.icon_name;
            }
        }

        private void set_generic_tooltip() {
            tooltip_icon_name = null;
            tooltip_icon_pixbuf = null;
            try {
                string title = proxy.get_title();
                if (title.length == 0) {
                    tooltip_markup = proxy.id;
                } else {
                    tooltip_markup = title;
                }
            } catch {
                tooltip_markup = proxy.id;
            }
        }

        private Gdk.Pixbuf load_icon_from_theme(string icon_name, int size) throws Error {
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

        private Gdk.Pixbuf pixbuf_from_pixmaps(IconPixmap[] icon_pixmaps) throws PixmapError {
            if (icon_pixmaps.length == 0) {
                throw new PixmapError.ERROR("No pixmaps");
            }

            if (icon_pixmaps[0].bytes.length == 0) {
                throw new PixmapError.ERROR("First pixmap is empty");
            }

            var new_bytes = (uint[]) icon_pixmaps[0].bytes;
            for (int i = 0; i < new_bytes.length; i++) {
                new_bytes[i] = new_bytes[i].to_big_endian();
            }

            var new_bytes8 = (uint8[]) new_bytes;
            for (int i = 0; i < new_bytes8.length; i = i + 4) {
                var red = new_bytes8[i];
                new_bytes8[i] = new_bytes8[i + 2];
                new_bytes8[i + 2] = red;
            }

            return new Gdk.Pixbuf.from_data(new_bytes8,
                                            Gdk.Colorspace.RGB,
                                            true,
                                            8,
                                            icon_pixmaps[0].width,
                                            icon_pixmaps[0].height,
                                            Cairo.Format.ARGB32.stride_for_width(icon_pixmaps[0].width));
        }

    }
}

