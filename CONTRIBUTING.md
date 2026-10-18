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
4. Format shell files with `shfmt -i 4 -ci -w tomatoplay core/*.sh providers/*.sh`
5. Run shellcheck: `shellcheck -s sh -o all -e 2250 tomatoplay core/*.sh providers/*.sh`
6. Test your changes
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Code Style

- Follow POSIX shell conventions
- Use 4 spaces for indentation
- No extra dependencies unless absolutely necessary
- Keep the CLI entry point and shared helpers in `tomatoplay`.
- Put extracted core responsibilities in `core/` and provider adapters in
  `providers/`.
- Follow [`core/CONTRACT.md`](core/CONTRACT.md) for shared state and core module
  dependencies.
- Keep provider-specific functions in `providers/`; these files are sourced
  into the same POSIX shell process and may use the documented shared state.

### Adding New Providers

To add a new streaming source:

1. Add the provider functions to the matching `providers/<provider>.sh`
   module, or to `providers/torrents.sh` for torrent sources:
   - `providername_search()` - Search for content
   - `providername_episodes()` - Get episode list
   - `providername_m3u8()` - Get video URLs

2. Register its supported operations in `providers/dispatch.sh`.
3. Follow the input, output, and failure rules in `providers/CONTRACT.md`.

4. Update the help text with the new source

5. Test the provider thoroughly

## Development Setup

```bash
git clone https://github.com/killahtomato/tomato-play.git
cd tomato-play
chmod +x tomatoplay
./tomatoplay --help
```

## Testing

Run all offline checks and the shell linter before submitting changes:

```sh
for test_script in tests/*.sh; do
  sh "$test_script"
done
shellcheck --shell=sh --severity=error tomatoplay install.sh core/*.sh providers/*.sh tests/*.sh
```

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
