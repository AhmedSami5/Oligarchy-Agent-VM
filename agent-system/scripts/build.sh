#!/bin/bash
# ========================================
# build.sh - Build script for DeMoD Agent System
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_status() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo -e "${NC}$2${NC}"
    echo -e "${NC}$3${NC}"
}

# Function to print error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}"
    echo -e "${RED}$2${NC}"
    exit 1
}

# Function to print success message
success_message() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    echo -e "${GREEN}$2${NC}"
}

# ========================================
# Configuration
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="demod-agent-system"
VERSION="1.0.0"
BUILD_NUMBER=${BUILD_NUMBER:-"$(date +%Y%m%d)"}
REGISTRY="${DOCKER_REGISTRY:-localhost:5000}"

echo "Building ${PROJECT_NAME} version ${VERSION} (build ${BUILD_NUMBER})"

# ========================================
# Prerequisites Check
# ========================================

check_prerequisites() {
    print_status "Checking prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is required but not installed"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error_exit "Docker Compose is required but not installed"
    fi
    
    # Check Python (for local build)
    if [ "$BUILD_MODE" = "local" ] && ! command -v python3 &> /dev/null; then
        error_exit "Python 3.11+ is required for local build but not installed"
    fi
    
    success_message "Prerequisites check passed"
}

# ========================================
# Build Functions
# ========================================

build_docker_images() {
    print_status "Building Docker images"
    
    # Build multi-platform images
    local platforms=("linux/amd64" "linux/arm64")
    
    for platform in "${platforms[@]}"; do
        echo -e "${YELLOW}Building for platform: $platform${NC}"
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            -t "${REGISTRY}/${PROJECT_NAME}:${VERSION}-${platform}" \
            -f docker/Dockerfile \
            --target cloud \
            .
        
        if [ $? -eq 0 ]; then
            success_message "Docker image built for $platform"
        else
            error_exit "Failed to build Docker image for $platform"
        fi
    done
    
    # Also tag as latest
    docker tag "${REGISTRY}/${PROJECT_NAME}:${VERSION}-linux/amd64" "${REGISTRY}/${PROJECT_NAME}:latest"
    docker tag "${REGISTRY}/${PROJECT_NAME}:${VERSION}-linux/arm64" "${REGISTRY}/${PROJECT_NAME}:latest-arm64"
    
    success_message "Docker images built successfully"
}

build_python_package() {
    print_status "Building Python package"
    
    cd "$SCRIPT_DIR"
    
    # Create distribution
    if [ "$BUILD_MODE" = "local" ]; then
        python -m build
    else
        # Use poetry for containerized builds
        docker run --rm -v "$PWD":/app -w /app \
            python:3.11-slim \
            pip install build \
            && python -m build
    fi
    
    if [ $? -eq 0 ]; then
        success_message "Python package built successfully"
    else
        error_exit "Failed to build Python package"
    fi
}

run_tests() {
    print_status "Running tests"
    
    cd "$SCRIPT_DIR"
    
    if [ "$BUILD_MODE" = "container" ]; then
        docker run --rm \
            -v "$PWD":/app \
            python:3.11 \
            pip install pytest pytest-asyncio pytest-cov \
            && python -m pytest tests/ -v --cov=src --cov-report=html
    else
        python -m pytest tests/ -v --cov=src --cov-report=html
    fi
    
    if [ $? -eq 0 ]; then
        success_message "All tests passed"
    else
        error_exit "Some tests failed"
    fi
}

build_documentation() {
    print_status "Building documentation"
    
    cd "$SCRIPT_DIR"
    
    # Build MkDocs documentation
    mkdocs build
    
    if [ $? -eq 0 ]; then
        success_message "Documentation built successfully"
    else
        error_exit "Failed to build documentation"
    fi
}

# ========================================
# Build Modes
# ========================================

case "${1:-all}" in
    "all")
        echo "Building everything..."
        check_prerequisites
        build_docker_images
        run_tests
        build_documentation
        ;;
    "docker")
        BUILD_MODE="container"
        check_prerequisites
        build_docker_images
        ;;
    "local")
        BUILD_MODE="local"
        check_prerequisites
        build_python_package
        run_tests
        ;;
    "tests")
        echo "Running tests..."
        check_prerequisites
        run_tests
        ;;
    "docs")
        echo "Building documentation..."
        build_documentation
        ;;
    *)
        echo "Usage: $0 {all|docker|local|tests|docs}"
        echo "  all      - Build everything (default)"
        echo "  docker   - Build Docker images only"
        echo "  local    - Build Python package locally"
        echo "  tests    - Run tests only"
        echo "  docs     - Build documentation only"
        exit 1
        ;;
esac

success_message "Build process completed successfully!"