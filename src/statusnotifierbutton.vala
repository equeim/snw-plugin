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

public class StatusNotifierButton : Gtk.Button {
    string service;
    string object_path;
    SNWPlugin plugin;

    StatusNotifierItem item;

    DbusmenuGtk.Menu menu;

    Xfce.PanelImage icon;
    Gtk.IconTheme icon_theme;
    bool custom_icon_theme;
    GLib.Icon tooltip_image;

    public StatusNotifierButton(string service, string object_path, SNWPlugin plugin) {
        this.service = service;
        this.object_path = object_path;
        this.plugin = plugin;

        set_relief(Gtk.ReliefStyle.NONE);

        item = GLib.Bus.get_proxy_sync(BusType.SESSION,
                                       service,
                                       object_path);

        set_size_request(plugin.size, plugin.size);

        if (item.menu != null) {
            if (item.menu.length != 0) {
                menu = new DbusmenuGtk.Menu(service, item.menu);
                menu.attach_to_widget(this, null);
            }
        }

        icon = new Xfce.PanelImage();
        add(icon);

        icon_theme = Gtk.IconTheme.get_default();
        custom_icon_theme = false;
        if (item.icon_theme_path != null) {
            if (item.icon_theme_path.length != 0) {
                icon_theme.prepend_search_path(item.icon_theme_path);
                custom_icon_theme = true;
            }
        }
 
        button_press_event.connect(button_pressed);
        button_release_event.connect(button_released);
        scroll_event.connect(wheel_rotated);
        query_tooltip.connect(tooltip_requested);

        item.new_tool_tip.connect(update_tooltip);
        item.new_icon.connect(update_icon);
        item.new_attention_icon.connect(update_icon);
        item.new_overlay_icon.connect(update_icon);
        item.new_status.connect(update_status);

        update_icon();
        update_tooltip();
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
            item.activate((int) event.x_root, (int) event.y_root);
        else if (event.button == 2)
            item.secondary_activate((int) event.x_root, (int) event.y_root);
        return false;
    }

    bool wheel_rotated(Gdk.EventScroll event) {
        switch (event.direction) {
            case Gdk.ScrollDirection.LEFT:
                item.scroll(-120, "horizontal");
                break;
            case Gdk.ScrollDirection.RIGHT:
                item.scroll(120, "horizontal");
                break;
            case Gdk.ScrollDirection.DOWN:
                item.scroll(-120, "vertical");
                break;
            case Gdk.ScrollDirection.UP:
                item.scroll(120, "vertical");
                break;
        }
        return false;
    }

    bool tooltip_requested(int x, int y, bool keyboard, Gtk.Tooltip tip) {
        tip.set_icon_from_gicon(tooltip_image, Gtk.IconSize.DIALOG);
        tip.set_markup(tooltip_markup);
        return true;
    }

    void update_icon() {
        StatusNotifierItem item = GLib.Bus.get_proxy_sync(GLib.BusType.SESSION,
                                                          service,
                                                          object_path);

        int thickness;
        if (plugin.orientation == Gtk.Orientation.HORIZONTAL)
            thickness = 2 * style.ythickness;
        else
            thickness = 2 * style.xthickness;

        int icon_size = plugin.size - thickness;
        int overlay_icon_size = icon_size / 2;


        bool has_icon_name = false;
        if (item.icon_name != null)
            if (item.icon_name.length != 0)
                has_icon_name = true;

        bool has_icon_pixmap = false;
        if (item.icon_pixmap.length != 0)
            if (item.icon_pixmap[0].bytes.length != 0)
                has_icon_pixmap = true;


        bool has_attention_icon_name = false;
        if (item.attention_icon_name != null)
            if (item.attention_icon_name.length != 0)
                has_attention_icon_name = true;

        bool has_attention_icon_pixmap = false;
        if (item.attention_icon_pixmap.length != 0)
            if (item.attention_icon_pixmap[0].bytes.length != 0)
                has_attention_icon_pixmap = true;


        bool has_overlay_icon_name = false;
        if (item.overlay_icon_name != null)
            if (item.overlay_icon_name.length != 0)
                has_overlay_icon_name = true;

        bool has_overlay_icon_pixmap = false;
        if (item.overlay_icon_pixmap.length != 0)
            if (item.overlay_icon_pixmap[0].bytes.length != 0)
                has_overlay_icon_pixmap = true;

        /*GLib.stdout.printf("has_icon_name: %s\n", has_icon_name.to_string());
        GLib.stdout.printf("has_icon_pixmap: %s\n", has_icon_pixmap.to_string());
        GLib.stdout.printf("has_attention_icon_name: %s\n", has_attention_icon_name.to_string());
        GLib.stdout.printf("has_attention_icon_pixmap: %s\n", has_attention_icon_pixmap.to_string());
        GLib.stdout.printf("has_overlay_icon_name: %s\n", has_overlay_icon_name.to_string());
        GLib.stdout.printf("has_overlay_icon_pixap: %s\n", has_overlay_icon_pixmap.to_string());
        GLib.stdout.printf("icon_theme is null: %s\n", (icon_theme == null).to_string());*/

        if (item.status == "NeedsAttention") {
            if (has_attention_icon_name) {
                if (custom_icon_theme) {
                    icon_theme.rescan_if_needed();
                    try {
                        icon.set_from_pixbuf(icon_theme.load_icon(item.attention_icon_name,
                                             icon_size,
                                             0));
                        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                            set_size_request(plugin.size * (icon.pixbuf.width / icon.pixbuf.height),
                                             plugin.size);
                        }
                    } catch (GLib.Error error) {
                        icon.set_from_source("image-missing");
                    }
                } else {
                    icon.set_from_source(item.attention_icon_name);
                }
            } else if (has_attention_icon_pixmap)
                icon.set_from_pixbuf(pixbuf_from_pixmap(item.attention_icon_pixmap[0]));
            return;
        }

        Gdk.Pixbuf icon_pixbuf = null;

        if (has_icon_name) {
            if (custom_icon_theme ||
                    has_overlay_icon_name ||
                    has_overlay_icon_pixmap) {
                icon_theme.rescan_if_needed();
                try {
                    icon_pixbuf = icon_theme.load_icon(item.icon_name,
                                                       icon_size,
                                                       0);
                } catch (GLib.Error error) {
                    icon.set_from_source("image-missing");
                    return;
                }
            } else {
                icon.set_from_source(item.icon_name);
                return;
            }
        } else if (has_icon_pixmap) {
            icon_pixbuf = pixbuf_from_pixmap(item.icon_pixmap[0]);
        } else {
            icon.set_from_source("image-missing");
            return;
        }

        Gdk.Pixbuf overlay_icon_pixbuf = null;

        if (has_overlay_icon_name) {
            try {
                overlay_icon_pixbuf = icon_theme.load_icon(item.overlay_icon_name,
                                                           overlay_icon_size,
                                                           0);
            } catch (GLib.Error error) { }
        } else if (has_overlay_icon_pixmap) {
            overlay_icon_pixbuf = pixbuf_from_pixmap(item.overlay_icon_pixmap[0]);
        }

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

        icon.set_from_pixbuf(icon_pixbuf);

        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
            set_size_request(plugin.size * (icon_pixbuf.width / icon_pixbuf.height),
                             plugin.size);
        } else {
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
        StatusNotifierItem item = GLib.Bus.get_proxy_sync(BusType.SESSION,
                                                          service,
                                                          object_path);

        tooltip_text = item.title;
        if (item.tool_tip.title != null) {
            if (item.tool_tip.title.length != 0) {
                bool is_pango_markup = true;
                try {
                    Pango.parse_markup(item.tool_tip.title, -1, '\0', null, null, null);
                } catch (GLib.Error error) {
                    is_pango_markup = false;
                }

                if (is_pango_markup) {
                    tooltip_markup = item.tool_tip.title;
                } else {
                    string str = "<markup>" + item.tool_tip.title + "</markup>";
                    if (str.contains("&"))
                        str = str.replace("&","&amp;");
                    QRichTextParser parser = new QRichTextParser(str);
                    parser.translate_markup();
                    tooltip_image = parser.icon;
                    tooltip_markup = parser.pango_markup;
                }
            }
        }
    }

    Gdk.Pixbuf pixbuf_from_pixmap(IconPixmap icon_pixmap) {
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
