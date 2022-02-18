"""
    get_num_sites(unit_cell::UnitCell,lattice::Lattice)

Returns the number of sites `Nₛ` in a finite lattice.
"""
function get_num_sites(unit_cell::UnitCell,lattice::Lattice)

    @assert unit_cell.D == lattice.D
    return unit_cell.n * lattice.N
end


"""
    valid_site(s::Int,unit_cell::UnitCell,lattice::Lattice)

Return whether `s` is a valid site index.
"""
function valid_site(s::Int,unit_cell::UnitCell,lattice::Lattice)

    @assert unit_cell.D == lattice.D
    Nₛ = get_num_sites(unit_cell, lattice)
    return 0 < s <= Nₛ
end


"""
    site_to_unitcell(s::Int,unit_cell::UnitCell,lattice::Lattice)

Return the unit cell `u` containing lattice site `s`.
"""
function site_to_unitcell(s::Int,unit_cell::UnitCell,lattice::Lattice)

    @assert valid_site(s,unit_cell,lattice)

    return (s-1) ÷ unit_cell.n + 1 
end


"""
    site_to_orbital(s::Int,unit_cell::UnitCell,lattice::Lattice)

Return the orbtial species of site `s`.
"""
function site_to_orbital(s::Int,unit_cell::UnitCell,lattice::Lattice)

    return mod1(s,unit_cell.n)
end


"""
    site_to_loc!(loc::AbstractVector{Int},s::Int,unit_cell::UnitCell,lattice::Lattice)

For a given site `s` in the lattice, calculate the location `l` of the unit cell it is in
and return the orbital species `o` of the site.
"""
function site_to_loc!(l::AbstractVector{Int},s::Int,unit_cell::UnitCell,lattice::Lattice)

    o = site_to_orbital(s,unit_cell,lattice)
    u = site_to_unitcell(s,unit_cell,lattice)
    unitcell_to_loc!(l,u,lattice)
    return o
end

"""
    site_to_loc(s::Int,unit_cell::UnitCell,lattice::Lattice)

For a given site `s` in the lattice, return the location `l` of the unit cell it is in
and the orbital species `o`.
"""
function site_to_loc(s::Int,unit_cell::UnitCell,lattice::Lattice)

    @assert unit_cell.D == lattice.D
    l = zeros(Int,unit_cell.D)
    o   = site_to_loc!(l,s,unit_cell,lattice)
    return (l, o)
end


"""
    loc_to_site(l::AbstractVector{Int},o::Int,unit_cell::UnitCell,lattice::Lattice)

Given a unit cell location `l` and orbital species `o`, return the corresponding
site `s` in the lattice. If the location is not valid owing to open boundary conditions
then return `s = 0`.
"""
function loc_to_site(l::AbstractVector{Int},o::Int,unit_cell::UnitCell,lattice::Lattice)

    @assert unit_cell.D == lattice.D
    @assert 0 < o <= unit_cell.n
    
    if valid_location(l,lattice)
        u = loc_to_unitcell(l,lattice)
        s = loc_to_site(u,o,unit_cell,lattice)
    else
        s = 0
    end
    
    return s
end

"""
    loc_to_site(u::Int,o::Int,unit_cell::UnitCell,lattice::Lattice)

Given a unit cell index `u` and orbital `o`, return the correspond site `s`.
"""
function loc_to_site(u::Int,o::Int,unit_cell::UnitCell,lattice::Lattice)

    (; D, N) = lattice
    (; n)    = unit_cell

    @assert 0 < o <= n "0 < $o <= $n"
    @assert 0 < u <= N "0 < $u <= $N"

    s = n * (u-1) + o

    return s
end


"""
    site_to_site(s₁::Int,Δl::AbstractVector{Int},o₂::Int,unit_cell::UnitCell,lattice::Lattice)

Given an initial site `s₁`, and a displacement in unit cells `Δl` and a terminating orbital
species `o₂`, return the resulting site `s₂` in the lattice. If the displacement is
not allowed as a result of open boundary conditions, then  `s₂=0` is returned.
"""
function site_to_site(s₁::Int,Δl::AbstractVector{Int},o₂::Int,unit_cell::UnitCell,lattice::Lattice)

    (; D, n) = unit_cell
    l = lattice.lvec

    # check that initial site index is valid
    @assert valid_site(s₁, unit_cell, lattice)

    # get unit cell location containing s₁
    o₁ = site_to_loc!(l, s₁, unit_cell, lattice)

    # displace unit cell location
    @. l += Δl

    # apply periodic boundary conditions
    pbc!(l, lattice)

    # get final site
    s₂ = loc_to_site(l, o₂, unit_cell, lattice)

    return s₂
end


"""
    calc_k_point!(k_point::AbstractVector{T}, k_loc::AbstractVector{Int},
        unit_cell::UnitCell{T}, lattice::Lattice) where {T}

Calculate the k-point `k_point` corresponding to the k-point location `k_loc`.
"""
function calc_k_point!(k_point::AbstractVector{T}, k_loc::AbstractVector{Int}, unit_cell::UnitCell{T}, lattice::Lattice) where {T}


    @assert length(k_point) == length(k_loc) == unit_cell.D == lattice.D
    (; reciprocal_vecs) = unit_cell
    (; D, L, periodic) = lattice

    fill!(k_point,0.0)
    for d in 1:D
        l = max( L[d]*periodic[d] , 1 )
        @assert 0 <= k_loc[d] < l "0 <= $(k_loc[d]) < $l"
        @views @. k_point += k_loc[d] * reciprocal_vecs[:,d] / l
    end

    return nothing
end

"""
    calc_k_point(k_point::AbstractVector{T}, k_loc::AbstractVector{Int},
        unit_cell::UnitCell{T}, lattice::Lattice) where {T}

Return the k-point `k_point` corresponding to the k-point location `k_loc`.
"""
function calc_k_point(k_loc::AbstractVector{Int}, unit_cell::UnitCell{T}, lattice::Lattice) where {T}
    
    k_point = zeros(T,lattice.D)
    calc_k_point!(k_point,k_loc,unit_cell)

    return k_point
end


"""
    calc_k_points!(k_points::AbstractArray{T}, unit_cell::UnitCell{T},
        lattice::Lattice) where {T}

Calculate the k-point grid `k_points` assicated with a finite lattice.
"""
function calc_k_points!(k_points::AbstractArray{T}, unit_cell::UnitCell{T}, lattice::Lattice) where {T}
    
    @assert unit_cell.D == lattice.D
    (; D, reciprocal_vecs) = unit_cell
    (; L, N, periodic)     = lattice
    k_loc                  = lattice.lvec
    
    for ci in CartesianIndices( size(k_points)[2:D+1] )
        for d in 1:D
            k_loc[d] = ci[d] - 1
        end
        k_point = @view k_points[:,ci]
        calc_k_point!(k_point, k_loc, unit_cell, lattice)
    end

    return nothing
end

"""
    calc_k_points!(unit_cell::UnitCell{T}, lattice::Lattice) where {T}

Return the k-point grid assicated with a finite lattice.
For a `D` dimensional lattice, a `D+1` dimensional array will be returned.
If the system has open boundary conditions in a given direction, it will treat the linear
extent of the system in that direction as equalling `L=1` for the purposes of calucting the k-points.
"""
function calc_k_points(unit_cell::UnitCell{T}, lattice::Lattice) where {T}
    
    (; D, L, periodic) = lattice
    k_points = zeros(T, D, (max(L[d]*periodic[d] , 1) for d in 1:D)...)
    calc_k_points!(k_points, unit_cell, lattice)

    return k_points
end


"""
    bond_to_vec!(Δr::AbstractVector{T},bond::Bond,unit_cell::UnitCell{T}) where {T}

Calculate the displacement vector associated with a `bond`.
"""
function bond_to_vec!(Δr::AbstractVector{T},bond::Bond,unit_cell::UnitCell{T}) where {T}

    displacement_to_vec!(Δr,Δl,o[1],o[2],unit_cell)
    return nothing
end

"""
    bond_to_vec(bond::Bond,unit_cell::UnitCell{T})

Return the displacement vector associated with a `bond`.
"""
function bond_to_vec(bond::Bond,unit_cell::UnitCell{T}) where {T}

    Δr = zeros(T,bond.D)
    bond_to_vec!(bond,unit_cell)
    return Δr
end


"""
    build_neighbor_table(bond::Bond, unit_cell::UnitCell, lattice::Lattice)

Construct the neighbor table corresponding to `bond`.
"""
function build_neighbor_table(bond::Bond, unit_cell::UnitCell, lattice::Lattice)

    @assert bond.D == unit_cell.D == lattice.D
    @assert length(bond.o) == 2
    @assert 0 < bond.o[1] <= unit_cell.n
    @assert 0 < bond.o[2] <= unit_cell.n

    (; D, L, N, periodic) = lattice
    (; n)                 = unit_cell
    (; Δl, o)             = bond

    # initialize empty neighbor table
    neighbor_table = Vector{Int}[]

    # iterate over all unit cells
    for u in 1:N
        # get initial site
        s₁ = loc_to_site(u, o[1], unit_cell, lattice)
        # get final site
        s₂ = site_to_site(s₁, Δl, o[2], unit_cell, lattice)
        # check if final site was found
        if s₂ != 0
            # add to neighbor table
            push!(neighbor_table, [s₁,s₂])
        end
    end

    return hcat(neighbor_table...)
end

"""
    build_neighbor_table(bonds::AbstractVector{Bond}, unit_cell::UnitCell, lattice::Lattice)

Construct the neighbor table corresponding to `bonds`.
"""
function build_neighbor_table(bonds::AbstractVector{Bond}, unit_cell::UnitCell, lattice::Lattice)

    neighbor_tables = Matrix{Int}[]
    for i in 1:length(bonds)
        neighbor_table = build_neighbor_table(bonds[i], unit_cell, lattice)
        push!(neighbor_tables, neighbor_table)
    end

    return hcat(neighbor_tables...)
end


"""
    sort_neighbor_table!(neighbor_table::Matrix{Int})

Sorts `neighbor_table` so that the first row is in strictly ascending order, and for fixed values
in the first row, the second row is also in ascending order.
Also returns the inverse of the sorting perumtation, so original order of neighbors in `neighbor_table`
can be easily recovered.
"""
function sort_neighbor_table!(neighbor_table::Matrix{Int})

    perm = sorted_neighbor_table_perm!(neighbor_table)
    @views @. neighbor_table = neighbor_table[:,perm]
    inv_perm = sortperm(perm)

    return inv_perm
end

"""
    sorted_neighbor_table_perm!(neighbor_table::Matrix{Int})

Returns the permutation that sorts `neighbor_table` so that the first row is in strictly ascending order,
and for fixed values in the first row, the second row is also in ascending order. This method also modifies
the `neighbor_table` such that the smaller index in each column is always in the first row.
"""
function sorted_neighbor_table_perm!(neighbor_table::Matrix{Int})
    
    @assert size(neighbor_table,1)==2

    # make sure smaller number is always in first column of neighbor table
    for i in 1:size(neighbor_table,2)
        c1 = neighbor_table[1,i]
        c2 = neighbor_table[2,i]
        if c1 > c2
            neighbor_table[1,i] = c2
            neighbor_table[2,i] = c1
        end
    end

    top_row    = @view neighbor_table[1,:]
    bottom_row = @view neighbor_table[2,:]
    max_index  = maximum(neighbor_table)
    vals       = max_index * top_row + bottom_row
    perm       = sortperm(vals)

    return perm
end