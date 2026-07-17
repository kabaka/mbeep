# Contributing to mbeep

Thanks for your interest in improving mbeep. This is a small C99 command-line
tool; contributions of all sizes are welcome.

## Building

```
make                 # builds ./mbeep and generates mbeep.1
make CFLAGS="-Wall -Wextra -Werror -std=c99"   # strict build used by CI
```

On Linux you need OpenAL headers (`libopenal-dev` on Debian/Ubuntu,
`openal-soft-devel` on Fedora/RHEL). macOS ships OpenAL with the system.

## Testing

```
make test            # end-to-end suite; generates .wav files, needs no audio hardware
```

The suite drives the built binary and validates exit codes and `.wav` output.
Playback tests that open the audio device are skipped unless `MBEEP_PLAYBACK=1`
is set; CI runs them on Linux against openal-soft's null backend
(`ALSOFT_DRIVERS=null`) so no sound hardware is required.

To check coverage locally (requires `gcovr`):

```
make coverage        # writes coverage.xml and prints a summary
```

When you add or change behavior, add or update a case in
[`tests/run_tests.sh`](tests/run_tests.sh).

## Coding standards

- C99, and the build must stay clean under `-Wall -Wextra` (CI uses `-Werror`).
- Validate all user input; report failures through the `SoundError` enum and a
  non-zero exit status rather than crashing or silently continuing.
- Keep `.wav` generation free of any audio-device dependency (file mode).

## Commits and pull requests

- Follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `chore:`, `test:`, `ci:`, `docs:` …).
- The `main` branch is protected: changes land via pull request, merged by
  rebase, with a linear history. CI (build, tests, coverage) and CodeQL must
  pass before merge.
- Keep pull requests focused; update the README or man-page text when you change
  user-visible behavior.

## License

By contributing, you agree that your contributions are licensed under the
project's [BSD 2-Clause license](LICENSE).
