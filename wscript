def options(context):
    context.load("compiler_c gnu_dirs vala")
    context.add_option("--gtk3", action="store_true", default=False)
    context.add_option("--mate", action="store_true", default=False)


def configure(context):
    context.load("compiler_c gnu_dirs vala")

    context.env.GTK3 = context.options.gtk3
    context.env.MATE = context.options.mate

    if context.env.GTK3:
        context.check_cfg(package="dbusmenu-gtk3-0.4", uselib_store="DBUSMENU-GTK", args="--libs --cflags")
    else:
        context.check_cfg(package="dbusmenu-gtk-0.4", uselib_store="DBUSMENU-GTK", args="--libs --cflags")

    if context.env.MATE:
        context.check_cfg(package="libmatepanelapplet-4.0", args="--libs --cflags")
    else:
        if context.env.GTK3:
            context.check_cfg(package="libxfce4panel-2.0", uselib_store="LIBXFCE4PANEL", args="--libs --cflags")
        else:
            context.check_cfg(package="libxfce4panel-1.0", uselib_store="LIBXFCE4PANEL", args="--libs --cflags")


def build(context):
    _features = ["c"]
    _uselib = ["DBUSMENU-GTK"]
    _packages = ["Dbusmenu-0.4"]
    _vala_defines = list()
    _source = [
        "src/qrichtextparser.vala",
        "src/statusnotifierbutton.vala",
        "src/statusnotifieritem.vala",
        "src/statusnotifierwatcher.vala",
        "src/statusnotifierwidget.vala"
    ]

    if context.env.GTK3:
        _packages.append("DbusmenuGtk3-0.4")
        _vala_defines.append("GTK3")
    else:
        _packages.append("DbusmenuGtk-0.4")

    if context.env.MATE:
        _target = "snw-applet"
        _features.append("cprogram")
        _uselib.append("LIBMATEPANELAPPLET-4.0")
        _vala_defines.append("MATE")
        _source.append("src/mate-snw-applet.vala")
        _install_path = "${LIBDIR}/mate-panel"

        if context.env.GTK3:
            _packages.append("MatePanelApplet-4.0-gtk3")
        else:
            _packages.append("MatePanelApplet-4.0-gtk2")
    else:
        _target = "snw"
        _features.append("cshlib")
        _uselib.append("LIBXFCE4PANEL")
        _source.append("src/xfce4-snw-plugin.vala")
        _install_path = "${LIBDIR}/xfce4/panel/plugins"

        if context.env.GTK3:
            _packages.append("libxfce4panel-2.0")
        else:
            _packages.append("libxfce4panel-1.0")


    context(
        target=_target,
        features=_features,
        packages=_packages,
        vapi_dirs="src/vapi",
        uselib=_uselib,
        vala_defines=_vala_defines,
        source=_source,
        install_binding=False,
        install_path=_install_path
    )

    if context.env.MATE:
        context(
            features="subst",
            source="data/org.SNWApplet.mate-panel-applet.in",
            target="org.SNWApplet.mate-panel-applet",
            install_path="${DATADIR}/mate-panel/applets",
            LOCATION="{}/mate-panel/snw-applet".format(context.env.LIBDIR)
        )

        context(
            features="subst",
            source="data/org.mate.panel.applet.SNWAppletFactory.service.in",
            target="org.mate.panel.applet.SNWAppletFactory.service",
            install_path="${DATADIR}/dbus-1/services",
            LOCATION="{}/mate-panel/snw-applet".format(context.env.LIBDIR)
        )
    else:
        if context.env.GTK3:
            api = "2.0"
        else:
            api = "1.0"

        context(
            features="subst",
            source="data/snw.desktop.in",
            target="snw.desktop",
            install_path="${DATADIR}/xfce4/panel/plugins",
            API=api
        )
