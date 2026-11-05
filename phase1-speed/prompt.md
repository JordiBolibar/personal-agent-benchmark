Do not use any tools. Answer directly in a single response.

Implement in pure Julia (Base only, no external packages) a function

    heat_step!(T::Matrix{Float64}, kappa::Float64, dt::Float64, dx::Float64)

that performs one explicit finite-difference timestep of the 2D heat equation
dT/dt = kappa * Laplacian(T) on a rectangular grid with Neumann (zero-flux)
boundary conditions, updating T in place.

Then, in the same response:
1. Derive the von Neumann stability condition for this explicit scheme in 2D
   and show that it reduces to dt <= dx^2 / (4*kappa).
2. Explain what changes in 3D.
3. Discuss what happens numerically when the condition is violated.
4. State the computational complexity per timestep.

Put the final Julia code in a single fenced code block, followed by the
derivation and discussion.
