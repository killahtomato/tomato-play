# Contributing to Tomato Play

Thank you for your interest in contributing to Tomato Play!

## How to Contribute

### Reporting Issues

- Use the issue tracker
- Provide clear description of the problem
- Include steps to reproduce if applicable

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run linter: `shfmt -i 4 -ci -d -w tomatoplay`
5. Run shellcheck: `shellcheck -s sh -o all -e 2250 tomatoplay`
6. Test your changes
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Code Style

- Follow POSIX shell conventions
- Use 4 spaces for indentation
- No extra dependencies unless absolutely necessary
- Keep the script monolithic

### Adding New Providers

To add a new streaming source:

1. Add the provider functions:
   - `providername_search()` - Search for content
   - `providername_episodes()` - Get episode list
   - `providername_m3u8()` - Get video URLs

2. Register the provider in `provider_search()`, `provider_episodes()`, and `provider_m3u8()`

3. Update the help text with the new source

4. Test the provider thoroughly

## Development Setup

```bash
git clone https://github.com/killahtomato/tomato-play.git
cd tomato-play
chmod +x tomatoplay
./tomatoplay --help
```

## Testing

Test your changes with:

```bash
# Basic functionality
./tomatoplay -V
./tomatoplay -h

# Search tests
./tomatoplay -s anidb "test"
./tomatoplay -s aniwatch "test"
./tomatoplay -s gogoanime "test"
./tomatoplay -s 9anime "test"

# Playback tests
./tomatoplay -s anidb -e 1 "test anime"
```

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0 License.
