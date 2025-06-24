# G-code Generation System

## Overview

OrcaSlicer's G-code generation system is a sophisticated pipeline that transforms sliced print data into optimized, printer-specific G-code. The system handles multi-material printing, advanced pressure control, thermal management, path optimization, and extensive post-processing capabilities.

## Core G-code Generation Pipeline

### Main Architecture
Implementation: `src/libslic3r/GCode.cpp`, `src/libslic3r/GCodeWriter.cpp`

```cpp
class GCode {
public:
    struct DoExportGCodeParams {
        const Print *print;
        const std::vector<ThumbnailsList> *thumbnails_list;
        GCodeProcessor::Result *result;
        ThumbnailsGeneratorCallback thumbnail_cb;
    };
    
    // Main G-code generation entry point
    void do_export(Print *print, const char *path, 
                   GCodeProcessor::Result *result = nullptr,
                   ThumbnailsGeneratorCallback thumbnail_cb = nullptr);
    
private:
    void _do_export(Print &print, GCodeOutputStream &file, 
                   ThumbnailsGeneratorCallback thumbnail_cb);
    
    // Core components
    GCodeWriter m_writer;
    PlaceholderParser m_placeholder_parser;
    OozePrevention m_ooze_prevention;
    Wipe m_wipe;
    AvoidCrossingPerimeters m_avoid_crossing_perimeters;
    RetractWhenCrossingPerimeters m_retract_when_crossing_perimeters;
    bool m_enable_loop_clipping;
    coordf_t m_last_pos_defined;
};

class GCodeWriter {
public:
    // State management
    struct Extruder {
        unsigned int id;
        double E;                    // Current extruder position
        double absolute_E;           // Absolute E position
        double retracted;            // Retracted amount
        double restart_extra;        // Extra extrusion on restart
        double e_per_mm3;            // E per mm³ volumetric
        double filament_diameter;
        bool need_toolchange;
        int temperature;             // Target temperature
        int bed_temperature;         // Bed temperature
        double extrusion_axis;       // Total extruded length
        double retracted_length;     // Total retracted length
        double used_filament;        // Total filament used
    };
    
    // G-code generation
    std::string preamble() const;
    std::string postamble() const;
    std::string set_temperature(int temperature, bool wait = false, int tool = -1);
    std::string set_bed_temperature(int temperature, bool wait = false);
    std::string set_fan(unsigned int speed, bool dont_save = false);
    std::string travel_to_xy(const Vec2d &point, const std::string &comment = "");
    std::string travel_to_xyz(const Vec3d &point, const std::string &comment = "");
    std::string travel_to_z(double z, const std::string &comment = "");
    std::string extrude_to_xy(const Vec2d &point, double dE, const std::string &comment = "");
    std::string extrude_to_xyz(const Vec3d &point, double dE, const std::string &comment = "");
    std::string retract(bool before_wipe = false);
    std::string retract_for_toolchange(bool before_wipe = false);
    std::string unretract();
    std::string lift();
    std::string unlift();
    std::string set_acceleration(unsigned int acceleration);
    std::string tool_change(unsigned int tool_id);
    
private:
    GCodeConfig m_config;
    std::vector<Extruder> m_extruders;
    unsigned int m_tool;
    Vec3d m_pos;
    double m_last_acceleration;
    unsigned int m_last_fan_speed;
    int m_last_temperature;
    int m_last_bed_temperature;
    GCodeFlavor m_flavor;
};
```

### Generation Pipeline Flow

1. **Initialization Phase**
   - Configure writer settings and machine limits
   - Initialize post-processing modules
   - Set up placeholder parser with print variables

2. **Header Generation**
   - Machine envelope information
   - Thumbnail embedding
   - Configuration metadata
   - Custom start G-code

3. **Layer Processing**
   - Parallel layer processing with filtering
   - Object-by-object or layer-by-layer generation
   - Support and object coordination

4. **Post-Processing Pipeline**
   - Cooling buffer optimization
   - Pressure equalization
   - Adaptive pressure advance
   - Spiral vase processing

5. **Finalization**
   - Time estimation and statistics
   - Custom end G-code
   - File output and validation

## G-code Flavors and Printer Support

### Supported Flavors
Implementation: `src/libslic3r/PrintConfig.hpp`

```cpp
enum GCodeFlavor {
    gcfMarlinLegacy,      // Marlin legacy firmware
    gcfMarlinFirmware,    // Current Marlin firmware
    gcfKlipper,           // Klipper firmware
    gcfRepRapFirmware,    // RepRap firmware (Duet)
    gcfRepRapSprinter,    // Original RepRap
    gcfRepetier,          // Repetier firmware
    gcfTeacup,            // Teacup firmware
    gcfMakerWare,         // MakerBot MakerWare
    gcfSailfish,          // MakerBot Sailfish
    gcfMach3,             // Mach3 CNC software
    gcfMachinekit,        // Machinekit/LinuxCNC
    gcfSmoothie,          // Smoothieware
    gcfNoExtrusion        // Testing without extrusion
};
```

### Flavor-Specific Features

**Temperature Commands**:
```cpp
std::string GCodeWriter::set_temperature(int temperature, bool wait, int tool) {
    if (m_flavor == gcfRepRapFirmware) {
        // RepRap firmware uses G10 for temperature setting
        return std::string("G10 P") + std::to_string(tool) + 
               " S" + std::to_string(temperature);
    } else {
        // Standard Marlin/others use M104/M109
        std::string cmd = wait ? "M109" : "M104";
        if (tool >= 0) cmd += " T" + std::to_string(tool);
        cmd += " S" + std::to_string(temperature);
        return cmd;
    }
}
```

**Tool Change Handling**:
```cpp
std::string GCodeWriter::tool_change(unsigned int tool_id) {
    std::string gcode;
    
    switch (m_flavor) {
        case gcfKlipper:
            // Klipper tool change with advanced features
            gcode = "ACTIVATE_EXTRUDER EXTRUDER=extruder";
            if (tool_id > 0) gcode += std::to_string(tool_id);
            break;
            
        case gcfRepRapFirmware:
            // RepRap firmware tool selection
            gcode = "T" + std::to_string(tool_id);
            break;
            
        default:
            // Standard Marlin tool change
            gcode = "T" + std::to_string(tool_id);
            break;
    }
    
    return gcode;
}
```

### Machine Limits Integration

```cpp
struct MachineEnvelopeConfig {
    ConfigOptionFloats machine_max_acceleration_extruding;
    ConfigOptionFloats machine_max_acceleration_retracting;
    ConfigOptionFloats machine_max_acceleration_travel;
    ConfigOptionFloats machine_max_feedrate_x;
    ConfigOptionFloats machine_max_feedrate_y;
    ConfigOptionFloats machine_max_feedrate_z;
    ConfigOptionFloats machine_max_feedrate_e;
    ConfigOptionFloats machine_max_jerk_x;
    ConfigOptionFloats machine_max_jerk_y;
    ConfigOptionFloats machine_max_jerk_z;
    ConfigOptionFloats machine_max_jerk_e;
    ConfigOptionFloat machine_min_extruding_rate;
    ConfigOptionFloat machine_min_travel_rate;
};
```

## Toolpath Optimization

### Avoid Crossing Perimeters
Implementation: `src/libslic3r/GCode/AvoidCrossingPerimeters.cpp`

```cpp
class AvoidCrossingPerimeters {
public:
    struct Boundary {
        Polygons boundaries;
        BoundingBoxf bbox;
        std::vector<std::vector<float>> boundaries_params;
        EdgeGrid::Grid grid;
        
        void clear() {
            boundaries.clear();
            boundaries_params.clear();
            grid.clear();
        }
    };
    
    // Main interface
    Polyline travel_to(const GCode &gcodegen, const Point &point);
    
private:
    // Path planning algorithms
    Polyline find_path(const Point &start, const Point &end, 
                      const Boundary &boundary);
    bool intersects_boundary(const Line &line, const Boundary &boundary);
    
    // Spatial acceleration
    std::vector<Boundary> m_boundaries;
    Mode m_mode;
    bool m_use_external_mp;
    bool m_use_external_mp_once;
};

// Path planning using A* algorithm
Polyline AvoidCrossingPerimeters::find_path(const Point &start, const Point &end,
                                           const Boundary &boundary) {
    // A* pathfinding implementation
    struct Node {
        Point position;
        double g_cost;  // Cost from start
        double h_cost;  // Heuristic cost to end
        double f_cost() const { return g_cost + h_cost; }
        Node* parent;
    };
    
    std::vector<Node> open_set;
    std::vector<Node> closed_set;
    
    // Initialize start node
    Node start_node;
    start_node.position = start;
    start_node.g_cost = 0;
    start_node.h_cost = (end - start).cast<double>().norm();
    start_node.parent = nullptr;
    
    open_set.push_back(start_node);
    
    while (!open_set.empty()) {
        // Find node with lowest f_cost
        auto current = std::min_element(open_set.begin(), open_set.end(),
            [](const Node &a, const Node &b) { return a.f_cost() < b.f_cost(); });
        
        // Check if we reached the goal
        if ((current->position - end).cast<double>().norm() < SCALED_EPSILON) {
            // Reconstruct path
            Polyline path;
            Node* node = &(*current);
            while (node) {
                path.points.insert(path.points.begin(), node->position);
                node = node->parent;
            }
            return path;
        }
        
        // Move current to closed set
        closed_set.push_back(*current);
        open_set.erase(current);
        
        // Generate neighbors
        generate_neighbors(closed_set.back(), boundary, open_set, closed_set);
    }
    
    // No path found, return direct line
    return Polyline({start, end});
}
```

### Retraction Management
Implementation: `src/libslic3r/GCode/RetractWhenCrossingPerimeters.cpp`

```cpp
class RetractWhenCrossingPerimeters {
public:
    bool travel_needs_retraction(const Polyline &travel);
    
private:
    const PrintConfig *m_config;
    const LayerRegion *m_layer_region;
    Polygons m_internal_islands;
    
    // Check if travel path crosses printed material
    bool path_crosses_perimeter(const Polyline &travel) {
        for (const Line &segment : travel.lines()) {
            for (const Polygon &island : m_internal_islands) {
                if (island.intersects(segment)) {
                    return true;
                }
            }
        }
        return false;
    }
};
```

## Multi-Material G-code Handling

### Tool Ordering System
Implementation: `src/libslic3r/GCode/ToolOrdering.cpp`

```cpp
class ToolOrdering {
public:
    struct LayerTools {
        coordf_t print_z;
        bool has_object;
        bool has_support;
        bool has_wipe_tower;
        
        // Extruders used in this layer
        std::vector<unsigned int> extruders;
        
        // Tool change sequence optimization
        std::vector<unsigned int> extruder_order;
        
        // Wipe volumes between tools
        std::vector<std::vector<float>> wipe_volumes;
    };
    
    // Main interface
    void initialize(const Print &print, coordf_t first_layer_height);
    const std::vector<LayerTools>& layer_tools() const { return m_layer_tools; }
    
private:
    std::vector<LayerTools> m_layer_tools;
    std::vector<unsigned int> m_all_printing_extruders;
    
    // Optimization algorithms
    void optimize_tool_changes();
    void calculate_wipe_volumes();
    void assign_custom_gcodes();
};

// Tool change optimization
void ToolOrdering::optimize_tool_changes() {
    for (auto &layer_tools : m_layer_tools) {
        if (layer_tools.extruders.size() <= 1) continue;
        
        // Use TSP solver for optimal tool sequence
        std::vector<unsigned int> optimized_order = 
            solve_tool_change_tsp(layer_tools.extruders, layer_tools.wipe_volumes);
        
        layer_tools.extruder_order = optimized_order;
    }
}
```

### Wipe Tower System
Implementation: `src/libslic3r/GCode/WipeTower.hpp`

```cpp
class WipeTower {
public:
    struct ToolChangeResult {
        float print_z;
        size_t layer_id;
        size_t tool_change_id;
        bool finished;
        std::string gcode;
        std::vector<WipeTower::Extrusion> extrusions;
        Vec2f start_pos;
        Vec2f end_pos;
        float elapsed_time;
        float consumed_material;
        int cooling_turns;
        float purge_volume;
    };
    
    // Main interface
    ToolChangeResult tool_change(unsigned int new_tool, bool is_last_layer);
    ToolChangeResult finish_layer();
    
    // Tower geometry
    void set_layer_height(float layer_height) { m_layer_height = layer_height; }
    void set_position(const Vec2f &position) { m_wipe_tower_pos = position; }
    void set_size(float width, float depth) { 
        m_wipe_tower_width = width; 
        m_wipe_tower_depth = depth; 
    }
    
private:
    // Tower state
    float m_layer_height;
    Vec2f m_wipe_tower_pos;
    float m_wipe_tower_width;
    float m_wipe_tower_depth;
    unsigned int m_current_tool;
    
    // Purge volume calculation
    std::vector<std::vector<float>> m_filament_ramming_parameters;
    std::vector<float> m_purge_volumes;
    
    // Generation algorithms
    ToolChangeResult generate_purge_sequence(unsigned int old_tool, 
                                           unsigned int new_tool);
    std::string generate_ramming_gcode(unsigned int tool);
    std::string generate_priming_gcode(unsigned int tool, float volume);
};
```

## Post-Processing Modules

### Cooling Buffer
Implementation: `src/libslic3r/GCode/CoolingBuffer.cpp`

```cpp
class CoolingBuffer {
public:
    struct PerExtruderAdjustments {
        float elapsed_time_total;
        float elapsed_time_extruding;
        float elapsed_time_retracting;
        float elapsed_time_travel;
        std::vector<float> cooling_slow_down_factors;
        float fan_speed;
    };
    
    // Main processing
    std::string process_layer(std::string &&gcode, size_t layer_id,
                             bool flush = false);
    
private:
    struct Adjustment {
        float temperature;
        float fan_speed;
        float slow_down_factor;
    };
    
    // Analysis and adjustment
    PerExtruderAdjustments analyze_layer_times(const std::string &gcode);
    std::vector<Adjustment> calculate_adjustments(
        const PerExtruderAdjustments &adjustments);
    std::string apply_adjustments(const std::string &gcode,
                                 const std::vector<Adjustment> &adjustments);
    
    // Configuration
    const CoolingConfig *m_config;
    std::vector<std::string> m_gcode_lines;
    std::vector<PerExtruderAdjustments> m_per_extruder_adjustments;
};
```

### Pressure Equalizer
Implementation: `src/libslic3r/GCode/PressureEqualizer.cpp`

```cpp
class PressureEqualizer {
public:
    struct ExtrusionRateSlope {
        float positive;  // mm³/s² acceleration limit
        float negative;  // mm³/s² deceleration limit
    };
    
    // Process G-code for smooth flow transitions
    std::string process(const std::string &gcode, bool flush = false);
    
private:
    struct Line {
        enum Type { TYPE_MOVE_E, TYPE_MOVE_XY, TYPE_MOVE_Z, TYPE_OTHER };
        
        Type type;
        float dx, dy, dz, de;
        float feedrate;
        float volumetric_extrusion_rate;
        float volumetric_extrusion_rate_start;
        float volumetric_extrusion_rate_end;
        size_t modified_lines_count;
    };
    
    // Flow rate analysis
    void calculate_volumetric_extrusion_rates(std::vector<Line> &lines);
    void apply_rate_smoothing(std::vector<Line> &lines);
    void segment_long_lines(std::vector<Line> &lines);
    
    // Rate limiting per extrusion role
    std::array<ExtrusionRateSlope, ExtrusionRole::erCount> m_max_slopes;
    float m_max_segment_length;
};
```

### Adaptive Pressure Advance
Implementation: `src/libslic3r/GCode/AdaptivePAProcessor.cpp`

```cpp
class AdaptivePAProcessor {
public:
    struct AdaptivePAData {
        double flow_rate;     // mm³/s
        double pressure_advance;  // PA value
    };
    
    // Real-time pressure advance adjustment
    std::string process_gcode_line(const std::string &line);
    
private:
    class AdaptivePAInterpolator {
    public:
        // PCHIP interpolation for smooth PA transitions
        double get_pressure_advance(double flow_rate) const;
        void add_data_point(double flow_rate, double pa_value);
        
    private:
        std::vector<AdaptivePAData> m_data_points;
        std::vector<double> m_derivatives;  // PCHIP derivatives
        bool m_needs_recompute;
    };
    
    // Per-extruder interpolators
    std::unordered_map<unsigned int, std::unique_ptr<AdaptivePAInterpolator>> 
        m_adaptive_pa_interpolators;
    
    // State tracking
    double m_last_predicted_pa;
    double m_current_flow_rate;
    unsigned int m_current_extruder;
    
    // G-code pattern matching
    std::regex m_pa_change_pattern;
    std::regex m_extrusion_pattern;
};
```

### Spiral Vase Mode
Implementation: `src/libslic3r/GCode/SpiralVase.cpp`

```cpp
class SpiralVase {
public:
    // Process layer for continuous Z movement
    std::string process_layer(std::string gcode);
    
private:
    struct Point3D {
        float x, y, z, e, f;  // Position, extrusion, feedrate
    };
    
    // Layer transition smoothing
    std::vector<Point3D> smooth_layer_transition(
        const std::vector<Point3D> &current_layer,
        const std::vector<Point3D> &next_layer);
    
    // Z-axis interpolation
    float interpolate_z(float progress, float z_start, float z_end);
    
    // State management
    float m_current_z;
    std::vector<Point3D> m_previous_layer_points;
    bool m_transitioning;
};
```

## Time Estimation and Material Usage

### GCode Processor
Implementation: `src/libslic3r/GCodeProcessor.cpp`

```cpp
class GCodeProcessor {
public:
    enum ETimeMode : unsigned char {
        Normal,  // Normal printing mode
        Stealth, // Silent/stealth mode
        Count
    };
    
    struct PrintEstimatedStatistics {
        struct Mode {
            float time;                    // Total print time
            std::vector<std::pair<CustomGCode::Type, std::pair<float, float>>> 
                custom_gcode_times;        // Custom G-code timing
            std::vector<std::pair<EMoveType, float>> moves_times;  // Move type timing
            std::vector<std::pair<ExtrusionRole, float>> roles_times;  // Role timing
            std::vector<float> volumes_per_extruder;  // Material usage
        };
        
        std::array<Mode, ETimeMode::Count> modes;
        std::map<size_t, double> total_volumes_per_extruder;
        std::map<ExtrusionRole, std::pair<double, double>> used_filaments_per_role;
    };
    
    struct Result {
        PrintEstimatedStatistics print_statistics;
        std::vector<MoveVertex> moves;
        std::vector<ExtrusionRole> roles;
        Pointfs bed_shape;
        float extruders_count;
        std::vector<std::vector<float>> filament_diameters;
        std::vector<std::vector<float>> filament_densities;
        PrintEstimatedStatistics::ETimeMode time_mode;
    };
    
    // Main processing interface
    void process_file(const std::string &filename, bool apply_postprocess = true);
    void process_buffer(const std::string &buffer);
    
private:
    // Movement simulation
    struct TimeEstimator {
        struct Axis {
            float position;           // Current position
            float max_feedrate;       // Maximum feedrate
            float max_acceleration;   // Maximum acceleration
            float max_jerk;          // Maximum jerk/junction deviation
        };
        
        std::array<Axis, 4> axes;  // XYZE axes
        
        // Calculate movement time with acceleration profile
        float calculate_time(const Vec3f &target, float feedrate, float extrusion);
        void simulate_movement(const Vec3f &target, float feedrate, float extrusion);
    };
    
    // Material usage tracking
    struct MaterialTracker {
        std::vector<float> volumes_per_extruder;
        std::vector<float> weights_per_extruder;
        std::map<ExtrusionRole, float> volumes_per_role;
        
        void add_extrusion(unsigned int extruder, float volume, 
                          ExtrusionRole role, float density);
    };
    
    TimeEstimator m_time_estimator;
    MaterialTracker m_material_tracker;
    
    // G-code parsing and analysis
    void process_gcode_line(const std::string &line);
    void parse_move_command(const std::string &line);
    void parse_temperature_command(const std::string &line);
    void update_time_estimates();
};
```

## Thumbnail Generation and Metadata

### Thumbnail System
Implementation: `src/libslic3r/GCode/Thumbnails.cpp`

```cpp
struct ThumbnailData {
    unsigned int width;
    unsigned int height;
    GCodeThumbnailsFormat format;
    std::vector<unsigned char> pixels;  // Raw image data
    
    // Encoding for G-code embedding
    std::string encode_base64() const;
    std::string encode_qoi() const;      // Quite OK Image format
    std::string encode_colpic() const;   // Color Picker format
};

enum class GCodeThumbnailsFormat {
    PNG,      // Portable Network Graphics
    JPG,      // JPEG format
    QOI,      // Quite OK Image format
    BTT_TFT,  // BigTreeTech TFT format
    ColPic    // Color Picker format (Ender 3 V2, etc.)
};

class ThumbnailsGenerator {
public:
    using ThumbnailsList = std::vector<ThumbnailData>;
    using ThumbnailsGeneratorCallback = std::function<ThumbnailsList(
        ThumbnailsParams thumbnail_params, const PrintObject &print_object)>;
    
    // Generate thumbnails for G-code embedding
    static ThumbnailsList generate_thumbnails(
        const ThumbnailsParams &params,
        const PrintObject &print_object,
        const std::function<void(const ThumbnailData&)> &thumbnail_cb = nullptr);
    
private:
    // Rendering pipeline
    static ThumbnailData render_thumbnail(
        unsigned int width, unsigned int height,
        GCodeThumbnailsFormat format,
        const PrintObject &print_object);
    
    // Format-specific encoding
    static std::vector<unsigned char> encode_png(
        const std::vector<unsigned char> &pixels,
        unsigned int width, unsigned int height);
    
    static std::vector<unsigned char> encode_jpg(
        const std::vector<unsigned char> &pixels,
        unsigned int width, unsigned int height, int quality = 85);
};
```

### Metadata Embedding
Implementation: `src/libslic3r/GCode/PlaceholderParser.cpp`

```cpp
class PlaceholderParser {
public:
    // Variable context for template processing
    std::map<std::string, std::string> config_variables;
    std::map<std::string, std::vector<std::string>> config_array_variables;
    
    // Process template with variable substitution
    std::string process(std::string str, unsigned int current_extruder_id = 0,
                       const DynamicConfig *config_override = nullptr,
                       ContextData *context_data = nullptr) const;
    
    // Special processing for conditional logic
    std::string process_conditional(const std::string &condition,
                                   const std::string &if_true,
                                   const std::string &if_false) const;
    
private:
    // Variable lookup and substitution
    std::string resolve_variable(const std::string &variable_name,
                                const ConfigOptionDef *opt_def = nullptr) const;
    
    // Mathematical expression evaluation
    double evaluate_expression(const std::string &expression) const;
    
    // Template parsing
    struct Token {
        enum Type { TEXT, VARIABLE, EXPRESSION, CONDITIONAL };
        Type type;
        std::string content;
        size_t position;
    };
    
    std::vector<Token> tokenize(const std::string &template_str) const;
};

// Plate data for multi-plate prints
struct PlateBBoxData {
    std::vector<coordf_t> bbox_all;          // Overall bounding box
    std::vector<BBoxData> bbox_objs;         // Per-object bounding boxes
    std::vector<int> filament_ids;           // Material assignments
    std::vector<std::string> filament_colors; // Color information
    bool is_seq_print;                       // Sequential printing flag
    std::string to_json() const;             // JSON serialization
};
```

## Custom G-code Integration

### Custom G-code Types
Implementation: `src/libslic3r/CustomGCode.hpp`

```cpp
namespace CustomGCode {
    enum Type {
        ColorChange,  // M600 - Filament change
        PausePrint,   // M601 - Pause print
        ToolChange,   // Tool change request
        Template,     // Template-based custom code
        Custom        // Arbitrary G-code
    };
    
    struct Item {
        Type type;
        int extruder;
        double print_z;
        std::string color;
        std::string extra;
        std::string gcode;
    };
    
    class Info {
    public:
        std::vector<Item> gcodes;
        
        // Management interface
        void add_code(Type type, int extruder, double print_z,
                     const std::string &extra = "");
        void remove_code(size_t index);
        void move_code(size_t from, size_t to);
        
        // Processing interface
        std::vector<Item> get_codes_for_layer(double layer_z) const;
        bool has_color_changes() const;
        bool has_pause_commands() const;
        
    private:
        void sort_by_layer();
        bool validate_item(const Item &item) const;
    };
}

// Template processing with placeholder parser
class CustomGCodeProcessor {
public:
    std::string process_custom_gcode(const CustomGCode::Item &item,
                                    const PlaceholderParser &parser,
                                    unsigned int current_extruder,
                                    const DynamicConfig *config) const;
    
private:
    // Standard G-code generation for predefined types
    std::string generate_color_change(int extruder, const std::string &color) const;
    std::string generate_pause_print(const std::string &message) const;
    std::string generate_tool_change(int new_tool) const;
    
    // Template validation
    bool validate_template(const std::string &template_code) const;
    std::vector<std::string> extract_variables(const std::string &template_code) const;
};
```

## Error Handling and Validation

### Validation Systems
Implementation: Various validation throughout the pipeline

```cpp
class GCodeValidator {
public:
    struct ValidationResult {
        bool is_valid;
        std::vector<std::string> errors;
        std::vector<std::string> warnings;
        
        // Specific validation categories
        bool syntax_valid;
        bool semantics_valid;
        bool machine_limits_respected;
        bool thermal_safety_check;
    };
    
    // Main validation interface
    ValidationResult validate_gcode(const std::string &gcode,
                                   const PrintConfig &config) const;
    
private:
    // Validation categories
    ValidationResult validate_syntax(const std::string &gcode) const;
    ValidationResult validate_machine_limits(const std::string &gcode,
                                            const PrintConfig &config) const;
    ValidationResult validate_thermal_safety(const std::string &gcode,
                                            const PrintConfig &config) const;
    
    // Specific checks
    bool check_temperature_limits(int temperature, const std::string &context) const;
    bool check_speed_limits(float feedrate, const std::string &context) const;
    bool check_acceleration_limits(float acceleration, const std::string &context) const;
};

// Conflict detection for multi-object prints
class ConflictChecker {
public:
    struct ConflictResult {
        std::string object_name_1;
        std::string object_name_2;
        double height;
        const void *object_1;
        const void *object_2;
        int layer;
        ConflictType type;
    };
    
    enum ConflictType {
        OBJECT_COLLISION,      // Objects physically collide
        EXTRUDER_COLLISION,    // Extruder hits object
        PATH_COLLISION,        // Travel path conflicts
        THERMAL_INTERFERENCE   // Heat zones overlap
    };
    
    // Main conflict detection
    std::vector<ConflictResult> check_print_conflicts(const Print &print) const;
    
private:
    // Specific conflict types
    std::vector<ConflictResult> check_object_collisions(const Print &print) const;
    std::vector<ConflictResult> check_extruder_collisions(const Print &print) const;
    std::vector<ConflictResult> check_path_conflicts(const Print &print) const;
};
```

## Performance Considerations

### Memory Management
```cpp
class GCodeMemoryManager {
public:
    // Streaming G-code generation to minimize memory usage
    class StreamingGCodeWriter {
    public:
        StreamingGCodeWriter(const std::string &filename);
        ~StreamingGCodeWriter();
        
        void write_line(const std::string &line);
        void write_buffer(const std::string &buffer);
        void flush();
        
    private:
        std::ofstream m_file;
        std::string m_buffer;
        size_t m_buffer_size_limit;
        size_t m_total_written;
    };
    
    // Memory pool for temporary objects
    template<typename T>
    class ObjectPool {
    public:
        T* acquire();
        void release(T* obj);
        void clear();
        
    private:
        std::vector<std::unique_ptr<T>> m_pool;
        std::queue<T*> m_available;
    };
    
private:
    StreamingGCodeWriter m_writer;
    ObjectPool<ExtrusionPath> m_path_pool;
    ObjectPool<Polygon> m_polygon_pool;
};
```

### Computational Optimization
```cpp
// Parallel layer processing with pipeline stages
class ParallelGCodeGenerator {
public:
    void generate_parallel(const Print &print, const std::string &output_path) {
        // Pipeline stages
        tbb::pipeline pipeline;
        
        // Stage 1: Layer preparation
        pipeline.add_filter(tbb::filter::serial_in_order,
            [&](tbb::flow_control &fc) -> Layer* {
                static size_t layer_index = 0;
                if (layer_index >= print.total_layer_count()) {
                    fc.stop();
                    return nullptr;
                }
                return print.get_layer(layer_index++);
            });
        
        // Stage 2: G-code generation (parallel)
        pipeline.add_filter(tbb::filter::parallel,
            [&](Layer* layer) -> std::string {
                return generate_layer_gcode(*layer);
            });
        
        // Stage 3: Post-processing (parallel)
        pipeline.add_filter(tbb::filter::parallel,
            [&](std::string gcode) -> std::string {
                return apply_post_processing(gcode);
            });
        
        // Stage 4: Output (serial)
        pipeline.add_filter(tbb::filter::serial_out_of_order,
            [&](std::string processed_gcode) -> void {
                write_to_output(processed_gcode);
            });
        
        // Execute pipeline
        pipeline.run(tbb::task_scheduler_init::default_num_threads());
    }
    
private:
    std::string generate_layer_gcode(const Layer &layer);
    std::string apply_post_processing(const std::string &gcode);
    void write_to_output(const std::string &gcode);
};
```

## Odin Rewrite Considerations

### Architecture Recommendations

**Modular Design Principles**:
1. **Separation of Concerns**: Generator, processor, output modules
2. **Plugin Architecture**: Configurable post-processing pipeline
3. **Stream Processing**: Memory-efficient generation for large prints
4. **Parallel Processing**: Multi-threaded layer and post-processing

**Core Data Structures**:
```odin
// Example Odin structures for G-code generation
GCode_Generator :: struct {
    writer: ^GCode_Writer,
    config: ^Print_Config,
    post_processors: []^Post_Processor,
    output_stream: ^Output_Stream,
}

GCode_Writer :: struct {
    extruders: []Extruder_State,
    current_position: Vec3,
    flavor: GCode_Flavor,
    precision: Precision_Config,
}

Extruder_State :: struct {
    id: u32,
    position: f64,
    temperature: i32,
    retracted: f64,
    flow_rate: f64,
}

Post_Processor :: struct {
    name: string,
    enabled: bool,
    process: proc(gcode: string) -> string,
}
```

**Performance Targets**:
- Linear memory usage relative to print size
- Streaming output for unlimited print complexity  
- Sub-second G-code generation for typical prints
- Real-time post-processing pipeline

**Extension Points**:
- Custom post-processing modules
- Printer-specific G-code flavors
- Advanced path optimization algorithms
- Custom metadata embedding formats

The G-code generation system represents the final critical step in the 3D printing pipeline, where all previous processing culminates in machine-executable instructions. A successful Odin rewrite must preserve the sophisticated optimization algorithms while modernizing the architecture for better performance, maintainability, and extensibility.