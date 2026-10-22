# Two roots, one coefficient plane

Browser 0.11.0 adds the pair interaction from Katherine Stange's Starscape viewer. Native remains 0.9.0.

## Try it

1. Enter `1,0,1` and **Select**: this represents (t²+1), with upper root (i).
2. Enter `1,1,1` and **Pair entered point**, or Shift-click that point. Its upper root is ((-1+i\sqrt3)/2).
3. The plane is **2a − 2c = 0**, with geodesic endpoints **−1 and 1**. Amber rings mark displayed complex-root points in the plane, including multiples. Their discriminant colors remain unchanged.
4. **Project to Klein disk** shows the plane's chord on the screen. **Clear pair** removes only the construction. A new ordinary selection or **Next point** clears it; **Reset** clears the pair and restores the starting selection and framing.

Pairing preserves the primary selection and camera. Invalid pairs preserve the previous pair. Signed and nonprimitive point identities remain visible; two copies of the same primitive direction cannot define a geodesic. Crop/filter changes retain the pair and disclose a hidden second point.

## Mathematics

For (p=(a,b,c)), its discriminant-bilinear dual is (p^*=(-2c,b,-2a)). The primitive integer normal (n=(A,B,C)) is obtained from (p^*\times q^*). Its plane is

\[
-2Ca+Bb-2Ac=0,
\]

and the endpoints are the real roots of (At²+Bt+C), including infinity when (A=0). Integer arithmetic determines incidence, the normal, rational endpoint labels and radicands. Floating-point coordinates draw the finite scene.

With our coordinates (X=-b,Y=a+c,Z=c-a), the same plane is (-BX-(A+C)Y+(C-A)Z=0). The displayed patch is sampled and clipped to |Y|≤R and X²+Z²≤R². Its intersection with the cone gives null boundary rays; its Y=4 slice is a Klein geodesic chord. Euclidean Inhabit motion is not intrinsic hyperbolic navigation.

## Provenance and limits

The [deployed viewer](https://katestange.net/starscape-lattice/#lm=1&c=1&sc=0&p=0&cp=1) was audited on 22 October 2026 using actual selection input. Its normal calculation is `ke` in [the main module](https://katestange.net/_astro/index.astro_astro_type_script_index_0_lang.kfTP0QEk.js), SHA-256 `f22013e04c8de068f6d74ccf4b4a16d76218c53d6f236eb9f64b435697c1174b`. The example above and its translated pair (endpoints 0 and 2) were verified. Our implementation is original code; no reference code or media is bundled.

Credit: [Katherine Stange's talk](https://katestange.net/talks/math-exploration/) and [Harriss–Stange–Trettel, *Algebraic Number Starscapes*](https://arxiv.org/abs/2008.07655). The separate Farey view credits [Caroline Series](https://doi.org/10.1112/jlms/s2-31.1.69).

This bounded interaction does not implement the source's SL₂ motion, shells, animated projection or multiple root models. Our symmetric cone, finite ball and contrast palette remain presentation choices. Source **Reset views** preserves selected mathematics; our **Reset** clears the selection and pair while retaining the chosen category palette. Reload still starts fresh; there is no link claiming to reproduce the complete scene state.

Tests cover exact examples, sign/scalar invariance, degeneracies, infinity, plane/cone incidence, Shift-click and button input, invalid-state preservation, filtering, Inhabit, reset, phone layout and repeated disposal. These are desktop-browser checks. Real WebXR, controller pairing and native parity remain unverified or unimplemented.
