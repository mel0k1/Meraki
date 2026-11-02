cmake_minimum_required(VERSION 3.20)
include(cmake/version.cmake)
project(SwineWM LANGUAGES C VERSION ${SWINEWM_VERSION_NUMERIC})

# The portable core (tree, commands, config, IPC JSON) builds everywhere so
# that its unit tests run on Linux CI as well as on Windows. The executables
# need Windows (MSVC or MinGW-w64).

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

option(SWINEWM_BUILD_TESTS "Build the unit tests" ON)

if(MSVC)
  add_compile_options(/W4 /utf-8)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_DEPRECATE)
else()
  add_compile_options(-Wall -Wextra -Wno-unused-parameter)
endif()

add_library(swine_common STATIC
  common/fileutil.c
  common/ipc-client.c
  common/json.c
  common/json-parse.c
  common/list.c
  common/log.c
  common/menu.c
  common/regex.c
  common/stringop.c
)
target_include_directories(swine_common PUBLIC include)
if(WIN32)
  target_compile_definitions(swine_common PRIVATE UNICODE _UNICODE)
  target_link_libraries(swine_common PUBLIC advapi32 shell32)
endif()

# Built-in defaults are generated from the files in resources/, which are
# also installed, so the two cannot drift apart.
set(SWINEWM_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
configure_file(swinewm/version.h.in ${SWINEWM_GENERATED_DIR}/swinewm_version.h
  @ONLY)
function(swinewm_embed input name)
  set(output ${SWINEWM_GENERATED_DIR}/${name}.h)
  add_custom_command(OUTPUT ${output}
    COMMAND ${CMAKE_COMMAND} -DINPUT=${CMAKE_CURRENT_SOURCE_DIR}/${input}
      -DOUTPUT=${output} -DNAME=${name}
      -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed.cmake
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${input}
      ${CMAKE_CURRENT_SOURCE_DIR}/cmake/embed.cmake
    VERBATIM)
  set(SWINEWM_EMBEDDED ${SWINEWM_EMBEDDED} ${output} PARENT_SCOPE)
endfunction()
swinewm_embed(resources/waybar/config.jsonc default_bar_config)
swinewm_embed(resources/waybar/style.css default_bar_style)

add_library(swinewm_core STATIC
  ${SWINEWM_EMBEDDED}
  swinewm/bar/bar.c
  swinewm/bar/css.c
  swinewm/bar/custom.c
  swinewm/bar/format.c
  swinewm/bar/tray.c
  swinewm/commands.c
  swinewm/commands/assign.c
  swinewm/commands/audio.c
  swinewm/commands/bar.c
  swinewm/commands/border.c
  swinewm/commands/bind.c
  swinewm/commands/exec.c
  swinewm/commands/floating.c
  swinewm/commands/focus.c
  swinewm/commands/for_window.c
  swinewm/commands/gaps.c
  swinewm/commands/grim.c
  swinewm/commands/input.c
  swinewm/commands/layout.c
  swinewm/commands/mark.c
  swinewm/commands/mode.c
  swinewm/commands/move.c
  swinewm/commands/no_focus.c
  swinewm/commands/notify.c
  swinewm/commands/output.c
  swinewm/commands/rename.c
  swinewm/commands/resize.c
  swinewm/commands/session.c
  swinewm/commands/set.c
  swinewm/commands/settings.c
  swinewm/commands/split.c
  swinewm/commands/sticky.c
  swinewm/commands/swap.c
  swinewm/commands/workspace.c
  swinewm/config.c
  swinewm/criteria.c
  swinewm/desktop/transaction.c
  swinewm/input/cursor.c
  swinewm/input/keyboard.c
  swinewm/input/seat.c
  swinewm/ipc-json.c
  swinewm/ipc-server.c
  swinewm/notify/notify.c
  swinewm/server.c
  swinewm/swaynag.c
  swinewm/tree/arrange.c
  swinewm/tree/container.c
  swinewm/tree/node.c
  swinewm/tree/output.c
  swinewm/tree/root.c
  swinewm/tree/titlebar.c
  swinewm/tree/view.c
  swinewm/tree/workspace.c
)
target_include_directories(swinewm_core PUBLIC ${SWINEWM_GENERATED_DIR})
target_link_libraries(swinewm_core PUBLIC swine_common)
if(NOT MSVC)
  target_link_libraries(swinewm_core PUBLIC m)
endif()

if(WIN32)
  option(MERAKI_QML "Build the Meraki QML shell layer" ON)
  if(MERAKI_QML)
    enable_language(CXX)
    set(CMAKE_AUTOMOC ON)
    find_package(Qt6 REQUIRED COMPONENTS Quick Shadertools)
  endif()
  enable_language(RC)
  set(SWINEWM_ICON ${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/swinewm.ico)
  configure_file(swinewm/win32/swinewm.rc.in
    ${SWINEWM_GENERATED_DIR}/swinewm.rc @ONLY)

  add_executable(swinewm
    ${SWINEWM_GENERATED_DIR}/swinewm.rc
    swinewm/main.c
    swinewm/win32/exec.c
    swinewm/win32/appbar.c
    swinewm/win32/audio.c
    swinewm/win32/bar.c
    swinewm/win32/canvas.c
    swinewm/win32/decor.c
    swinewm/win32/draw.c
    swinewm/win32/ipc.c
    swinewm/win32/keyboard.c
    swinewm/win32/layout.c
    swinewm/win32/mouse.c
    swinewm/win32/network.c
    swinewm/win32/notify.c
    swinewm/win32/output.c
    swinewm/win32/platform.c
    swinewm/win32/recover.c
    swinewm/win32/screenshot.c
    swinewm/win32/script.c
    swinewm/win32/shell.c
    swinewm/win32/slurp.c
    swinewm/win32/sysinfo.c
    swinewm/win32/swaynag.c
    swinewm/win32/theme.c
    swinewm/win32/titlebar.c
    swinewm/win32/toast.c
    swinewm/win32/tray.c
    swinewm/win32/util.c
    swinewm/win32/wallpaper.c
    swinewm/win32/watch.c
    swinewm/win32/window.c
  )
  # The user-facing binary is meraki.exe: the engine stays SwineWM inside,
  # but processes, shortcuts and the shell entry all show Meraki.
  set_target_properties(swinewm PROPERTIES OUTPUT_NAME meraki)
  target_compile_definitions(swinewm PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN
    WINVER=0x0A00 _WIN32_WINNT=0x0A00)
  target_link_libraries(swinewm PRIVATE swinewm_core user32 gdi32 dwmapi shell32
    shcore advapi32 ole32 propsys windowscodecs msimg32 uuid iphlpapi wlanapi
    pdh ws2_32 powrprof)

  if(MERAKI_QML)
    target_sources(swinewm PRIVATE
      swinewm/qmlbar/bridge.c
      swinewm/qmlbar/qmlbar.cpp
      swinewm/qmlbar/capture.cpp
      swinewm/qmlbar/media.cpp)
    set(MERAKI_QML_ROOT swinewm/qml)
    foreach(f Meraki/Main.qml Meraki/Bar.qml Meraki/Tray.qml Meraki/Workspaces.qml Meraki/Clock.qml
        Meraki/MinimizeFx.qml Meraki/glass/LiquidGlass.qml
        Meraki/glass/DockGlassPanel.qml Meraki/dock/Dock.qml
        Meraki/dock/DockIcon.qml Meraki/dock/DockTip.qml Meraki/dock/Preview.qml
        Meraki/dock/DockMenu.qml Meraki/center/Center.qml
        Meraki/apps/Launchpad.qml Meraki/widgets/Widgets.qml
        Meraki/widgets/ClockCard.qml Meraki/widgets/CalendarCard.qml
        Meraki/widgets/WeatherCard.qml Meraki/widgets/MediaCard.qml
        Meraki/widgets/WeatherGlyph.qml)
      set_source_files_properties(${MERAKI_QML_ROOT}/${f} PROPERTIES QT_RESOURCE_ALIAS ${f})
    endforeach()
    qt_add_resources(swinewm "meraki_qml" PREFIX "/qml" FILES
      ${MERAKI_QML_ROOT}/Meraki/Main.qml
      ${MERAKI_QML_ROOT}/Meraki/Bar.qml
      ${MERAKI_QML_ROOT}/Meraki/Tray.qml
      ${MERAKI_QML_ROOT}/Meraki/Workspaces.qml
      ${MERAKI_QML_ROOT}/Meraki/Clock.qml
      ${MERAKI_QML_ROOT}/Meraki/MinimizeFx.qml
      ${MERAKI_QML_ROOT}/Meraki/glass/LiquidGlass.qml
      ${MERAKI_QML_ROOT}/Meraki/glass/DockGlassPanel.qml
      ${MERAKI_QML_ROOT}/Meraki/dock/Dock.qml
      ${MERAKI_QML_ROOT}/Meraki/dock/DockIcon.qml
      ${MERAKI_QML_ROOT}/Meraki/dock/DockTip.qml
      ${MERAKI_QML_ROOT}/Meraki/dock/Preview.qml
      ${MERAKI_QML_ROOT}/Meraki/dock/DockMenu.qml
      ${MERAKI_QML_ROOT}/Meraki/center/Center.qml
      ${MERAKI_QML_ROOT}/Meraki/apps/Launchpad.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/Widgets.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/ClockCard.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/CalendarCard.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/WeatherCard.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/MediaCard.qml
      ${MERAKI_QML_ROOT}/Meraki/widgets/WeatherGlyph.qml)
    qt_add_shaders(swinewm "meraki_shaders" PREFIX "/shaders" FILES
      swinewm/qml/Meraki/shaders/liquidglass.frag
      swinewm/qml/Meraki/shaders/dockglass.frag)
    get_filename_component(_qt_prefix_dir ${Qt6_DIR}/../../.. ABSOLUTE)
    find_program(QSB_EXEC qsb HINTS ${QT6_INSTALL_BINS} ${_qt_prefix_dir}/bin)
    if(NOT QSB_EXEC)
      message(FATAL_ERROR "qsb not found")
    endif()
    set(GENIE_FRAG_QSB ${CMAKE_CURRENT_BINARY_DIR}/genie.frag.qsb)
    set(GENIE_VERT_QSB ${CMAKE_CURRENT_BINARY_DIR}/genie.vert.qsb)
    add_custom_command(OUTPUT ${GENIE_FRAG_QSB} ${GENIE_VERT_QSB}
      COMMAND ${QSB_EXEC} --qt6 -o ${GENIE_FRAG_QSB}
        ${CMAKE_CURRENT_SOURCE_DIR}/swinewm/qml/Meraki/shaders/genie.frag
      COMMAND ${QSB_EXEC} --qt6 -o ${GENIE_VERT_QSB}
        ${CMAKE_CURRENT_SOURCE_DIR}/swinewm/qml/Meraki/shaders/genie.vert
      DEPENDS swinewm/qml/Meraki/shaders/genie.frag
        swinewm/qml/Meraki/shaders/genie.vert
      VERBATIM)
    target_sources(swinewm PRIVATE ${GENIE_FRAG_QSB} ${GENIE_VERT_QSB})
    set_source_files_properties(${GENIE_FRAG_QSB} PROPERTIES
      QT_RESOURCE_ALIAS /shaders/genie.frag.qsb)
    set_source_files_properties(${GENIE_VERT_QSB} PROPERTIES
      QT_RESOURCE_ALIAS /shaders/genie.vert.qsb)
    qt_add_resources(swinewm "meraki_genie_shaders" PREFIX "/shaders" FILES
      ${GENIE_FRAG_QSB} ${GENIE_VERT_QSB})
    target_compile_definitions(swinewm PRIVATE MERAKI_QML)
    set_property(TARGET swinewm PROPERTY CXX_STANDARD 20)
    target_link_libraries(swinewm PRIVATE Qt6::Quick windowsapp)
  endif()

  # The bar's CSS engine and per-pixel alpha drawing, for wofi's style.css.
  add_executable(swinemenu WIN32 swinemenu/main.c swinemenu/apps.c
    swinemenu/openwith.c swinewm/bar/css.c swinewm/win32/canvas.c)
  target_compile_definitions(swinemenu PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN
    WINVER=0x0A00 _WIN32_WINNT=0x0A00)
  target_link_libraries(swinemenu PRIVATE swine_common user32 gdi32 shell32 ole32
    shlwapi uuid)
  target_include_directories(swinemenu PRIVATE ${SWINEWM_GENERATED_DIR})

  add_executable(swinemsg swinemsg/main.c)
  target_compile_definitions(swinemsg PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
  target_link_libraries(swinemsg PRIVATE swine_common)
  target_include_directories(swinemsg PRIVATE ${SWINEWM_GENERATED_DIR})

  add_executable(switcher WIN32 tools/switcher/main.c)
  target_compile_definitions(switcher PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
  target_link_libraries(switcher PRIVATE user32 gdi32 advapi32)

  # The front ends of the built-in Mako, named as on Linux so that scripts
  # and configs that call them keep working.
  foreach(tool notify-send makoctl)
    add_executable(${tool} ${tool}/main.c)
    target_compile_definitions(${tool} PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
    target_link_libraries(${tool} PRIVATE swine_common)
    target_include_directories(${tool} PRIVATE ${SWINEWM_GENERATED_DIR})
  endforeach()

  # Put the default config files next to the executable in the build tree
  # too, laid out as they are installed, so a build runs like an install.
  add_custom_target(swinewm_default_config ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${CMAKE_CURRENT_SOURCE_DIR}/config.in $<TARGET_FILE_DIR:swinewm>/config
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${CMAKE_CURRENT_SOURCE_DIR}/resources/waybar $<TARGET_FILE_DIR:swinewm>/waybar
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${CMAKE_CURRENT_SOURCE_DIR}/resources/mako $<TARGET_FILE_DIR:swinewm>/mako
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      ${CMAKE_CURRENT_SOURCE_DIR}/resources/wallpapers/swinewm-default.png
      $<TARGET_FILE_DIR:swinewm>/wallpapers/swinewm-default.png
    DEPENDS config.in)

  include(cmake/packaging.cmake)
endif()

if(SWINEWM_BUILD_TESTS)
  enable_testing()
  add_executable(swinewm_tests
    tests/fake_platform.c
    tests/test_main.c
    tests/test_commands.c
    tests/test_common.c
    tests/test_config.c
    tests/test_criteria.c
    tests/test_marks.c
    tests/test_outputs.c
    tests/test_cursor.c
    tests/test_decorations.c
    tests/test_tree.c
    tests/test_bar.c
    tests/test_notify.c
  )
  target_link_libraries(swinewm_tests PRIVATE swinewm_core)
  add_test(NAME swinewm_tests COMMAND swinewm_tests)
endif()
if(SWINEWM_BUILD_TESTS)
  target_compile_definitions(swinewm_tests PRIVATE
    SWINEWM_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
endif()
