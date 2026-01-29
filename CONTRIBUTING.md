# Contributing to Oligarchy AgentVM

Thank you for considering contributing to Oligarchy AgentVM! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)
- [Security](#security)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment for all contributors. Please be respectful in all interactions and follow professional standards of conduct.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- System information (OS, Nix version, etc.)
- Any relevant error messages or logs

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:

- Use a clear and descriptive title
- Provide a detailed description of the proposed feature
- Explain the motivation and use case
- Include examples if applicable

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Update documentation as needed
6. Ensure all tests pass
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## Development Setup

### Prerequisites

- Nix package manager with flakes enabled
- QEMU/KVM for virtualization
- Git for version control

### Quick Start

```bash
# Clone the repository
git clone https://github.com/ALH477/Oligarchy-Agent-VM.git
cd Oligarchy-Agent-VM

# Enter development shell
nix develop

# Build the VM
nix build .#agent-vm-qcow2

# Launch VM
nix run .#run
```

### Development Environment

The project includes a development shell with all necessary tools:

```bash
# Enter development environment
nix develop

# Available tools:
# - nix (package manager)
# - qemu (virtualization)
# - git (version control)
# - python3 (for client library)
# - Various development utilities
```

## Code Style

### Nix/NixOS Configuration

- Use 2-space indentation
- Follow Nixpkgs conventions
- Use meaningful variable names
- Add comments for complex configurations
- Keep lines under 100 characters when possible

### Python Code

- Follow PEP 8 style guidelines
- Use type hints for all function parameters and returns
- Add docstrings for all public functions and classes
- Use meaningful variable and function names
- Keep functions focused and under 50 lines when possible

### Shell Scripts

- Use `set -euo pipefail` at the beginning
- Quote variables properly
- Use descriptive variable names
- Add comments for complex logic
- Follow POSIX shell standards

### Documentation

- Use clear, concise language
- Follow the existing documentation structure
- Include examples for new features
- Update existing examples when APIs change
- Use proper Markdown formatting

## Testing

### Unit Tests

Unit tests should be written for all new functionality:

```python
# Example test structure
def test_function_name():
    """Test description."""
    # Arrange
    input_data = "test input"
    
    # Act
    result = function_to_test(input_data)
    
    # Assert
    assert result == expected_output
```

### Integration Tests

Integration tests verify that components work together correctly:

- Test API endpoints
- Test agent execution
- Test UI interactions
- Test configuration loading

### Running Tests

```bash
# Run Python tests
python -m pytest tests/

# Run specific test file
python -m pytest tests/unit/test_agent_manager.py

# Run with coverage
python -m pytest --cov=src tests/
```

## Documentation

### Documentation Standards

- Use clear, professional language
- Avoid emojis in technical documentation
- Include code examples for complex features
- Update documentation when APIs change
- Follow the existing documentation structure

### Documentation Files

- `README.md` - Main project documentation
- `docs/EXAMPLES.md` - Usage examples and patterns
- `docs/TROUBLESHOOTING.md` - Common issues and solutions
- `CHANGELOG.md` - Version history and changes

### API Documentation

All public APIs should include:

- Clear parameter descriptions
- Return value documentation
- Usage examples
- Error conditions and handling

## Security

### Security Best Practices

- Never commit secrets or API keys
- Use proper input validation
- Follow security guidelines for each technology
- Report security vulnerabilities privately

### Security Considerations

- API keys should be configurable, not hardcoded
- Use HTTPS in production environments
- Implement proper authentication and authorization
- Follow principle of least privilege

## Pull Request Process

### PR Guidelines

1. **Descriptive Title**: Use a clear, descriptive title
2. **Small PRs**: Keep PRs focused on a single feature or fix
3. **Tests**: Include tests for new functionality
4. **Documentation**: Update documentation as needed
5. **Changelog**: Add entries to CHANGELOG.md for user-facing changes

### PR Template

```markdown
## Summary
Brief description of changes

## Test plan
- [ ] Test case 1
- [ ] Test case 2
- [ ] Documentation updated

## Documentation
- [ ] README updated
- [ ] Examples updated
- [ ] Changelog updated

## Breaking Changes
List any breaking changes and migration steps
```

### Review Process

1. Automated checks must pass
2. At least one maintainer review required
3. Address all review comments
4. Squash commits before merging (optional)

## Getting Help

- Check existing issues and discussions
- Ask questions in GitHub Discussions
- Review the documentation
- Join community discussions

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

## Contact

For questions or support, please:

- Open an issue for bug reports or feature requests
- Use GitHub Discussions for questions and community support
- Check the documentation for common questions

Thank you for contributing to Oligarchy AgentVM!