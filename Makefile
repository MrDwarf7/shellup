# Optimized Cross-Platform C/C++ Makefile
# Usage: make [BUILD_TYPE=debug|release] [VERBOSE=1]

# Thanks claude for writing yet another Makefile lmao

# Project configuration
PROJECT_NAME = shellup
ENTRY_FILE = main.c
CC = gcc
CPPCHECK_VERSION = c23
C_STD = c23

INSTALL_PATH ?= /usr/local/bin
INSTALL_MODE ?= 755

HYPERFINE_WARMUP = 10
HYPERFINE_RUNS = 1000
HYPERFINE_PREP_COMMAND = rm -f /tmp/fetch_run
HYPERFINE_CLEANUP = $(HYPERFINE_PREP_COMMAND)

# Detect best available compiler for optimized builds
OPT_CC := $(shell which gcc-13 2>/dev/null || which gcc-12 2>/dev/null || which gcc 2>/dev/null)

# Platform detection
ifeq ($(OS),Windows_NT)
    PLATFORM = windows
    EXE_EXT = .exe
    MKDIR = mkdir
    RMDIR = rmdir /S /Q
    PATH_SEP = \$(strip)
    FIX_PATH = $(subst /,\,$1)
    LDLIBS_EXT = 
else
    PLATFORM = unix
    EXE_EXT = 
    MKDIR = mkdir -p
    RMDIR = rm -rf
    PATH_SEP = /
    FIX_PATH = $1
    LDLIBS_EXT = -lrt -lpthread
endif

# File extensions and directories
SRC_EXT = c
SRC_DIR = .
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
TARGET = $(BUILD_DIR)/$(PROJECT_NAME)$(EXE_EXT)

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.$(SRC_EXT))
# OBJECTS = $(SOURCES:$(SRC_DIR)/%.$(SRC_EXT)=$(OBJ_DIR)/%.o)
OBJECTS = $(OBJ_DIR)/$(ENTRY_FILE:.$(SRC_EXT)=.o)
DEPS = $(OBJECTS:.o=.d)

# Base compiler flags
BASE_CFLAGS = -Wall -Wextra -std=$(C_STD) -pipe -I$(SRC_DIR) -I$(OBJ_DIR)
DEBUG_CFLAGS = -g -O0 -DDEBUG -fsanitize=address -fsanitize=undefined

# Optimized performance flags - maximum performance single binary
RELEASE_CFLAGS = -O3 -Ofast -DNDEBUG \
    -flto -fuse-linker-plugin \
    -march=native -mtune=native \
    -ftracer -funroll-loops -fpredictive-commoning \
    -fgcse-after-reload -fprefetch-loop-arrays \
    -falign-functions=32 -falign-loops=32 \
    -finline-functions -finline-limit=1000 -fipa-pta \
    -ffunction-sections -fdata-sections \
    -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
    -msse4.2 -mavx2 -mfma \
    -fwhole-program \
    -fno-semantic-interposition

# Platform-specific flags
ifeq ($(PLATFORM),windows)
    BASE_CFLAGS += -Wunicode
    DEBUG_LDFLAGS = -Wl,--subsystem,console -Wunicode
    RELEASE_LDFLAGS = -Wl,--subsystem,console -Wunicode -Wl,--gc-sections
else
    DEBUG_LDFLAGS = 
    RELEASE_LDFLAGS = -Wl,--gc-sections -Wl,--strip-all
endif

# Build type configuration
BUILD_TYPE ?= debug
ifeq ($(BUILD_TYPE),release)
    CFLAGS = $(BASE_CFLAGS) $(RELEASE_CFLAGS)
    CC = $(OPT_CC)
    LDFLAGS = $(RELEASE_LDFLAGS)
    LDLIBS = $(LDLIBS_EXT)
else
    CFLAGS = $(BASE_CFLAGS) $(DEBUG_CFLAGS)
    LDFLAGS = $(DEBUG_LDFLAGS)
    LDLIBS = -lasan -lubsan
endif

ifeq ($(INSTALL_PATH),/usr/bin)
    INSTALL_OWNER = root:root
    INSTALL_REQUIRES_SUDO = yes
    INSTALL_PREFIX = /usr
else ifeq ($(INSTALL_PATH),/usr/local/bin)
    INSTALL_OWNER = $(USER):$(shell id -gn)
    INSTALL_REQUIRES_SUDO = maybe
    INSTALL_PREFIX = /usr/local
else ifneq ($(findstring /opt/,$(INSTALL_PATH)),)
    INSTALL_OWNER = $(USER):$(shell id -gn)
    INSTALL_REQUIRES_SUDO = maybe 
    INSTALL_PREFIX = /opt
else 
    INSTALL_OWNER = $(USER):$(shell id -gn)
    INSTALL_REQUIRES_SUDO = no
    INSTALL_PREFIX = $(dir $(INSTALL_PATH))
endif

# Verbose output control
VERBOSE ?= 0
ifeq ($(VERBOSE),1)
    Q = 
    V = 1
else
    Q = @
    V = 
endif

ifneq ($(VERBOSE),0)
    INSTALL_VERBOSE = -v
else 
    INSTALL_VERBOSE = 
endif


# Default target
all: $(TARGET)

# Link target
$(TARGET): $(OBJECTS) | $(BUILD_DIR)
	$(Q)echo "🔗 Linking $(BUILD_TYPE) build: $@"
	$(Q)$(CC) $(LDFLAGS) -o $@ $(OBJECTS) $(LDLIBS)
ifeq ($(BUILD_TYPE),release)
	$(Q)strip $@ 2>/dev/null || true
	$(Q)echo "✅ Optimized build complete! Binary size: $$(du -h $@ | cut -f1)"
endif

# Compile source files
$(OBJECTS): $(SOURCES) | $(OBJ_DIR)
	$(Q)echo "🔨 Compiling $(BUILD_TYPE): $<"
	$(Q)$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

# Create directories
$(BUILD_DIR) $(OBJ_DIR):
	$(Q)$(MKDIR) $(call FIX_PATH,$@)

# Build convenience targets
release:
	@echo "🚀 Building optimized release version..."
	@echo "   Using compiler: $(OPT_CC)"
	@echo "   Optimization level: MAXIMUM PERFORMANCE"
	$(MAKE) BUILD_TYPE=release VERBOSE=1

debug: 
	@echo "🐛 Building debug version with sanitizers..."
	$(MAKE) BUILD_TYPE=debug VERBOSE=1

# Profile-Guided Optimization workflow
pgo: pgo-clean
	@echo "🎯 Building with Profile-Guided Optimization..."
	@echo "   Step 1: Generating profile instrumented binary..."
	$(Q)$(OPT_CC) $(BASE_CFLAGS) $(RELEASE_CFLAGS) -fprofile-generate $(RELEASE_LDFLAGS) \
	    -o $(BUILD_DIR)/pgo_profiler $(SOURCES) $(LDLIBS_EXT)
	@echo "   Step 2: Running profiling workload..."
	$(Q)for i in $$(seq 1 10); do $(BUILD_DIR)/pgo_profiler >/dev/null 2>&1; rm -f /tmp/fetch_run; done
	@echo "   Step 3: Building optimized binary with profile data..."
	$(Q)$(OPT_CC) $(BASE_CFLAGS) $(RELEASE_CFLAGS) -fprofile-use -fprofile-correction \
	    $(RELEASE_LDFLAGS) -o $(TARGET) $(SOURCES) $(LDLIBS_EXT)
	$(Q)strip $(TARGET) 2>/dev/null || true
	@echo "✅ PGO build complete! Expected 10-30% additional performance gain."

pgo-clean:
	$(Q)rm -f *.gcda *.gcno $(BUILD_DIR)/pgo_profiler 2>/dev/null || true

# Performance benchmarking
benchmark:
	@echo "📊 PERFORMANCE BENCHMARK"
	@echo "========================"
	@if ! command -v hyperfine >/dev/null 2>&1; then \
	    echo "❌ hyperfine not found. Install with: cargo install hyperfine"; \
	    echo "   or: sudo apt install hyperfine / brew install hyperfine"; \
	    echo "   Falling back to basic benchmark..."; \
	    $(MAKE) benchmark-simple; \
	    exit 0; \
	fi
	@echo "🔧 Building debug and release versions..."
	$(Q)$(MAKE) clean >/dev/null 2>&1
	$(Q)$(MAKE) BUILD_TYPE=debug >/dev/null 2>&1
	$(Q)cp $(TARGET) $(BUILD_DIR)/$(PROJECT_NAME)_debug
	$(Q)$(MAKE) clean >/dev/null 2>&1
	$(Q)$(MAKE) BUILD_TYPE=release >/dev/null 2>&1
	$(Q)cp $(TARGET) $(BUILD_DIR)/$(PROJECT_NAME)_release
	@echo "🔧 Optimizing system for benchmarking..."
	$(Q)sync
	-$(Q)echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
	@echo ""
	@echo "🚀 Running hyperfine benchmark comparison..."
	$(Q)hyperfine \
	    --warmup $(HYPERFINE_WARMUP) \
	    --runs $(HYPERFINE_RUNS) \
	    --prepare '$(HYPERFINE_PREP_COMMAND)' \
		--cleanup '$(HYPERFINE_CLEANUP)' \
	    --export-markdown $(BUILD_DIR)/benchmark_results.md \
	    --export-json $(BUILD_DIR)/benchmark_results.json# Optimized Cross-Platform C/C++ Makefile
# Usage: make [BUILD_TYPE=debug|release] [VERBOSE=1]
# -$(Q)sudo cpupower frequency-set -g performance >/dev/null 2>&1

# Performance benchmarking
benchmark: debug release
	@echo "📊 PERFORMANCE BENCHMARK"
	@echo "========================"
	@if ! command -v hyperfine >/dev/null 2>&1; then \
	    echo "❌ hyperfine not found. Install with: cargo install hyperfine"; \
	    echo "   or: sudo apt install hyperfine / brew install hyperfine"; \
	    echo "   Falling back to basic benchmark..."; \
	    $(MAKE) benchmark-simple; \
	    exit 0; \
	fi
	@echo "🔧 Optimizing system for benchmarking..."
	$(Q)sync
	-$(Q)echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
# -$(Q)sudo cpupower frequency-set -g performance >/dev/null 2>&1
	@echo ""
	@echo "🚀 Running hyperfine benchmark comparison..."
	$(Q)$(MAKE) BUILD_TYPE=debug >/dev/null 2>&1
	$(Q)$(MAKE) BUILD_TYPE=release >/dev/null 2>&1
	$(Q)hyperfine \
	    --warmup 10 \
	    --runs 1000 \
	    --prepare 'rm -f /tmp/fetch_run' \
	    --export-markdown $(BUILD_DIR)/benchmark_results.md \
	    --export-json $(BUILD_DIR)/benchmark_results.json \
	    --command-name "Debug Build" \
	    "$(BUILD_DIR)/$(PROJECT_NAME) >/dev/null 2>&1" \
	    --command-name "Release Build (Optimized)" \
	    "$(BUILD_DIR)/$(PROJECT_NAME) >/dev/null 2>&1"
	@echo ""
	@echo "📊 Results exported to:"
	@echo "   - $(BUILD_DIR)/benchmark_results.md"
	@echo "   - $(BUILD_DIR)/benchmark_results.json"
	@echo ""
	@echo "✨ Benchmark complete!"
# -$(Q)sudo cpupower frequency-set -g ondemand >/dev/null 2>&1

# Simple benchmark fallback using time
benchmark-simple: debug release
	@echo "📊 SIMPLE PERFORMANCE BENCHMARK"
	@echo "==============================="
	@echo "🔧 Optimizing system for benchmarking..."
	$(Q)sync
	-$(Q)echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
	# -$(Q)sudo cpupower frequency-set -g performance >/dev/null 2>&1
	@echo ""
	@echo "⏱️  Benchmarking debug build (1000 runs)..."
	$(Q)$(MAKE) BUILD_TYPE=debug >/dev/null 2>&1
	$(Q)time -p sh -c 'for i in $(seq 1 1000); do $(BUILD_DIR)/$(PROJECT_NAME) >/dev/null 2>&1; rm -f /tmp/fetch_run; done' 2>&1 | grep real
	@echo ""
	@echo "🚀 Benchmarking optimized build (1000 runs)..."
	$(Q)$(MAKE) BUILD_TYPE=release >/dev/null 2>&1
	$(Q)time -p sh -c 'for i in $(seq 1 1000); do $(BUILD_DIR)/$(PROJECT_NAME) >/dev/null 2>&1; rm -f /tmp/fetch_run; done' 2>&1 | grep real
	@echo ""
	@echo "💡 For advanced benchmarking with statistics, install hyperfine"
	@echo "✨ Simple benchmark complete!"

# -$(Q)sudo cpupower frequency-set -g ondemand >/dev/null 2>&1



# Advanced performance analysis
perf-analysis: release
	@echo "🔬 CPU Performance Analysis"
	@echo "=========================="
	@if command -v perf >/dev/null 2>&1; then \
	    echo "Analyzing CPU performance..."; \
	    perf stat -e cycles,instructions,cache-references,cache-misses,branches,branch-misses \
	        $(TARGET) 2>&1 | grep -E "(cycles|instructions|cache|branches)"; \
	else \
	    echo "perf not available - install linux-perf-tools for CPU analysis"; \
	fi

memory-analysis: release
	@echo "💾 Memory Usage Analysis"
	@echo "======================="
	@if command -v valgrind >/dev/null 2>&1; then \
	    echo "Running memory analysis..."; \
	    valgrind --tool=massif --pages-as-heap=yes $(TARGET) >/dev/null 2>&1; \
	    echo "Memory analysis complete"; \
	else \
	    echo "valgrind not available - install for memory analysis"; \
	fi

# Static analysis
check:
	$(Q)echo "🔍 Running static analysis..."
	$(Q)cppcheck --enable=all --suppress=missingIncludeSystem --force \
	    --inconclusive --std=$(CPPCHECK_VERSION) --check-level=exhaustive \
	    $(SOURCES)

# Size analysis for binaries
size-analysis: debug release
	@echo "📏 Binary Size Analysis"
	@echo "======================"
	@echo "Debug build:"
	$(Q)$(MAKE) BUILD_TYPE=debug >/dev/null 2>&1
	@ls -lh $(TARGET) 2>/dev/null || echo "  Not built"
	@echo "Release build:"
	$(Q)$(MAKE) BUILD_TYPE=release >/dev/null 2>&1
	@ls -lh $(TARGET) 2>/dev/null || echo "  Not built"

# Clean up build artifacts
clean:
	$(Q)echo "🧹 Cleaning build directory..."
	$(Q)if [ -d "$(BUILD_DIR)" ]; then $(RMDIR) $(call FIX_PATH,$(BUILD_DIR)); fi
	$(Q)rm -f *.gcda *.gcno 2>/dev/null || true

# Complete clean including profile data
distclean: clean
	$(Q)echo "🧹 Deep cleaning all generated files..."
	$(Q)rm -f massif.out.* perf.data* 2>/dev/null || true

# Installation target
install: release
	$(Q)echo "🔧 Installing $(PROJECT_NAME) to $(INSTALL_PATH)..."
	@if [ "$(INSTALL_REQUIRES_SUDO)" = "yes" ]; then \
	    echo "   Requires sudo for installation"; \
	    echo "   Use 'sudo make install' to proceed"; \
	else \
	    echo "   Installing without sudo"; \
	fi
	@echo "📦 Installing optimized binary..."
	$(Q)install -m $(INSTALL_MODE) $(TARGET) $(INSTALL_PATH)/$(PROJECT_NAME) || \
		echo "Run 'sudo make install' for system installation"

# Not sure why we can't use /usr/bin ... but alright
# $(Q)install -m 755 $(TARGET) /usr/local/bin/$(PROJECT_NAME) || \
#     echo "Run 'sudo make install' for system installation"

bench: benchmark

# Performance optimization shortcuts
p: pgo
b: benchmark

# Convenience shortcuts  
r: release
d: debug
cl: clean
c: check
h: help
s: size-analysis

# Show build configuration
info:
	@echo "🔧 Build Configuration"
	@echo "===================="
	@echo "Platform: $(PLATFORM)"
	@echo "Entry File: $(ENTRY_FILE)"
	@echo "Project Name: $(PROJECT_NAME)"
	@echo "Standard Compiler: $(CC)"
	@echo "Optimized Compiler: $(OPT_CC)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo "Target: $(TARGET)"
	@echo "Sources: $(SOURCES)"
	@echo ""
	@echo "🚀 Optimization Flags: $(RELEASE_CFLAGS)"

# Performance tips
tips:
	@echo "🎯 PERFORMANCE OPTIMIZATION TIPS"
	@echo "================================"
	@echo "🚀 For maximum performance:"
	@echo "   make release          - Build optimized version"
	@echo "   make pgo              - Build with Profile-Guided Optimization"
	@echo "   make benchmark        - Compare debug vs release performance"
	@echo ""
	@echo "⚡ Runtime optimizations:"
	@echo "   sudo nice -n -20 ./$(TARGET)"
	# @echo "   sudo cpupower frequency-set -g performance"
	@echo ""
	@echo "🔬 Analysis tools:"
	@echo "   make perf-analysis    - CPU performance analysis"
	@echo "   make memory-analysis  - Memory usage analysis"

# Help target
help:
	@echo "🚀 OPTIMIZED MAKEFILE"
	@echo "===================="
	@echo ""
	@echo "📦 Build Targets:"
	@echo "  all      - Build the project (default: debug)"
	@echo "  release  - Build optimized release version"
	@echo "  debug    - Build debug version with sanitizers"
	@echo "  pgo      - 🎯 Build with Profile-Guided Optimization (+10-30%)"
	@echo ""
	@echo "📊 Performance & Analysis:"
	@echo "  benchmark       - Compare debug vs release performance"
	@echo "  perf-analysis   - CPU performance analysis with perf"
	@echo "  memory-analysis - Memory usage analysis with valgrind"
	@echo "  size-analysis   - Compare binary sizes"
	@echo ""
	@echo "🔧 Utilities:"
	@echo "  clean     - Remove build directory"
	@echo "  distclean - Deep clean including profile data"
	@echo "  check     - Run static analysis with cppcheck"
	@echo "  install   - Install optimized binary to /usr/local/bin"
	@echo "  info      - Show build configuration"
	@echo "  tips      - Show performance optimization tips"
	@echo "  help      - Show this help"
	@echo ""
	@echo "⚡ Quick shortcuts: r=release, d=debug, p=pgo, b=benchmark"
	@echo ""
	@echo "🔧 Options:"
	@echo "  BUILD_TYPE=debug|release  - Set build type"
	@echo "  VERBOSE=1                 - Enable verbose output"

.PHONY: all release debug pgo pgo-clean benchmark perf-analysis memory-analysis \
        check size-analysis clean distclean install info tips help \
        p b r d cl c h s

# Include dependency files
-include $(DEPS)
