using GLib;

public class StatusNotifierButton : Gtk.ToggleButton {

    public StatusNotifierButton(string service, string object_path, SNWPlugin plugin) {
        this.service = service;
        this.object_path = object_path;
        this.plugin = plugin;

        set_relief(Gtk.ReliefStyle.NONE);

#if GTK3
        Gtk.CssProvider provider = new Gtk.CssProvider();
        provider.load_from_data("""
                                StatusNotifierButton {
                                    padding: 2px 2px 2px 2px;
                                }""", -1);
        get_style_context().add_provider(provider, -99);
#endif

        item = Bus.get_proxy_sync(BusType.SESSION,
                                service,
                                object_path);

        int size = plugin.size;
        set_size_request(size, size);

        if (item.menu != null) {
            if (item.menu.length != 0) {
                menu = new DbusmenuGtk.Menu(service, item.menu);
                menu.attach_to_widget(this, null);
                menu.deactivate.connect(hide_menu);
            }
        }

        tooltip_text = item.title;
        if (item.tool_tip.title != null) {
            if (item.tool_tip.title.length != 0) {
                tooltip_text = item.tool_tip.title;
            }
        }

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
        scroll_event.connect(wheel_rotated);
        query_tooltip.connect(tooltip_requested);

        item.new_tool_tip.connect(update_tooltip);
        item.new_icon.connect(update_icon);
    }

    //
    // Signal handlers
    //

    void hide_menu() {
        if (active) {
            active = false;
        }
    }

    bool button_pressed(Gdk.EventButton event) {
        if (event.button == 1) {
            active = true;
            menu.reposition();
            menu.popup(null,
                       null,
                       (menu, out x, out y, out push_in) => {
                           Xfce.PanelPlugin.position_menu(menu, out x, out y, out push_in, plugin);
                       },
                       event.button,
                       event.time);
        } else if (event.button == 2) {
            item.activate((int) event.x_root, (int) event.y_root);
        } else if (event.button == 3) {
            plugin.button_press_event(event);
        }
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
                var str = "<markup>" + item.tool_tip.title + "</markup>";
                if (str.contains("&"))
                    str = str.replace("&","&amp;");
                QRichTextParser parser = new QRichTextParser(str);
                parser.translate_markup();
                tooltip_image = parser.icon;
                tooltip_markup = parser.pango_markup;
            }
        }
    }

    public void update_icon() {
        StatusNotifierItem item = Bus.get_proxy_sync(BusType.SESSION,
                                                    service,
                                                    object_path);

        int thickness;

#if GTK3
        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
            thickness = 2 * get_style_context().get_padding(Gtk.StateFlags.NORMAL).top;
        } else {
            thickness = 2 * get_style_context().get_padding(Gtk.StateFlags.NORMAL).left;
        }
        thickness += 2;
#else
        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
            thickness = 2 * this.style.ythickness;
        } else {
            thickness = 2 * this.style.xthickness;
        }
#endif

        int icon_size = plugin.size - thickness;

        Gdk.Pixbuf icon_pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB,
                                                true,
                                                8,
                                                icon_size,
                                                icon_size);

        bool has_icon = true;
        string icon_name = item.attention_icon_name.length == 0 ?
                            item.icon_name :
                            item.attention_icon_name;

        if (icon_name.length != 0) {
            icon_theme.rescan_if_needed();
            try {
#if GTK3
                Gtk.IconInfo info = icon_theme.lookup_icon(item.icon_name, icon_size, 0);
                icon_pixbuf = info.load_icon().copy();
                info.free();
#else
                icon_pixbuf = icon_theme.load_icon(item.icon_name, icon_size, 0);
#endif
            } catch (Error e) {
                stdout.printf("Error: %s\n", e.message);
                has_icon = false;
            }
        } else {

            IconPixmap icon_pixmap = IconPixmap();

            if (item.icon_pixmap.length == 0) {
                has_icon = false;
            } else if (item.icon_pixmap[0].bytes.length == 0) {
                has_icon = false;
            }

            if (has_icon) {
                if (item.attention_icon_pixmap.length != 0) {
                    if (item.attention_icon_pixmap[0].bytes.length != 0) {
                        icon_pixmap = item.attention_icon_pixmap[0];
                    }
                }

                uint[] new_bytes = (uint[]) icon_pixmap.bytes;
                for (int i = 0; i < new_bytes.length; i++) {
                    new_bytes[i] = new_bytes[i].to_big_endian();
                }

                icon_pixmap.bytes = (uint8[]) new_bytes;
                for (int i = 0; i < icon_pixmap.bytes.length; i = i+4) {
                    uint8 red = icon_pixmap.bytes[i];
                    icon_pixmap.bytes[i] = icon_pixmap.bytes[i+2];
                    icon_pixmap.bytes[i+2] = red;
                }

                icon_pixbuf = new Gdk.Pixbuf.from_data(icon_pixmap.bytes,
                                                        Gdk.Colorspace.RGB,
                                                        true,
                                                        8,
                                                        icon_pixmap.width,
                                                        icon_pixmap.height,
                                                        Cairo.Format.ARGB32.stride_for_width(icon_pixmap.width));
            }
        }

        if (!has_icon) {
            try {
                icon_pixbuf = icon_theme.load_icon("image-missing", icon_size, 0);
            } catch (Error e) {
                stdout.printf("Error: %s\n", e.message);
            }
        }

        if (icon_pixbuf.width > icon_size) {
            icon_pixbuf = icon_pixbuf.scale_simple(icon_size, icon_size, Gdk.InterpType.BILINEAR);
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

    public void change_size(int size) {
        set_size_request(size, size);
        update_icon();
    }

    //
    // Private members
    //

    SNWPlugin plugin;
    StatusNotifierItem item;
    string service;
    string object_path;
    DbusmenuGtk.Menu menu;
    Gtk.Image icon;
    Gtk.IconTheme icon_theme;
    Icon tooltip_image;
}
