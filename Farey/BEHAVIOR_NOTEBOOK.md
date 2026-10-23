# Behavior notebook

Durable notes on how Stange's Starscape/Lattice viewer behaves and how this project matches or departs from it. Observations come from the public viewer at <https://katestange.net/starscape-lattice/> and from read-only reading of its deployed bundle; the identifiers below are its minified function names. Nothing is copied from it: our implementation is original, and its software and assets are not relicensed here. The exact mathematical cases live in the [shared parity contract](PARITY_CONTRACT.md) and `parity/fixtures.json`.

## Polynomial labels (2026-10-23)

**Source** (`Ne`, `rn`):

- **Formatter:** the polynomial is written with spaced operators (`15x² + 31x + 31`, `x² − 2x + 1`), a leading minus without a space, implicit unit coefficients and zero terms dropped. It uses the actual signed coefficients.
- **Drawing:** one plain line at 12 px, left-aligned, stroked first with a 4 px round-joined halo at 0.92 opacity, then filled. Hover labels use 0.75 ink and selected labels full text colour.
- **Placement:** below-right of the point by max(8, r+7) and max(8, r+6) pixels, with no card.
- **Where labels appear:** in the roots pane, hover labels the hovered star. In 3D, hover only highlights; labels go on selections.

**Ours (browser, since this commit):**

- **Formatter:** `polynomial()` gives the same typography.
- **Desktop hover label:** one plain 12 px line just right of a thin ring, over a dark halo (our background is black), flipping left at the right edge and clamping vertically. It never reduces a multiple.
- **Our extension:** 3D hover labels, which the source does not show.

**Native:** a polynomial hover label is impossible from gaze alone, because visionOS renders hover outside the app and never tells it which entity is being looked at. Native labels can only follow selection.

## Möbius drag (2026-10-23)

**Source, roots pane** (`Br`, `ve`, `O`, `A`, `j`):

- **One state:** a single g ∈ SL₂(ℝ), starting at the identity.
- **Each move:** after a 4 px threshold, both the previous and the current pointer positions are pulled back through the model chart to points z₀ and z₁ of the upper half-plane. Then g ← normalize(T·g), where T is the hyperbolic transvection carrying z₀ to z₁ (composed on the left, so the point under the pointer follows it). Outside the model disk there is no anchor and nothing moves.
- **Gestures that leave g alone:** Shift-drag pans, the wheel zooms (0.5–8× the fit), and a click under 4 px selects.
- **Snap:** an optional release snap reduces g to an integer matrix.
- **Coefficients:** they are drawn at j(g)·(a,b,c), with a′ = s²a − rs·b + r²c, b′ = −2qs·a + (ps+qr)·b − 2pr·c and c′ = q²a − pq·b + p²c for g = [[p,q],[r,s]], so roots move by z ↦ (pz+q)/(rz+s) and Δ is preserved. Integer identities, labels and plane membership stay on the base (a,b,c).

**Source, 3D** (`Wr`):

- With the eye at the origin, a drag uses the view ray's Klein point and the same rule. The cloud moves by the Lorentz map j(g); this is not a camera move.
- The visible crop is recomputed for the current g (a+c ≤ R in transformed coordinates) after enough motion.

**Ours:** not yet implemented. Euclidean viewing rotations in both platforms leave coefficients, discriminants, selections and planes unchanged, and are not SL₂ or hyperbolic navigation.

## Versions referenced

- Browser 0.14.0 plus this label commit.
- Native 0.11.0 (15) in the main simulator.
- The source was observed live on 2026-10-23.
