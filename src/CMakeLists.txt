set(VALA_SOURCES
    xfce4-snw-applet.vala
    statusnotifierbutton.vala
    statusnotifieritem.vala
    statusnotifierwatcher.vala
    statusnotifierwidget.vala
)

if(USE_GTK3)
    vala_precompile(VALA_C
        ${VALA_SOURCES}
    PACKAGES
        Dbusmenu-0.4
        gtk+-3.0
        DbusmenuGtk3-0.4
    CUSTOM_VAPIS
        vapi/libxfce4panel.vapi
        vapi/gio-addons-2.0.vapi
    OPTIONS
        -D GTK3
    )
else()
    vala_precompile(VALA_C
        ${VALA_SOURCES}
    PACKAGES
        Dbusmenu-0.4
        gtk+-2.0
        DbusmenuGtk-0.4
    CUSTOM_VAPIS
        vapi/libxfce4panel.vapi
        vapi/gio-addons-2.0.vapi
    )
endif()

add_library(snw SHARED ${VALA_C})
include_directories(${GTK+_INCLUDE_DIRS} ${LIBXFCE4PANEL_INCLUDE_DIRS} ${DBUSMENU_GTK_INCLUDE_DIRS})
target_link_libraries(snw ${GTK+_LIBRARIES} ${LIBXFCE4PANEL_LIBRARIES} ${DBUSMENU_GTK_LIBRARIES})

include(GNUInstallDirs)
install(TARGETS snw DESTINATION "${CMAKE_INSTALL_FULL_LIBDIR}/xfce4/panel/plugins")

