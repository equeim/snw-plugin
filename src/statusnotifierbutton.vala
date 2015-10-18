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

public class StatusNotifierButton : Gtk.Button {

    public StatusNotifierButton(string service, string object_path, SNWPlugin plugin) {
        this.service = service;
        this.object_path = object_path;
        this.plugin = plugin;

        set_relief(Gtk.ReliefStyle.NONE);

        item = Bus.get_proxy_sync(BusType.SESSION,
                                service,
                                object_path);

        int size = plugin.size;
        set_size_request(size, size);

        if (item.menu != null) {
            if (item.menu.length != 0) {
                menu = new DbusmenuGtk.Menu(service, item.menu);
                menu.attach_to_widget(this, null);
            }
        }

        update_tooltip();

        icon_theme = Gtk.IconTheme.get_default();
        if (item.icon_theme_path != null) {
            if (item.icon_theme_path.length != 0) {
                icon_theme.prepend_search_path(item.icon_theme_path);
            }
        }

        //
        // Signal connections
        //

        button_press_event.connect(button_pressed);
        button_release_event.connect(button_released);
        scroll_event.connect(wheel_rotated);
        query_tooltip.connect(tooltip_requested);

        item.new_tool_tip.connect(update_tooltip);
        item.new_icon.connect(update_icon);
        item.new_attention_icon.connect(update_icon);
        item.new_overlay_icon.connect(update_icon);
        item.new_status.connect(update_status);
    }

    //
    // Signal handlers
    //

    bool button_pressed(Gdk.EventButton event) {
        if (event.button == 3) {
            if (!menu_title_added) {
                Gtk.SeparatorMenuItem separator = new Gtk.SeparatorMenuItem();
                menu.prepend(separator);
                separator.show();
                Gtk.MenuItem title_item = new Gtk.MenuItem.with_label(service);
                if (item.title != null) {
                    if (item.title.length != 0)
                        title_item.label = item.title;
                }
                title_item.sensitive = false;
                menu.prepend(title_item);
                title_item.show();

                menu_title_added = true;
            }
            menu.popup(null,
                       null,
                       null,
                       event.button,
                       event.time);
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

    void update_tooltip() {
        StatusNotifierItem item = Bus.get_proxy_sync(BusType.SESSION,
                                                    service,
                                                    object_path);

        tooltip_text = item.title;
        if (item.tool_tip.title != null) {
            if (item.tool_tip.title.length != 0) {
                bool is_pango_markup = true;
                try {
                    Pango.parse_markup(item.tool_tip.title, -1, '\0', null, null, null);
                } catch (Error e) {
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

    public void update_icon() {
        StatusNotifierItem item = Bus.get_proxy_sync(BusType.SESSION,
                                                    service,
                                                    object_path);

        int thickness;
        if (plugin.orientation == Gtk.Orientation.HORIZONTAL)
            thickness = 2 * style.ythickness;
        else
            thickness = 2 * style.xthickness;

        bool has_icon = true;
        int icon_size = plugin.size - thickness;
        float aspect_ratio = 1;
        int icon_width = icon_size;
        int overlay_icon_size = icon_size / 2;

        Gdk.Pixbuf icon_pixbuf = null;

        string icon_name = item.icon_name;
        if (icon_name == null)
            has_icon = false;
        else if (icon_name.length == 0)
            has_icon = false;

        if (has_icon) {
            if (item.attention_icon_name != null) {
                if (item.attention_icon_name.length != 0) {
                    icon_name = item.attention_icon_name;
                }
            }
            icon_theme.rescan_if_needed();

            Gtk.IconInfo info = icon_theme.lookup_icon(icon_name, icon_size, 0);
            if (info == null) {
                has_icon = false;
            } else {
                icon_pixbuf = info.load_icon().copy();
                aspect_ratio = (float) icon_pixbuf.width / (float) icon_pixbuf.height;
                if (aspect_ratio != 1) {
                    icon_width = (int) (icon_size * aspect_ratio);
                    info = icon_theme.lookup_icon(icon_name, icon_width, 0);
                    icon_pixbuf = info.load_icon().copy();
                }
            }
        } else {
            has_icon = true;
            if (item.icon_pixmap.length == 0) {
                has_icon = false;
            } else if (item.icon_pixmap[0].bytes.length == 0) {
                has_icon = false;
            }

            if (has_icon) {
                bool attention_pixmap = false;
                if (item.attention_icon_pixmap.length != 0) {
                    if (item.attention_icon_pixmap[0].bytes.length != 0) {
                        attention_pixmap = true;
                    }
                }
                icon_pixbuf = pixbuf_from_pixmap(attention_pixmap? item.attention_icon_pixmap[0] : item.icon_pixmap[0]);
                aspect_ratio = (float) icon_pixbuf.width / (float) icon_pixbuf.height;
                if (aspect_ratio != 1)
                    icon_width = icon_pixbuf.width;
            }
        }

        if (!has_icon) {
            try {
                icon_pixbuf = icon_theme.load_icon("image-missing", icon_size, 0);
            } catch (Error e) {
                stdout.printf("Error: %s\n", e.message);
            }
        }

        if (icon_pixbuf.height > icon_size) {
            icon_pixbuf = icon_pixbuf.scale_simple(icon_width, icon_size, Gdk.InterpType.BILINEAR);
        }

        if (aspect_ratio != 1) {
            if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
                set_size_request(icon_width + thickness, plugin.size);
            }
        }

        // overlay icon
        Gdk.Pixbuf overlay_icon_pixbuf = null;

        bool has_overlay_icon = true;
        if (item.overlay_icon_name == null) {
            has_overlay_icon = false;
        } else if (item.overlay_icon_name.length == 0) {
            has_overlay_icon = false;
        }

        if (has_overlay_icon) {
            icon_theme.rescan_if_needed();
            Gtk.IconInfo info = icon_theme.lookup_icon(item.overlay_icon_name, overlay_icon_size, 0);

            if (info == null) {
                has_overlay_icon = false;
            } else {
                overlay_icon_pixbuf = info.load_icon().copy();
            } 
        } else {
            has_overlay_icon = true;
            if (item.overlay_icon_pixmap.length == 0) {
                has_overlay_icon = false;
            } else if (item.overlay_icon_pixmap[0].bytes.length == 0) {
                has_overlay_icon = false;
            }

            if (has_overlay_icon)
                overlay_icon_pixbuf = pixbuf_from_pixmap(item.overlay_icon_pixmap[0]);
        }

        if (has_overlay_icon) {
            if (overlay_icon_pixbuf.height > overlay_icon_size) {
                overlay_icon_pixbuf = overlay_icon_pixbuf.scale_simple(overlay_icon_size, overlay_icon_size, Gdk.InterpType.BILINEAR);
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

        if (icon == null) {
            icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
            add(icon);
            icon.show();
        }
        else {
            icon.set_from_pixbuf(icon_pixbuf);
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

    public void change_size(int size) {
        set_size_request(size, size);
        update_icon();
    }

    //
    // Private members
    //

    string service;
    string object_path;
    SNWPlugin plugin;

    StatusNotifierItem item;

    DbusmenuGtk.Menu menu;
    bool menu_title_added;

    Gtk.Image icon;
    Gtk.IconTheme icon_theme;
    Icon tooltip_image;
}
