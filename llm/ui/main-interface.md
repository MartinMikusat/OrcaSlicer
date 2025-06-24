# UI Components and Interactions

## Overview

OrcaSlicer's user interface is built on wxWidgets with extensive OpenGL integration for 3D visualization. The system follows a Model-View-Controller architecture with sophisticated event handling, custom widgets, and real-time 3D interaction capabilities.

## Main Window Architecture

### GUI Application Foundation
Implementation: `src/slic3r/GUI/GUI_App.cpp`

```cpp
class GUI_App : public wxApp {
public:
    enum class EAppMode {
        Editor,
        GCodeViewer
    };
    
    // Application lifecycle
    bool OnInit() override;
    int OnExit() override;
    void OnFatalException() override;
    
    // Core components
    MainFrame* mainframe;
    Plater* plater() { return mainframe ? mainframe->plater() : nullptr; }
    TabManager* tabs() { return mainframe ? mainframe->tabs() : nullptr; }
    
    // Configuration and presets
    PresetBundle* preset_bundle;
    PresetUpdater* preset_updater;
    AppConfig* app_config;
    
    // Mode management
    void set_app_mode(EAppMode mode);
    EAppMode get_app_mode() const { return m_app_mode; }
    
    // Event handling
    void post_init();
    void check_updates(const bool verbose = false);
    void persist_window_geometry(wxTopLevelWindow *window, bool default_maximized = false);
    void update_ui_from_settings();
    
private:
    EAppMode m_app_mode = EAppMode::Editor;
    std::unique_ptr<RemovableDriveManager> m_removable_drive_manager;
    std::unique_ptr<UndoRedo::Stack> m_undo_redo_stack;
    
    // Initialization phases
    void init_app_config();
    void init_single_instance_checker();
    void init_http_extra_certs();
    void init_params();
    void init_fonts();
    void init_opengl();
    void init_app_menu();
};
```

### Main Window Structure
Implementation: `src/slic3r/GUI/MainFrame.cpp`

```cpp
class MainFrame : public DPIFrame {
public:
    enum {
        // Menu IDs
        wxID_FILE_NEW_PROJECT = 1000,
        wxID_FILE_OPEN_PROJECT,
        wxID_FILE_SAVE_PROJECT,
        wxID_FILE_SAVE_PROJECT_AS,
        wxID_FILE_IMPORT_STL,
        wxID_FILE_IMPORT_3MF,
        wxID_FILE_EXPORT_GCODE,
        wxID_FILE_EXPORT_STL,
        // ... more menu IDs
    };
    
    // Core UI components
    wxNotebook* m_tabpanel;
    Plater* m_plater;
    TabManager* m_tabs;
    
    // Status and progress
    ProgressStatusBar* m_statusbar;
    std::shared_ptr<ProgressIndicator> m_progress_indicator;
    
    // Construction
    MainFrame();
    ~MainFrame();
    
    // Interface management
    void create_preset_tabs();
    void add_created_tab(Tab* panel, const std::string& bmp_name = "");
    void init_tabpanel();
    void init_menubar();
    void init_notification_manager();
    
    // Event handlers
    void on_dpi_changed(const wxRect& suggested_rect) override;
    void on_sys_color_changed() override;
    void on_config_changed(AppConfig* config) const;
    
    // File operations
    void quick_slice(const int qs = qsUndef);
    void reslice_now();
    void repair_stl();
    void export_config();
    void load_config_file();
    void export_configbundle();
    void load_configbundle();
    
private:
    // Menu management
    wxMenuBar* m_menubar;
    wxMenu* m_fileMenu;
    wxMenu* m_editMenu;
    wxMenu* m_windowMenu;
    wxMenu* m_viewMenu;
    wxMenu* m_helpMenu;
    
    // Window state
    wxSize m_last_size;
    bool m_layout_changed = false;
    
    void init_menu_item(wxMenu* menu, int id, const wxString& string, 
                       const wxString& tooltip, std::function<void()> cb,
                       const wxString& icon = "", bool is_checkable = false);
};
```

## Plater and 3D Scene Management

### Plater Core System
Implementation: `src/slic3r/GUI/Plater.cpp`

```cpp
class Plater : public wxPanel {
public:
    struct priv;  // PIMPL pattern for implementation details
    
    // Core functionality
    Plater(wxWindow *parent, MainFrame *main_frame);
    ~Plater();
    
    // Model management
    void add_model(bool imperial_units = false);
    void add_model_from_gallery();
    void import_sl1_archive();
    void load_project();
    void add_file();
    void load_files(const wxArrayString& filenames, bool delete_after_load = false);
    
    // Scene operations
    void select_all();
    void deselect_all();
    void remove_selected();
    void increase_instances(size_t num = 1);
    void decrease_instances(size_t num = 1);
    void set_number_of_copies(size_t num);
    void fill_bed_with_instances();
    
    // View and interaction
    void select_view(const std::string& direction);
    void set_camera_zoom(double zoom);
    void zoom_to_bed();
    void zoom_to_selection();
    void zoom_to_all_objects();
    
    // Processing
    void reslice();
    void send_gcode();
    void eject_drive();
    
    // State management
    bool is_project_dirty() const;
    bool is_presets_dirty() const;
    void update_ui_from_settings();
    void update_object_menu();
    
    // Access to components
    Sidebar& sidebar();
    Model& model();
    const Print& fff_print() const;
    Print& fff_print();
    GLCanvas3D* canvas3D();
    
private:
    std::unique_ptr<priv> p;
};

// Internal implementation details
struct Plater::priv {
    // Core components
    Plater *q;
    MainFrame *main_frame;
    
    // UI panels
    wxPanel *panel;
    wxSplitterWindow *splitter;
    Sidebar *sidebar;
    GLCanvas3D *view3D;
    
    // Background processing
    BackgroundSlicingProcess background_process;
    bool suppressed_backround_processing_update;
    
    // Model and state
    Model model;
    Print fff_print;
    SLAPrint sla_print;
    
    // Selection and manipulation
    Selection selection;
    GLGizmosManager gizmos;
    
    // Event handling
    void on_process_completed(SlicingProcessCompletedEvent &evt);
    void on_layer_editing_toggled(bool enable);
    void on_slicing_update(SlicingStatusEvent &evt);
    void on_action_add(SimpleEvent&);
    void on_action_split_objects(SimpleEvent&);
    void on_action_split_volumes(SimpleEvent&);
    void on_action_layersediting(SimpleEvent&);
    
    // Model operations
    void reload_from_disk();
    void reload_all_from_disk();
    void fix_through_winsdk();
    void set_bed_shape();
    void find_new_position(const ModelInstancePtrs &instances);
    
    // View operations
    void reset_gcode_toolpaths();
    void update_fff_scene();
    void update_sla_scene();
    void render();
};
```

### 3D Canvas and OpenGL Integration
Implementation: `src/slic3r/GUI/GLCanvas3D.cpp`

```cpp
class GLCanvas3D {
public:
    struct Camera {
        enum EType : unsigned char {
            Unknown,
            Perspective,
            Ortho
        };
        
        // Camera state
        EType type;
        Vec3d target;
        float theta;  // Rotation around Z axis
        float phi;    // Rotation around X axis
        float distance; // Distance from target
        float zoom;
        
        // Projection matrices
        void apply_view_matrix() const;
        void apply_projection(const BoundingBoxf3& box, double near_z, double far_z) const;
        
        // Interaction
        void rotate_on_sphere(double delta_x, double delta_y);
        void pan(double delta_x, double delta_y);
        void zoom_in(double factor);
        void zoom_out(double factor);
        
        // Utilities
        Vec3d get_position() const;
        Vec3d get_dir_forward() const;
        Vec3d get_dir_right() const;
        Vec3d get_dir_up() const;
    };
    
    struct Selection {
        enum EMode : unsigned char {
            Volume,
            Instance
        };
        
        // Selection state
        EMode mode;
        Model* model;
        std::set<unsigned int> volumes_idxs;
        std::set<unsigned int> instances_idxs;
        
        // Selection management
        void add(unsigned int volume_idx, bool as_single_selection = true);
        void remove(unsigned int volume_idx);
        void add_instance(unsigned int object_idx, unsigned int instance_idx, 
                         bool as_single_selection = true);
        void remove_instance(unsigned int object_idx, unsigned int instance_idx);
        void add_volume(unsigned int object_idx, unsigned int volume_idx, 
                       int instance_idx, bool as_single_selection = true);
        void remove_volume(unsigned int object_idx, unsigned int volume_idx);
        
        // Queries
        bool is_empty() const;
        bool is_single_full_instance() const;
        bool is_multiple_full_instance() const;
        bool is_single_volume() const;
        bool is_single_modifier() const;
        bool is_single_full_object() const;
        bool contains_volume(unsigned int volume_idx) const;
        
        // Transformations
        void translate(const Vec3d& displacement);
        void rotate(const Vec3d& rotation, TransformationType transformation_type);
        void scale(const Vec3d& scale, TransformationType transformation_type);
        void mirror(Axis axis);
        
        // Geometry
        BoundingBoxf3 get_bounding_box() const;
        Vec3d get_center() const;
        const GLVolume* get_volume(unsigned int volume_idx) const;
    };
    
    // Construction and lifecycle
    GLCanvas3D(wxGLCanvas* canvas, Bed3D& bed);
    ~GLCanvas3D();
    
    // Rendering
    void render();
    void reload_scene(bool refresh_immediately, bool force_full_scene_refresh = false);
    void load_gcode_preview(const GCodeProcessor::Result& gcode_result, 
                           const std::vector<std::string>& str_tool_colors);
    
    // Interaction
    bool is_layers_editing_enabled() const;
    bool is_layers_editing_allowed() const;
    void enable_layers_editing(bool enable);
    void enable_legend_texture(bool enable);
    void enable_picking(bool enable);
    void enable_moving(bool enable);
    void enable_gizmos(bool enable);
    void enable_selection(bool enable);
    void enable_main_toolbar(bool enable);
    void enable_undoredo_toolbar(bool enable);
    
    // Camera and view
    void zoom_to_bed();
    void zoom_to_selection();
    void zoom_to_all_objects();
    void zoom_to_volumes(const std::vector<int>& volumes_idxs);
    void select_view(const std::string& direction);
    void set_camera_zoom(double zoom);
    
    // Events
    void on_mouse(wxMouseEvent& evt);
    void on_key(wxKeyEvent& evt);
    void on_char(wxKeyEvent& evt);
    void on_timer(wxTimerEvent& evt);
    void on_render_timer(wxTimerEvent& evt);
    void on_idle(wxIdleEvent& evt);
    void on_size(wxSizeEvent& evt);
    
private:
    // Rendering components
    struct LegendTexture;
    struct WarningTexture;
    struct Tooltip;
    
    wxGLCanvas* m_canvas;
    wxGLContext* m_context;
    
    // Scene components
    Camera m_camera;
    Selection m_selection;
    Bed3D& m_bed;
    GLToolbar m_main_toolbar;
    GLToolbar m_undoredo_toolbar;
    ClippingPlane m_clipping_planes[2];
    mutable GLVolumeCollection m_volumes;
    GCodeViewer m_gcode_viewer;
    
    // Interaction state
    bool m_initialized;
    bool m_apply_zoom_to_volumes_filter;
    bool m_picking_enabled;
    bool m_moving_enabled;
    bool m_dynamic_background_enabled;
    bool m_multisample_allowed;
    
    // Mouse and keyboard interaction
    struct Mouse {
        struct Drag {
            static const Point Invalid_2D_Point;
            static const Vec3d Invalid_3D_Point;
            
            Point start_position_2D;
            Vec3d start_position_3D;
            int volume_idx;
        };
        
        bool dragging;
        Vec2d position;
        Drag drag;
        
        void set_start_position_2D_as_invalid() { drag.start_position_2D = Invalid_2D_Point; }
        void set_start_position_3D_as_invalid() { drag.start_position_3D = Invalid_3D_Point; }
        bool is_start_position_2D_defined() const { return drag.start_position_2D != Invalid_2D_Point; }
        bool is_start_position_3D_defined() const { return drag.start_position_3D != Invalid_3D_Point; }
    };
    Mouse m_mouse;
    
    // Rendering implementation
    void _render_background() const;
    void _render_bed(bool bottom) const;
    void _render_objects() const;
    void _render_selection() const;
    void _render_sequential_clearance() const;
    void _render_gcode() const;
    void _render_selection_sidebar_hints() const;
    void _render_current_gizmo() const;
    
    // Picking and hit testing
    std::vector<unsigned int> _render_objects_for_picking() const;
    void _render_volumes_for_picking() const;
    void _render_bed_for_picking(bool bottom) const;
    bool _picking_checksum() const;
    
    // Event handling implementation
    void _on_select(int volume_idx);
    void _on_double_click(int volume_idx);
    void _on_right_click(int volume_idx);
    void _on_drag(int volume_idx);
    void _on_move(int volume_idx);
};
```

## Gizmos System for 3D Manipulation

### Gizmo Manager
Implementation: `src/slic3r/GUI/Gizmos/GLGizmosManager.cpp`

```cpp
class GLGizmosManager {
public:
    enum EType : unsigned char {
        Undefined,
        Move,
        Scale,
        Rotate,
        Flatten,
        Cut,
        Hollow,
        SlaSupports,
        FdmSupports,
        Seam,
        MmuSegmentation,
        Simplify,
        Text,
        Svg,
        Emboss,
        CameraControl,
        
        Count
    };
    
    struct Layout {
        float scale;
        float icons_size;
        float border;
        float gap_y;
        float stride_y;
        float left, top, right, bottom;
    };
    
    // Construction
    GLGizmosManager(GLCanvas3D& parent);
    ~GLGizmosManager();
    
    // Gizmo management
    bool init();
    void set_enabled(bool enable);
    void set_overlay_icon_size(float size);
    void set_overlay_scale(float scale);
    void refresh_on_off_state();
    void reset_all_states();
    
    // Current gizmo
    void open_gizmo(EType type);
    void close_gizmo();
    bool is_running() const;
    bool handle_shortcut(int key);
    
    // Rendering
    void render_overlay();
    void render_current_gizmo();
    void render_current_gizmo_for_picking_pass();
    
    // Event handling
    bool on_mouse(const wxMouseEvent& evt);
    bool on_char(const wxKeyEvent& evt);
    bool on_key(const wxKeyEvent& evt);
    void update_after_undo_redo(const UndoRedo::Snapshot& snapshot);
    
private:
    GLCanvas3D& m_parent;
    bool m_enabled;
    std::vector<std::unique_ptr<GLGizmoBase>> m_gizmos;
    EType m_current;
    Layout m_layout;
    
    // Gizmo creation
    void generate_icons_texture();
    void create_gizmo(EType type);
    GLGizmoBase* get_gizmo(EType type) const;
};

// Base gizmo class
class GLGizmoBase {
public:
    // Gizmo states
    enum EState {
        Off,
        On,
        Num_States
    };
    
    struct Grabber {
        static const float SizeFactor;
        static const float MinHalfSize;
        static const float DraggingScaleFactor;
        
        Vec3d center;
        Vec3d angles;
        ColorRGBA color;
        bool enabled;
        bool dragging;
        
        void render(float size, const ColorRGBA& render_color) const;
        void render_for_picking(float size) const;
    };
    
    // Construction
    GLGizmoBase(GLCanvas3D& parent, const std::string& icon_filename, unsigned int sprite_id);
    virtual ~GLGizmoBase() = default;
    
    // State management
    EState get_state() const { return m_state; }
    void set_state(EState state) { m_state = state; on_set_state(); }
    void set_hover_id(int id);
    
    // Interaction
    bool is_activable() const;
    bool is_selectable() const;
    unsigned int get_sprite_id() const { return m_sprite_id; }
    int get_hover_id() const { return m_hover_id; }
    void set_highlight_color(const ColorRGBA& color);
    
    // Event handling
    void start_dragging();
    void stop_dragging();
    bool is_dragging() const { return m_dragging; }
    void update(const UpdateData& data);
    void render();
    void render_for_picking();
    virtual void render_input_window(float x, float y, float bottom_limit) {}
    
protected:
    GLCanvas3D& m_parent;
    int m_group_id;
    EState m_state;
    int m_shortcut_key;
    std::string m_icon_filename;
    unsigned int m_sprite_id;
    int m_hover_id;
    bool m_dragging;
    std::vector<Grabber> m_grabbers;
    
    // Virtual interface
    virtual bool on_init() = 0;
    virtual void on_set_state() {}
    virtual void on_set_hover_id() {}
    virtual void on_enable_grabber(unsigned int id) {}
    virtual void on_disable_grabber(unsigned int id) {}
    virtual void on_start_dragging() {}
    virtual void on_stop_dragging() {}
    virtual void on_dragging(const UpdateData& data) {}
    virtual void on_render() = 0;
    virtual void on_render_for_picking() = 0;
    virtual void on_render_input_window(float x, float y, float bottom_limit) {}
    
    // Utility methods
    void render_grabbers(const BoundingBoxf3& box) const;
    void render_grabbers_for_picking(const BoundingBoxf3& box) const;
    std::string format(float value, unsigned int decimals) const;
    void set_tooltip(const std::string& tooltip) const;
};

// Move gizmo implementation
class GLGizmoMove3D : public GLGizmoBase {
    Vec3d m_displacement;
    double m_snap_step;
    Vec3d m_starting_drag_position;
    Vec3d m_starting_box_center;
    Vec3d m_starting_box_bottom_center;
    
public:
    GLGizmoMove3D(GLCanvas3D& parent, const std::string& icon_filename, unsigned int sprite_id);
    
    double get_snap_step(double step) const { return m_snap_step; }
    void set_snap_step(double step) { m_snap_step = step; }
    const Vec3d& get_displacement() const { return m_displacement; }
    
protected:
    bool on_init() override;
    void on_start_dragging() override;
    void on_dragging(const UpdateData& data) override;
    void on_render() override;
    void on_render_for_picking() override;
    void on_render_input_window(float x, float y, float bottom_limit) override;
    
private:
    double calc_projection(const UpdateData& data) const;
    void render_grabber_extension(Axis axis, const BoundingBoxf3& box, bool picking) const;
};
```

## Configuration Tabs and Panels

### Tab Management System
Implementation: `src/slic3r/GUI/Tab.cpp`

```cpp
class Tab : public wxPanel {
public:
    enum PageType { ptPrint, ptFilament, ptPrinter };
    
    // Core properties
    PageType m_type;
    PresetBundle* m_preset_bundle;
    PresetCollection* m_presets;
    DynamicPrintConfig* m_config;
    
    // UI components
    wxChoice* m_presets_choice;
    ScalableButton* m_btn_save_preset;
    ScalableButton* m_btn_delete_preset;
    wxBitmapButton* m_btn_hide_incompatible_presets;
    wxBoxSizer* m_hsizer;
    wxBoxSizer* m_left_sizer;
    wxTreeCtrl* m_treectrl;
    wxImageList* m_icons;
    
    // Page management
    std::vector<wxScrolledWindow*> m_pages;
    std::vector<ConfigOptionsGroup*> m_optgroups;
    
    // Construction
    Tab(wxBookCtrlBase* parent, const wxString& title, Preset::Type type);
    virtual ~Tab() = default;
    
    // Configuration management
    void create_preset_tab();
    void load_current_preset();
    void save_preset(std::string name = "", bool detach = false);
    void delete_preset();
    void toggle_show_hide_incompatible();
    void update_tab_ui();
    void update_ui_from_settings();
    void clear_pages();
    
    // Event handling
    void on_presets_changed();
    void on_preset_loaded();
    void on_value_change(const std::string& opt_key, const boost::any& value);
    void update_changed_ui();
    void update_visibility();
    
    // Page construction
    wxScrolledWindow* add_options_page(const wxString& title, const std::string& icon, 
                                      bool is_extruder_pages = false);
    ConfigOptionsGroup* new_optgroup(const wxString& title, int noncommon_label_width = -1);
    
protected:
    // Virtual interface
    virtual void build() = 0;
    virtual void build_preset_description_line(ConfigOptionsGroup* optgroup) = 0;
    virtual void update_description_lines() = 0;
    virtual void toggle_options() = 0;
    
    // Preset operations
    void select_preset(std::string preset_name, bool delete_current = false);
    bool may_discard_current_dirty_preset();
    void on_option_changed(const std::string& opt_key);
    void changed_value(const std::string& opt_key, const boost::any& value);
    
private:
    // UI state
    bool m_is_modified_values;
    bool m_is_nonsys_values;
    bool m_postpone_update_ui;
    std::map<std::string, wxColour> m_colored_Label_colors;
    std::map<std::string, bool> m_options_list;
};

// Configuration options group
class ConfigOptionsGroup {
public:
    // Construction
    ConfigOptionsGroup(wxWindow* parent, const wxString& title, 
                      DynamicPrintConfig* config, bool is_tab_opt = true,
                      int extra_column = -1);
    ~ConfigOptionsGroup() = default;
    
    // Option management
    Line append_single_option_line(const Option& option, const wxString& path = wxEmptyString);
    Line append_single_option_line(const std::string& opt_key, const wxString& path = wxEmptyString);
    void append_line(const Line& line, const wxString& path = wxEmptyString);
    void append_separator();
    
    // Layout and display
    wxSizer* get_sizer() { return sizer; }
    wxStaticText* get_title() { return m_title; }
    void set_grid_vgap(int gap) { m_grid_sizer->SetVGap(gap); }
    void show_field(const std::string& opt_key, bool show = true);
    void hide_field(const std::string& opt_key) { show_field(opt_key, false); }
    void set_name(const wxString& new_name);
    
    // Value management
    void set_value(const std::string& opt_key, const boost::any& value, bool change_event = false);
    boost::any get_value(const std::string& opt_key);
    void enable_field(const std::string& opt_key, bool enable = true);
    void disable_field(const std::string& opt_key) { enable_field(opt_key, false); }
    
    // Event handling
    void register_on_change(std::function<void()> cb) { m_on_change = cb; }
    void reload_config();
    void Hide();
    void Show(const bool show);
    bool IsShown() { return sizer->IsShown(m_grid_sizer); }
    
private:
    // UI components
    wxStaticText* m_title {nullptr};
    wxStaticText* m_extra_column_item_ptrs {nullptr};
    wxFlexGridSizer* m_grid_sizer {nullptr};
    wxBoxSizer* sizer {nullptr};
    
    // Configuration
    DynamicPrintConfig* m_config {nullptr};
    bool m_use_custom_ctrl {false};
    
    // Fields and options
    std::map<std::string, Option> m_options;
    std::map<std::string, Field*> m_fields;
    std::function<void()> m_on_change {nullptr};
    
    // Field creation
    void create_line(const Line& line, const wxString* path = nullptr);
    void create_widget(wxWindow* parent, const Line& line);
    Field* create_field(const Option& option, wxWindow* parent = nullptr);
};
```

## Custom Widgets and Controls

### Specialized Widget Implementations
Implementation: `src/slic3r/GUI/Widgets/`

```cpp
// AMS Control Widget
class AMSControl : public wxPanel {
public:
    struct Filament {
        std::string material_name;
        std::string color;
        int temperature;
        bool is_loaded;
        float remaining_percentage;
    };
    
    struct AMS {
        int id;
        bool is_connected;
        std::vector<Filament> filaments;
        int active_filament_index;
    };
    
    // Construction
    AMSControl(wxWindow* parent);
    ~AMSControl();
    
    // AMS management
    void add_ams(const AMS& ams);
    void remove_ams(int ams_id);
    void update_ams_status(int ams_id, const AMS& ams);
    void set_active_ams(int ams_id);
    
    // Filament operations
    void load_filament(int ams_id, int slot);
    void unload_filament(int ams_id, int slot);
    void change_filament(int ams_id, int from_slot, int to_slot);
    
    // Visual updates
    void refresh_display();
    void set_printer_connection_status(bool connected);
    
protected:
    // Event handling
    void OnPaint(wxPaintEvent& event);
    void OnMouseMove(wxMouseEvent& event);
    void OnLeftClick(wxMouseEvent& event);
    void OnRightClick(wxMouseEvent& event);
    void OnSize(wxSizeEvent& event);
    
private:
    std::vector<AMS> m_ams_units;
    int m_active_ams_id;
    bool m_printer_connected;
    
    // Rendering
    void draw_ams_unit(wxDC& dc, const AMS& ams, const wxRect& rect);
    void draw_filament_slot(wxDC& dc, const Filament& filament, const wxRect& rect);
    void draw_connection_status(wxDC& dc, const wxRect& rect);
    
    // Hit testing
    int hit_test_ams(const wxPoint& point);
    int hit_test_filament_slot(int ams_id, const wxPoint& point);
    
    // Layout
    wxRect get_ams_rect(int ams_id) const;
    wxRect get_filament_rect(int ams_id, int slot) const;
};

// Fan Control Widget
class FanControl : public wxPanel {
public:
    enum FanType {
        PART_FAN,
        HOTEND_FAN,
        CHAMBER_FAN
    };
    
    struct FanState {
        FanType type;
        int speed_percentage;  // 0-100
        int target_speed;
        bool is_auto;
        bool is_enabled;
        int rpm;               // Actual RPM if available
    };
    
    // Construction
    FanControl(wxWindow* parent, FanType type);
    ~FanControl();
    
    // Fan control
    void set_fan_speed(int percentage);
    void set_auto_mode(bool auto_mode);
    void enable_fan(bool enable);
    void update_fan_state(const FanState& state);
    
    // Events
    wxDECLARE_EVENT(EVT_FAN_SPEED_CHANGED, wxCommandEvent);
    wxDECLARE_EVENT(EVT_FAN_AUTO_TOGGLED, wxCommandEvent);
    
protected:
    void OnPaint(wxPaintEvent& event);
    void OnMouseMove(wxMouseEvent& event);
    void OnLeftDown(wxMouseEvent& event);
    void OnLeftUp(wxMouseEvent& event);
    void OnMouseWheel(wxMouseEvent& event);
    
private:
    FanType m_fan_type;
    FanState m_current_state;
    bool m_dragging;
    wxPoint m_drag_start;
    
    // Visual components
    void draw_fan_dial(wxDC& dc, const wxRect& rect);
    void draw_speed_indicator(wxDC& dc, const wxRect& rect);
    void draw_labels(wxDC& dc, const wxRect& rect);
    
    // Interaction
    int angle_to_speed(double angle) const;
    double speed_to_angle(int speed) const;
    double point_to_angle(const wxPoint& point, const wxPoint& center) const;
};

// Scalable Button
class ScalableButton : public wxButton {
public:
    ScalableButton(wxWindow* parent, wxWindowID id, const std::string& icon_name = "",
                  const wxString& label = wxEmptyString, const wxSize& size = wxDefaultSize,
                  const wxPoint& pos = wxDefaultPosition, long style = 0);
    ~ScalableButton() {}
    
    void SetBitmap_(const std::string& bmp_name);
    void SetBitmapDisabled_(const std::string& bmp_name);
    void SetBitmapPressed_(const std::string& bmp_name);
    void SetBitmapFocus_(const std::string& bmp_name);
    void SetBitmapCurrent_(const std::string& bmp_name);
    
    // Scaling support
    void msw_rescale();
    void sys_color_changed();
    
protected:
    void OnMouseEnter(wxMouseEvent& event);
    void OnMouseLeave(wxMouseEvent& event);
    void OnLeftDown(wxMouseEvent& event);
    void OnLeftUp(wxMouseEvent& event);
    
private:
    std::string m_icon_name;
    std::string m_disabled_icon_name;
    std::string m_pressed_icon_name;
    std::string m_focus_icon_name;
    std::string m_current_icon_name;
    
    // State tracking
    bool m_has_border;
    bool m_use_default_disabled_bitmap;
    
    void update_bitmap();
    wxBitmap create_scaled_bitmap(const std::string& bmp_name);
};
```

## Event Handling and Message Passing

### Application Event System
Implementation: Custom event framework on top of wxWidgets

```cpp
// Custom event types
wxDECLARE_EVENT(EVT_SLICING_UPDATE, SlicingStatusEvent);
wxDECLARE_EVENT(EVT_PROCESS_COMPLETED, SlicingProcessCompletedEvent);
wxDECLARE_EVENT(EVT_EXPORT_BEGAN, wxCommandEvent);
wxDECLARE_EVENT(EVT_EXPORT_FINISHED, wxCommandEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_OBJECT_SELECT, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_RIGHT_CLICK, RBtnEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_REMOVE_OBJECT, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_ARRANGE, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_SELECT_ALL, SimpleEvent);

// Event classes
class SlicingStatusEvent : public wxEvent {
public:
    enum StatusType {
        UPDATE_PRINT_STEP,
        UPDATE_PRINT_OBJECT_STEP,
        UPDATE_EXPORT_PREVIEW,
        UPDATE_PREVIEW_REFRESH
    };
    
    StatusType status;
    int step;
    std::string message;
    bool warning_step;
    
    SlicingStatusEvent(wxEventType eventType, int winid, StatusType status)
        : wxEvent(winid, eventType), status(status), step(0), warning_step(false) {}
    
    virtual wxEvent* Clone() const override { return new SlicingStatusEvent(*this); }
};

class SimpleEvent : public wxEvent {
public:
    size_t obj_idx;
    
    SimpleEvent(wxEventType eventType, int winid, size_t obj_idx = size_t(-1))
        : wxEvent(winid, eventType), obj_idx(obj_idx) {}
    
    virtual wxEvent* Clone() const override { return new SimpleEvent(*this); }
};

// Event handler binding
class PlaterEventHandler {
public:
    void bind_events() {
        // Slicing process events
        wxGetApp().plater()->Bind(EVT_SLICING_UPDATE, &PlaterEventHandler::on_slicing_update, this);
        wxGetApp().plater()->Bind(EVT_PROCESS_COMPLETED, &PlaterEventHandler::on_process_completed, this);
        
        // Canvas events
        wxGetApp().plater()->canvas3D()->Bind(EVT_GLCANVAS_OBJECT_SELECT, 
                                             &PlaterEventHandler::on_object_select, this);
        wxGetApp().plater()->canvas3D()->Bind(EVT_GLCANVAS_RIGHT_CLICK, 
                                             &PlaterEventHandler::on_right_click, this);
        
        // Configuration events
        wxGetApp().mainframe->tabs()->Bind(EVT_TAB_VALUE_CHANGED, 
                                          &PlaterEventHandler::on_config_change, this);
    }
    
private:
    void on_slicing_update(SlicingStatusEvent& evt);
    void on_process_completed(SlicingProcessCompletedEvent& evt);
    void on_object_select(SimpleEvent& evt);
    void on_right_click(RBtnEvent& evt);
    void on_config_change(wxCommandEvent& evt);
};

// Inter-thread communication
class ThreadSafeEventQueue {
public:
    template<typename EventType>
    void post_event(EventType* event) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_pending_events.push(std::unique_ptr<wxEvent>(event));
        
        // Wake up main thread
        wxGetApp().CallAfter([this]() {
            process_pending_events();
        });
    }
    
private:
    std::mutex m_mutex;
    std::queue<std::unique_ptr<wxEvent>> m_pending_events;
    
    void process_pending_events() {
        std::lock_guard<std::mutex> lock(m_mutex);
        
        while (!m_pending_events.empty()) {
            auto event = std::move(m_pending_events.front());
            m_pending_events.pop();
            
            // Process event on main thread
            wxGetApp().GetTopWindow()->GetEventHandler()->ProcessEvent(*event);
        }
    }
};
```

## Performance Optimizations

### Rendering Optimizations
```cpp
class GLPerformanceManager {
public:
    // Viewport culling
    struct ViewportCuller {
        static bool is_visible(const BoundingBoxf3& bbox, const Camera& camera) {
            // Frustum culling implementation
            return true; // Simplified
        }
        
        static std::vector<size_t> cull_volumes(const GLVolumeCollection& volumes, 
                                               const Camera& camera) {
            std::vector<size_t> visible_indices;
            
            for (size_t i = 0; i < volumes.volumes.size(); ++i) {
                if (is_visible(volumes.volumes[i]->bounding_box(), camera)) {
                    visible_indices.push_back(i);
                }
            }
            
            return visible_indices;
        }
    };
    
    // Level of detail management
    class LODManager {
    public:
        enum LODLevel {
            HIGH_DETAIL,    // Full resolution
            MEDIUM_DETAIL,  // Half resolution
            LOW_DETAIL,     // Quarter resolution
            BBOX_ONLY       // Bounding box only
        };
        
        static LODLevel calculate_lod(const BoundingBoxf3& bbox, const Camera& camera) {
            double distance = (bbox.center() - camera.get_position()).norm();
            double object_size = bbox.size().norm();
            double screen_size = object_size / distance;
            
            if (screen_size > 0.1) return HIGH_DETAIL;
            if (screen_size > 0.05) return MEDIUM_DETAIL;
            if (screen_size > 0.01) return LOW_DETAIL;
            return BBOX_ONLY;
        }
    };
    
    // Batch rendering
    class BatchRenderer {
    public:
        struct RenderBatch {
            std::vector<GLVolume*> volumes;
            unsigned int shader_id;
            unsigned int texture_id;
            GLenum primitive_type;
        };
        
        void add_volume(GLVolume* volume) {
            // Group volumes by rendering state
            unsigned int state_key = calculate_state_key(volume);
            m_batches[state_key].volumes.push_back(volume);
        }
        
        void render_all_batches() {
            for (auto& [key, batch] : m_batches) {
                render_batch(batch);
            }
            m_batches.clear();
        }
        
    private:
        std::map<unsigned int, RenderBatch> m_batches;
        
        unsigned int calculate_state_key(const GLVolume* volume) const {
            // Combine shader, texture, and other state into key
            return volume->shader_id ^ (volume->texture_id << 8);
        }
        
        void render_batch(const RenderBatch& batch) {
            // Set up rendering state once for entire batch
            glUseProgram(batch.shader_id);
            glBindTexture(GL_TEXTURE_2D, batch.texture_id);
            
            // Render all volumes in batch
            for (const GLVolume* volume : batch.volumes) {
                volume->render();
            }
        }
    };
};

// Memory management for UI
class UIMemoryManager {
public:
    // Texture caching
    class TextureCache {
    public:
        unsigned int get_texture(const std::string& filename) {
            auto it = m_textures.find(filename);
            if (it != m_textures.end()) {
                // Update access time for LRU
                it->second.last_access = std::chrono::steady_clock::now();
                return it->second.texture_id;
            }
            
            // Load new texture
            unsigned int texture_id = load_texture_from_file(filename);
            
            TextureEntry entry;
            entry.texture_id = texture_id;
            entry.last_access = std::chrono::steady_clock::now();
            entry.file_size = get_file_size(filename);
            
            m_textures[filename] = entry;
            m_total_memory += entry.file_size;
            
            // Evict old textures if memory limit exceeded
            if (m_total_memory > m_max_memory) {
                evict_lru_textures();
            }
            
            return texture_id;
        }
        
    private:
        struct TextureEntry {
            unsigned int texture_id;
            std::chrono::steady_clock::time_point last_access;
            size_t file_size;
        };
        
        std::map<std::string, TextureEntry> m_textures;
        size_t m_total_memory = 0;
        size_t m_max_memory = 256 * 1024 * 1024; // 256MB
        
        void evict_lru_textures() {
            // Implementation of LRU eviction
        }
    };
    
    // Widget pooling
    template<typename WidgetType>
    class WidgetPool {
    public:
        WidgetType* acquire(wxWindow* parent) {
            if (!m_available.empty()) {
                WidgetType* widget = m_available.back();
                m_available.pop_back();
                widget->Reparent(parent);
                return widget;
            }
            
            return new WidgetType(parent);
        }
        
        void release(WidgetType* widget) {
            if (m_available.size() < m_max_pool_size) {
                widget->Hide();
                widget->Reparent(nullptr); // Remove from parent
                m_available.push_back(widget);
            } else {
                widget->Destroy();
            }
        }
        
    private:
        std::vector<WidgetType*> m_available;
        size_t m_max_pool_size = 20;
    };
};
```

## Odin Rewrite Considerations

### UI Framework Alternatives

**Native Solutions**:
```odin
// Example Odin UI framework design
UI_Framework :: enum {
    IMMEDIATE_MODE,  // Dear ImGui style
    RETAINED_MODE,   // Traditional widget tree
    DECLARATIVE,     // React/SwiftUI style
}

Window :: struct {
    handle: rawptr,
    title: string,
    size: [2]i32,
    position: [2]i32,
    flags: Window_Flags,
}

Widget :: struct {
    type: Widget_Type,
    bounds: Rectangle,
    visible: bool,
    enabled: bool,
    parent: ^Widget,
    children: []^Widget,
    event_handlers: map[Event_Type]Event_Handler,
}

Event_Type :: enum {
    CLICK,
    DOUBLE_CLICK,
    KEY_PRESS,
    MOUSE_MOVE,
    PAINT,
    RESIZE,
}
```

**Rendering Backend**:
```odin
// OpenGL/Vulkan abstraction
Renderer :: struct {
    backend: Render_Backend,
    device: rawptr,
    context: rawptr,
    command_queue: Command_Queue,
}

Render_Backend :: enum {
    OPENGL,
    VULKAN,
    METAL,
    DIRECTX12,
}

render_3d_scene :: proc(renderer: ^Renderer, scene: ^Scene_3D) {
    // High-performance 3D rendering
}

render_ui_overlay :: proc(renderer: ^Renderer, ui: ^UI_Context) {
    // Immediate mode UI rendering
}
```

**Architecture Recommendations**:
1. **Modular Design**: Separate 3D rendering from UI framework
2. **Performance First**: GPU-accelerated UI rendering
3. **Cross-Platform**: Abstract platform differences
4. **Modern APIs**: Vulkan/Metal for best performance
5. **Immediate Mode**: Consider ImGui for developer tools
6. **Declarative UI**: For complex application interfaces

### Integration Strategy
1. **Phase 1**: Replace wxWidgets with lightweight framework
2. **Phase 2**: Implement custom 3D scene management
3. **Phase 3**: Add advanced interaction systems
4. **Phase 4**: Optimize for performance and platform features

The UI system represents a significant engineering challenge but offers opportunities for modernization with better performance, more responsive interactions, and improved visual quality in an Odin rewrite.