# Contributing

- `make deps check` must be green: byte-compiling the package and the tests
  with every warning an error, checkdoc, package-lint, relint, the format check
  and the ERT tests.
- Every fix comes with a regression test, shown to fail without the fix.
- Stub only the OS and process boundaries, never the behaviour under test.
- The tests are compiled like the package, so their warnings fail the build too.
- Formatting is whatever `make format` does, which is plain `emacs -Q`
  indentation, spaces rather than tabs, and no trailing whitespace. Write a
  quoted list of data one item per line, so that other indentation setups agree.
