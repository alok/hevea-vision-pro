# Hévéa finite-mesh scale microscope

This standalone Swift package runs the repository's deterministic numerical
extension over all four `HeveaCore` stages. It writes a machine-readable JSON
receipt and a human-readable Markdown report. Every derived measurement is
labelled `HV EXPERIMENT`.

From the repository root, first verify that `Packages/HeveaCore` still matches
checkpoint `68202cae55a59a71b1573c869a05ac82b87c7ee2`, then run in release mode:

```sh
git diff --exit-code \
  68202cae55a59a71b1573c869a05ac82b87c7ee2 \
  -- Packages/HeveaCore
swift run -c release \
  --package-path Research/ScaleMicroscope \
  hevea-scale-microscope \
  --output-directory docs/research
```

The output is deterministic: no wall-clock time, random system seed, machine
path, or locale-dependent number formatting is retained. The finite-mesh
measurements are descriptive. They do not certify isometry, infer a fractal
dimension, establish limiting regularity, or reproduce the upstream
corrugation algorithm.
