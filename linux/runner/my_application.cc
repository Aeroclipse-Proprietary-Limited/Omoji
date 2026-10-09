#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gboolean window_focus_in_cb(GtkWidget* widget, GdkEventFocus* event, gpointer user_data) {
  if (!gtk_window_get_accept_focus(GTK_WINDOW(widget))) {
    return TRUE; // Block GTK window focus acquisition in overlay mode!
  }
  return FALSE;
}

static void window_control_method_call_cb(FlMethodChannel* channel,
                                           FlMethodCall* method_call,
                                           gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "showOverlay") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    double x = 100, y = 100, width = 440, height = 60;
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* x_val = fl_value_lookup_string(args, "x");
      FlValue* y_val = fl_value_lookup_string(args, "y");
      FlValue* w_val = fl_value_lookup_string(args, "width");
      FlValue* h_val = fl_value_lookup_string(args, "height");
      if (x_val) x = fl_value_get_float(x_val);
      if (y_val) y = fl_value_get_float(y_val);
      if (w_val) width = fl_value_get_float(w_val);
      if (h_val) height = fl_value_get_float(h_val);
    }

    gtk_window_set_accept_focus(window, FALSE);
    gtk_window_set_focus_on_map(window, FALSE);
    gtk_widget_set_can_focus(GTK_WIDGET(window), FALSE);

    gtk_window_set_keep_above(window, TRUE);
    gtk_window_set_skip_taskbar_hint(window, TRUE);
    gtk_window_set_skip_pager_hint(window, TRUE);

    gtk_window_move(window, (gint)x, (gint)y);
    gtk_window_resize(window, (gint)width, (gint)height);
    gtk_widget_set_opacity(GTK_WIDGET(window), 1.0);
    gtk_widget_show(GTK_WIDGET(window));

    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(TRUE)));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  if (g_strcmp0(method, "hideOverlay") == 0) {
    gtk_widget_set_opacity(GTK_WIDGET(window), 0.0);
    gtk_window_move(window, -9999, -9999);
    gtk_window_set_skip_taskbar_hint(window, FALSE);
    gtk_window_set_keep_above(window, FALSE);
    gtk_window_set_accept_focus(window, TRUE);
    gtk_window_set_focus_on_map(window, TRUE);
    gtk_widget_set_can_focus(GTK_WIDGET(window), TRUE);

    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_bool(TRUE)));
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
      fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void set_window_app_icon(GtkWindow* window) {
  const char* possible_paths[] = {
    "data/flutter_assets/lib/assets/imgs/app-logo.png",
    "lib/assets/imgs/app-logo.png",
    "data/flutter_assets/lib/assets/imgs/app-logo.jpg",
    "lib/assets/imgs/app-logo.jpg",
    "/usr/share/pixmaps/omoji.png",
    "/usr/share/pixmaps/omoji.jpg",
    "/usr/share/icons/hicolor/256x256/apps/omoji.png",
    NULL
  };

  GdkPixbuf* pixbuf = NULL;
  for (int i = 0; possible_paths[i] != NULL; i++) {
    if (g_file_test(possible_paths[i], G_FILE_TEST_EXISTS)) {
      pixbuf = gdk_pixbuf_new_from_file(possible_paths[i], NULL);
      if (pixbuf) break;
    }
  }

  if (!pixbuf) {
    g_autofree char* user_icon = g_build_filename(g_get_user_data_dir(), "pixmaps", "omoji.png", NULL);
    if (g_file_test(user_icon, G_FILE_TEST_EXISTS)) {
      pixbuf = gdk_pixbuf_new_from_file(user_icon, NULL);
    }
  }

  if (!pixbuf) {
    g_autofree char* user_icon_jpg = g_build_filename(g_get_user_data_dir(), "pixmaps", "omoji.jpg", NULL);
    if (g_file_test(user_icon_jpg, G_FILE_TEST_EXISTS)) {
      pixbuf = gdk_pixbuf_new_from_file(user_icon_jpg, NULL);
    }
  }

  if (pixbuf) {
    gtk_window_set_icon(window, pixbuf);
    gtk_window_set_default_icon(pixbuf);
    g_object_unref(pixbuf);
  } else {
    gtk_window_set_icon_name(window, "omoji");
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  g_signal_connect(window, "focus-in-event", G_CALLBACK(window_focus_in_cb), NULL);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;

  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != NULL) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
  }
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);

#ifdef GDK_WINDOWING_X11
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "omoji");
    gtk_header_bar_set_show_close_button(header_bar, FALSE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "omoji");
  }

  set_window_app_icon(window);
  gtk_window_set_default_size(window, 420, 540);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.aeroclipse.omoji/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, window_control_method_call_cb, window, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname("com.aeroclipse.omoji");

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", "com.aeroclipse.omoji", "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
