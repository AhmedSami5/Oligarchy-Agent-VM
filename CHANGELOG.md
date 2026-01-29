# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Oligarchy AgentVM
- Complete NixOS VM configuration with three deployment modes
- FastAPI REST API for agent orchestration
- Python client library with CLI support
- GTK4 Wayland native UI with brutalist design
- Full Godot/Redot editor plugin
- Comprehensive documentation and examples
- Automated installation scripts

### Security
- Removed hardcoded API keys from production configuration
- Added proper secrets management support
- Implemented API key validation and security warnings
- Added security hardening for systemd services

### Fixed
- Fixed API key fallback to use development-safe defaults
- Updated documentation to remove production warnings
- Standardized API key usage across all components

## [1.0.0] - 2026-01-29

### Added
- Initial stable release
- Production-ready NixOS VM with reproducible builds
- AI coding agent integration (aider, opencode, claude-code)
- Programmatic agent control via REST API
- Session recording and cleanup functionality
- CPU isolation support for real-time workloads
- Multiple UI options (GTK4, Godot plugin)
- Comprehensive testing and troubleshooting guides

### Security
- Secure API key management with file-based secrets
- Systemd service hardening with sandboxing
- Network isolation via QEMU port forwarding
- Read-only host directory sharing

### Documentation
- Complete README with installation and usage
- Extensive examples for different integration scenarios
- Troubleshooting guide with common issues and solutions
- Repository structure documentation

## [0.1.0] - 2025-12-15

### Added
- Initial project structure
- Basic NixOS configuration
- Core agent management system
- API implementation

### Changed
- Project architecture refinements
- Security improvements

## [0.0.1] - 2025-11-01

### Added
- Project initialization
- Basic flake.nix structure
- Initial agent integration

---

## Versioning

This project follows Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes that require migration
- **MINOR**: New features that are backward compatible
- **PATCH**: Bug fixes and minor improvements

## Migration Guide

### From 0.x to 1.0

The 1.0 release is the first stable version. All APIs and configurations are now considered stable.

**Breaking Changes:**
- None - 1.0 is backward compatible with 0.x versions

**Recommended Actions:**
- Update to latest 1.0 release for production use
- Review security configuration for production deployments
- Consider implementing proper secrets management

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.