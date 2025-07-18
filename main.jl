using Pkg
Pkg.activate(".")
Pkg.instantiate()


using MPSGE
using JuMP
using NamedArrays
using DataFrames

include("model.jl")


### The intial data. This is not a balanced dataset, as we will see below.
inputs = NamedArray(
    Float64[
    20 50 100 0;
    50 15 100 0;
    0  0  0   200;
    10 25 0   0;
    20 25 0   0],
    ([:PX, :PY, :PW, :PL, :PK], [:X,:Y, :W, :RA]),
)

outputs = NamedArray(
    Float64[
    170 0 0 0;
    0 125 0 0;
    0 0 200 0;
    0 0 0 100;
    0 0 0 100],
    ([:PX, :PY, :PW, :PL, :PK], [:X,:Y, :W, :RA]),
)


# Initialize the first model and solve it.
M = simple_model(inputs, outputs)
fix(M[:PL], 1)

# Uncomment this line to verify that model is unbalanced. You will see a non-zero residual in the output.
# solve!(M, cumulative_iteration_limit=0)

solve!(M)
set_silent(M) # Setting the model to silent suppresses output. Feel free to comment it out and see what happens.

# Create new inputs and outputs based the initial model's solution
new_inputs = NamedArray(
    [new_quantity(M, X, PX, :s) for PX in [:PX, :PY, :PW, :PL, :PK], X in [:X, :Y, :W, :RA]],
    ([:PX, :PY, :PW, :PL, :PK], [:X,:Y, :W, :RA]),
)

new_outputs = NamedArray(
    [new_quantity(M, X, PX, :t) for PX in [:PX, :PY, :PW, :PL, :PK], X in [:X, :Y, :W, :RA]],
    ([:PX, :PY, :PW, :PL, :PK], [:X,:Y, :W, :RA]),
)


# Verify the new model is fully calibrated
L = simple_model(new_inputs, new_outputs)
fix(L[:PL], 1)
solve!(L, cumulative_iteration_limit=0)
set_silent(L)

# Create a third model. This one has the same inputs and outputs as the first
# model, but uses the solutions of the first model as starting values. This should
# be fully balanced. 
start_values = Dict{Symbol,Real}(
    :X => value(M[:X]),
    :Y => value(M[:Y]),
    :W => value(M[:W]),
    :PX => value(M[:PX]),
    :PY => value(M[:PY]),
    :PW => value(M[:PW]),
    :PL => value(M[:PL]),
    :PK => value(M[:PK]),
    :RA => value(M[:RA]),
)

N = simple_model(inputs, outputs; start_values=start_values)
fix(N[:PL], 1)
solve!(N, cumulative_iteration_limit=0)
set_silent(N)

pre_tax = outerjoin(
    report(M; value = :M),
    report(N; value = :N),
    report(L; value = :L),
    on = :var
)

set_value!(N[:T], .2)
set_value!(M[:T], .2)
set_value!(L[:T], .2)

solve!(M)
solve!(L)
solve!(N)


post_tax = outerjoin(
    report(M; value = :M),
    report(N; value = :N),
    report(L; value = :L),
    on = :var
)




leftjoin(
    stack(pre_tax, variable_name = :model, value_name = :pre_tax),
    stack(post_tax, variable_name = :model, value_name = :post_tax),
    on = [:var, :model]
) |>
x -> transform(x,
    [:pre_tax, :post_tax] => ByRow((pre,post) -> post/pre) => :ratio
) |>
x -> select(x, :var, :model, :ratio) |>
x -> unstack(x, :model, :ratio)





new_quantity(M, :X, :PX, :s)
new_quantity(L, :X, :PX, :s)
new_quantity(N, :X, :PX, :s)

