"""
Let me know if you can figure out what I'm doing here. I've noticed something
potentially interesting, but didn't have the time to dive into it.
"""

using JuMP
using NamedArrays
using Ipopt

commodities = [:PX, :PY, :PW, :PL, :PK]
sectors = [:X, :Y, :W, :RA]
consumers = [:RA]



inputs = NamedArray(
    Float64[
    20 50 100 0;
    50 15 100 0;
    0  0  0   200;
    10 25 0   0;
    20 25 0   0],
    (commodities, [sectors; consumers]),
)

outputs = NamedArray(
    Float64[
    170 0 0 0;
    0 125 0 0;
    0 0 200 0;
    0 0 0 100;
    0 0 0 100],
    (commodities, [sectors; consumers]),
)


C = Model(Ipopt.Optimizer)

@variables(C, begin
    IN[c = commodities, i=[sectors; consumers]], (start = inputs[c,i], lower_bound = 0)
    OUT[c = commodities, i=[sectors; consumers]], (start = outputs[c,i], lower_bound = 0)
end)

for c in commodities, i in [sectors; consumers]
    if inputs[c,i] == 0
        fix(IN[c,i], 0; force=true)
    end
    if outputs[c,i] == 0
        fix(OUT[c,i], 0; force=true)
    end
end

@objective(C, Min,
    sum((IN[c,i] - inputs[c,i])^2 for c in commodities, i in [sectors; consumers]) +
    sum((OUT[c,i] - outputs[c,i])^2 for c in commodities, i in [sectors; consumers])
)

@constraints(C, begin
    row_sums[c= commodities], 
        sum(IN[c,i] for i in [sectors; consumers]) == sum(OUT[c,i] for i in [sectors; consumers])
    col_sums[i = [sectors; consumers]], 
        sum(IN[c,i] for c in commodities) == sum(OUT[c,i] for c in commodities)
end)

optimize!(C)

value.(IN)

new_inputs

value.(OUT)
new_outputs



G = simple_model(value.(IN), value.(OUT))
fix(G[:PL], 1)
solve!(G, cumulative_iteration_limit=0)
