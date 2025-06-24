# Configuration and Profile System

## Overview

OrcaSlicer's configuration system is a sophisticated framework that manages print settings, material properties, and printer configurations through a hierarchical system of presets, inheritance, and dynamic validation. The system supports multiple configuration formats, vendor-specific extensions, and real-time UI integration.

## Core Configuration Architecture

### Configuration Hierarchy
Implementation: `src/libslic3r/Config.hpp`, `src/libslic3r/PrintConfig.hpp`

```cpp
// Base configuration interface
class ConfigBase {
public:
    virtual ~ConfigBase() = default;
    
    // Core operations
    virtual ConfigOption* option(const std::string &opt_key) = 0;
    virtual const ConfigOption* option(const std::string &opt_key) const = 0;
    virtual bool has(const std::string &opt_key) const = 0;
    virtual std::set<std::string> keys() const = 0;
    
    // Serialization
    virtual std::string serialize(const std::string &opt_key) const = 0;
    virtual bool deserialize(const std::string &opt_key, const std::string &str, 
                           ConfigSubstitutionContext &substitution_context, bool append = false) = 0;
    
    // Comparison and modification
    virtual bool equals(const ConfigBase &other) const = 0;
    virtual ConfigBase* clone() const = 0;
    virtual void apply(const ConfigBase &other, bool ignore_nonexistent = false) = 0;
    virtual bool empty() const = 0;
    
    // Difference tracking
    virtual std::vector<std::string> diff(const ConfigBase &other) const = 0;
    virtual bool is_compatible(const ConfigBase &other) const = 0;
};

// Static configuration (compile-time defined)
template<class T>
class StaticConfig : public ConfigBase {
public:
    // Template-based option access
    template<typename O>
    const O& get() const { return static_cast<const O&>(option_ref<O>()); }
    
    template<typename O>
    O& get() { return static_cast<O&>(option_ref<O>()); }
    
    // Type-safe option access
    template<typename O>
    const ConfigOption& option_ref() const;
    
    template<typename O>
    ConfigOption& option_ref();
    
protected:
    // Static option registry
    static const ConfigOptionDef* get_option_def(const std::string &key);
    static const std::map<std::string, ConfigOptionDef>& option_defs();
};

// Dynamic configuration (runtime defined)
class DynamicConfig : public ConfigBase {
public:
    DynamicConfig() = default;
    DynamicConfig(const DynamicConfig &other);
    DynamicConfig(DynamicConfig &&other) noexcept;
    
    // Dynamic option management
    void set_key_value(const std::string &key, ConfigOption *option);
    void set_deserialize(const std::string &opt_key, const std::string &str,
                        ConfigSubstitutionContext &substitution_context, bool append = false);
    
    // Option access
    const ConfigOption* option(const std::string &opt_key) const override;
    ConfigOption* option(const std::string &opt_key) override;
    
    // Container operations
    void clear();
    void erase(const std::string &opt_key);
    size_t size() const { return options.size(); }
    
private:
    std::map<std::string, std::unique_ptr<ConfigOption>> options;
};
```

### Configuration Classes Hierarchy

```cpp
// Print configuration
class PrintConfig : public StaticConfig<PrintConfig> {
public:
    // Layer settings
    ConfigOptionFloat layer_height;
    ConfigOptionFloat first_layer_height;
    ConfigOptionPercent first_layer_speed;
    
    // Perimeter settings
    ConfigOptionInt wall_loops;
    ConfigOptionEnum<WallSequence> wall_sequence;
    ConfigOptionEnum<WallDirection> wall_direction;
    ConfigOptionFloatOrPercent line_width;
    
    // Infill settings
    ConfigOptionPercent fill_density;
    ConfigOptionEnum<InfillPattern> fill_pattern;
    ConfigOptionFloat infill_angle;
    ConfigOptionFloat infill_speed;
    
    // Support settings
    ConfigOptionEnum<SupportMaterialStyle> support_material_style;
    ConfigOptionEnum<SupportMaterialPattern> support_material_pattern;
    ConfigOptionFloat support_material_threshold;
    ConfigOptionFloat support_material_spacing;
    
    // Advanced features
    ConfigOptionBool ironing;
    ConfigOptionEnum<IroningType> ironing_type;
    ConfigOptionFloat ironing_flow;
    ConfigOptionFloat ironing_speed;
    
    // Validation
    std::string validate() const override;
    
protected:
    void initialize(StaticCacheBase &cache, const char *base_ptr) override;
};

// Filament configuration
class FilamentConfig : public StaticConfig<FilamentConfig> {
public:
    // Material properties
    ConfigOptionString filament_type;
    ConfigOptionFloats filament_diameter;
    ConfigOptionFloat filament_density;
    ConfigOptionFloat filament_cost;
    ConfigOptionString filament_vendor;
    
    // Temperature settings
    ConfigOptionInts temperature;
    ConfigOptionInts bed_temperature;
    ConfigOptionInts first_layer_temperature;
    ConfigOptionInts first_layer_bed_temperature;
    
    // Flow and speed settings
    ConfigOptionFloat extrusion_multiplier;
    ConfigOptionFloat first_layer_extrusion_multiplier;
    ConfigOptionFloatOrPercent first_layer_speed;
    
    // Retraction settings
    ConfigOptionFloats retract_length;
    ConfigOptionFloats retract_speed;
    ConfigOptionFloats retract_restart_extra;
    ConfigOptionFloats retract_before_travel;
    ConfigOptionBools retract_layer_change;
    
    // Advanced material properties
    ConfigOptionFloat filament_max_volumetric_speed;
    ConfigOptionFloats filament_loading_speed;
    ConfigOptionFloats filament_unloading_speed;
    ConfigOptionString filament_notes;
    
    std::string validate() const override;
    
protected:
    void initialize(StaticCacheBase &cache, const char *base_ptr) override;
};

// Printer configuration
class PrinterConfig : public StaticConfig<PrinterConfig> {
public:
    // Printer identification
    ConfigOptionString printer_model;
    ConfigOptionString printer_variant;
    ConfigOptionString printer_vendor;
    ConfigOptionString printer_notes;
    
    // Physical properties
    ConfigOptionPoints bed_shape;
    ConfigOptionFloat max_print_height;
    ConfigOptionFloat printer_max_diff_layer_height;
    
    // Kinematics and limits
    ConfigOptionFloats machine_max_acceleration_x;
    ConfigOptionFloats machine_max_acceleration_y;
    ConfigOptionFloats machine_max_acceleration_z;
    ConfigOptionFloats machine_max_acceleration_e;
    ConfigOptionFloats machine_max_feedrate_x;
    ConfigOptionFloats machine_max_feedrate_y;
    ConfigOptionFloats machine_max_feedrate_z;
    ConfigOptionFloats machine_max_feedrate_e;
    ConfigOptionFloats machine_max_jerk_x;
    ConfigOptionFloats machine_max_jerk_y;
    ConfigOptionFloats machine_max_jerk_z;
    ConfigOptionFloats machine_max_jerk_e;
    
    // Extruder configuration
    ConfigOptionFloat nozzle_diameter;
    ConfigOptionString extruder_colour;
    ConfigOptionFloats extruder_offset;
    ConfigOptionFloat retract_length;
    ConfigOptionFloat retract_speed;
    
    // G-code settings
    ConfigOptionEnum<GCodeFlavor> gcode_flavor;
    ConfigOptionBool use_relative_e_distances;
    ConfigOptionBool use_firmware_retraction;
    ConfigOptionString start_gcode;
    ConfigOptionString end_gcode;
    ConfigOptionString before_layer_gcode;
    ConfigOptionString layer_gcode;
    ConfigOptionString toolchange_gcode;
    
    std::string validate() const override;
    
protected:
    void initialize(StaticCacheBase &cache, const char *base_ptr) override;
};
```

## Configuration Option Types

### Option Type System
Implementation: `src/libslic3r/Config.hpp`

```cpp
// Base option class
class ConfigOption {
public:
    virtual ~ConfigOption() = default;
    
    // Core operations
    virtual ConfigOption* clone() const = 0;
    virtual bool equals(const ConfigOption &other) const = 0;
    virtual void assign(const ConfigOption &other) = 0;
    virtual std::string serialize() const = 0;
    virtual bool deserialize(const std::string &str, bool append = false) = 0;
    
    // Type information
    virtual ConfigOptionType type() const = 0;
    virtual bool nullable() const { return false; }
    virtual bool is_scalar() const = 0;
    virtual bool is_vector() const { return !is_scalar(); }
    
    // Vector operations (for vector types)
    virtual bool is_nil() const { return false; }
    virtual void clear() {}
    virtual size_t size() const { return is_scalar() ? 1 : 0; }
    virtual ConfigOption* get_at(size_t i) { return nullptr; }
    virtual void resize(size_t n, const ConfigOption *opt_default = nullptr) {}
    
    // Special handling
    virtual bool is_compatible(const ConfigOption &other) const;
    virtual void set_enum_values(const ConfigOptionDef &def) {}
};

// Scalar option template
template<class T>
class ConfigOptionSingle : public ConfigOption {
public:
    T value;
    
    explicit ConfigOptionSingle(T value) : value(value) {}
    ConfigOptionSingle() = default;
    
    // ConfigOption interface
    ConfigOption* clone() const override { return new ConfigOptionSingle<T>(*this); }
    bool equals(const ConfigOption &other) const override;
    void assign(const ConfigOption &other) override;
    std::string serialize() const override;
    bool deserialize(const std::string &str, bool append = false) override;
    bool is_scalar() const override { return true; }
    
    // Type-specific operations
    operator T() const { return value; }
    ConfigOptionSingle<T>& operator=(T val) { value = val; return *this; }
};

// Vector option template
template<class T>
class ConfigOptionVector : public ConfigOption {
public:
    std::vector<T> values;
    
    ConfigOptionVector() = default;
    explicit ConfigOptionVector(size_t n, const T &value) : values(n, value) {}
    explicit ConfigOptionVector(std::initializer_list<T> il) : values(il) {}
    
    // ConfigOption interface
    ConfigOption* clone() const override { return new ConfigOptionVector<T>(*this); }
    bool equals(const ConfigOption &other) const override;
    void assign(const ConfigOption &other) override;
    std::string serialize() const override;
    bool deserialize(const std::string &str, bool append = false) override;
    bool is_scalar() const override { return false; }
    
    // Vector operations
    void clear() override { values.clear(); }
    size_t size() const override { return values.size(); }
    void resize(size_t n, const ConfigOption *opt_default = nullptr) override;
    
    // Element access
    T& get_at(size_t i) { return values[i]; }
    const T& get_at(size_t i) const { return values[i]; }
    void set_at(size_t i, const T &value) { values[i] = value; }
};

// Specific option types
using ConfigOptionFloat = ConfigOptionSingle<double>;
using ConfigOptionFloats = ConfigOptionVector<double>;
using ConfigOptionInt = ConfigOptionSingle<int>;
using ConfigOptionInts = ConfigOptionVector<int>;
using ConfigOptionString = ConfigOptionSingle<std::string>;
using ConfigOptionStrings = ConfigOptionVector<std::string>;
using ConfigOptionPercent = ConfigOptionSingle<double>;  // 0-100 range
using ConfigOptionPercents = ConfigOptionVector<double>;
using ConfigOptionFloatOrPercent = ConfigOptionSingle<FloatOrPercent>;
using ConfigOptionPoint = ConfigOptionSingle<Vec2d>;
using ConfigOptionPoints = ConfigOptionVector<Vec2d>;
using ConfigOptionBool = ConfigOptionSingle<bool>;
using ConfigOptionBools = ConfigOptionVector<bool>;

// Enum option
template<class T>
class ConfigOptionEnum : public ConfigOptionSingle<T> {
public:
    ConfigOptionEnum() : ConfigOptionSingle<T>(T(0)) {}
    explicit ConfigOptionEnum(T val) : ConfigOptionSingle<T>(val) {}
    
    std::string serialize() const override {
        const ConfigOptionEnumDef *def = ConfigOptionEnum<T>::get_enum_def();
        return def ? def->names[static_cast<int>(this->value)] : std::to_string(static_cast<int>(this->value));
    }
    
    bool deserialize(const std::string &str, bool append = false) override {
        const ConfigOptionEnumDef *def = ConfigOptionEnum<T>::get_enum_def();
        if (!def) return false;
        
        return def->deserialize(str, reinterpret_cast<int&>(this->value));
    }
    
private:
    static const ConfigOptionEnumDef* get_enum_def();
};

// Nullable option wrapper
template<class T>
class ConfigOptionNullable : public ConfigOption {
public:
    std::unique_ptr<T> value;
    
    ConfigOptionNullable() = default;
    explicit ConfigOptionNullable(const T &val) : value(std::make_unique<T>(val)) {}
    
    bool nullable() const override { return true; }
    bool is_nil() const override { return !value; }
    
    // Nil operations
    void set_nil() { value.reset(); }
    bool has_value() const { return static_cast<bool>(value); }
    
    // Value access
    const T& get_value() const { return *value; }
    T& get_value() { return *value; }
    void set_value(const T &val) { value = std::make_unique<T>(val); }
};
```

### Option Definitions and Metadata
Implementation: `src/libslic3r/PrintConfig.cpp`

```cpp
struct ConfigOptionDef {
    // Basic properties
    ConfigOptionType type;
    std::string label;
    std::string full_label;  // Label with unit
    std::string category;
    std::string tooltip;
    std::string sidetext;
    std::string cli;
    
    // Value constraints
    std::vector<std::string> enum_values;
    std::vector<std::string> enum_labels;
    double min = 0;
    double max = std::numeric_limits<double>::max();
    double default_value = 0;
    
    // UI behavior
    bool multiline = false;
    bool full_width = false;
    bool readonly = false;
    int height = -1;
    int width = -1;
    std::string mode;  // simple, advanced, expert
    
    // Compatibility and validation
    std::vector<std::string> aliases;
    std::string ratio_over;  // For ratio calculations
    std::string max_literal;  // String representation of max
    std::function<bool(const ConfigOption*)> validate;
    
    // GUI integration
    std::function<void(wxWindow*)> on_value_change;
    bool is_vector_extruder = false;  // Per-extruder vector option
};

// Option definition registry
class ConfigDef {
public:
    std::map<std::string, ConfigOptionDef> options;
    
    // Registration
    ConfigOptionDef& add(const std::string &opt_key, ConfigOptionType type);
    ConfigOptionDef& add_nullable(const std::string &opt_key, ConfigOptionType type);
    
    // Access
    const ConfigOptionDef* get(const std::string &opt_key) const;
    bool has(const std::string &opt_key) const;
    std::vector<std::string> keys() const;
    
    // Validation
    std::string validate(const DynamicConfig &config, bool check_required = true) const;
    void validate_option(const std::string &opt_key, const ConfigOption *opt) const;
    
    // Serialization support
    void save(const DynamicConfig &config, std::ostream &stream) const;
    void load(DynamicConfig &config, std::istream &stream) const;
};
```

## Preset System

### Preset Core Classes
Implementation: `src/libslic3r/Preset.hpp`

```cpp
class Preset {
public:
    enum Type { TYPE_INVALID, TYPE_PRINT, TYPE_FILAMENT, TYPE_PRINTER };
    
    // Preset properties
    Type type;
    std::string name;
    std::string file;
    DynamicConfig config;
    bool is_default;
    bool is_external;
    bool is_system;
    bool is_visible;
    bool is_dirty;
    std::string vendor;
    
    // Inheritance
    std::string inherits;  // Parent preset name
    std::vector<std::string> alias;
    std::string renamed_from;
    
    // Compatibility
    ConfigOptionString compatible_prints;
    ConfigOptionString compatible_printers;
    std::string compatible_prints_condition;
    std::string compatible_printers_condition;
    
    // Construction
    Preset(Type type, const std::string &name, bool is_default = false) 
        : type(type), name(name), is_default(is_default), is_external(false),
          is_system(false), is_visible(true), is_dirty(false) {}
    
    // Core operations
    void save();
    bool load(const std::string &file_path);
    void set_num_extruders(unsigned int num_extruders);
    std::vector<std::string> print_options() const;
    std::vector<std::string> filament_options() const;
    std::vector<std::string> printer_options() const;
    
    // Inheritance and compatibility
    bool is_compatible_with_printer(const Preset &printer) const;
    bool is_compatible_with_print(const Preset &print) const;
    bool is_compatible_with_filament(const Preset &filament) const;
    void set_visible_from_appconfig(const AppConfig &app_config);
    
    // Validation
    std::string validate() const;
    bool validate_option(const std::string &opt_key) const;
    
    // Comparison
    bool operator<(const Preset &other) const { return name < other.name; }
    bool equals(const Preset &other) const;
    
private:
    mutable std::vector<std::string> m_print_options;
    mutable std::vector<std::string> m_filament_options;
    mutable std::vector<std::string> m_printer_options;
};

// Collection of presets of the same type
class PresetCollection {
public:
    Preset::Type type() const { return m_type; }
    std::string name() const;
    const std::string& section_name() const { return m_section_name; }
    
    // Preset management
    size_t size() const { return m_presets.size(); }
    bool empty() const { return m_presets.empty(); }
    void reset(bool delete_files);
    void save_current_preset(const std::string &new_name, bool detach = true);
    bool delete_preset(size_t idx);
    
    // Access
    Preset& preset(size_t idx) { return m_presets[idx]; }
    const Preset& preset(size_t idx) const { return m_presets[idx]; }
    Preset& default_preset() { return m_presets.front(); }
    const Preset& default_preset() const { return m_presets.front(); }
    
    // Search
    Preset* find_preset(const std::string &name, bool first_visible_if_not_found = false);
    const Preset* find_preset(const std::string &name, bool first_visible_if_not_found = false) const;
    size_t get_preset_name_renamed(const std::string &old_name) const;
    
    // Current preset management
    Preset& get_current_preset() { return m_presets[m_idx_selected]; }
    const Preset& get_current_preset() const { return m_presets[m_idx_selected]; }
    size_t get_current_preset_idx() const { return m_idx_selected; }
    void select_preset(size_t idx);
    bool select_preset_by_name(const std::string &name, bool force);
    
    // File operations
    void load_presets(const std::string &dir_path);
    void load_preset(const std::string &file_path, bool save = true);
    Preset& load_external_preset(const std::string &file_path);
    
    // Configuration
    DynamicConfig get_current_config() const;
    void update_config(const DynamicConfig &config);
    std::vector<std::string> current_different_from_parent_keys() const;
    
private:
    Preset::Type m_type;
    std::string m_section_name;
    std::vector<Preset> m_presets;
    size_t m_idx_selected;
    std::string m_dir_path;
    
    // Inheritance resolution
    void update_saved_preset_from_current_preset();
    std::vector<std::string> dirty_options(const Preset *edited = nullptr, 
                                          const Preset *reference = nullptr) const;
};
```

### Preset Bundle System
Implementation: `src/libslic3r/PresetBundle.hpp`

```cpp
class PresetBundle {
public:
    // Preset collections
    PresetCollection prints;
    PresetCollection filaments;
    PresetCollection printers;
    
    // Vendor management
    VendorProfile vendors;
    std::string vendor_profile_name;
    
    // Construction
    PresetBundle();
    ~PresetBundle();
    
    // Initialization
    void setup_directories();
    void load_presets(AppConfig &config, const std::string &preferred_model_id = "");
    void load_installed_printers(AppConfig &config);
    
    // Bundle operations
    void reset(bool delete_files);
    void save_changes_for_current_preset();
    void export_configbundle(const std::string &file_path, bool export_system_settings = false);
    bool load_configbundle(const std::string &file_path, 
                          std::vector<std::string> *loaded_presets = nullptr);
    
    // Configuration access
    DynamicConfig full_config() const;
    DynamicConfig full_config_secure() const;  // Without passwords/keys
    void load_config_from_wizard(const ConfigWizard::RunReason reason, 
                                const DynamicConfig &config);
    
    // Validation and compatibility
    bool is_compatible_with_printer(const Preset &printer) const;
    bool is_compatible_with_print(const Preset &print) const;
    std::string validate() const;
    
    // Updates and synchronization
    bool has_defaul_presets() const;
    bool are_presets_dirty() const;
    void set_default_suppressed(bool default_suppressed);
    UpdateResult update_multi_material_filament_presets();
    void update_compatible_with_printer(bool select_other_if_incompatible);
    
    // Physical printers
    PhysicalPrinterCollection physical_printers;
    std::string get_preset_name_by_alias(const Preset::Type &preset_type, 
                                        const std::string &alias) const;
    
private:
    // Path management
    std::string m_dir_path;
    boost::filesystem::path directory_path(Preset::Type type) const;
    boost::filesystem::path default_preset_path(Preset::Type type, 
                                               const std::string &preset_name) const;
    
    // Loading and saving
    void load_preset_collection(PresetCollection &presets, Preset::Type type, 
                               const std::vector<std::string> &preferred_model_ids);
    void save_preset_collection(const PresetCollection &presets) const;
    
    // Compatibility checking
    void update_compatible(const std::string &preset_name, 
                          const std::string &preset_condition,
                          std::vector<std::string> &preset_names) const;
};
```

## Profile Inheritance and Overrides

### Inheritance Resolution
Implementation: `src/libslic3r/Preset.cpp`

```cpp
class PresetInheritance {
public:
    // Resolve inheritance chain
    static DynamicConfig resolve_inheritance(const Preset &preset, 
                                           const PresetCollection &collection) {
        DynamicConfig resolved_config;
        std::set<std::string> visited;  // Prevent circular inheritance
        
        resolve_recursive(preset, collection, resolved_config, visited);
        return resolved_config;
    }
    
private:
    static void resolve_recursive(const Preset &preset,
                                 const PresetCollection &collection,
                                 DynamicConfig &resolved_config,
                                 std::set<std::string> &visited) {
        
        // Prevent infinite recursion
        if (visited.find(preset.name) != visited.end()) {
            throw std::runtime_error("Circular inheritance detected: " + preset.name);
        }
        visited.insert(preset.name);
        
        // First, resolve parent if exists
        if (!preset.inherits.empty()) {
            const Preset *parent = collection.find_preset(preset.inherits);
            if (parent) {
                resolve_recursive(*parent, collection, resolved_config, visited);
            }
        }
        
        // Then apply current preset's configuration
        resolved_config.apply(preset.config);
        
        visited.erase(preset.name);
    }
};

// Configuration difference tracking
class ConfigDiff {
public:
    struct DiffItem {
        std::string key;
        std::string old_value;
        std::string new_value;
        bool is_addition;
        bool is_deletion;
        bool is_modification;
    };
    
    static std::vector<DiffItem> compute_diff(const DynamicConfig &old_config,
                                            const DynamicConfig &new_config) {
        std::vector<DiffItem> diff;
        
        // Find all keys in both configs
        std::set<std::string> all_keys;
        for (const auto &key : old_config.keys()) all_keys.insert(key);
        for (const auto &key : new_config.keys()) all_keys.insert(key);
        
        for (const std::string &key : all_keys) {
            DiffItem item;
            item.key = key;
            
            bool old_has_key = old_config.has(key);
            bool new_has_key = new_config.has(key);
            
            if (!old_has_key && new_has_key) {
                // Addition
                item.is_addition = true;
                item.new_value = new_config.serialize(key);
            } else if (old_has_key && !new_has_key) {
                // Deletion
                item.is_deletion = true;
                item.old_value = old_config.serialize(key);
            } else if (old_has_key && new_has_key) {
                // Potential modification
                std::string old_val = old_config.serialize(key);
                std::string new_val = new_config.serialize(key);
                
                if (old_val != new_val) {
                    item.is_modification = true;
                    item.old_value = old_val;
                    item.new_value = new_val;
                }
            }
            
            if (item.is_addition || item.is_deletion || item.is_modification) {
                diff.push_back(item);
            }
        }
        
        return diff;
    }
};
```

### Override System
Implementation: Profile-specific override mechanisms

```cpp
class ConfigOverrides {
public:
    struct Override {
        std::string key;
        std::string value;
        std::string condition;  // When to apply override
        int priority;           // Override precedence
        std::string source;     // Source of override (user, vendor, etc.)
    };
    
    // Override management
    void add_override(const std::string &key, const std::string &value,
                     const std::string &condition = "", int priority = 0,
                     const std::string &source = "user");
    void remove_override(const std::string &key);
    void clear_overrides();
    
    // Apply overrides to configuration
    void apply_overrides(DynamicConfig &config, 
                        const DynamicConfig &context = DynamicConfig()) const;
    
    // Query overrides
    bool has_override(const std::string &key) const;
    std::vector<Override> get_overrides_for_key(const std::string &key) const;
    std::vector<Override> get_all_overrides() const;
    
private:
    std::multimap<std::string, Override> m_overrides;
    
    // Condition evaluation
    bool evaluate_condition(const std::string &condition, 
                           const DynamicConfig &context) const;
};

// Per-extruder configuration handling
class PerExtruderConfig {
public:
    // Manage per-extruder vector options
    static void update_extruder_count(DynamicConfig &config, size_t new_count) {
        for (const auto &[key, option] : config.options) {
            if (option->is_vector() && is_extruder_option(key)) {
                resize_extruder_option(option.get(), new_count);
            }
        }
    }
    
    // Get value for specific extruder
    template<typename T>
    static T get_extruder_value(const DynamicConfig &config, 
                               const std::string &key, size_t extruder_id) {
        const ConfigOption *opt = config.option(key);
        if (!opt) return T{};
        
        if (opt->is_scalar()) {
            // Single value applies to all extruders
            return static_cast<const ConfigOptionSingle<T>*>(opt)->value;
        } else {
            // Vector value, get specific extruder
            const auto *vec_opt = static_cast<const ConfigOptionVector<T>*>(opt);
            if (extruder_id < vec_opt->size()) {
                return vec_opt->get_at(extruder_id);
            } else if (!vec_opt->values.empty()) {
                // Use last value if extruder_id is out of range
                return vec_opt->values.back();
            }
        }
        
        return T{};
    }
    
private:
    static bool is_extruder_option(const std::string &key);
    static void resize_extruder_option(ConfigOption *option, size_t new_count);
};
```

## Serialization and Persistence

### Configuration File Formats
Implementation: Multiple serialization backends

```cpp
// INI format serialization
class INIConfigSerialization {
public:
    // Save configuration to INI format
    static void save(const DynamicConfig &config, 
                    const std::string &file_path,
                    const std::string &header_comment = "") {
        std::ofstream file(file_path);
        if (!file.is_open()) {
            throw std::runtime_error("Cannot open file for writing: " + file_path);
        }
        
        if (!header_comment.empty()) {
            file << "# " << header_comment << std::endl;
        }
        
        // Write configuration options
        for (const std::string &key : config.keys()) {
            const ConfigOption *opt = config.option(key);
            if (opt) {
                file << key << " = " << opt->serialize() << std::endl;
            }
        }
    }
    
    // Load configuration from INI format
    static DynamicConfig load(const std::string &file_path,
                             ConfigSubstitutionContext &substitution_context) {
        DynamicConfig config;
        std::ifstream file(file_path);
        
        if (!file.is_open()) {
            throw std::runtime_error("Cannot open file for reading: " + file_path);
        }
        
        std::string line;
        int line_number = 0;
        
        while (std::getline(file, line)) {
            ++line_number;
            
            // Skip comments and empty lines
            boost::trim(line);
            if (line.empty() || line[0] == '#' || line[0] == ';') {
                continue;
            }
            
            // Parse key=value pairs
            size_t eq_pos = line.find('=');
            if (eq_pos == std::string::npos) {
                throw std::runtime_error("Invalid syntax at line " + 
                                       std::to_string(line_number) + ": " + line);
            }
            
            std::string key = line.substr(0, eq_pos);
            std::string value = line.substr(eq_pos + 1);
            boost::trim(key);
            boost::trim(value);
            
            // Deserialize option
            try {
                config.set_deserialize(key, value, substitution_context);
            } catch (const std::exception &e) {
                throw std::runtime_error("Error parsing line " + 
                                       std::to_string(line_number) + ": " + e.what());
            }
        }
        
        return config;
    }
};

// JSON format serialization
class JSONConfigSerialization {
public:
    // Convert configuration to JSON
    static nlohmann::json to_json(const DynamicConfig &config) {
        nlohmann::json json_config;
        
        for (const std::string &key : config.keys()) {
            const ConfigOption *opt = config.option(key);
            if (!opt) continue;
            
            // Convert option to JSON based on type
            switch (opt->type()) {
                case coFloat:
                case coPercent:
                    json_config[key] = static_cast<const ConfigOptionFloat*>(opt)->value;
                    break;
                case coFloats:
                case coPercents:
                    json_config[key] = static_cast<const ConfigOptionFloats*>(opt)->values;
                    break;
                case coInt:
                    json_config[key] = static_cast<const ConfigOptionInt*>(opt)->value;
                    break;
                case coInts:
                    json_config[key] = static_cast<const ConfigOptionInts*>(opt)->values;
                    break;
                case coString:
                    json_config[key] = static_cast<const ConfigOptionString*>(opt)->value;
                    break;
                case coStrings:
                    json_config[key] = static_cast<const ConfigOptionStrings*>(opt)->values;
                    break;
                case coBool:
                    json_config[key] = static_cast<const ConfigOptionBool*>(opt)->value;
                    break;
                case coBools:
                    json_config[key] = static_cast<const ConfigOptionBools*>(opt)->values;
                    break;
                default:
                    // For complex types, serialize as string
                    json_config[key] = opt->serialize();
                    break;
            }
        }
        
        return json_config;
    }
    
    // Create configuration from JSON
    static DynamicConfig from_json(const nlohmann::json &json_config,
                                  ConfigSubstitutionContext &substitution_context) {
        DynamicConfig config;
        
        for (const auto &[key, value] : json_config.items()) {
            std::string str_value;
            
            // Convert JSON value to string for deserialization
            if (value.is_string()) {
                str_value = value.get<std::string>();
            } else if (value.is_number()) {
                str_value = std::to_string(value.get<double>());
            } else if (value.is_boolean()) {
                str_value = value.get<bool>() ? "1" : "0";
            } else if (value.is_array()) {
                // Convert array to comma-separated string
                std::vector<std::string> elements;
                for (const auto &elem : value) {
                    if (elem.is_string()) {
                        elements.push_back(elem.get<std::string>());
                    } else {
                        elements.push_back(elem.dump());
                    }
                }
                str_value = boost::join(elements, ",");
            } else {
                str_value = value.dump();
            }
            
            config.set_deserialize(key, str_value, substitution_context);
        }
        
        return config;
    }
};

// Binary format for efficient storage
class BinaryConfigSerialization {
public:
    struct Header {
        uint32_t magic = 0x43464742;  // "BGFC" - Binary G-code File Config
        uint32_t version = 1;
        uint32_t num_options;
        uint32_t data_size;
    };
    
    // Save configuration in binary format
    static void save(const DynamicConfig &config, const std::string &file_path) {
        std::ofstream file(file_path, std::ios::binary);
        if (!file.is_open()) {
            throw std::runtime_error("Cannot open file for writing: " + file_path);
        }
        
        // Prepare data
        std::vector<std::pair<std::string, std::string>> serialized_options;
        for (const std::string &key : config.keys()) {
            const ConfigOption *opt = config.option(key);
            if (opt) {
                serialized_options.emplace_back(key, opt->serialize());
            }
        }
        
        // Write header
        Header header;
        header.num_options = static_cast<uint32_t>(serialized_options.size());
        file.write(reinterpret_cast<const char*>(&header), sizeof(header));
        
        // Write options
        for (const auto &[key, value] : serialized_options) {
            write_string(file, key);
            write_string(file, value);
        }
    }
    
private:
    static void write_string(std::ofstream &file, const std::string &str) {
        uint32_t length = static_cast<uint32_t>(str.length());
        file.write(reinterpret_cast<const char*>(&length), sizeof(length));
        file.write(str.c_str(), length);
    }
    
    static std::string read_string(std::ifstream &file) {
        uint32_t length;
        file.read(reinterpret_cast<char*>(&length), sizeof(length));
        
        std::string str(length, '\0');
        file.read(&str[0], length);
        return str;
    }
};
```

## Configuration Validation

### Validation Framework
Implementation: `src/libslic3r/Config.cpp`

```cpp
class ConfigValidator {
public:
    struct ValidationResult {
        bool is_valid;
        std::vector<std::string> errors;
        std::vector<std::string> warnings;
        std::map<std::string, std::string> substitutions;
    };
    
    // Main validation entry point
    static ValidationResult validate_config(const DynamicConfig &config,
                                          const ConfigDef &config_def) {
        ValidationResult result;
        result.is_valid = true;
        
        // Validate each option
        for (const std::string &key : config.keys()) {
            const ConfigOption *opt = config.option(key);
            const ConfigOptionDef *def = config_def.get(key);
            
            if (!def) {
                result.warnings.push_back("Unknown option: " + key);
                continue;
            }
            
            auto option_result = validate_option(key, opt, def);
            merge_validation_results(result, option_result);
        }
        
        // Check for missing required options
        auto required_result = check_required_options(config, config_def);
        merge_validation_results(result, required_result);
        
        // Cross-option validation
        auto cross_result = validate_cross_dependencies(config, config_def);
        merge_validation_results(result, cross_result);
        
        return result;
    }
    
private:
    // Individual option validation
    static ValidationResult validate_option(const std::string &key,
                                          const ConfigOption *opt,
                                          const ConfigOptionDef *def) {
        ValidationResult result;
        result.is_valid = true;
        
        if (!opt) {
            result.errors.push_back("Option " + key + " is null");
            result.is_valid = false;
            return result;
        }
        
        // Type checking
        if (opt->type() != def->type) {
            result.errors.push_back("Option " + key + " has wrong type");
            result.is_valid = false;
            return result;
        }
        
        // Range validation for numeric types
        if (def->type == coFloat || def->type == coPercent) {
            const auto *float_opt = static_cast<const ConfigOptionFloat*>(opt);
            if (float_opt->value < def->min || float_opt->value > def->max) {
                result.errors.push_back("Option " + key + " value " + 
                                      std::to_string(float_opt->value) +
                                      " is out of range [" + std::to_string(def->min) +
                                      ", " + std::to_string(def->max) + "]");
                result.is_valid = false;
            }
        }
        
        // Enum validation
        if (def->type == coEnum && !def->enum_values.empty()) {
            std::string serialized = opt->serialize();
            auto it = std::find(def->enum_values.begin(), def->enum_values.end(), serialized);
            if (it == def->enum_values.end()) {
                result.errors.push_back("Option " + key + " has invalid enum value: " + serialized);
                result.is_valid = false;
            }
        }
        
        // Custom validation function
        if (def->validate && !def->validate(opt)) {
            result.errors.push_back("Option " + key + " failed custom validation");
            result.is_valid = false;
        }
        
        return result;
    }
    
    // Cross-option dependency validation
    static ValidationResult validate_cross_dependencies(const DynamicConfig &config,
                                                       const ConfigDef &config_def) {
        ValidationResult result;
        result.is_valid = true;
        
        // Example: Validate support material dependencies
        if (config.has("support_material") && 
            static_cast<const ConfigOptionBool*>(config.option("support_material"))->value) {
            
            if (!config.has("support_material_threshold")) {
                result.errors.push_back("Support material enabled but threshold not specified");
                result.is_valid = false;
            }
        }
        
        // Example: Validate multi-material settings
        if (config.has("filament_diameter")) {
            const auto *diameters = static_cast<const ConfigOptionFloats*>(
                config.option("filament_diameter"));
            
            if (config.has("extruder_count")) {
                const auto *extruder_count = static_cast<const ConfigOptionInt*>(
                    config.option("extruder_count"));
                
                if (diameters->size() != static_cast<size_t>(extruder_count->value)) {
                    result.warnings.push_back("Filament diameter count doesn't match extruder count");
                }
            }
        }
        
        return result;
    }
};

// Configuration substitution system
class ConfigSubstitutionContext {
public:
    enum Rule {
        ForwardCompatibilitySubstitutionRule,
        EnableSilentSubstitutionRule,
        DisableSubstitutionRule
    };
    
    Rule rule;
    std::map<std::string, std::string> substitutions;
    
    explicit ConfigSubstitutionContext(Rule rule) : rule(rule) {}
    
    // Record a substitution
    void substitute(const std::string &opt_key, const std::string &old_value, 
                   const std::string &new_value) {
        if (rule != DisableSubstitutionRule) {
            substitutions[opt_key] = old_value + " -> " + new_value;
        }
    }
    
    // Check if substitution is allowed
    bool is_substitution_allowed(const std::string &opt_key) const {
        switch (rule) {
            case ForwardCompatibilitySubstitutionRule:
                return true;  // Allow all substitutions for compatibility
            case EnableSilentSubstitutionRule:
                return true;  // Allow but don't report
            case DisableSubstitutionRule:
                return false; // No substitutions allowed
            default:
                return false;
        }
    }
    
    // Get substitution report
    std::vector<std::string> get_substitution_report() const {
        std::vector<std::string> report;
        for (const auto &[key, substitution] : substitutions) {
            report.push_back(key + ": " + substitution);
        }
        return report;
    }
};
```

## UI Integration

### Configuration Tabs
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
    
    // UI state
    bool m_is_modified_values;
    bool m_is_nonsys_values;
    bool m_postpone_update_ui;
    
    // Construction
    explicit Tab(wxBookCtrlBase* parent, const wxString& title, 
                Preset::Type type, bool no_controller = false);
    virtual ~Tab() = default;
    
    // Configuration management
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
    
    // Validation
    bool validate_custom_gcodes();
    bool current_preset_is_dirty() const;
    std::vector<std::string> get_dependent_tabs() const;
    
protected:
    // UI building
    virtual void build() = 0;
    virtual void build_preset_description_line(ConfigOptionsGroup* optgroup) = 0;
    virtual void update_description_lines() = 0;
    virtual void toggle_options() = 0;
    
    // Page management
    wxScrolledWindow* add_options_page(const wxString& title, 
                                      const std::string& icon, bool is_extruder_pages = false);
    ConfigOptionsGroup* new_optgroup(const wxString& title, int noncommon_label_width = -1);
    
    // Option handling
    void on_option_changed(const std::string& opt_key);
    void update_changed_tree_ui();
    void changed_value(const std::string& opt_key, const boost::any& value);
    
    // Preset operations
    void select_preset(std::string preset_name, bool delete_current = false, 
                      const std::string& last_selected_ph_printer_name = "");
    bool may_discard_current_dirty_preset(PresetCollection* presets = nullptr,
                                         const std::string& new_printer_name = "");
    
private:
    // UI components
    wxChoice* m_presets_choice;
    ScalableButton* m_btn_save_preset;
    ScalableButton* m_btn_delete_preset;
    wxBitmapButton* m_btn_hide_incompatible_presets;
    
    // Page management
    std::vector<wxScrolledWindow*> m_pages;
    std::vector<ConfigOptionsGroup*> m_optgroups;
    
    // State tracking
    std::map<std::string, wxColour> m_colored_Label_colors;
    std::map<std::string, bool> m_options_list;
};

// Specific tab implementations
class TabPrint : public Tab {
public:
    TabPrint(wxBookCtrlBase* parent) : Tab(parent, _L("Print Settings"), Preset::TYPE_PRINT) {}
    
protected:
    void build() override;
    void build_preset_description_line(ConfigOptionsGroup* optgroup) override;
    void update_description_lines() override;
    void toggle_options() override;
    
private:
    void build_layers_page();
    void build_perimeters_page();
    void build_infill_page();
    void build_support_page();
    void build_speed_page();
    void build_advanced_page();
};

class TabFilament : public Tab {
public:
    TabFilament(wxBookCtrlBase* parent) : Tab(parent, _L("Filament Settings"), Preset::TYPE_FILAMENT) {}
    
protected:
    void build() override;
    void build_preset_description_line(ConfigOptionsGroup* optgroup) override;
    void update_description_lines() override;
    void toggle_options() override;
    
private:
    void build_filament_page();
    void build_temperature_page();
    void build_cooling_page();
    void build_advanced_page();
    void build_retraction_page();
};

class TabPrinter : public Tab {
public:
    TabPrinter(wxBookCtrlBase* parent) : Tab(parent, _L("Printer Settings"), Preset::TYPE_PRINTER) {}
    
protected:
    void build() override;
    void build_preset_description_line(ConfigOptionsGroup* optgroup) override;
    void update_description_lines() override;
    void toggle_options() override;
    
private:
    void build_general_page();
    void build_extruder_page();
    void build_bed_shape_page();
    void build_machine_limits_page();
    void build_firmware_page();
    void build_gcode_page();
};
```

### Real-time Configuration Updates
Implementation: Event-driven configuration synchronization

```cpp
class ConfigUpdateManager {
public:
    // Configuration change notification
    struct ConfigChangeEvent {
        std::string option_key;
        boost::any old_value;
        boost::any new_value;
        Tab* source_tab;
        std::chrono::steady_clock::time_point timestamp;
    };
    
    // Event handling
    using ConfigChangeCallback = std::function<void(const ConfigChangeEvent&)>;
    
    void register_callback(const std::string &option_key, ConfigChangeCallback callback);
    void unregister_callback(const std::string &option_key);
    void notify_change(const ConfigChangeEvent &event);
    
    // Batch updates
    void begin_batch_update();
    void end_batch_update();
    bool is_batch_updating() const { return m_batch_updating; }
    
    // Update scheduling
    void schedule_update(const std::string &option_key, 
                        std::chrono::milliseconds delay = std::chrono::milliseconds(100));
    void cancel_scheduled_update(const std::string &option_key);
    
private:
    std::multimap<std::string, ConfigChangeCallback> m_callbacks;
    std::vector<ConfigChangeEvent> m_batch_events;
    bool m_batch_updating = false;
    
    // Scheduled updates
    std::map<std::string, std::chrono::steady_clock::time_point> m_scheduled_updates;
    std::thread m_update_thread;
    std::atomic<bool> m_shutdown_requested;
    
    void update_thread_loop();
    void process_scheduled_updates();
};

// Cross-tab dependency management
class TabDependencyManager {
public:
    struct Dependency {
        std::string dependent_option;
        std::string dependency_option;
        std::function<bool(const ConfigOption*)> condition;
        std::function<void(Tab*)> update_action;
    };
    
    void add_dependency(const Dependency &dep);
    void remove_dependency(const std::string &dependent_option);
    void update_dependencies(const std::string &changed_option, Tab* source_tab);
    
private:
    std::multimap<std::string, Dependency> m_dependencies;
    
    void check_and_update_dependency(const Dependency &dep, Tab* source_tab);
};
```

## Performance Considerations

### Memory Management
```cpp
class ConfigMemoryManager {
public:
    // Configuration caching
    class ConfigCache {
    public:
        void cache_config(const std::string &key, const DynamicConfig &config);
        const DynamicConfig* get_cached_config(const std::string &key) const;
        void clear_cache();
        void set_cache_size_limit(size_t max_size);
        
    private:
        struct CacheEntry {
            DynamicConfig config;
            std::chrono::steady_clock::time_point last_access;
            size_t access_count;
        };
        
        mutable std::map<std::string, CacheEntry> m_cache;
        size_t m_max_cache_size = 100;
        
        void evict_lru_entries();
    };
    
    // Memory pool for config options
    template<typename T>
    class OptionPool {
    public:
        T* acquire() {
            std::lock_guard<std::mutex> lock(m_mutex);
            
            if (!m_available.empty()) {
                T* option = m_available.back();
                m_available.pop_back();
                return option;
            }
            
            return new T();
        }
        
        void release(T* option) {
            if (!option) return;
            
            std::lock_guard<std::mutex> lock(m_mutex);
            
            // Reset option to default state
            *option = T();
            
            if (m_available.size() < m_max_pool_size) {
                m_available.push_back(option);
            } else {
                delete option;
            }
        }
        
    private:
        std::vector<T*> m_available;
        std::mutex m_mutex;
        size_t m_max_pool_size = 50;
    };
    
private:
    ConfigCache m_config_cache;
    OptionPool<ConfigOptionFloat> m_float_pool;
    OptionPool<ConfigOptionInt> m_int_pool;
    OptionPool<ConfigOptionString> m_string_pool;
};
```

### Threading and Concurrency
```cpp
class ThreadSafeConfigManager {
public:
    // Thread-safe configuration access
    class ConfigLock {
    public:
        ConfigLock(const DynamicConfig &config, std::shared_mutex &mutex)
            : m_config(config), m_lock(mutex) {}
        
        const DynamicConfig& config() const { return m_config; }
        
    private:
        const DynamicConfig &m_config;
        std::shared_lock<std::shared_mutex> m_lock;
    };
    
    class ConfigWriteLock {
    public:
        ConfigWriteLock(DynamicConfig &config, std::shared_mutex &mutex)
            : m_config(config), m_lock(mutex) {}
        
        DynamicConfig& config() { return m_config; }
        
    private:
        DynamicConfig &m_config;
        std::unique_lock<std::shared_mutex> m_lock;
    };
    
    // Safe access methods
    ConfigLock read_config() const {
        return ConfigLock(m_config, m_mutex);
    }
    
    ConfigWriteLock write_config() {
        return ConfigWriteLock(m_config, m_mutex);
    }
    
    // Atomic operations
    void atomic_update(const std::string &key, const std::string &value) {
        std::unique_lock<std::shared_mutex> lock(m_mutex);
        ConfigSubstitutionContext ctx(ConfigSubstitutionContext::EnableSilentSubstitutionRule);
        m_config.set_deserialize(key, value, ctx);
    }
    
    std::string atomic_read(const std::string &key) const {
        std::shared_lock<std::shared_mutex> lock(m_mutex);
        const ConfigOption *opt = m_config.option(key);
        return opt ? opt->serialize() : std::string();
    }
    
private:
    DynamicConfig m_config;
    mutable std::shared_mutex m_mutex;
};
```

## Odin Rewrite Considerations

### Architecture Recommendations

**Type System Modernization**:
```odin
// Example Odin configuration system design
Config_Option_Type :: enum {
    FLOAT,
    INT,
    STRING,
    BOOL,
    ENUM,
    VECTOR_FLOAT,
    VECTOR_INT,
    VECTOR_STRING,
    VECTOR_BOOL,
}

Config_Option :: struct {
    type: Config_Option_Type,
    value: union {
        float_val: f64,
        int_val: i32,
        string_val: string,
        bool_val: bool,
        enum_val: i32,
        vector_float: []f64,
        vector_int: []i32,
        vector_string: []string,
        vector_bool: []bool,
    },
}

Config :: struct {
    options: map[string]Config_Option,
    metadata: map[string]Config_Option_Def,
}

Config_Option_Def :: struct {
    label: string,
    tooltip: string,
    category: string,
    min_value: f64,
    max_value: f64,
    default_value: Config_Option,
    is_visible: bool,
    validation_proc: proc(option: ^Config_Option) -> bool,
}
```

**Performance Improvements**:
1. **Enum-based Keys**: Use enums instead of strings for better performance
2. **Memory Layout**: Optimize data structures for cache locality
3. **Parallel Processing**: Leverage Odin's threading capabilities
4. **Serialization**: Implement efficient binary protocols

**Error Handling**:
```odin
Config_Error :: enum {
    NONE,
    INVALID_TYPE,
    OUT_OF_RANGE,
    MISSING_REQUIRED,
    CIRCULAR_INHERITANCE,
    VALIDATION_FAILED,
}

Config_Result :: struct {
    value: Config_Option,
    error: Config_Error,
    message: string,
}

validate_config :: proc(config: ^Config) -> []Config_Result {
    // Implementation with explicit error handling
}
```

**Simplification Opportunities**:
1. **Reduce Inheritance Complexity**: Simpler composition-based approach
2. **Static Typing**: Leverage Odin's type system for compile-time checking
3. **Immutable Configurations**: Prefer immutable config objects
4. **Functional Validation**: Pure validation functions

The configuration system represents the backbone of OrcaSlicer's flexibility and extensibility. A successful Odin rewrite should preserve the powerful preset system and validation framework while modernizing the implementation for better performance, type safety, and maintainability.