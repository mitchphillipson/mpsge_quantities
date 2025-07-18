

function simple_model(inputs, outputs; start_values::Dict{Symbol,Real}=Dict{Symbol,Real}())
     M = MPSGEModel()

    @parameters(M, begin
        T, 0
    end)

    @sectors(M, begin
        X, (start = get(start_values, :X, 1.0))
        Y, (start = get(start_values, :Y, 1.0))
        W, (start = get(start_values, :W, 1.0))
    end)

    @commodities(M, begin
        PX, (start = get(start_values, :PX, 1.0))
        PY, (start = get(start_values, :PY, 1.0))
        PW, (start = get(start_values, :PW, 1.0))
        PL, (start = get(start_values, :PL, 1.0))
        PK, (start = get(start_values, :PK, 1.0))
    end)

    @consumer(M, RA, start = get(start_values, :RA, 1.0))


    @production(M, X, [t=0, s=1, va=>s=.5], begin
        @output(PX, outputs[:PX,:X], t)
        @input(PX, inputs[:PX,:X], s, taxes=[Tax(RA, T)])
        @input(PY, inputs[:PY, :X], s)
        @input(PK, inputs[:PK, :X], va)
        @input(PL, inputs[:PL, :X], va)
    end)


    @production(M, Y, [t=0, s=1, va=>s=2], begin
        @output(PY, outputs[:PY,:Y], t)
        @input(PX, inputs[:PX, :Y], s)
        @input(PY, inputs[:PY, :Y], s)
        @input(PK, inputs[:PK, :Y], va)
        @input(PL, inputs[:PL, :Y], va)
    end)

    @production(M, W, [t=0, s=0], begin
        @output(PW, outputs[:PW,:W], t)
        @input(PX, inputs[:PX, :W], s)
        @input(PY, inputs[:PY, :W], s)
    end)

    @demand(M, RA, begin
        @final_demand(PW, inputs[:PW, :RA])
        @endowment(PL, outputs[:PL, :RA])
        @endowment(PK, outputs[:PK, :RA])
    end)

    return M
end

function new_quantity(M::MPSGEModel,X::Symbol,P::Symbol,n::Symbol)
    sign = n == :s ? 1 : -1
    return sign*new_quantity(M[X], M[P], n)
end

function new_quantity(X::Sector, P::Commodity, n::Symbol)
    return value(compensated_demand(X, P, n)*X*P)
end

function new_quantity(RA::Consumer, P::Commodity, n::Symbol)
    if n == :s
        return value(demand(RA, P)*P)
    elseif n == :t
        return -value(endowment(RA, P)*P)
    else
        return 0
    end
end



function report(M::MPSGEModel; value = :value)

    return generate_report(M) |>
            x -> transform(x, 
                :var => ByRow(x -> JuMP.name(x)) => :var,
            ) |>
            x -> select(x, :var, :value) |>
            x -> rename(x, :value => value)

end
