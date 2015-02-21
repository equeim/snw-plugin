using GLib;

public class StatusNotifierButton : Gtk.ToggleButton {

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

        menu = new DbusmenuGtk.Menu(service, item.menu);
        menu.deactivate.connect(hide_menu);

        if (item.tool_tip.title.length != 0) {
            tooltip_text = item.tool_tip.title;
        } else {
            tooltip_text = item.title;
        }
        
        icon_theme = Gtk.IconTheme.get_default();

        //
        // Signal connections
        //

        button_press_event.connect(button_pressed);
        scroll_event.connect(wheel_rotated);

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

    void update_tooltip() {
        StatusNotifierItem item = Bus.get_proxy_sync(BusType.SESSION,
                                                    service,
                                                    object_path);
            
        tooltip_text = item.title;                                             
        if (item.tool_tip.title != null) {
            if (item.tool_tip.title.length != 0) {
                tooltip_text = item.tool_tip.title;
            }
        }
    }

    public void update_icon() {
        StatusNotifierItem item = Bus.get_proxy_sync(BusType.SESSION,
                                                    service,
                                                    object_path);

        int thickness;
        if (plugin.orientation == Gtk.Orientation.HORIZONTAL) {
            thickness = 2 * this.style.ythickness;
        } else {
            thickness = 2 * this.style.xthickness;
        }
        int icon_size = plugin.size - thickness;

        Gdk.Pixbuf icon_pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB,
                                                true,
                                                8,
                                                icon_size,
                                                icon_size);
                                                
        try {
            icon_pixbuf = icon_theme.load_icon("image-missing", icon_size, 0);
        } catch (Error e) {
            stdout.printf("Error: %s\n", e.message);
        }
                                                            
        string icon_name = item.attention_icon_name.length == 0 ?
                            item.icon_name :
                            item.attention_icon_name;
                            
        if (icon_name.length != 0) {
            if (item.icon_theme_path != null)
                icon_theme.prepend_search_path(item.icon_theme_path);
                    
            try {
                icon_pixbuf = icon_theme.load_icon(item.icon_name, icon_size, 0);
            } catch (Error e) {
                stdout.printf("Error: %s\n", e.message);
            }

        } else {
            
            IconPixmap icon_pixmap = IconPixmap();
            bool has_icon = false;
            
            if (item.icon_pixmap.length != 0) {
                if (item.icon_pixmap[0].bytes.length != 0) {
                    icon_pixmap = item.icon_pixmap[0];
                    has_icon = true;
                }
            }
                
            if (!has_icon) {
                if (icon != null) {
                    remove(icon);
                }
                icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
                add(icon);
                icon.show();
                return;
            }
                
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

        if (icon_pixbuf.width > icon_size) {
            icon_pixbuf = icon_pixbuf.scale_simple(icon_size, icon_size, Gdk.InterpType.BILINEAR);
        }

        if (icon != null) {
            remove(icon);
        }
                
        icon = new Gtk.Image.from_pixbuf(icon_pixbuf);
        add(icon);
        icon.show();
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
}
