namespace StatusNotifier {
    private Gtk.Orientation get_orientation(uint orient) {
        switch (orient) {
        case MatePanel.AppletOrient.UP:
        case MatePanel.AppletOrient.DOWN:
            return Gtk.Orientation.HORIZONTAL;
        }
        return Gtk.Orientation.VERTICAL;
    }

    private bool factory_callback(MatePanel.Applet applet, string iid) {
        if (iid != "SNWApplet") {
            return false;
        }

        applet.flags = MatePanel.AppletFlags.HAS_HANDLE;

        var widget = new Widget(get_orientation(applet.orient), (int) applet.size, applet);

        applet.change_orient.connect((orient) => {
            widget.orientation = get_orientation(orient);
            widget.update_size();
        });

        applet.change_size.connect((size) => {
            widget.size = size;
            widget.update_size();
        });

        applet.add(widget);
        applet.show_all();

        return true;
    }
}

void main(string[] args) {
    Gtk.init(ref args);
    MatePanel.Applet.factory_main("SNWAppletFactory", true, typeof (MatePanel.Applet), StatusNotifier.factory_callback);
}
