# Contributing to dlmalloc-zig

Thank you for your interest in contributing to dlmalloc-zig! This document provides guidelines for contributing to the project.

## Development Setup

1. **Install Zig 0.15.x or later**
   ```bash
   # Download from https://ziglang.org/download/
   ```

2. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd dlmalloc-zig
   ```

3. **Build and test**
   ```bash
   zig build
   zig build test
   ```

## Code Style

- Follow Zig's standard formatting: `zig build fmt`
- Use meaningful variable and function names
- Add comments for complex algorithms
- Keep functions focused and reasonably sized
- Prefer explicit error handling over panics

## Testing

- All new functionality must include tests
- Run the full test suite: `zig build test`
- Test cross-compilation: `zig build cross-compile`
- Run benchmarks to check performance: `zig build benchmark`

## Platform Support

When adding new platform support:

1. Update `src/platform.zig` with platform-specific code
2. Update `src/c_compat.zig` if new C APIs are needed
3. Add the platform to `build.zig` cross-compilation targets
4. Test compilation and basic functionality
5. Update documentation

## Performance Considerations

- This is a memory allocator - performance matters
- Profile changes with the benchmark suite
- Consider memory fragmentation impact
- Maintain alignment requirements
- Be careful with atomic operations and thread safety

## Submitting Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the code style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Test thoroughly**
   ```bash
   zig build test
   zig build cross-compile
   zig build fmt-check
   ```

4. **Commit with clear messages**
   ```bash
   git commit -m "Add support for new platform XYZ"
   ```

5. **Submit a pull request**
   - Describe the changes and motivation
   - Reference any related issues
   - Include test results for affected platforms

## Areas for Contribution

- **Platform support**: Add new OS/architecture combinations
- **Performance**: Optimize hot paths and reduce fragmentation
- **Features**: Implement additional malloc extensions
- **Testing**: Improve test coverage and add stress tests  
- **Documentation**: Improve examples and API documentation
- **Debugging**: Better memory corruption detection

## Code Review Process

- All changes require review before merging
- Maintainers will provide feedback within a few days
- Address review feedback promptly
- Large changes may require design discussion first

## Compatibility

- Maintain API compatibility when possible
- Document breaking changes clearly
- Support multiple Zig versions when feasible
- Keep platform abstraction clean

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for design questions
- Check existing issues before creating new ones

Thank you for contributing!