# Contributing Guide

Welcome! We appreciate your interest in contributing to VAR. This guide explains how to contribute effectively.

## Code of Conduct

This project follows a standard code of conduct. Be respectful, inclusive, and collaborative.

## Quick Start

1. **Fork** the repository on GitHub
2. **Clone** your fork: `git clone https://github.com/yourusername/var.git`
3. **Create** a feature branch: `git checkout -b feature/your-feature`
4. **Make** your changes
5. **Test** thoroughly: `zig build test && zig build benchmark`
6. **Commit** with clear messages: `git commit -m "feat: add your feature"`
7. **Push** to your fork: `git push origin feature/your-feature`
8. **Create** a Pull Request

## Development Setup

### Prerequisites

- **Zig**: 0.15.1 or later
- **Git**: For version control
- **CPU**: AVX2 support for SIMD development

### Clone and Setup

```bash
git clone https://github.com/boonzy00/var.git
cd var
zig build  # Verify build works
zig build test  # Run tests
zig build benchmark  # Run benchmarks
```

### Development Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes
# ... edit files ...

# Test changes
zig build test
zig build benchmark -Doptimize=ReleaseFast

# Format code
zig fmt .

# Commit changes
git add .
git commit -m "feat: description of changes"

# Push and create PR
git push origin feature/my-feature
```

## Development Guidelines

### Code Style

- **Formatting**: Use `zig fmt` for consistent formatting
- **Naming**: Follow Zig conventions (snake_case for functions/variables)
- **Documentation**: Document all public APIs with doc comments
- **Error handling**: Use Zig's error system appropriately

### Example Code Style

```zig
/// Routes a single query based on volume selectivity.
/// Returns the recommended backend (CPU or GPU).
pub fn route(self: VAR, query_vol: f32, world_vol: f32) Decision {
    if (world_vol <= 0.0 or !self.config.gpu_available) return .cpu;
    const selectivity = query_vol / world_vol;
    return if (selectivity < self.config.gpu_threshold) .gpu else .cpu;
}
```

### Testing

- **Unit tests**: Required for all new functionality
- **Edge cases**: Test boundary conditions
- **Performance**: Ensure no regressions
- **Cross-platform**: Test on Linux, macOS, Windows

### Example Test

```zig
test "route with zero world volume" {
    const router = VAR.init(null);
    const decision = router.route(100.0, 0.0);
    try std.testing.expect(decision == .cpu);
}

test "route with high selectivity" {
    const router = VAR.init(.{ .gpu_threshold = 0.1 });
    const decision = router.route(100.0, 1000.0); // selectivity = 0.1
    try std.testing.expect(decision == .cpu); // Equal to threshold routes to CPU
}
```

## Performance Requirements

### Benchmarks Must Pass

- **SIMD mode**: ≥1.0B decisions/sec on modern hardware
- **Scalar mode**: ≥1M decisions/sec
- **No regressions**: Performance must not degrade

### Performance Testing

```bash
# Run benchmarks before/after changes
zig build benchmark -Doptimize=ReleaseFast

# Statistical analysis
hyperfine --warmup 3 --runs 10 "zig build benchmark -Doptimize=ReleaseFast"
```

## Pull Request Process

### PR Checklist

- [ ] **Tests pass**: `zig build test`
- [ ] **Benchmarks pass**: `zig build benchmark -Doptimize=ReleaseFast`
- [ ] **Code formatted**: `zig fmt .`
- [ ] **Documentation updated**: API docs, README if needed
- [ ] **No regressions**: Performance maintained or improved
- [ ] **Cross-platform**: Tested on multiple platforms if applicable

### PR Description Template

```markdown
## Description
Brief description of the changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Benchmarks pass
- [ ] Manual testing performed

## Performance Impact
- [ ] No performance impact
- [ ] Performance improved
- [ ] Performance regression (explain why acceptable)

## Breaking Changes
- [ ] No breaking changes
- [ ] Breaking changes (explain and migration guide provided)
```

### Review Process

1. **Automated checks**: CI must pass
2. **Code review**: At least one maintainer review
3. **Performance review**: Benchmarks reviewed
4. **Merge**: Squash merge with descriptive commit message

## Architecture Guidelines

### Core Principles

- **Performance first**: SIMD optimization is critical
- **Simple API**: Keep the public interface minimal
- **Zero allocations**: Hot path must not allocate
- **Type safety**: Leverage Zig's type system
- **Cross-platform**: Support all major platforms

### Adding New Features

1. **Start with tests**: Write tests first (TDD)
2. **SIMD consideration**: Can this be vectorized?
3. **API design**: Does this fit the existing patterns?
4. **Performance impact**: Measure and document
5. **Documentation**: Update docs and examples

### SIMD Development

When adding SIMD code:

```zig
// Use consistent vector types
const Vec8f32 = @Vector(8, f32);
const Vec8u32 = @Vector(8, u32);

// Document SIMD requirements
// @note: Requires AVX2 support

// Provide scalar fallback
if (!self.config.simd_enabled or len < 8) {
    // Scalar implementation
}
```

## Debugging

### Common Issues

**SIMD compilation errors**:
```zig
// Check AVX2 support
grep avx2 /proc/cpuinfo

// Force scalar mode for testing
const router = VAR.init(.{ .simd_enabled = false });
```

**Performance regressions**:
```bash
# Compare before/after
git stash  # Stash changes
zig build benchmark -Doptimize=ReleaseFast  # Baseline
git stash pop  # Restore changes
zig build benchmark -Doptimize=ReleaseFast  # Compare
```

**Memory issues**:
```bash
# Use Valgrind
valgrind --leak-check=full zig build test
```

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] Update version in README
- [ ] Update CHANGELOG.md
- [ ] Tag release: `git tag v1.2.3`
- [ ] Create GitHub release
- [ ] Update package registry

## Getting Help

### Communication Channels

- **Issues**: Bug reports and feature requests
- **Discussions**: General questions and ideas
- **Pull Requests**: Code contributions

### Asking for Help

When asking for help:

1. **Be specific**: Include error messages, code snippets, system info
2. **Provide context**: What are you trying to accomplish?
3. **Show effort**: What have you tried already?
4. **Use formatting**: Code blocks for code, proper markdown

### Example Help Request

```markdown
## Problem
Getting compilation error when adding SIMD code.

## Code
```zig
const Vec8f32 = @Vector(8, f32);
// error: expected integer, float, bool, or pointer for vector element type
```

## System Info
- Zig version: 0.15.1
- CPU: Intel i7-8700K
- OS: Ubuntu 22.04

## What I've tried
- Checked AVX2 support (confirmed)
- Tried different vector sizes
- Looked at existing SIMD code in the codebase
```

## Recognition

Contributors are recognized in:

- **CHANGELOG.md**: Release notes
- **GitHub contributors**: Repository statistics
- **Documentation**: Attribution where appropriate

Thank you for contributing to VAR! 🚀