# OrcaSlicer UI Data Flow and Integration Patterns

## Data Flow Architecture

### Model-View-Controller Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                         Model Layer                         │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Model     │  │ PrintConfig  │  │  PresetBundle    │  │
│  │  Objects    │  │   (Dynamic)  │  │ (Print/Filament/ │  │
│  │             │  │              │  │    Printer)      │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↑↓
┌─────────────────────────────────────────────────────────────┐
│                      Controller Layer                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │   Plater    │  │ Background   │  │     Gizmos      │  │
│  │             │  │   Process    │  │    Manager      │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↑↓
┌─────────────────────────────────────────────────────────────┐
│                         View Layer                          │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ GLCanvas3D  │  │   Sidebar    │  │      Tabs       │  │
│  │             │  │              │  │                 │  │
│  └─────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Data Structures

### Model Representation
```cpp
// Core 3D model structure
class Model {
    ModelObjectPtrs         objects;        // List of objects
    
    // Model operations
    ModelObject* add_object();
    void delete_object(size_t idx);
    bool arrange_objects(const BoundingBoxf& bed);
    void duplicate_objects(size_t copies);
};

class ModelObject {
    std::string             name;
    ModelInstancePtrs       instances;      // Copies/arrangements
    ModelVolumePtrs         volumes;        // Parts/modifiers
    DynamicPrintConfig      config;         // Per-object settings
    
    // Geometry cache
    TriangleMesh            raw_mesh;
    BoundingBoxf3           bounding_box;
    
    // State
    ModelObjectCutAttributes cut_info;
    LayerHeightProfile      layer_height_profile;
};
```

### Configuration System
```cpp
// Configuration hierarchy
class DynamicPrintConfig : public ConfigBase {
    std::map<t_config_option_key, ConfigOption*> options;
    
    // Type-safe access
    template<typename T>
    T* opt(const t_config_option_key& key);
    
    // Serialization
    void load(const std::string& file);
    void save(const std::string& file) const;
};

// Preset management
class Preset {
    std::string         name;
    std::string         file;
    DynamicPrintConfig  config;
    bool                is_default;
    bool                is_system;
    bool                is_visible;
    
    // Inheritance
    const Preset*       parent;
    std::vector<std::string> inherits;
};
```

## Event System Details

### Event Types and Flow

```cpp
// Custom event definitions
wxDECLARE_EVENT(EVT_GLCANVAS_OBJECT_SELECT, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_UPDATE_BED_SHAPE, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_MOUSE_DRAGGING_FINISHED, SimpleEvent);
wxDECLARE_EVENT(EVT_GLCANVAS_RELOAD_FROM_DISK, SimpleEvent);

// Event routing example
void GLCanvas3D::on_mouse(wxMouseEvent& evt) {
    if (m_gizmos.on_mouse(evt))
        return;  // Gizmo handled it
        
    if (evt.LeftDown()) {
        // Perform selection
        do_selection(evt.GetPosition());
        
        // Notify observers
        post_event(SimpleEvent(EVT_GLCANVAS_OBJECT_SELECT));
    }
}

// Event handling in Plater
void Plater::priv::on_object_select(SimpleEvent& evt) {
    // Update sidebar
    sidebar->update_objects_list_extruder_column();
    
    // Update gizmos
    view3D->get_canvas3d()->update_gizmos_on_off_state();
    
    // Schedule background processing if needed
    this->schedule_background_process();
}
```

### Message Passing Patterns

```cpp
// Synchronous updates
class ObjectList {
    void update_selections() {
        // Direct call to plater
        wxGetApp().plater()->canvas3D()->update_gizmos_on_off_state();
    }
};

// Asynchronous updates via events
class Tab {
    void on_value_change(const std::string& opt_key, const boost::any& value) {
        // Update config
        m_config->set_key_value(opt_key, new_opt_value);
        
        // Post event for async handling
        wxCommandEvent event(EVT_TAB_VALUE_CHANGED);
        event.SetString(opt_key);
        wxPostEvent(m_parent, event);
    }
};
```

## Data Binding Mechanisms

### Configuration to UI Binding

```cpp
// Field binding example
class Field {
protected:
    ConfigOption*       m_opt;
    std::function<void(const boost::any&)> m_on_change;
    
public:
    void set_value(const boost::any& value) {
        // Update UI
        do_set_value(value);
        
        // Notify change
        if (m_on_change)
            m_on_change(get_value());
    }
};

// Options group binding
class ConfigOptionsGroup {
    void bind_field(Field* field, const ConfigOption* opt) {
        // Initial value
        field->set_value(opt->get_any());
        
        // Change handler
        field->m_on_change = [this, opt_key](const boost::any& value) {
            this->change_opt_value(opt_key, value);
        };
    }
};
```

### Model to View Synchronization

```cpp
// Object list synchronization
class ObjectList {
    void update_objects_list() {
        // Clear existing
        m_objects_model->Clear();
        
        // Rebuild from model
        for (const ModelObject* object : m_model->objects) {
            add_object_to_list(object);
            
            for (const ModelVolume* volume : object->volumes) {
                add_volume_to_list(volume, object);
            }
        }
    }
};

// 3D view synchronization
class GLCanvas3D {
    void reload_scene(bool refresh_immediately) {
        // Update volumes from model
        m_volumes.volumes.clear();
        
        for (const ModelObject* obj : m_model->objects) {
            for (const ModelInstance* inst : obj->instances) {
                for (const ModelVolume* vol : obj->volumes) {
                    m_volumes.load_object_volume(obj, vol, inst);
                }
            }
        }
        
        if (refresh_immediately)
            render();
    }
};
```

## State Management

### Application State
```cpp
class GUI_App {
    // Global state
    EAppMode            m_app_mode;
    PresetBundle*       preset_bundle;
    Model               model;
    
    // State queries
    bool has_current_preset_changes() const;
    bool check_unsaved_changes();
    
    // State transitions
    void load_project(const wxString& filename);
    void reset_project();
    void update_mode();
};
```

### Undo/Redo System
```cpp
class PlaterUndo {
    struct Snapshot {
        Model               model;
        DynamicPrintConfig  config;
        Selection           selection;
        std::string         name;
        size_t              timestamp;
    };
    
    std::vector<Snapshot>   m_snapshots;
    size_t                  m_current_snapshot_index;
    
    void take_snapshot(const std::string& name) {
        // Capture current state
        Snapshot snapshot;
        snapshot.model = m_model;
        snapshot.config = m_config;
        snapshot.selection = m_selection;
        
        // Add to history
        m_snapshots.push_back(std::move(snapshot));
    }
    
    void undo() {
        if (can_undo()) {
            --m_current_snapshot_index;
            load_snapshot(m_current_snapshot_index);
        }
    }
};
```

## Background Processing Integration

### Job Queue System
```cpp
class PlaterWorker {
    struct Job {
        std::function<void()>   work;
        std::function<void()>   finalize;
        bool                    canceled;
    };
    
    std::queue<std::unique_ptr<Job>>   m_jobs;
    std::thread                        m_thread;
    
    void enqueue_job(std::unique_ptr<Job> job) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_jobs.push(std::move(job));
        m_condition.notify_one();
    }
};
```

### Progress Reporting
```cpp
class ProgressIndicator {
    virtual void set_range(int range) = 0;
    virtual void set_progress(int progress) = 0;
    virtual void set_status_text(const std::string& text) = 0;
    virtual bool was_canceled() const = 0;
};

class NotificationProgressIndicator : public ProgressIndicator {
    NotificationManager*    m_nm;
    
    void set_progress(int progress) override {
        m_nm->set_progress_bar_percentage(m_id, 
            float(progress) / float(m_range));
    }
};
```

## Network Integration

### Device Communication
```cpp
class MachineObject {
    // Connection state
    std::string         dev_id;
    std::string         dev_ip;
    bool                is_connected;
    
    // Status monitoring
    void update_status() {
        json request = {
            {"method", "get_status"},
            {"params", {}}
        };
        
        send_request(request, [this](const json& response) {
            parse_status(response);
            notify_observers();
        });
    }
    
    // Command sending
    void send_gcode(const std::string& gcode_path) {
        // Upload file
        upload_file(gcode_path, [this, gcode_path](bool success) {
            if (success) {
                // Start print
                start_print(gcode_path);
            }
        });
    }
};
```

## Performance Considerations

### Lazy Loading
```cpp
class PresetBundle {
    mutable std::map<std::string, std::unique_ptr<Preset>> m_presets_cache;
    
    const Preset* find_preset(const std::string& name) const {
        auto it = m_presets_cache.find(name);
        if (it == m_presets_cache.end()) {
            // Load on demand
            auto preset = load_preset_from_file(name);
            m_presets_cache[name] = std::move(preset);
            return m_presets_cache[name].get();
        }
        return it->second.get();
    }
};
```

### Batch Updates
```cpp
class GLCanvas3D {
    bool m_dirty;
    
    void request_extra_frame() {
        m_dirty = true;
    }
    
    void render() {
        if (!m_dirty && !m_mouse_dragging)
            return;  // Skip redundant renders
            
        do_render();
        m_dirty = false;
    }
};
```

## Best Practices for UI Development

### 1. Event-Driven Architecture
- Use events for loose coupling
- Avoid direct cross-component calls
- Implement proper event cleanup

### 2. State Management
- Centralize application state
- Use immutable updates where possible
- Implement proper undo/redo

### 3. Performance
- Profile rendering bottlenecks
- Use virtual controls for large lists
- Implement proper culling

### 4. Threading
- Keep UI updates on main thread
- Use job queues for background work
- Implement progress reporting

### 5. Memory Management
- Use RAII consistently
- Prefer stack allocation
- Profile memory usage

## Integration Points for Odin

### Key Areas to Consider

1. **FFI Boundary**
   - Minimize C++ ↔ Odin transitions
   - Batch data transfers
   - Use simple data types

2. **Event System**
   - Design Odin-friendly event types
   - Consider message passing
   - Implement proper marshaling

3. **Rendering**
   - Direct OpenGL from Odin
   - Shared context management
   - Efficient buffer sharing

4. **Configuration**
   - Pure data structures
   - JSON serialization
   - Type-safe access

5. **Background Processing**
   - Odin job system
   - Progress callbacks
   - Cancellation support