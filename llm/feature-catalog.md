# OrcaSlicer Complete Feature Catalog

## Overview

This document provides a comprehensive catalog of every feature available in OrcaSlicer, organized by functional category. Each feature includes implementation details, configuration parameters, and user interface locations.

## 1. File Format Support

### Import Formats
- **3MF** - 3D Manufacturing Format (primary)
  - Implementation: `src/libslic3r/Format/3mf.cpp`
  - Location: File → Import → Import 3MF/STL/STEP/SVG/OBJ/AMF
  - Features: Full project support, metadata, materials, plate info

- **STL** - Stereolithography format
  - Implementation: `src/libslic3r/TriangleMesh.cpp`
  - ASCII and binary support
  - Unit detection and conversion

- **STEP** - Standard for Exchange of Product Data
  - Implementation: `src/libslic3r/Format/STEP.cpp`
  - CAD-quality import with precise geometry

- **OBJ** - Wavefront OBJ format
  - Implementation: `src/libslic3r/Format/OBJ.cpp`
  - Material support via MTL files

- **AMF** - Additive Manufacturing File Format
  - Implementation: `src/libslic3r/Format/AMF.cpp`
  - Multi-material and color support

- **SVG** - Scalable Vector Graphics
  - Implementation: `src/libslic3r/SVG.cpp`
  - For 2D profiles and custom shapes

- **Zip Archives** - Batch import
  - Location: File → Import → Import Zip Archive
  - Multi-file processing

### Export Formats
- **3MF Export** - Standard and Generic
  - Location: File → Export → Export Generic 3MF
  - Preserves all project data

- **STL Export** - Single or batch
  - Location: File → Export → Export all objects as one STL/STLs
  - Merged or individual file options

- **G-code Export** - Printer-ready output
  - Location: File → Export → Export G-code
  - Flavor-specific formatting

- **Sliced File Export** - Complete projects
  - Location: File → Export → Export plate/all plate sliced file
  - Includes settings and preview data

- **Preset Bundle Export** - Configuration sharing
  - Location: File → Export → Export Preset Bundle
  - Complete configuration packages

## 2. Print Settings Configuration

### Layer Settings
- **Layer Height** (`layer_height`)
  - Implementation: `src/libslic3r/PrintConfig.cpp:538`
  - Range: 0.05-0.5mm (printer dependent)
  - Quality vs speed trade-off

- **Initial Layer Height** (`initial_layer_height`)
  - Enhanced first layer adhesion
  - Typically 150-200% of layer height
  - Bed adhesion optimization

- **Variable Layer Height**
  - Implementation: `src/slic3r/GUI/GLCanvas3D.cpp`
  - Location: Right-click model → Variable layer height
  - Adaptive quality based on geometry
  - Real-time preview

### Wall/Perimeter Settings
- **Wall Loops** (`wall_loops`)
  - Implementation: `src/libslic3r/PerimeterGenerator.cpp`
  - Number of perimeter walls (1-10)
  - Strength and surface quality control

- **Wall Sequence** (`wall_sequence`)
  - Options: Inner-Outer, Outer-Inner, Inner-Outer-Inner
  - Implementation: `src/libslic3r/PrintConfig.hpp:86-91`
  - Print quality optimization

- **Wall Direction** (`wall_direction`)
  - Options: Auto, Clockwise, Counter-clockwise
  - Implementation: `src/libslic3r/PrintConfig.hpp:94-100`
  - Seam placement control

- **Wall-Infill Order** (`wall_infill_order`)
  - Options: Inner-Outer-Infill, Outer-Inner-Infill, etc.
  - Implementation: `src/libslic3r/PrintConfig.hpp:76-83`
  - Print sequence optimization

- **Speed Settings**
  - External Wall Speed (`outer_wall_speed`)
  - Internal Wall Speed (`inner_wall_speed`)
  - Quality vs speed balance

### Infill System

#### Infill Patterns (`fill_pattern`)
Implementation: `src/libslic3r/PrintConfig.hpp:60-65`

**Basic Patterns**:
- **Concentric** (`ipConcentric`) - Following object contours
- **Rectilinear** (`ipRectilinear`) - Straight lines, alternating direction
- **Grid** (`ipGrid`) - Crossed lines forming squares
- **Zig Zag** (`ipZigZag`) - Continuous zigzag lines

**Advanced Patterns**:
- **Triangles** (`ipTriangles`) - Triangular tessellation
- **Stars** (`ipStars`) - Star-shaped patterns
- **Cubic** (`ipCubic`) - 3D cubic lattice
- **Quarter Cubic** (`ipQuarterCubic`) - Reduced cubic pattern

**Optimized Patterns**:
- **Gyroid** (`ipGyroid`) - Triply periodic minimal surface
- **Honeycomb** (`ipHoneycomb`) - Hexagonal cells
- **2D Honeycomb** (`ip2DHoneycomb`) - Flat hexagonal
- **3D Honeycomb** (`ip3DHoneycomb`) - Layered hexagonal

**Specialized Patterns**:
- **Lightning** (`ipLightning`) - Minimal support infill
- **Adaptive Cubic** (`ipAdaptiveCubic`) - Density-aware cubic
- **Cross Hatch** (`ipCrossHatch`) - Diagonal crossing lines

**Mathematical Patterns**:
- **Hilbert Curve** (`ipHilbertCurve`) - Space-filling curve
- **Archimedean Chords** (`ipArchimedeanChords`) - Spiral-based
- **Octagram Spiral** (`ipOctagramSpiral`) - Eight-pointed star spiral

#### Infill Settings
- **Infill Density** (`fill_density`) - 0-100% fill percentage
- **Infill Speed** (`infill_speed`) - Print speed for infill
- **Infill Direction** (`fill_angle`) - Pattern orientation

### Support System

#### Support Types (`support_type`)
Implementation: `src/libslic3r/PrintConfig.hpp:150-152`
- **Normal (Auto)** (`stNormalAuto`) - Automatic traditional supports
- **Tree (Auto)** (`stTreeAuto`) - Automatic tree supports
- **Normal** (`stNormal`) - Manual traditional supports
- **Tree** (`stTree`) - Manual tree supports

#### Support Styles (`support_material_style`)
Implementation: `src/libslic3r/PrintConfig.hpp:134-136`
- **Grid** (`smsGrid`) - Regular grid pattern
- **Snug** (`smsSnug`) - Tight-fitting supports
- **Tree Slim** (`smsTreeSlim`) - Minimal tree supports
- **Tree Strong** (`smsTreeStrong`) - Robust tree supports
- **Tree Hybrid** (`smsTreeHybrid`) - Mixed tree approach
- **Tree Organic** (`smsTreeOrganic`) - Natural tree growth

#### Support Patterns (`support_material_pattern`)
Implementation: `src/libslic3r/PrintConfig.hpp:127-132`
- **Rectilinear** (`smpRectilinear`) - Straight line pattern
- **Rectilinear Grid** (`smpRectilinearGrid`) - Crossed lines
- **Honeycomb** (`smpHoneycomb`) - Hexagonal structure
- **Lightning** (`smpLightning`) - Minimal material usage

### Advanced Print Features

#### Ironing
- **Ironing Type** (`ironing_type`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:67-73`
  - Options: None, Top Surfaces, Topmost Only, All Solid
  - Surface smoothing technique

- **Ironing Parameters**
  - Flow rate (`ironing_flow`)
  - Speed (`ironing_speed`)
  - Spacing (`ironing_spacing`)

#### Fuzzy Skin
- **Fuzzy Skin Type** (`fuzzy_skin`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:37-42`
  - Options: None, External, All, All Walls
  - Texture generation for organic feel

- **Fuzzy Parameters**
  - Thickness (`fuzzy_skin_thickness`)
  - Point Distance (`fuzzy_skin_point_dist`)

#### Seam Control
- **Seam Position** (`seam_position`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:166-168`
  - Options: Nearest, Aligned, Rear, Random
  - Visual quality control

- **Seam Scarf** (`seam_scarf_type`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:171-175`
  - Options: None, External, All
  - Seam hiding technique

## 3. User Interface Features

### Main Interface
- **Tabbed Layout**
  - Prepare: 3D model preparation (`src/slic3r/GUI/Plater.cpp`)
  - Preview: G-code visualization (`src/slic3r/GUI/GCodeViewer.cpp`)
  - Process: Print settings (`src/slic3r/GUI/Tab.cpp`)
  - Filament: Material configuration
  - Printer: Machine settings

### Menu System
**File Menu**:
- New/Open/Save Project (Ctrl+N/O/S)
- Recent Projects
- Import/Export submenus
- Batch operations

**Edit Menu**:
- Undo/Redo (Ctrl+Z/Y)
- Cut/Copy/Paste (Ctrl+X/C/V)
- Selection tools
- Plate duplication

**View Menu**:
- 3D view controls
- Show/hide options
- Navigator and labels
- Overhang visualization

### Dialog Systems
- **Calibration Wizard** (`src/slic3r/GUI/CalibrationWizard.cpp`)
- **Configuration Wizard** (`src/slic3r/GUI/ConfigWizard.cpp`)
- **Preferences** (`src/slic3r/GUI/Preferences.cpp`)
- **Bed Shape** (`src/slic3r/GUI/BedShapeDialog.cpp`)

### 3D Scene Interaction
- **Gizmos** - Interactive manipulation tools
  - Move, Rotate, Scale
  - Cut, Hollow, Support Paint
  - Color Change, Face Selection

- **Camera Controls**
  - Perspective/Orthogonal switching
  - Auto-perspective
  - Free navigation

## 4. Calibration System

### Automatic Calibrations
Implementation: `src/slic3r/GUI/Calibration.cpp`
- **Micro Lidar Calibration** (`xcam_cali:49`)
- **Bed Leveling** (`bed_leveling:50`)
- **Vibration Compensation** (`vibration:51`)
- **Motor Noise Cancellation** (`motor_noise:52`)

### Manual Calibrations
Implementation: `src/slic3r/GUI/CalibrationWizard.cpp`
- **Pressure Advance** - K-value optimization (0.0-1.5 range)
- **Flow Rate** - Extrusion multiplier tuning
- **Temperature Tower** - Optimal temperature finding
- **Retraction** - Stringing elimination

### Calibration Infrastructure
- **History Tracking** (`src/slic3r/GUI/CaliHistoryDialog.cpp`)
- **Panel Interface** (`src/slic3r/GUI/CalibrationPanel.cpp`)
- **Extrusion Tests** (`src/slic3r/GUI/ExtrusionCalibration.cpp`)

## 5. Network Printing

### Supported Print Hosts
Implementation: `src/libslic3r/PrintConfig.hpp:52-54`
- **Bambu Link** (`htPrusaLink`) - Bambu Lab printers
- **Bambu Connect** (`htPrusaConnect`) - Cloud service
- **OctoPrint** (`htOctoPrint`) - Popular print server
- **Duet** (`htDuet`) - Duet controller
- **FlashAir** (`htFlashAir`) - SD card over WiFi
- **AstroBox** (`htAstroBox`) - Cloud printing platform
- **Repetier** (`htRepetier`) - Repetier Server
- **MKS** (`htMKS`) - MKS WiFi modules
- **ESP3D** (`htESP3D`) - ESP32-based controllers
- **Creality Print** (`htCrealityPrint`) - Creality cloud
- **Obico** (`htObico`) - AI-powered monitoring
- **FlashForge** (`htFlashforge`) - FlashForge printers
- **Simply Print** (`htSimplyPrint`) - Cloud service
- **ElegooLink** (`htElegooLink`) - Elegoo printers

### Print Operations
- **Direct Printing** - Send to printer immediately
- **Upload** - Store on printer for later
- **Batch Operations** - Multiple plates/files
- **Queue Management** - Print scheduling

### Cloud Features
- **User Authentication** (`src/slic3r/GUI/MainFrame.cpp:78-86`)
- **Preset Synchronization** - Settings across devices
- **Multi-machine Support** - Fleet management

## 6. Multi-Material System

### AMS Integration
- **Material Management** (`src/slic3r/GUI/AMSMaterialsSetting.cpp`)
- **Automatic Loading** - Filament detection
- **Color Mapping** - Object to filament assignment
- **Compatibility Checking** - Material validation

### Multi-Color Features
- **Print Sequence** (`print_sequence`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:103-108`
  - Options: By Layer, By Object, By Default

- **Wipe Tower** (`src/slic3r/GUI/WipeTowerDialog.cpp`)
- **Prime Tower** - Purge volume management
- **Tool Change G-code** - Custom sequences

### Color Management
- **Layer Sequences**
  - First Layer (`first_layer_print_sequence`)
  - Other Layers (`other_layers_print_sequence`)
  - Sequence Choice (`first_layer_sequence_choice`)

## 7. Advanced Processing

### Print Optimization
- **Print Order** (`print_order`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:110-115`
  - Options: Default, As Object List

- **Slicing Mode** (`slicing_mode`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:117-125`
  - Options: Regular, Even-Odd, Close Holes

### Special Features
- **Spiral Mode** (`spiral_mode`) - Continuous single wall
- **Shell Thickness** (`ensure_vertical_shell_thickness`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:178-183`

### Gap Filling
- **Gap Fill Target** (`gap_fill_target`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:196-198`
  - Options: Everywhere, Top/Bottom, Nowhere

- **Bridge Filtering** (`internal_bridge_filter`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:186-188`
  - Options: Disabled, Limited, No Filter

- **Extra Bridge Layers** (`enable_extra_bridge_layer`)
  - Implementation: `src/libslic3r/PrintConfig.hpp:191-193`

## 8. G-code Generation

### G-code Flavors
Implementation: `src/libslic3r/PrintConfig.hpp:32-35`
- **Marlin Legacy** (`gcfMarlinLegacy`) - Older Marlin versions
- **Klipper** (`gcfKlipper`) - Modern Klipper firmware
- **RepRap Firmware** (`gcfRepRapFirmware`) - Duet controllers
- **Marlin Firmware** (`gcfMarlinFirmware`) - Current Marlin
- **RepRap Sprinter** (`gcfRepRapSprinter`) - Legacy RepRap
- **Repetier** (`gcfRepetier`) - Repetier firmware
- **Teacup** (`gcfTeacup`) - Minimal firmware
- **MakerWare** (`gcfMakerWare`) - MakerBot format
- **Sailfish** (`gcfSailfish`) - MakerBot alternative
- **Mach3** (`gcfMach3`) - CNC machine control
- **Machinekit** (`gcfMachinekit`) - LinuxCNC derivative
- **Smoothie** (`gcfSmoothie`) - Smoothieboard firmware

### G-code Features
- **Custom Code Insertion**
  - Start/End G-code
  - Before/After layer change
  - Tool change sequences

- **Metadata Generation**
  - Thumbnails (`src/libslic3r/GCode/Thumbnails.cpp`)
  - Time estimates
  - Material usage
  - Print statistics

## 9. Plate Management

### Multi-Plate System
Implementation: `src/slic3r/GUI/PartPlate.cpp`
- **Plate Duplication** - Edit → Duplicate Current Plate
- **Individual Settings** - Per-plate configuration
- **Batch Processing** - All plates simultaneously

### Arrangement Tools
- **Automatic Arrangement** - Optimal placement
- **Manual Positioning** - Drag and drop
- **Plate Optimization** - Maximum utilization
- **Collision Detection** - Overlap prevention

## 10. Quality & Precision Features

### Model Correction
- **Elephant Foot Compensation** (`elephant_foot_compensation`)
  - Implementation: `src/libslic3r/PrintConfig.cpp:518-520`
  - First layer expansion correction

- **Model Repair** - Automatic mesh fixing
- **Wall Thickness Analysis** - Printability checking
- **Overhang Detection** - Support requirement analysis

### Performance Optimization
- **Travel Optimization** (`avoid_crossing_perimeters`)
  - Implementation: `src/libslic3r/PrintConfig.cpp:677-679`
  - Minimize travel moves

- **Adaptive Layers** - Geometry-based layer heights
- **Background Processing** - Non-blocking slicing
- **Memory Management** - Large model support

### Visualization
- **3D Preview** - Real-time rendering
- **Layer View** - Per-layer inspection
- **Support Visualization** - 3D support preview
- **Travel Path Display** - Movement visualization
- **Overhang Highlighting** - Problem area identification

## Implementation Reference

### Core Files
- **Configuration**: `src/libslic3r/PrintConfig.cpp/.hpp`
- **GUI Framework**: `src/slic3r/GUI/Tab.cpp`
- **Main Interface**: `src/slic3r/GUI/MainFrame.cpp`
- **3D Scene**: `src/slic3r/GUI/GLCanvas3D.cpp`

### Feature Modules
- **Calibration**: `src/slic3r/GUI/Calibration*.cpp`
- **File I/O**: `src/libslic3r/Format/`
- **Print Engine**: `src/libslic3r/Print*.cpp`
- **Support Generation**: `src/libslic3r/Support/`
- **Fill Patterns**: `src/libslic3r/Fill/`
- **G-code Output**: `src/libslic3r/GCode/`

This catalog represents the complete feature set of OrcaSlicer, providing the foundation for understanding every capability that would need to be implemented in an Odin rewrite.