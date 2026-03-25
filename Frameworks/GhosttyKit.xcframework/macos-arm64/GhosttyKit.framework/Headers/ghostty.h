#ifndef GHOSTTY_H
#define GHOSTTY_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Opaque types
typedef void* ghostty_app_t;
typedef void* ghostty_surface_t;
typedef void* ghostty_config_t;
typedef void* ghostty_inspector_t;

// Platform enum
typedef enum {
    GHOSTTY_PLATFORM_MACOS = 0,
    GHOSTTY_PLATFORM_IOS = 1,
} ghostty_platform_e;

// Surface context
typedef enum {
    GHOSTTY_SURFACE_CONTEXT_WINDOW = 0,
    GHOSTTY_SURFACE_CONTEXT_TAB = 1,
    GHOSTTY_SURFACE_CONTEXT_SPLIT = 2,
} ghostty_surface_context_e;

// Input action
typedef enum {
    GHOSTTY_KEY_PRESS = 0,
    GHOSTTY_KEY_RELEASE = 1,
    GHOSTTY_KEY_REPEAT = 2,
} ghostty_input_action_e;

// Input modifier flags
typedef enum {
    GHOSTTY_MOD_NONE    = 0,
    GHOSTTY_MOD_SHIFT   = 1 << 0,
    GHOSTTY_MOD_CTRL    = 1 << 1,
    GHOSTTY_MOD_ALT     = 1 << 2,
    GHOSTTY_MOD_SUPER   = 1 << 3,
    GHOSTTY_MOD_CAPS    = 1 << 4,
    GHOSTTY_MOD_NUM     = 1 << 5,
} ghostty_input_mods_e;

// Mouse button
typedef enum {
    GHOSTTY_MOUSE_BUTTON_LEFT = 0,
    GHOSTTY_MOUSE_BUTTON_RIGHT = 1,
    GHOSTTY_MOUSE_BUTTON_MIDDLE = 2,
    GHOSTTY_MOUSE_BUTTON_FOUR = 3,
    GHOSTTY_MOUSE_BUTTON_FIVE = 4,
} ghostty_input_mouse_button_e;

// Mouse state
typedef enum {
    GHOSTTY_MOUSE_RELEASE = 0,
    GHOSTTY_MOUSE_PRESS = 1,
} ghostty_input_mouse_state_e;

// Mouse momentum (for scroll)
typedef enum {
    GHOSTTY_MOUSE_MOMENTUM_NONE = 0,
    GHOSTTY_MOUSE_MOMENTUM_BEGAN = 1,
    GHOSTTY_MOUSE_MOMENTUM_STATIONARY = 2,
    GHOSTTY_MOUSE_MOMENTUM_CHANGED = 3,
    GHOSTTY_MOUSE_MOMENTUM_ENDED = 4,
    GHOSTTY_MOUSE_MOMENTUM_CANCELLED = 5,
    GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN = 6,
} ghostty_input_mouse_momentum_e;

// Clipboard type
typedef enum {
    GHOSTTY_CLIPBOARD_STANDARD = 0,
    GHOSTTY_CLIPBOARD_SELECTION = 1,
    GHOSTTY_CLIPBOARD_PRIMARY = 2,
} ghostty_clipboard_e;

// Color scheme
typedef enum {
    GHOSTTY_COLOR_SCHEME_LIGHT = 0,
    GHOSTTY_COLOR_SCHEME_DARK = 1,
} ghostty_color_scheme_e;

// Action tags (subset -- the most important ones)
typedef enum {
    GHOSTTY_ACTION_NEW_WINDOW = 0,
    GHOSTTY_ACTION_NEW_TAB = 1,
    GHOSTTY_ACTION_NEW_SPLIT = 2,
    GHOSTTY_ACTION_CLOSE_SURFACE = 3,
    GHOSTTY_ACTION_CLOSE_TAB = 4,
    GHOSTTY_ACTION_CLOSE_WINDOW = 5,
    GHOSTTY_ACTION_SET_TITLE = 10,
    GHOSTTY_ACTION_SET_WORKING_DIRECTORY = 11,
    GHOSTTY_ACTION_REPORT_CHILD_PID = 12,
    GHOSTTY_ACTION_OPEN_URL = 13,
    GHOSTTY_ACTION_BELL = 14,
    GHOSTTY_ACTION_COPY_TO_CLIPBOARD = 20,
    GHOSTTY_ACTION_PASTE_FROM_CLIPBOARD = 21,
    GHOSTTY_ACTION_SIZE_REPORT = 30,
    GHOSTTY_ACTION_COLOR_CHANGE = 31,
    GHOSTTY_ACTION_CELL_SIZE = 32,
    GHOSTTY_ACTION_RENDERER_HEALTH = 40,
    GHOSTTY_ACTION_QUIT = 50,
} ghostty_action_tag_e;

// Key input struct
typedef struct {
    ghostty_input_action_e action;
    ghostty_input_mods_e mods;
    ghostty_input_mods_e consumed_mods;
    uint32_t keycode;
    const char* text;
    size_t text_len;
    uint32_t unshifted_codepoint;
    bool composing;
} ghostty_input_key_s;

// Platform union
typedef struct {
    void* nsview;
    uint32_t display_id;
} ghostty_platform_macos_s;

typedef union {
    ghostty_platform_macos_s macos;
} ghostty_platform_u;

// Surface config
typedef struct {
    ghostty_platform_e platform_tag;
    ghostty_platform_u platform;
    void* userdata;
    double scale_factor;
    float font_size;
    const char* working_directory;
    const char* command;
    ghostty_surface_context_e context;
} ghostty_surface_config_s;

// Target (for action callbacks)
typedef struct {
    bool is_surface;
    ghostty_surface_t surface;
} ghostty_target_s;

// Set title action data
typedef struct {
    const char* title;
    size_t title_len;
} ghostty_action_set_title_s;

// Set working directory action data
typedef struct {
    const char* path;
    size_t path_len;
} ghostty_action_set_working_directory_s;

// Child PID report
typedef struct {
    int32_t pid;
} ghostty_action_child_pid_s;

// Action union (simplified -- real one has all action payloads)
typedef union {
    ghostty_action_set_title_s set_title;
    ghostty_action_set_working_directory_s set_working_directory;
    ghostty_action_child_pid_s child_pid;
    int32_t close_surface;
} ghostty_action_u;

// Action struct
typedef struct {
    ghostty_action_tag_e tag;
    ghostty_action_u action;
} ghostty_action_s;

// Clipboard content
typedef struct {
    const char* data;
    size_t len;
} ghostty_clipboard_content_s;

// Text result
typedef struct {
    const char* data;
    size_t len;
} ghostty_text_s;

// Callback typedefs
typedef void (*ghostty_runtime_wakeup_cb)(void* userdata);
typedef bool (*ghostty_runtime_action_cb)(
    ghostty_app_t app,
    ghostty_target_s target,
    ghostty_action_s action,
    void* userdata
);
typedef void (*ghostty_runtime_read_clipboard_cb)(
    void* userdata,
    ghostty_clipboard_e clipboard_type,
    void* context
);
typedef void (*ghostty_runtime_confirm_read_clipboard_cb)(
    void* userdata,
    const char* content,
    size_t len,
    void* context
);
typedef void (*ghostty_runtime_write_clipboard_cb)(
    void* userdata,
    ghostty_clipboard_e clipboard_type,
    const ghostty_clipboard_content_s* content,
    size_t count,
    bool clear
);
typedef void (*ghostty_runtime_close_surface_cb)(
    void* userdata,
    bool force_close
);

// Runtime config
typedef struct {
    void* userdata;
    bool supports_selection_clipboard;
    ghostty_runtime_wakeup_cb wakeup_cb;
    ghostty_runtime_action_cb action_cb;
    ghostty_runtime_read_clipboard_cb read_clipboard_cb;
    ghostty_runtime_confirm_read_clipboard_cb confirm_read_clipboard_cb;
    ghostty_runtime_write_clipboard_cb write_clipboard_cb;
    ghostty_runtime_close_surface_cb close_surface_cb;
} ghostty_runtime_config_s;

// ============ API Functions ============

// Global init
void ghostty_init(int argc, const char** argv);

// Config
ghostty_config_t ghostty_config_new(void);
void ghostty_config_free(ghostty_config_t config);
ghostty_config_t ghostty_config_clone(ghostty_config_t config);
void ghostty_config_load_default_files(ghostty_config_t config);
void ghostty_config_finalize(ghostty_config_t config);
bool ghostty_config_set(ghostty_config_t config, const char* key, size_t key_len, const char* value, size_t value_len);

// App
ghostty_app_t ghostty_app_new(const ghostty_runtime_config_s* runtime, ghostty_config_t config);
void ghostty_app_free(ghostty_app_t app);
void ghostty_app_tick(ghostty_app_t app);
void ghostty_app_set_focus(ghostty_app_t app, bool focused);
void ghostty_app_update_config(ghostty_app_t app, ghostty_config_t config);
void ghostty_app_set_color_scheme(ghostty_app_t app, ghostty_color_scheme_e scheme);

// Surface
ghostty_surface_t ghostty_surface_new(ghostty_app_t app, const ghostty_surface_config_s* config);
void ghostty_surface_free(ghostty_surface_t surface);
void ghostty_surface_draw(ghostty_surface_t surface);
void ghostty_surface_refresh(ghostty_surface_t surface);
void ghostty_surface_set_size(ghostty_surface_t surface, uint32_t width, uint32_t height);
void ghostty_surface_set_content_scale(ghostty_surface_t surface, double x_scale, double y_scale);
void ghostty_surface_set_focus(ghostty_surface_t surface, bool focused);
void ghostty_surface_set_occlusion(ghostty_surface_t surface, bool occluded);

// Surface input
bool ghostty_surface_key(ghostty_surface_t surface, ghostty_input_key_s event);
void ghostty_surface_text(ghostty_surface_t surface, const char* text, size_t len);
bool ghostty_surface_mouse_button(
    ghostty_surface_t surface,
    ghostty_input_mouse_state_e state,
    ghostty_input_mouse_button_e button,
    ghostty_input_mods_e mods
);
void ghostty_surface_mouse_pos(
    ghostty_surface_t surface,
    double x, double y,
    ghostty_input_mods_e mods
);
void ghostty_surface_mouse_scroll(
    ghostty_surface_t surface,
    double dx, double dy,
    ghostty_input_mods_e mods,
    ghostty_input_mouse_momentum_e momentum
);

// Surface selection/text
ghostty_text_s ghostty_surface_selection(ghostty_surface_t surface);

// Surface clipboard
void ghostty_surface_complete_clipboard_request(
    ghostty_surface_t surface,
    const char* data,
    size_t len,
    void* context
);

#endif // GHOSTTY_H
