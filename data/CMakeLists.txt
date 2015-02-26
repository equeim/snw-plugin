if(USE_GTK3)
    set(XFCE_API 2.0)
else()
    set(XFCE_API 1.0)
endif()

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/snw.desktop.in" "${CMAKE_CURRENT_SOURCE_DIR}/snw.desktop")

install(FILES snw.desktop DESTINATION share/xfce4/panel/plugins)
