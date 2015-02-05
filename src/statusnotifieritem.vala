using GLib;

struct IconPixmap {
    int width;
    int height;
    uint8[] bytes;
}

struct ToolTip {
    string icon_name;
    IconPixmap[] pixmap;
    string title;
    string description;
}

[DBus (name = "org.kde.StatusNotifierItem")]
interface StatusNotifierItem : Object {
    public abstract string category { owned get; }
    public abstract string id { owned get; }
    public abstract string title { owned get; }
    public abstract string status { owned get; }
    public abstract int window_id { owned get; }
    public abstract string icon_name { owned get; }
    public abstract string icon_theme_path { owned get; }
    public abstract string overlay_icon_name { owned get; }
    public abstract string attention_icon_name { owned get; }
    public abstract ToolTip tool_tip { owned get; }
    public abstract GLib.ObjectPath menu { owned get; }
    
    public abstract void context_menu(int x, int y) throws IOError;
    public abstract void activate(int x, int y) throws IOError;
    public abstract void secondary_activate(int x, int y) throws IOError;
    public abstract void scroll(int delta, string orientation) throws IOError;
    
    public signal void new_title();
    public signal void new_icon();
    public signal void new_attention_icon();
    public signal void new_overlay_icon();
    public signal void new_tool_tip();
    public signal void new_status();
}
