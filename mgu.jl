using Match

# Step 1
function check_predicates_match(expressions::Array)
    exp = [exp[1] for exp in expressions]
    return all(exp.==exp[1])
end


# Replace all instances of x with y in the expression
function replace_in_expression(x, y, exp)
    replace(e) = begin
        if e == x
            return y
        elseif isa(e, Symbol)
            return e
        else
            return map(replace, e)
        end
    end

    exp = replace(exp)
    return exp
end


# Checks whether symbol occurs in the expression
function _occurs_in(symbol::Symbol, fx)
    return @match fx begin
        s::Symbol              => s == symbol
        [F, s::Symbol]         => s == symbol
        [F, x...]              => symbol in fx || any([_occurs_in(symbol, e) for e in fx])  # It's a function, so go deeper
        _                      => false
    end
end

function _unify(e1, e2, constants)
    return _unify(e1, e2, Dict(), constants)
end

function _unify(e1, e2, substitutions::Dict, constants::Set)
    @assert length(e1) == length(e2) "Arguments should be the same length"
    err() = throw(ArgumentError("Not Unifiable"))

    find_subs(pair) = @match pair begin
                                                    # Constants shouldn't be replaced by free variables
        [s::Symbol, t::Symbol]                => begin
                                                    if s in constants && t in constants
                                                        err()
                                                    elseif (s in constants)
                                                        [t, s]
                                                    elseif (t in constants)
                                                        [s, t]    # Replace symbol with symbol
                                                    else
                                                        [s, t]
                                                    end
                                                  end
        [s::Symbol, fx] || [fx, s::Symbol]    => begin
                                                    if _occurs_in(s, fx); err() end  # Occurs check
                                                    [s, fx]
                                                 end
        [ [F, x], [G, y] ]                    => find_subs([x, y])  # If they are both functions, go inside
        [ [F, x], [G, x] ]                    => err()
        [[], _] || [_, []]                    => err()
    end

    for i = 1:length(e1)
        pair = [e1[i], e2[i]]
        if pair[1] != pair[2]
            x, y = find_subs(pair)
            e1 = replace_in_expression(x, y, e1)
            e2 = replace_in_expression(x, y, e2)
            substitutions[x] = y
        end
    end
    return e1, e2, substitutions
end

function unify(e1, e2, constants::Set)
    if !check_predicates_match([e1, e2])
        throw(ArgumentError("Predicates don't match"))
    end
    predicate = e1[1]
    e1, e2 = e1[2:end], e2[2:end]
    e1, e2, subs = _unify(e1, e2, constants)
    @assert e1 == e2 "Input is likely invalid"    # Actually unecessary, as exception should be raised in _unify
    return [predicate; e1], subs
end

function unify(e1, e2)
    return unify(e1, e2, Set())
end
