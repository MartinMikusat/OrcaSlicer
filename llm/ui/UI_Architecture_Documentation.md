# OrcaSlicer UI Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Main Window Architecture](#main-window-architecture)
3. [Plater and 3D Scene Management](#plater-and-3d-scene-management)
4. [Gizmos System](#gizmos-system)
5. [Configuration Tabs and Panels](#configuration-tabs-and-panels)
6. [Dialogs and Wizards](#dialogs-and-wizards)
7. [Custom Widgets](#custom-widgets)
8. [Event Handling](#event-handling)
9. [wxWidgets Integration](#wxwidgets-integration)
10. [OpenGL Rendering Pipeline](#opengl-rendering-pipeline)
11. [User Interaction Patterns](#user-interaction-patterns)
12. [Performance Optimizations](#performance-optimizations)

## Overview

OrcaSlicer's UI is built on wxWidgets 3.x with extensive customization and OpenGL rendering for 3D visualization. The architecture follows a Model-View-Controller pattern with clear separation between business logic and UI components.

### Key Technologies
- **wxWidgets 3.x**: Cross-platform UI framework
- **OpenGL/GLEW**: 3D rendering
- **ImGui**: Immediate mode GUI for overlays and gizmos
- **Custom widgets**: Extended wxWidgets controls with custom painting

## Main Window Architecture

### MainFrame (MainFrame.cpp/hpp)

The main window is implemented as `MainFrame`, derived from `DPIFrame` (DPI-aware frame):

```cpp
class MainFrame : public DPIFrame
{
    // Key components:
    BBLTopbar*            m_topbar;          // Custom top bar replacing title/menu
    Plater*               m_plater;          // 3D editor panel
    MonitorPanel*         m_monitor;         // Print monitoring
    MultiMachinePage*     m_multi_machine;   // Multi-printer management
    ProjectPanel*         m_project;         // Project management
    CalibrationPanel*     m_calibration;     // Printer calibration
    Notebook*             m_tabpanel;        // Main tab container
    ParamsPanel*          m_param_panel;     // Parameter editing panel
};
```

#### Key Features:
- **Borderless frame style** with custom title bar
- **Tab-based navigation** with positions:
  - Home (0)
  - 3D Editor (1)
  - Preview (2)
  - Monitor (3)
  - Multi Device (4)
  - Project (5)
  - Calibration (6)
  - Auxiliary (7)

### GUI_App (GUI_App.cpp/hpp)

The application class manages:
- **Initialization** of OpenGL, localization, and resources
- **Configuration** management (AppConfig)
- **Preset bundle** handling
- **Event routing** between components
- **Dark/Light mode** switching
- **Single instance** management

## Plater and 3D Scene Management

### Plater (Plater.cpp/hpp)

The Plater is the central 3D editing workspace:

```cpp
class Plater : public wxPanel
{
    // Core components:
    GLCanvas3D*           m_canvas3D;        // OpenGL canvas
    Preview*              m_preview;         // G-code preview
    Sidebar*              m_sidebar;         // Object settings
    ObjectList*           m_object_list;     // Object hierarchy
    PlateList*            m_plate_list;      // Build plate management
    
    // State management:
    BackgroundSlicingProcess* m_background_process;
    ProjectDirtyStateManager* m_project_state;
};
```

#### Key Responsibilities:
- **Model management**: Loading, arranging, manipulating 3D objects
- **Slicing coordination**: Managing background slicing process
- **Build plate system**: Multiple build plates support
- **Object manipulation**: Through gizmos and sidebar controls

### GLCanvas3D (GLCanvas3D.cpp/hpp)

The OpenGL canvas for 3D rendering:

```cpp
class GLCanvas3D
{
    // Rendering components:
    Camera                m_camera;          // View management
    GLGizmosManager       m_gizmos;          // Gizmo system
    Selection             m_selection;       // Object selection
    GLToolbar             m_main_toolbar;    // Main toolbar
    Mouse3DController     m_mouse3d;         // 3D mouse support
    
    // Rendering pipeline:
    void render();                           // Main render loop
    void render_objects();                   // Model rendering
    void render_bed();                       // Build plate
    void render_gizmos();                    // Active gizmos
};
```

## Gizmos System

### GLGizmosManager (Gizmos/GLGizmosManager.hpp)

Manages all manipulation gizmos:

```cpp
enum EType : unsigned char
{
    Move,               // Translation
    Rotate,             // Rotation
    Scale,              // Scaling
    Flatten,            // Flatten to bed
    Cut,                // Cut tool
    MeshBoolean,        // Boolean operations
    FdmSupports,        // Support painting
    Seam,               // Seam painting
    MmuSegmentation,    // Multi-material painting
    Emboss,             // Text embossing
    Svg,                // SVG import
    Measure,            // Measurement tool
    Assembly,           // Assembly view
    Simplify,           // Mesh simplification
    BrimEars,           // Brim ears
};
```

### Gizmo Architecture

Each gizmo inherits from `GLGizmoBase`:

```cpp
class GLGizmoBase
{
public:
    virtual void on_render();              // Render gizmo
    virtual bool on_mouse(const wxMouseEvent&);
    virtual void on_update(const UpdateData&);
    
protected:
    GLCanvas3D& m_parent;
    ImGuiWrapper* m_imgui;                 // ImGui for UI
    std::vector<Grabber> m_grabbers;       // Interactive handles
};
```

## Configuration Tabs and Panels

### Tab System (Tab.cpp/hpp)

Configuration tabs for print/filament/printer settings:

```cpp
class Tab : public wxPanel
{
    // Tab types:
    // - PrintTab: Layer heights, infill, supports, etc.
    // - FilamentTab: Temperatures, flow, retraction
    // - PrinterTab: Machine limits, extruder settings
    
    std::vector<PageShp> m_pages;          // Option pages
    TabPresetComboBox*   m_presets_choice; // Preset selector
    DynamicPrintConfig*  m_config;         // Current configuration
};
```

### Page System

Each tab contains multiple pages:

```cpp
class Page
{
    std::vector<ConfigOptionsGroupShp> m_optgroups; // Option groups
    wxString m_title;                               // Page title
    size_t m_iconID;                                // Icon identifier
};
```

## Dialogs and Wizards

### ConfigWizard (ConfigWizard.cpp/hpp)

Initial setup wizard for printer configuration:
- Printer selection
- Filament profiles
- Network setup
- Calibration guidance

### CalibrationWizard (CalibrationWizard.cpp/hpp)

Printer calibration wizard:
- Flow rate calibration
- Temperature calibration
- Retraction tuning
- Pressure advance

### Common Dialogs

- **MsgDialog**: Styled message dialogs
- **FileArchiveDialog**: Project archive management
- **PlateSettingsDialog**: Per-plate settings
- **PrintHostDialog**: Network printing setup
- **PhysicalPrinterDialog**: Physical printer management

## Custom Widgets

### AMSControl (Widgets/AMSControl.hpp)

Advanced Material System control widget:

```cpp
class AMSControl : public wxSimplebook
{
    // Components:
    AmsCansHash          m_ams_cans_list;   // Filament slots
    AMSextruder*         m_extruder;        // Extruder visualization
    StepIndicator*       m_filament_step;   // Loading progress
    
    // Features:
    - Filament selection and monitoring
    - Load/unload operations
    - Humidity display
    - RFID tag reading
    - Multi-AMS support
};
```

### Custom Controls

- **Button**: Styled button with hover/press states
- **CheckBox**: Custom checkbox with animations
- **RadioBox**: Radio button groups
- **TextInput**: Enhanced text input
- **ComboBox**: Dropdown with custom rendering
- **TabCtrl**: Custom tab control
- **ProgressBar**: Styled progress indicators
- **StaticBox**: Grouped control container

## Event Handling

### Event System Architecture

Custom event types for application-specific needs:

```cpp
// Base event classes
struct SimpleEvent : public wxEvent;
struct IntEvent : public wxEvent;
template<class T> struct Event : public wxEvent;

// Application events
wxDECLARE_EVENT(EVT_SLICING_UPDATE, SlicingStatusEvent);
wxDECLARE_EVENT(EVT_PROCESS_COMPLETED, SlicingProcessCompletedEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_OBJECT_SELECT, SimpleEvent);
```

### Event Flow

1. **User Input** → wxWidgets events
2. **Canvas Events** → GLCanvas3D processing
3. **Gizmo Events** → GLGizmosManager routing
4. **Model Changes** → Update notifications
5. **Background Tasks** → Progress events

## wxWidgets Integration

### Custom Extensions

- **DPIFrame/DPIDialog**: DPI-aware windows
- **ScalableBitmap**: Resolution-independent images
- **StyledButton**: Platform-styled buttons
- **Notebook**: Enhanced tab control

### Platform-Specific Code

```cpp
#ifdef __WXMSW__
    // Windows-specific: Dark mode, DWM integration
#elif __WXOSX__
    // macOS-specific: Native toolbar, fullscreen
#elif __WXGTK__
    // Linux-specific: GTK theming
#endif
```

## OpenGL Rendering Pipeline

### Rendering Components

1. **OpenGLManager**: Context management, capability detection
2. **GLShader**: Shader compilation and management
3. **GLTexture**: Texture loading and binding
4. **GLModel**: Vertex buffer management

### Render Pipeline

```cpp
void GLCanvas3D::render()
{
    // 1. Clear and setup
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // 2. Camera setup
    m_camera.apply_projection(canvas_size);
    m_camera.apply_view_matrix();
    
    // 3. Scene rendering
    render_bed();                  // Build volume
    render_objects();              // 3D models
    render_sla_slices();          // SLA preview
    
    // 4. Overlay rendering
    render_gizmos();              // Active gizmos
    render_selection();           // Selection highlights
    
    // 5. UI overlay (ImGui)
    render_gui();
}
```

### Shader System

Key shaders:
- **gouraud**: Basic 3D rendering
- **variable_layer_height**: Layer height visualization
- **toolpaths**: G-code preview
- **picking**: Object selection

## User Interaction Patterns

### Mouse Interaction

1. **Left Click**: Selection
2. **Right Click**: Context menu
3. **Middle Button**: Pan view
4. **Scroll**: Zoom
5. **Shift/Ctrl/Alt**: Modifiers for gizmos

### Keyboard Shortcuts

- Managed through `KBShortcutsDialog`
- Configurable bindings
- Context-sensitive (different in preview vs. edit)

### Drag & Drop

- Model files → Add to scene
- Preset files → Import settings
- Images → Emboss/SVG operations

## Performance Optimizations

### Rendering Optimizations

1. **Frustum Culling**: Skip off-screen objects
2. **Level of Detail**: Simplified meshes for distant objects
3. **Instanced Rendering**: Efficient duplicate rendering
4. **Vertex Buffer Caching**: Reuse GPU buffers

### Threading

```cpp
// Background slicing
BackgroundSlicingProcess: Separate thread for slicing
PlaterWorker: Job queue for long operations
BoostThreadWorker: Thread pool for parallel tasks
```

### Memory Management

- **Model simplification** for large meshes
- **Texture atlasing** for UI elements
- **Lazy loading** of presets and resources
- **Smart pointers** for automatic cleanup

## Key Design Patterns

1. **Model-View-Controller**: Clear separation of concerns
2. **Observer Pattern**: Event-based updates
3. **Command Pattern**: Undo/redo system
4. **Factory Pattern**: Object creation (GUI_Factories)
5. **Singleton**: App instance, configuration
6. **Strategy Pattern**: Different slicing engines

## Future Considerations for Odin Rewrite

1. **Immediate Mode GUI**: Consider full ImGui approach
2. **GPU Acceleration**: More compute shaders
3. **Modular Architecture**: Plugin system
4. **Modern C++ Features**: C++20/23 improvements
5. **Cross-platform Abstraction**: Reduce platform-specific code
6. **Testing Framework**: Automated UI testing
7. **Accessibility**: Screen reader support
8. **Localization**: Improved translation system