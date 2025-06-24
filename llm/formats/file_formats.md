# File Format Implementations

## Overview

OrcaSlicer supports a comprehensive range of file formats for 3D printing, from mesh formats like STL and 3MF to CAD formats like STEP, plus configuration files and G-code processing. The implementation emphasizes robustness, performance, and extensive metadata support.

## 3MF Format Support

### 3MF Core Implementation
Implementation: `src/libslic3r/Format/3mf.cpp`

```cpp
class _3MF_Importer {
public:
    struct ObjectMetadata {
        Transform3d transform;
        bool printable;
        std::string name;
        std::map<std::string, std::string> custom_properties;
    };
    
    // Main import interface
    bool load_model_from_file(const std::string& filename, Model& model,
                             DynamicPrintConfig& config, ConfigSubstitutionContext& substitution_context,
                             bool check_version = true);
    
    // Archive handling
    bool _extract_from_archive(mz_zip_archive& archive, const mz_zip_archive_file_stat& stat,
                              std::vector<char>& data);
    bool _extract_xml_from_archive(mz_zip_archive& archive, const mz_zip_archive_file_stat& stat,
                                  std::string& xml_content);
    
    // Model processing
    bool _handle_start_model(const char** attributes);
    bool _handle_start_object(const char** attributes);
    bool _handle_start_mesh(const char** attributes);
    bool _handle_start_vertices(const char** attributes);
    bool _handle_start_vertex(const char** attributes);
    bool _handle_start_triangles(const char** attributes);
    bool _handle_start_triangle(const char** attributes);
    bool _handle_start_components(const char** attributes);
    bool _handle_start_component(const char** attributes);
    bool _handle_start_build(const char** attributes);
    bool _handle_start_item(const char** attributes);
    
private:
    // XML parsing state
    struct Object {
        ModelObject* object;
        std::vector<coordf_t> vertices;
        std::vector<int> triangles;
        std::map<std::string, std::string> metadata;
    };
    
    // Archive contents
    mz_zip_archive* m_archive;
    std::string m_archive_filename;
    Model* m_model;
    float m_unit_factor;
    int m_curr_object_id;
    bool m_curr_object_invalid;
    std::map<int, Object> m_objects;
    std::map<int, ObjectMetadata> m_objects_metadata;
    
    // XML parser
    XML_Parser m_xml_parser;
    std::string m_curr_metadata_name;
    std::string m_curr_characters;
};

// 3MF structure validation
struct _3MF_Validator {
    static bool validate_archive_structure(mz_zip_archive& archive) {
        // Check required files
        std::vector<std::string> required_files = {
            "[Content_Types].xml",
            "_rels/.rels",
            "3D/3dmodel.model"
        };
        
        for (const auto& file : required_files) {
            if (mz_zip_reader_locate_file(&archive, file.c_str(), nullptr, 0) < 0) {
                return false;
            }
        }
        
        return true;
    }
    
    static bool validate_model_xml(const std::string& xml_content) {
        // XML schema validation would go here
        return !xml_content.empty();
    }
};
```

### Bambu Lab 3MF Extensions
Implementation: Custom extensions to standard 3MF

```cpp
namespace Bambu3MF {
    // Custom metadata keys
    constexpr const char* OBJECT_TYPE = "object_type";
    constexpr const char* SUPPORT_TYPE = "support_type";
    constexpr const char* EXTRUDER_ID = "extruder_id";
    constexpr const char* PRINT_SEQUENCE = "print_sequence";
    
    // Plate extensions
    struct PlateData {
        std::string name;
        Vec3d origin;
        std::vector<int> object_instances;
        bool locked;
        std::map<std::string, std::string> settings_overrides;
    };
    
    // Multi-plate support
    class PlateManager {
    public:
        void add_plate(const PlateData& plate);
        void remove_plate(int plate_id);
        std::vector<PlateData> get_all_plates() const;
        
        // Serialization
        void serialize_to_xml(std::ostream& stream) const;
        bool deserialize_from_xml(const std::string& xml_content);
        
    private:
        std::vector<PlateData> m_plates;
        int m_next_plate_id = 1;
    };
    
    // Custom object types
    enum ObjectType {
        NORMAL_OBJECT,
        SUPPORT_OBJECT,
        MODIFIER_OBJECT,
        NEGATIVE_OBJECT
    };
    
    // Project metadata
    struct ProjectMetadata {
        std::string orca_version;
        std::string creation_time;
        std::string modification_time;
        std::string author;
        std::string description;
        std::map<std::string, std::string> custom_settings;
        std::vector<std::string> filament_ids;
        std::vector<std::string> filament_colors;
    };
}
```

### 3MF Export Implementation
```cpp
class _3MF_Exporter {
public:
    bool save_model_to_file(const std::string& filename, Model& model,
                           const DynamicPrintConfig& config, bool export_print_config = true,
                           const ThumbnailData* thumbnail_data = nullptr);
    
private:
    struct BuildItem {
        unsigned int id;
        Transform3d transform;
        bool printable;
    };
    
    // Archive creation
    bool _create_archive(const std::string& filename);
    bool _add_content_types_file_to_archive(mz_zip_writer& writer);
    bool _add_relationships_file_to_archive(mz_zip_writer& writer);
    bool _add_model_file_to_archive(mz_zip_writer& writer, Model& model, 
                                   const DynamicPrintConfig& config);
    bool _add_custom_files_to_archive(mz_zip_writer& writer, Model& model);
    bool _add_thumbnail_file_to_archive(mz_zip_writer& writer, 
                                       const ThumbnailData& thumbnail_data);
    
    // XML generation
    void _add_mesh_to_object_stream(std::ostringstream& stream, ModelObject& object);
    void _add_object_to_model_stream(std::ostringstream& stream, unsigned int& object_id,
                                    ModelObject& object, BuildItemsList& build_items);
    void _add_build_to_model_stream(std::ostringstream& stream, const BuildItemsList& build_items);
    void _add_layer_height_profile_file_to_archive(mz_zip_writer& writer, Model& model);
    void _add_layer_config_ranges_file_to_archive(mz_zip_writer& writer, Model& model);
    void _add_sla_support_points_file_to_archive(mz_zip_writer& writer, Model& model);
    void _add_sla_drain_holes_file_to_archive(mz_zip_writer& writer, Model& model);
    void _add_print_config_file_to_archive(mz_zip_writer& writer, const DynamicPrintConfig& config);
    void _add_model_config_file_to_archive(mz_zip_writer& writer, const Model& model);
    
    // ZIP archive management
    mz_zip_archive* m_archive;
    std::string m_temp_dir;
};
```

## STL Format Handling

### STL Import/Export
Implementation: `src/libslic3r/TriangleMesh.cpp`

```cpp
class STLParser {
public:
    // Format detection
    static bool is_binary_stl(const std::string& filename) {
        std::ifstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
        // Read header (80 bytes) + triangle count (4 bytes)
        char header[80];
        uint32_t triangle_count;
        
        file.read(header, 80);
        file.read(reinterpret_cast<char*>(&triangle_count), 4);
        
        // Check if file size matches expected binary STL size
        file.seekg(0, std::ios::end);
        size_t file_size = file.tellg();
        size_t expected_size = 80 + 4 + (triangle_count * 50); // 50 bytes per triangle
        
        return file_size == expected_size;
    }
    
    // Binary STL parsing
    static bool load_binary_stl(const std::string& filename, TriangleMesh& mesh) {
        std::ifstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
        // Skip 80-byte header
        file.seekg(80);
        
        // Read triangle count
        uint32_t triangle_count;
        file.read(reinterpret_cast<char*>(&triangle_count), 4);
        
        mesh.clear();
        mesh.reserve(triangle_count);
        
        for (uint32_t i = 0; i < triangle_count; ++i) {
            // Read normal vector (12 bytes) - currently ignored
            float normal[3];
            file.read(reinterpret_cast<char*>(normal), 12);
            
            // Read three vertices (36 bytes)
            Vec3f vertices[3];
            for (int j = 0; j < 3; ++j) {
                file.read(reinterpret_cast<char*>(&vertices[j]), 12);
            }
            
            // Skip attribute byte count (2 bytes)
            file.seekg(2, std::ios::cur);
            
            // Add triangle to mesh
            mesh.add_triangle(vertices[0], vertices[1], vertices[2]);
        }
        
        return true;
    }
    
    // ASCII STL parsing
    static bool load_ascii_stl(const std::string& filename, TriangleMesh& mesh) {
        std::ifstream file(filename);
        if (!file.is_open()) return false;
        
        std::string line;
        Vec3f vertices[3];
        int vertex_index = 0;
        
        while (std::getline(file, line)) {
            boost::trim(line);
            
            if (boost::starts_with(line, "vertex ")) {
                std::istringstream iss(line.substr(7)); // Skip "vertex "
                iss >> vertices[vertex_index].x() >> vertices[vertex_index].y() >> vertices[vertex_index].z();
                vertex_index++;
                
                if (vertex_index == 3) {
                    mesh.add_triangle(vertices[0], vertices[1], vertices[2]);
                    vertex_index = 0;
                }
            }
        }
        
        return true;
    }
};

// STL export
class STLExporter {
public:
    static bool save_binary_stl(const std::string& filename, const TriangleMesh& mesh) {
        std::ofstream file(filename, std::ios::binary);
        if (!file.is_open()) return false;
        
        // Write 80-byte header
        char header[80] = "Binary STL exported by OrcaSlicer";
        file.write(header, 80);
        
        // Write triangle count
        uint32_t triangle_count = static_cast<uint32_t>(mesh.facets_count());
        file.write(reinterpret_cast<const char*>(&triangle_count), 4);
        
        // Write triangles
        for (const auto& facet : mesh.facets()) {
            // Write normal (calculated from vertices)
            Vec3f normal = (facet.vertex[1] - facet.vertex[0]).cross(facet.vertex[2] - facet.vertex[0]).normalized();
            file.write(reinterpret_cast<const char*>(&normal), 12);
            
            // Write vertices
            for (int i = 0; i < 3; ++i) {
                file.write(reinterpret_cast<const char*>(&facet.vertex[i]), 12);
            }
            
            // Write attribute byte count (always 0)
            uint16_t attribute = 0;
            file.write(reinterpret_cast<const char*>(&attribute), 2);
        }
        
        return true;
    }
    
    static bool save_ascii_stl(const std::string& filename, const TriangleMesh& mesh) {
        std::ofstream file(filename);
        if (!file.is_open()) return false;
        
        file << "solid Exported from OrcaSlicer\n";
        
        for (const auto& facet : mesh.facets()) {
            Vec3f normal = (facet.vertex[1] - facet.vertex[0]).cross(facet.vertex[2] - facet.vertex[0]).normalized();
            
            file << "  facet normal " << normal.x() << " " << normal.y() << " " << normal.z() << "\n";
            file << "    outer loop\n";
            
            for (int i = 0; i < 3; ++i) {
                file << "      vertex " << facet.vertex[i].x() << " " << facet.vertex[i].y() << " " << facet.vertex[i].z() << "\n";
            }
            
            file << "    endloop\n";
            file << "  endfacet\n";
        }
        
        file << "endsolid Exported from OrcaSlicer\n";
        
        return true;
    }
};
```

### STL Mesh Repair Integration
Implementation: Using `admesh` library

```cpp
class STLRepair {
public:
    struct RepairStats {
        int degenerate_facets;
        int removed_facets;
        int filled_holes;
        int backwards_edges;
        bool watertight_achieved;
    };
    
    static RepairStats repair_mesh(TriangleMesh& mesh, bool aggressive = false) {
        RepairStats stats = {};
        
        // Convert to admesh format
        stl_file stl;
        mesh_to_stl(mesh, stl);
        
        // Basic repairs
        stl_check_facets_exact(&stl);
        stats.degenerate_facets = stl.stats.degenerate_facets;
        
        if (stl.stats.degenerate_facets > 0) {
            stl_remove_degenerate(&stl);
            stats.removed_facets += stl.stats.facets_removed;
        }
        
        // Fix normals
        stl_fix_normal_directions(&stl);
        stl_fix_normal_values(&stl);
        
        // Remove duplicate vertices
        stl_remove_duplicate_vertices(&stl);
        
        if (aggressive) {
            // More aggressive repairs
            stl_fill_holes(&stl);
            stats.filled_holes = stl.stats.holes_filled;
            
            stl_repair(&stl, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        }
        
        // Check if mesh is watertight
        stl_verify_neighbors(&stl);
        stats.watertight_achieved = (stl.stats.backwards_edges == 0);
        stats.backwards_edges = stl.stats.backwards_edges;
        
        // Convert back to TriangleMesh
        stl_to_mesh(stl, mesh);
        
        return stats;
    }
    
private:
    static void mesh_to_stl(const TriangleMesh& mesh, stl_file& stl);
    static void stl_to_mesh(const stl_file& stl, TriangleMesh& mesh);
};
```

## OBJ Format Support

### OBJ Parser Implementation
Implementation: `src/libslic3r/Format/OBJ.cpp`

```cpp
class OBJParser {
public:
    struct Material {
        std::string name;
        Vec3f ambient;
        Vec3f diffuse;
        Vec3f specular;
        float shininess;
        std::string diffuse_texture;
        std::string normal_texture;
    };
    
    struct Group {
        std::string name;
        std::string material_name;
        std::vector<int> face_indices;
    };
    
    // Main parsing interface
    bool load_obj(const std::string& filename, TriangleMesh& mesh,
                 std::vector<Material>& materials, std::vector<Group>& groups) {
        
        std::ifstream file(filename);
        if (!file.is_open()) return false;
        
        std::vector<Vec3f> vertices;
        std::vector<Vec3f> normals;
        std::vector<Vec2f> texcoords;
        std::vector<Vec3i> faces;
        
        std::string current_group;
        std::string current_material;
        
        std::string line;
        while (std::getline(file, line)) {
            boost::trim(line);
            
            if (line.empty() || line[0] == '#') continue;
            
            std::istringstream iss(line);
            std::string token;
            iss >> token;
            
            if (token == "v") {
                // Vertex coordinates
                Vec3f vertex;
                iss >> vertex.x() >> vertex.y() >> vertex.z();
                vertices.push_back(vertex);
                
            } else if (token == "vn") {
                // Vertex normals
                Vec3f normal;
                iss >> normal.x() >> normal.y() >> normal.z();
                normals.push_back(normal);
                
            } else if (token == "vt") {
                // Texture coordinates
                Vec2f texcoord;
                iss >> texcoord.x() >> texcoord.y();
                texcoords.push_back(texcoord);
                
            } else if (token == "f") {
                // Faces
                parse_face_line(iss, faces);
                
            } else if (token == "g") {
                // Group
                iss >> current_group;
                
            } else if (token == "usemtl") {
                // Material
                iss >> current_material;
                
            } else if (token == "mtllib") {
                // Material library
                std::string mtl_filename;
                iss >> mtl_filename;
                load_mtl_file(get_directory(filename) + "/" + mtl_filename, materials);
            }
        }
        
        // Convert to TriangleMesh
        mesh.clear();
        for (const auto& face : faces) {
            mesh.add_triangle(vertices[face.x()], vertices[face.y()], vertices[face.z()]);
        }
        
        return true;
    }
    
private:
    void parse_face_line(std::istringstream& iss, std::vector<Vec3i>& faces) {
        std::vector<std::string> face_vertices;
        std::string vertex_data;
        
        while (iss >> vertex_data) {
            face_vertices.push_back(vertex_data);
        }
        
        // Triangulate faces (assuming they're already triangles or quads)
        if (face_vertices.size() >= 3) {
            for (size_t i = 1; i < face_vertices.size() - 1; ++i) {
                Vec3i triangle;
                triangle.x() = parse_vertex_index(face_vertices[0]);
                triangle.y() = parse_vertex_index(face_vertices[i]);
                triangle.z() = parse_vertex_index(face_vertices[i + 1]);
                faces.push_back(triangle);
            }
        }
    }
    
    int parse_vertex_index(const std::string& vertex_data) {
        // Parse "v/vt/vn" format
        size_t slash_pos = vertex_data.find('/');
        std::string vertex_index_str = (slash_pos != std::string::npos) ? 
            vertex_data.substr(0, slash_pos) : vertex_data;
        
        int index = std::stoi(vertex_index_str);
        return (index > 0) ? index - 1 : index; // Convert to 0-based indexing
    }
    
    bool load_mtl_file(const std::string& filename, std::vector<Material>& materials) {
        std::ifstream file(filename);
        if (!file.is_open()) return false;
        
        Material current_material;
        bool has_material = false;
        
        std::string line;
        while (std::getline(file, line)) {
            boost::trim(line);
            
            if (line.empty() || line[0] == '#') continue;
            
            std::istringstream iss(line);
            std::string token;
            iss >> token;
            
            if (token == "newmtl") {
                if (has_material) {
                    materials.push_back(current_material);
                }
                current_material = Material();
                iss >> current_material.name;
                has_material = true;
                
            } else if (token == "Ka") {
                iss >> current_material.ambient.x() >> current_material.ambient.y() >> current_material.ambient.z();
                
            } else if (token == "Kd") {
                iss >> current_material.diffuse.x() >> current_material.diffuse.y() >> current_material.diffuse.z();
                
            } else if (token == "Ks") {
                iss >> current_material.specular.x() >> current_material.specular.y() >> current_material.specular.z();
                
            } else if (token == "Ns") {
                iss >> current_material.shininess;
                
            } else if (token == "map_Kd") {
                iss >> current_material.diffuse_texture;
                
            } else if (token == "map_Bump" || token == "bump") {
                iss >> current_material.normal_texture;
            }
        }
        
        if (has_material) {
            materials.push_back(current_material);
        }
        
        return true;
    }
    
    std::string get_directory(const std::string& filepath) {
        size_t last_slash = filepath.find_last_of("/\\");
        return (last_slash != std::string::npos) ? filepath.substr(0, last_slash) : "";
    }
};
```

## STEP/CAD Format Integration

### OpenCASCADE Integration
Implementation: `src/libslic3r/Format/STEP.cpp`

```cpp
class STEPImporter {
public:
    struct ImportSettings {
        double linear_deflection = 0.1;
        double angular_deflection = 0.1;
        bool optimize_mesh = true;
        bool merge_surfaces = true;
        int max_faces_per_object = 100000;
    };
    
    // Main import interface
    bool load_step_file(const std::string& filename, Model& model, 
                       const ImportSettings& settings = ImportSettings()) {
        
        try {
            // Initialize OpenCASCADE
            STEPCAFControl_Reader reader;
            IFSelect_ReturnStatus status = reader.ReadFile(filename.c_str());
            
            if (status != IFSelect_RetDone) {
                return false;
            }
            
            // Get document
            Handle(TDocStd_Document) doc;
            if (!reader.Transfer(doc)) {
                return false;
            }
            
            // Extract shapes
            Handle(XCAFDoc_ShapeTool) shape_tool = XCAFDoc_DocumentTool::ShapeTool(doc->Main());
            Handle(XCAFDoc_ColorTool) color_tool = XCAFDoc_DocumentTool::ColorTool(doc->Main());
            
            TDF_LabelSequence labels;
            shape_tool->GetFreeShapes(labels);
            
            for (int i = 1; i <= labels.Length(); ++i) {
                TDF_Label label = labels.Value(i);
                TopoDS_Shape shape = shape_tool->GetShape(label);
                
                if (!shape.IsNull()) {
                    process_shape(shape, model, color_tool, settings);
                }
            }
            
            return true;
            
        } catch (const Standard_Failure& e) {
            return false;
        }
    }
    
private:
    void process_shape(const TopoDS_Shape& shape, Model& model,
                      Handle(XCAFDoc_ColorTool) color_tool,
                      const ImportSettings& settings) {
        
        // Tessellate the shape
        BRepMesh_IncrementalMesh mesh_gen(shape, settings.linear_deflection,
                                        false, settings.angular_deflection);
        
        if (!mesh_gen.IsDone()) {
            return;
        }
        
        // Extract mesh data
        ModelObject* model_object = model.add_object();
        TriangleMesh* mesh = new TriangleMesh();
        
        // Iterate through faces
        for (TopExp_Explorer face_exp(shape, TopAbs_FACE); face_exp.More(); face_exp.Next()) {
            TopoDS_Face face = TopoDS::Face(face_exp.Current());
            extract_mesh_from_face(face, *mesh, settings);
        }
        
        // Optimize mesh if requested
        if (settings.optimize_mesh) {
            mesh->repair();
            mesh->merge_vertices();
        }
        
        model_object->add_volume(*mesh);
        
        // Extract color information
        Quantity_Color color;
        if (color_tool->GetColor(shape, XCAFDoc_ColorSurf, color)) {
            // Convert color to RGB
            // This would be stored in object metadata
        }
    }
    
    void extract_mesh_from_face(const TopoDS_Face& face, TriangleMesh& mesh,
                               const ImportSettings& settings) {
        
        TopLoc_Location location;
        Handle(Poly_Triangulation) triangulation = BRep_Tool::Triangulation(face, location);
        
        if (triangulation.IsNull()) {
            return;
        }
        
        // Get transformation
        gp_Trsf transform = location.Transformation();
        
        // Extract vertices
        std::vector<Vec3f> vertices;
        for (int i = 1; i <= triangulation->NbNodes(); ++i) {
            gp_Pnt point = triangulation->Node(i);
            point.Transform(transform);
            vertices.emplace_back(point.X(), point.Y(), point.Z());
        }
        
        // Extract triangles
        for (int i = 1; i <= triangulation->NbTriangles(); ++i) {
            const Poly_Triangle& triangle = triangulation->Triangle(i);
            int n1, n2, n3;
            triangle.Get(n1, n2, n3);
            
            // Convert to 0-based indexing and handle orientation
            bool reversed = (face.Orientation() == TopAbs_REVERSED);
            if (reversed) {
                mesh.add_triangle(vertices[n1-1], vertices[n3-1], vertices[n2-1]);
            } else {
                mesh.add_triangle(vertices[n1-1], vertices[n2-1], vertices[n3-1]);
            }
        }
    }
};

// Encoding detection for STEP files
class STEPEncodingDetector {
public:
    enum Encoding {
        UTF8,
        LATIN1,
        WINDOWS1252,
        UNKNOWN
    };
    
    static Encoding detect_encoding(const std::string& filename) {
        std::ifstream file(filename, std::ios::binary);
        if (!file.is_open()) return UNKNOWN;
        
        // Read first few KB to analyze
        std::vector<char> buffer(4096);
        file.read(buffer.data(), buffer.size());
        size_t bytes_read = file.gcount();
        
        // Check for BOM
        if (bytes_read >= 3 && 
            static_cast<unsigned char>(buffer[0]) == 0xEF &&
            static_cast<unsigned char>(buffer[1]) == 0xBB &&
            static_cast<unsigned char>(buffer[2]) == 0xBF) {
            return UTF8;
        }
        
        // Analyze byte patterns
        int high_ascii_count = 0;
        int total_chars = 0;
        
        for (size_t i = 0; i < bytes_read; ++i) {
            unsigned char c = buffer[i];
            if (c >= 32 && c <= 126) {
                // Standard ASCII
                total_chars++;
            } else if (c >= 128) {
                // High ASCII/Unicode
                high_ascii_count++;
                total_chars++;
            }
        }
        
        if (total_chars == 0) return UNKNOWN;
        
        double high_ascii_ratio = static_cast<double>(high_ascii_count) / total_chars;
        
        if (high_ascii_ratio < 0.05) return UTF8;      // Mostly ASCII, likely UTF-8
        if (high_ascii_ratio < 0.30) return LATIN1;    // Some extended chars
        return WINDOWS1252;                             // Many extended chars
    }
};
```

## G-code Processing

### G-code Parser
Implementation: `src/libslic3r/GCodeProcessor.cpp`

```cpp
class GCodeProcessor {
public:
    enum EMoveType : unsigned char {
        Noop,
        Retract,
        Unretract,
        Seam,
        Tool_change,
        Color_change,
        Pause_Print,
        Custom_GCode,
        Travel,
        Wipe,
        Extrude
    };
    
    struct MoveVertex {
        EMoveType type;
        ExtrusionRole extrusion_role;
        unsigned char extruder_id;
        unsigned char cp_color_id;
        Vec3f position;
        float delta_extruder;
        float feedrate;
        float width;
        float height;
        float fan_speed;
        float temperature;
        float volumetric_rate;
        int64_t layer_id;
        int64_t move_id;
        float time;
    };
    
    struct Result {
        std::vector<MoveVertex> moves;
        std::vector<ExtrusionRole> roles;
        Pointfs bed_shape;
        float extruders_count;
        std::vector<std::vector<float>> filament_diameters;
        std::vector<std::vector<float>> filament_densities;
        PrintEstimatedStatistics print_statistics;
        std::vector<CustomGCode::Item> custom_gcode_per_print_z;
    };
    
    // Main processing interface
    void process_file(const std::string& filename, bool apply_postprocess = true);
    void process_buffer(const std::string& buffer);
    const Result& get_result() const { return m_result; }
    
    // Real-time processing
    void reset();
    void process_line(const std::string& line);
    void finalize();
    
private:
    // Parser state
    struct State {
        Vec3f position = Vec3f::Zero();
        float e = 0.0f;
        float f = 0.0f;          // Feedrate
        int tool = 0;            // Current tool
        int fan_speed = 0;       // Fan speed (0-255)
        float temperature = 0.0f; // Hotend temperature
        float bed_temperature = 0.0f;
        bool absolute_positioning = true;
        bool absolute_e = true;
        GCodeFlavor flavor = gcfMarlinFirmware;
    };
    
    State m_state;
    Result m_result;
    
    // Line parsing
    void parse_line(const std::string& line);
    void process_command(const std::string& command, const std::map<char, float>& params);
    
    // Command handlers
    void process_G0_G1(const std::map<char, float>& params);
    void process_G2_G3(const std::map<char, float>& params, bool clockwise);
    void process_G28(const std::map<char, float>& params);  // Home
    void process_G90_G91(bool absolute);                     // Positioning mode
    void process_M104_M109(const std::map<char, float>& params); // Set temperature
    void process_M106_M107(const std::map<char, float>& params); // Fan control
    void process_M140_M190(const std::map<char, float>& params); // Bed temperature
    void process_T(int tool);                                 // Tool change
    
    // Move analysis
    EMoveType classify_move(const Vec3f& start_pos, const Vec3f& end_pos, 
                           float delta_e, float feedrate);
    ExtrusionRole detect_extrusion_role(const MoveVertex& move);
    
    // Arc processing
    void process_arc(const Vec3f& start, const Vec3f& end, const Vec3f& center, 
                    bool clockwise, float delta_e, float feedrate);
    std::vector<Vec3f> tessellate_arc(const Vec3f& start, const Vec3f& end, 
                                    const Vec3f& center, bool clockwise, int segments = 16);
    
    // Time estimation
    struct TimeEstimator {
        struct Axis {
            float position;
            float max_feedrate;
            float max_acceleration;
            float max_jerk;
        };
        
        std::array<Axis, 4> axes; // XYZE
        
        float calculate_time(const Vec3f& target, float feedrate, float delta_e);
        void simulate_move(const Vec3f& target, float feedrate, float delta_e);
    };
    
    TimeEstimator m_time_estimator;
    
    // Adaptive pressure advance processing
    void process_adaptive_pressure_advance(MoveVertex& move);
    double interpolate_pressure_advance(double flow_rate, unsigned int extruder_id);
};

// G-code line parser utilities
class GCodeLineParser {
public:
    static std::map<char, float> parse_parameters(const std::string& line) {
        std::map<char, float> params;
        
        for (size_t i = 0; i < line.length(); ++i) {
            char param_char = std::toupper(line[i]);
            
            if (std::isalpha(param_char) && i + 1 < line.length()) {
                size_t end_pos = i + 1;
                
                // Find end of parameter value
                while (end_pos < line.length() && 
                       (std::isdigit(line[end_pos]) || line[end_pos] == '.' || 
                        line[end_pos] == '-' || line[end_pos] == '+')) {
                    end_pos++;
                }
                
                if (end_pos > i + 1) {
                    try {
                        float value = std::stof(line.substr(i + 1, end_pos - i - 1));
                        params[param_char] = value;
                    } catch (const std::exception&) {
                        // Ignore invalid numbers
                    }
                    
                    i = end_pos - 1; // -1 because loop will increment
                }
            }
        }
        
        return params;
    }
    
    static std::string extract_command(const std::string& line) {
        std::string trimmed = boost::trim_copy(line);
        
        // Find first space or parameter
        size_t space_pos = trimmed.find(' ');
        size_t param_pos = std::string::npos;
        
        for (size_t i = 1; i < trimmed.length(); ++i) {
            if (std::isalpha(trimmed[i])) {
                param_pos = i;
                break;
            }
        }
        
        size_t end_pos = std::min(space_pos, param_pos);
        if (end_pos == std::string::npos) {
            end_pos = trimmed.length();
        }
        
        return trimmed.substr(0, end_pos);
    }
    
    static bool is_comment_line(const std::string& line) {
        std::string trimmed = boost::trim_copy(line);
        return trimmed.empty() || trimmed[0] == ';' || trimmed[0] == '(' || 
               boost::starts_with(trimmed, "//");
    }
    
    static std::string remove_comment(const std::string& line) {
        size_t comment_pos = line.find(';');
        if (comment_pos != std::string::npos) {
            return boost::trim_copy(line.substr(0, comment_pos));
        }
        return boost::trim_copy(line);
    }
};
```

## Configuration File Formats

### JSON Configuration
Implementation: Using nlohmann/json library

```cpp
class JSONConfigHandler {
public:
    // Serialization
    template<typename ConfigType>
    static nlohmann::json serialize_config(const ConfigType& config) {
        nlohmann::json j;
        
        for (const std::string& key : config.keys()) {
            const ConfigOption* opt = config.option(key);
            if (!opt) continue;
            
            switch (opt->type()) {
                case coFloat:
                case coPercent:
                    j[key] = static_cast<const ConfigOptionFloat*>(opt)->value;
                    break;
                case coFloats:
                case coPercents:
                    j[key] = static_cast<const ConfigOptionFloats*>(opt)->values;
                    break;
                case coInt:
                    j[key] = static_cast<const ConfigOptionInt*>(opt)->value;
                    break;
                case coInts:
                    j[key] = static_cast<const ConfigOptionInts*>(opt)->values;
                    break;
                case coString:
                    j[key] = static_cast<const ConfigOptionString*>(opt)->value;
                    break;
                case coStrings:
                    j[key] = static_cast<const ConfigOptionStrings*>(opt)->values;
                    break;
                case coBool:
                    j[key] = static_cast<const ConfigOptionBool*>(opt)->value;
                    break;
                case coBools:
                    j[key] = static_cast<const ConfigOptionBools*>(opt)->values;
                    break;
                case coEnum:
                    j[key] = opt->serialize(); // Use string representation
                    break;
                default:
                    j[key] = opt->serialize();
                    break;
            }
        }
        
        return j;
    }
    
    // Deserialization
    template<typename ConfigType>
    static bool deserialize_config(const nlohmann::json& j, ConfigType& config,
                                  ConfigSubstitutionContext& substitution_context) {
        try {
            for (const auto& [key, value] : j.items()) {
                std::string str_value;
                
                if (value.is_string()) {
                    str_value = value.get<std::string>();
                } else if (value.is_number()) {
                    str_value = std::to_string(value.get<double>());
                } else if (value.is_boolean()) {
                    str_value = value.get<bool>() ? "1" : "0";
                } else if (value.is_array()) {
                    std::vector<std::string> elements;
                    for (const auto& elem : value) {
                        elements.push_back(elem.dump());
                    }
                    str_value = boost::join(elements, ",");
                } else {
                    str_value = value.dump();
                }
                
                config.set_deserialize(key, str_value, substitution_context);
            }
            
            return true;
        } catch (const std::exception& e) {
            return false;
        }
    }
    
    // Validation
    static bool validate_json_structure(const nlohmann::json& j, 
                                       const std::vector<std::string>& required_keys) {
        if (!j.is_object()) return false;
        
        for (const std::string& key : required_keys) {
            if (j.find(key) == j.end()) {
                return false;
            }
        }
        
        return true;
    }
    
    // Schema validation
    static bool validate_against_schema(const nlohmann::json& j, 
                                       const nlohmann::json& schema) {
        // Implement JSON schema validation
        // This would use a library like nlohmann/json-schema-validator
        return true; // Simplified
    }
};

// Cereal serialization for binary configs
template<class Archive>
class CerealConfigSerializer {
public:
    template<typename ConfigType>
    static void serialize(Archive& archive, const ConfigType& config) {
        // Version for compatibility
        uint32_t version = 1;
        archive(version);
        
        // Serialize all options
        auto keys = config.keys();
        archive(keys);
        
        for (const std::string& key : keys) {
            const ConfigOption* opt = config.option(key);
            if (opt) {
                serialize_option(archive, key, opt);
            }
        }
    }
    
    template<typename ConfigType>
    static void deserialize(Archive& archive, ConfigType& config) {
        uint32_t version;
        archive(version);
        
        if (version > 1) {
            throw std::runtime_error("Unsupported config version");
        }
        
        std::vector<std::string> keys;
        archive(keys);
        
        for (const std::string& key : keys) {
            deserialize_option(archive, key, config);
        }
    }
    
private:
    template<class Archive>
    static void serialize_option(Archive& archive, const std::string& key, 
                                const ConfigOption* opt) {
        ConfigOptionType type = opt->type();
        archive(type);
        
        switch (type) {
            case coFloat:
                archive(static_cast<const ConfigOptionFloat*>(opt)->value);
                break;
            case coFloats:
                archive(static_cast<const ConfigOptionFloats*>(opt)->values);
                break;
            // ... handle other types
        }
    }
    
    template<class Archive, typename ConfigType>
    static void deserialize_option(Archive& archive, const std::string& key,
                                  ConfigType& config) {
        ConfigOptionType type;
        archive(type);
        
        switch (type) {
            case coFloat: {
                double value;
                archive(value);
                config.set(key, ConfigOptionFloat(value));
                break;
            }
            case coFloats: {
                std::vector<double> values;
                archive(values);
                config.set(key, ConfigOptionFloats(values));
                break;
            }
            // ... handle other types
        }
    }
};
```

## Error Handling and Validation

### Universal File Validator
```cpp
class FileFormatValidator {
public:
    enum ValidationLevel {
        BASIC,      // File exists and has correct extension
        STRUCTURAL, // Valid file structure
        SEMANTIC,   // Content makes sense
        STRICT      // Rigorous validation
    };
    
    struct ValidationResult {
        bool is_valid;
        std::vector<std::string> errors;
        std::vector<std::string> warnings;
        std::map<std::string, std::string> metadata;
    };
    
    static ValidationResult validate_file(const std::string& filename, 
                                         ValidationLevel level = STRUCTURAL) {
        ValidationResult result;
        result.is_valid = true;
        
        // Detect file format
        std::string extension = get_file_extension(filename);
        boost::to_lower(extension);
        
        if (extension == ".3mf") {
            return validate_3mf(filename, level);
        } else if (extension == ".stl") {
            return validate_stl(filename, level);
        } else if (extension == ".obj") {
            return validate_obj(filename, level);
        } else if (extension == ".step" || extension == ".stp") {
            return validate_step(filename, level);
        } else if (extension == ".gcode" || extension == ".gco") {
            return validate_gcode(filename, level);
        } else {
            result.is_valid = false;
            result.errors.push_back("Unsupported file format: " + extension);
        }
        
        return result;
    }
    
private:
    static ValidationResult validate_3mf(const std::string& filename, ValidationLevel level) {
        ValidationResult result;
        result.is_valid = true;
        
        // Check if file is a valid ZIP archive
        mz_zip_archive archive;
        memset(&archive, 0, sizeof(archive));
        
        if (!mz_zip_reader_init_file(&archive, filename.c_str(), 0)) {
            result.is_valid = false;
            result.errors.push_back("Not a valid ZIP archive");
            return result;
        }
        
        // Check required files
        if (level >= STRUCTURAL) {
            std::vector<std::string> required_files = {
                "[Content_Types].xml",
                "_rels/.rels",
                "3D/3dmodel.model"
            };
            
            for (const std::string& file : required_files) {
                if (mz_zip_reader_locate_file(&archive, file.c_str(), nullptr, 0) < 0) {
                    result.is_valid = false;
                    result.errors.push_back("Missing required file: " + file);
                }
            }
        }
        
        // Validate XML structure
        if (level >= SEMANTIC && result.is_valid) {
            // Extract and validate 3dmodel.model
            std::string model_xml;
            if (extract_file_from_archive(archive, "3D/3dmodel.model", model_xml)) {
                if (!validate_3mf_xml(model_xml)) {
                    result.warnings.push_back("Invalid 3MF XML structure");
                }
            }
        }
        
        mz_zip_reader_end(&archive);
        return result;
    }
    
    static ValidationResult validate_stl(const std::string& filename, ValidationLevel level) {
        ValidationResult result;
        result.is_valid = true;
        
        std::ifstream file(filename, std::ios::binary | std::ios::ate);
        if (!file.is_open()) {
            result.is_valid = false;
            result.errors.push_back("Cannot open file");
            return result;
        }
        
        size_t file_size = file.tellg();
        file.seekg(0);
        
        if (file_size < 84) { // Minimum binary STL size
            result.is_valid = false;
            result.errors.push_back("File too small to be valid STL");
            return result;
        }
        
        // Try to determine if binary or ASCII
        bool is_binary = STLParser::is_binary_stl(filename);
        result.metadata["format"] = is_binary ? "binary" : "ascii";
        
        if (level >= STRUCTURAL) {
            if (is_binary) {
                // Validate binary STL structure
                file.seekg(80); // Skip header
                uint32_t triangle_count;
                file.read(reinterpret_cast<char*>(&triangle_count), 4);
                
                size_t expected_size = 80 + 4 + (triangle_count * 50);
                if (file_size != expected_size) {
                    result.warnings.push_back("File size doesn't match triangle count");
                }
                
                result.metadata["triangle_count"] = std::to_string(triangle_count);
            } else {
                // Validate ASCII STL structure
                file.seekg(0);
                std::string first_line;
                std::getline(file, first_line);
                
                if (!boost::starts_with(boost::trim_copy(first_line), "solid")) {
                    result.warnings.push_back("ASCII STL doesn't start with 'solid'");
                }
            }
        }
        
        return result;
    }
    
    static ValidationResult validate_gcode(const std::string& filename, ValidationLevel level) {
        ValidationResult result;
        result.is_valid = true;
        
        std::ifstream file(filename);
        if (!file.is_open()) {
            result.is_valid = false;
            result.errors.push_back("Cannot open file");
            return result;
        }
        
        if (level >= STRUCTURAL) {
            std::string line;
            int line_number = 0;
            bool has_valid_commands = false;
            
            while (std::getline(file, line) && line_number < 100) { // Check first 100 lines
                line_number++;
                
                if (GCodeLineParser::is_comment_line(line)) continue;
                
                std::string command = GCodeLineParser::extract_command(line);
                if (is_valid_gcode_command(command)) {
                    has_valid_commands = true;
                }
            }
            
            if (!has_valid_commands) {
                result.warnings.push_back("No valid G-code commands found in first 100 lines");
            }
        }
        
        return result;
    }
    
    static bool is_valid_gcode_command(const std::string& command) {
        if (command.empty()) return false;
        
        char first_char = std::toupper(command[0]);
        return (first_char == 'G' || first_char == 'M' || first_char == 'T');
    }
    
    static std::string get_file_extension(const std::string& filename) {
        size_t dot_pos = filename.find_last_of('.');
        return (dot_pos != std::string::npos) ? filename.substr(dot_pos) : "";
    }
};
```

## Performance Optimizations

### Streaming File Processors
```cpp
template<typename DataType>
class StreamingFileProcessor {
public:
    using ProcessorFn = std::function<void(const DataType&)>;
    using CompletionFn = std::function<void(bool success, const std::string& error)>;
    
    StreamingFileProcessor(size_t buffer_size = 1024 * 1024) // 1MB default
        : m_buffer_size(buffer_size) {}
    
    void process_file_async(const std::string& filename, 
                           ProcessorFn processor, 
                           CompletionFn completion) {
        
        std::thread([this, filename, processor, completion]() {
            try {
                std::ifstream file(filename, std::ios::binary);
                if (!file.is_open()) {
                    completion(false, "Cannot open file");
                    return;
                }
                
                std::vector<char> buffer(m_buffer_size);
                DataType current_object;
                
                while (file.read(buffer.data(), buffer.size()) || file.gcount() > 0) {
                    size_t bytes_read = file.gcount();
                    
                    if (parse_buffer(buffer.data(), bytes_read, current_object)) {
                        processor(current_object);
                        current_object = DataType(); // Reset for next object
                    }
                    
                    if (m_cancel_requested) {
                        completion(false, "Cancelled by user");
                        return;
                    }
                }
                
                completion(true, "");
                
            } catch (const std::exception& e) {
                completion(false, e.what());
            }
        }).detach();
    }
    
    void cancel() {
        m_cancel_requested = true;
    }
    
private:
    size_t m_buffer_size;
    std::atomic<bool> m_cancel_requested{false};
    
    virtual bool parse_buffer(const char* data, size_t size, DataType& object) = 0;
};

// Memory-mapped file reader for large files
class MemoryMappedFileReader {
public:
    MemoryMappedFileReader(const std::string& filename) {
#ifdef _WIN32
        m_file_handle = CreateFileA(filename.c_str(), GENERIC_READ, FILE_SHARE_READ,
                                   nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (m_file_handle == INVALID_HANDLE_VALUE) return;
        
        LARGE_INTEGER file_size;
        if (!GetFileSizeEx(m_file_handle, &file_size)) return;
        m_file_size = file_size.QuadPart;
        
        m_mapping_handle = CreateFileMappingA(m_file_handle, nullptr, PAGE_READONLY, 0, 0, nullptr);
        if (!m_mapping_handle) return;
        
        m_data = static_cast<const char*>(MapViewOfFile(m_mapping_handle, FILE_MAP_READ, 0, 0, 0));
#else
        m_fd = open(filename.c_str(), O_RDONLY);
        if (m_fd == -1) return;
        
        struct stat st;
        if (fstat(m_fd, &st) == -1) return;
        m_file_size = st.st_size;
        
        m_data = static_cast<const char*>(mmap(nullptr, m_file_size, PROT_READ, MAP_PRIVATE, m_fd, 0));
        if (m_data == MAP_FAILED) m_data = nullptr;
#endif
    }
    
    ~MemoryMappedFileReader() {
#ifdef _WIN32
        if (m_data) UnmapViewOfFile(m_data);
        if (m_mapping_handle) CloseHandle(m_mapping_handle);
        if (m_file_handle != INVALID_HANDLE_VALUE) CloseHandle(m_file_handle);
#else
        if (m_data && m_data != MAP_FAILED) munmap(const_cast<char*>(m_data), m_file_size);
        if (m_fd != -1) close(m_fd);
#endif
    }
    
    bool is_valid() const { return m_data != nullptr; }
    const char* data() const { return m_data; }
    size_t size() const { return m_file_size; }
    
private:
    const char* m_data = nullptr;
    size_t m_file_size = 0;
    
#ifdef _WIN32
    HANDLE m_file_handle = INVALID_HANDLE_VALUE;
    HANDLE m_mapping_handle = nullptr;
#else
    int m_fd = -1;
#endif
};
```

## Odin Rewrite Considerations

### Modern File Format Architecture
```odin
// Example Odin file format system
File_Format :: enum {
    STL,
    OBJ,
    THREEMF,
    STEP,
    GCODE,
    JSON_CONFIG,
}

File_Parser :: interface {
    parse: proc(filename: string, result: ^$T) -> (bool, Error),
    validate: proc(filename: string) -> (Validation_Result, Error),
    get_metadata: proc(filename: string) -> (map[string]string, Error),
}

File_Writer :: interface {
    write: proc(filename: string, data: $T) -> Error,
    write_stream: proc(stream: ^io.Writer, data: $T) -> Error,
}

// Async file processing
File_Processor :: struct {
    parser: File_Parser,
    writer: File_Writer,
    buffer_size: int,
    thread_pool: ^Thread_Pool,
}

parse_file_async :: proc(processor: ^File_Processor, filename: string, 
                        callback: proc(result: $T, error: Error)) {
    // Implementation using Odin's async capabilities
}
```

**Key Improvements for Odin**:
1. **Type Safety**: Stronger typing with compile-time validation
2. **Memory Safety**: No buffer overflows or memory leaks
3. **Performance**: Zero-cost abstractions and SIMD optimizations
4. **Error Handling**: Explicit error types with stack traces
5. **Streaming**: Built-in async I/O for large files
6. **Extensibility**: Plugin system for new formats

**Implementation Strategy**:
1. **Phase 1**: Core parsers (STL, 3MF, JSON)
2. **Phase 2**: Validation and error handling systems
3. **Phase 3**: Streaming and async I/O
4. **Phase 4**: Advanced formats (STEP, specialized formats)
5. **Phase 5**: Optimization and platform-specific features

The file format system represents a critical foundation that would benefit significantly from Odin's memory safety, performance characteristics, and modern language features while maintaining compatibility with existing file standards.