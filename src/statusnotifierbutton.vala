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
    private errordomain PixmapError {
        ERROR
    }

    private class Button : Gtk.Button {
        private Widget widget;

#if MATE
        private MatePanel.Applet applet;
#else
        private Plugin plugin;
#endif

        private ItemProxy proxy;

        private DbusmenuGtk.Menu menu;

        private Gtk.Image icon = new Gtk.Image();
        private Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
        private bool custom_icon_theme = false;

        private string tooltip_icon_name;
        private Gdk.Pixbuf tooltip_icon_pixbuf;

        private string bus_name;

#if MATE
        public Button(string bus_name, string object_path, Widget widget, MatePanel.Applet applet) throws Error {
#else
        public Button(string bus_name, string object_path, Widget widget, Plugin plugin) throws Error {
#endif
            this.widget = widget;
#if MATE
            this.applet = applet;
#else
            this.plugin = plugin;
#endif
            relief = Gtk.ReliefStyle.NONE;

#if GTK3
            get_style_context().add_class("statusnotifierbutton");
#endif

            add(icon);
            icon.show();

            this.bus_name = bus_name;

            proxy = new ItemProxy(widget.dbus_connection, bus_name, object_path);
            proxy.got_all_properties.connect(proxy_got_all_properties);

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
        }

        ~Button() {
            proxy.unsubscribe_signals();
        }

        private void proxy_got_all_properties() {
            string menu_path = proxy.menu;
            if (menu_path != null) {
                if (menu_path.length != 0) {
                    menu = new DbusmenuGtk.Menu(bus_name, menu_path);
                    menu.attach_to_widget(this, null);
                }
            }

            string icon_theme_path = proxy.icon_theme_path;
            if (icon_theme_path != null) {
                if (icon_theme_path.length != 0) {
                    icon_theme.prepend_search_path(icon_theme_path);
                    custom_icon_theme = true;
                }
            }

            update_icon();
            update_tooltip();
            update_status();
        }

        public void update_icon() {
            int icon_size = widget.size;
            int icon_padding = 2;
#if GTK3
            Gtk.Border padding = get_style_context().get_padding(Gtk.StateFlags.NORMAL);
            if (widget.orientation == Gtk.Orientation.HORIZONTAL) {
                icon_padding += padding.top + padding.bottom;
            } else {
                icon_padding += padding.left + padding.right;
            }
#else
            if (widget.orientation == Gtk.Orientation.HORIZONTAL) {
                icon_padding += style.ythickness * 2;
            } else {
                icon_padding += style.xthickness * 2;
            }
#endif
            icon_size -= icon_padding;

            int overlay_icon_size = icon_size / 2;

            Gdk.Pixbuf icon_pixbuf = null;
            icon_theme.rescan_if_needed();

            try {
                if (proxy.status == "NeedsAttention") {
                    string attention_icon_name = proxy.attention_icon_name;
                    if (attention_icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmaps(proxy.attention_icon_pixmaps);
                    } else {
                        icon_pixbuf = load_icon_from_theme(attention_icon_name,
                                                           icon_size);
                    }
                } else {
                    string icon_name = proxy.icon_name;

                    Gdk.Pixbuf overlay_icon_pixbuf = null;
                    try {
                        string overlay_icon_name = proxy.overlay_icon_name;
                        if (overlay_icon_name.length == 0) {
                            overlay_icon_pixbuf = pixbuf_from_pixmaps(proxy.overlay_icon_pixmaps);
                        } else {
                            overlay_icon_pixbuf = load_icon_from_theme(overlay_icon_name,
                                                                       overlay_icon_size);
                        }
                    } catch { }

                    if (icon_name.length == 0) {
                        icon_pixbuf = pixbuf_from_pixmaps(proxy.icon_pixmaps);
                    } else {
                        icon_pixbuf = load_icon_from_theme(icon_name,
                                                           icon_size);
                    }

                    if (overlay_icon_pixbuf != null) {
                        if (widget.orientation == Gtk.Orientation.HORIZONTAL) {
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
                print_error(error.message);
                try {
                    icon_pixbuf = load_icon_from_theme("image-missing", icon_size);
                } catch (Error error) {
                    print_error(error.message);
                    return;
                }
            }

            if (widget.orientation == Gtk.Orientation.HORIZONTAL) {
                if (icon_pixbuf.height > icon_size) {
                    icon_pixbuf = icon_pixbuf.scale_simple(
                        (int) (icon_pixbuf.width * ((float) icon_size / icon_pixbuf.height)),
                        icon_size,
                        Gdk.InterpType.BILINEAR
                    );
                }
                if (icon_pixbuf.width <= icon_pixbuf.height) {
                    set_size_request(widget.size, widget.size);
                } else {
                    set_size_request(icon_pixbuf.width + icon_padding, widget.size);
                }
            } else {
                if (icon_pixbuf.width > icon_size) {
                    icon_pixbuf = icon_pixbuf.scale_simple(
                        icon_size,
                        (int) (icon_pixbuf.height * ((float) icon_size / icon_pixbuf.width)),
                        Gdk.InterpType.BILINEAR
                    );
                }
                if (icon_pixbuf.height <= icon_pixbuf.width) {
                    set_size_request(widget.size, widget.size);
                } else {
                    set_size_request(widget.size, icon_pixbuf.height + icon_padding);
                }
            }

            icon.set_from_pixbuf(icon_pixbuf);
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
#if MATE
                                       Gdk.Window window = get_window();
                                       int window_x, window_y;
                                       window.get_origin(out window_x, out window_y);
                                       int window_width = window.get_width();
                                       int window_height = window.get_height();
                                       int button_x, button_y;
                                       translate_coordinates(get_toplevel(), 0, 0, out button_x, out button_y);

                                       Gtk.Requisition requisition;
#if GTK3
                                       menu.get_preferred_size(null, out requisition);
#else
                                       menu.size_request(out requisition);
#endif

                                       Gdk.Screen screen = window.get_screen();

                                       uint orient = applet.orient;
                                       if (orient == MatePanel.AppletOrient.UP ||
                                           orient == MatePanel.AppletOrient.DOWN) {

                                           x = window_x + button_x;

                                           if (orient == MatePanel.AppletOrient.UP) {
                                               y = window_y - requisition.height;
                                           } else {
                                               y = window_height;
                                           }
                                       } else {
                                           if (orient == MatePanel.AppletOrient.LEFT) {
                                               x = window_x - requisition.width;
                                           } else {
                                               x = window_width;
                                           }

                                           y = window_y + button_y;
                                           if ((screen.height() - y) < requisition.height) {
                                               y = screen.height() - requisition.height;
                                           }
                                       }
#else
                                       Xfce.PanelPlugin.position_menu(menu, out x, out y, out push_in, plugin);
#endif
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

        private void update_status() {
            if (proxy.status == "Passive") {
                hide();
            } else {
                show();
            }
        }

        private void update_tooltip() {
            ToolTip tooltip = proxy.tooltip;

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

            string title = proxy.title;
            if (title != null) {
                if (title.length != 0) {
                    tooltip_markup = title;
                } else {
                    tooltip_markup = proxy.id;
                }
            } else {
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

            return icon_theme.load_icon(icon_name, size, 0);
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

