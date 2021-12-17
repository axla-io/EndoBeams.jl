#----------------------------------
# STRUCTURE
#----------------------------------
struct MyNode{T}
   
    i::Int # index
    pos::Vec3{T} # initial position

    # dof: total, displacement, angular
    idof_6::Vec6{Int}
    idof_disp::Vec3{Int}
    idof_ang::Vec3{Int}

    # current configuration of the node (@n+1)
    u::Vec3{T} # displacement
    udt::Vec3{T} # velocity
    udtdt::Vec3{T} # acceleration
    w::Vec3{T} # angle (spin vecotr)
    wdt::Vec3{T} # angular velocity
    wdtdt::Vec3{T} # angular acceleration
    R::Mat33{T} # local rotation matrix
    Delt::Mat33{T} # local rotation matrix variation

    # last configuration of the node (@n)
    u_n::Vec3{T}
    udt_n::Vec3{T}
    udtdt_n::Vec3{T}
    w_n::Vec3{T}
    wdt_n::Vec3{T}
    wdtdt_n::Vec3{T}
    R_n::Mat33{T}
    Delt_n::Mat33{T}

    R_global_to_local::Mat33{T}  # rotation matrix from global  (carthesian) to local (cylindrical) coordinates

end

#----------------------------------
# CONSTRUCTOR
#----------------------------------

"""
nodes = constructor_nodes(X, u_0, udt_0, udtdt_0, w_0, wdt_0, wdtdt_0, plane, R₀=nothing, T=Float64) 

Constructor of the nodes StructArray:
- `X`: nodes StructArray (created with constructor_nodes);
- `u_0`: initial displacements;
- `udt_0`: initial velocities;
- `udtdt_0`: initial accelerations;
- `w_0`: initial rotations;
- `wdt_0`: initial rotation velocities;
- `wdtdt_0`: initial rotation acceleration;
- `plane`: plane used for the conversin in cylindrical coordinates in case of BCs expressed in cylindrical coordinates.
- `R₀`: (not mandatory) initial rotation of the nodes.

Returns a StructArray{MyNode}, structure containing the information of the nodes. 
"""
function constructor_nodes(X, u_0, udt_0, udtdt_0, w_0, wdt_0, wdtdt_0, plane, R₀=nothing, T=Float64) 
  
    if isnothing(R₀)
            nodes = StructArray(MyNode{T}(
            i, 
            X[i], 
            Vec6{Int}(6*(i-1).+(1,2,3,4,5,6)), 
            Vec3(6*(i-1).+(1,2,3)), 
            Vec3(6*(i-1).+(4,5,6)), 
            Vec3(u_0[3*(i-1)+1], u_0[3*(i-1)+2], u_0[3*(i-1)+3]), 
            Vec3(udt_0[3*(i-1)+1], udt_0[3*(i-1)+2], udt_0[3*(i-1)+3]), 
            Vec3(udtdt_0[3*(i-1)+1], udtdt_0[3*(i-1)+2], udtdt_0[3*(i-1)+3]), 
            Vec3(w_0[3*(i-1)+1], w_0[3*(i-1)+2], w_0[3*(i-1)+3]), 
            Vec3(wdt_0[3*(i-1)+1], wdt_0[3*(i-1)+2], wdt_0[3*(i-1)+3]), 
            Vec3(wdtdt_0[3*(i-1)+1], wdtdt_0[3*(i-1)+2], wdtdt_0[3*(i-1)+3]), 
            ID3, 
            ID3,
            Vec3(u_0[3*(i-1)+1], u_0[3*(i-1)+2], u_0[3*(i-1)+3]), 
            Vec3(udt_0[3*(i-1)+1], udt_0[3*(i-1)+2], udt_0[3*(i-1)+3]), 
            Vec3(udtdt_0[3*(i-1)+1], udtdt_0[3*(i-1)+2], udtdt_0[3*(i-1)+3]), 
            Vec3(w_0[3*(i-1)+1], w_0[3*(i-1)+2], w_0[3*(i-1)+3]), 
            Vec3(wdt_0[3*(i-1)+1], wdt_0[3*(i-1)+2], wdt_0[3*(i-1)+3]), 
            Vec3(wdtdt_0[3*(i-1)+1], wdtdt_0[3*(i-1)+2], wdtdt_0[3*(i-1)+3]), 
            ID3, 
            ID3,
            compute_local_to_global_matrix(i, X, plane[i], T)) for i in 1:size(X,1))
    else
            nodes = StructArray(MyNode{T}(
            i, 
            X[i], 
            Vec6{Int}(6*(i-1).+(1,2,3,4,5,6)),
            Vec3(6*(i-1).+(1,2,3)), 
            Vec3(6*(i-1).+(4,5,6)), 
            Vec3(u_0[3*(i-1)+1], u_0[3*(i-1)+2], u_0[3*(i-1)+3]), 
            Vec3(udt_0[3*(i-1)+1], udt_0[3*(i-1)+2], udt_0[3*(i-1)+3]), 
            Vec3(udtdt_0[3*(i-1)+1], udtdt_0[3*(i-1)+2], udtdt_0[3*(i-1)+3]), 
            Vec3(w_0[3*(i-1)+1], w_0[3*(i-1)+2], w_0[3*(i-1)+3]), 
            Vec3(wdt_0[3*(i-1)+1], wdt_0[3*(i-1)+2], wdt_0[3*(i-1)+3]), 
            Vec3(wdtdt_0[3*(i-1)+1], wdtdt_0[3*(i-1)+2], wdtdt_0[3*(i-1)+3]), 
            R₀[i], 
            ID3,
            Vec3(u_0[3*(i-1)+1], u_0[3*(i-1)+2], u_0[3*(i-1)+3]), 
            Vec3(udt_0[3*(i-1)+1], udt_0[3*(i-1)+2], udt_0[3*(i-1)+3]), 
            Vec3(udtdt_0[3*(i-1)+1], udtdt_0[3*(i-1)+2], udtdt_0[3*(i-1)+3]), 
            Vec3(w_0[3*(i-1)+1], w_0[3*(i-1)+2], w_0[3*(i-1)+3]), 
            Vec3(wdt_0[3*(i-1)+1], wdt_0[3*(i-1)+2], wdt_0[3*(i-1)+3]), 
            Vec3(wdtdt_0[3*(i-1)+1], wdtdt_0[3*(i-1)+2], wdtdt_0[3*(i-1)+3]), 
            R₀[i], 
            ID3,
            compute_local_to_global_matrix(i, X, plane[i], T))
        for i in 1:size(X,1))
    end

    return nodes

end

#----------------------------------
# UTILS 
#----------------------------------

#  Compute rotation matrix from cylindrical to carthesian coordinates
function compute_local_to_global_matrix(i, X, plane, T=Float64)

    if plane == "xy"

        Xi = X[i]
        Θi = atan(Xi[2], Xi[1])  
        return Mat33(cos(Θi), -sin(Θi), 0,  sin(Θi), cos(Θi), 0, 0, 0, 1)

    elseif plane == "yz"

        Xi = X[i]
        Θi = atan(Xi[3], Xi[2])
        return Mat33(1, 0, 0, 0, cos(Θi), -sin(Θi), 0, sin(Θi), cos(Θi))
    
    elseif plane == "xz"

        Xi = X[i]
        Θi = atan(Xi[3], Xi[1])
        return Mat33(cos(Θi), 0, -sin(Θi), 0, 1, 0, sin(Θi), 0, cos(Θi))

    end 
    
end
