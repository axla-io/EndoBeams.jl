"Preallocates and initialises all the variables and starts the temporal loop"
function solver!(allnodes, allbeams, conf, comp, sdf, pn_constrains, params)
    
    # -------------------------------------------------------------------------------------------
    # INITIALISATION
    # -------------------------------------------------------------------------------------------
  
    @unpack scale, ENERGY_STOP, SHOW_COMP_TIME, SHOW_TIME_SECTIONS, SAVE_NODES_VTK, SAVE_ENERGY, SAVE_INTERPOLATION_VTK, SAVE_GP_VTK, thisDirOutputPath = params
    
    to = TimerOutput()
        
    if !SHOW_TIME_SECTIONS
        disable_timer!(to)
    end 

    @timeit to "Solver initialization" begin

        # vectors to save energy evolution
        plot_Phi_energy  = Vector{T}()
        plot_K_energy = Vector{T}()
        plot_C_energy = Vector{T}()
        
        # initialization of time loop variables
        t = 0.
        start = time()
        i = 1
        dt = comp.dt
        dt_plot = comp.dt_plot 
        fact_div::Int64 = 1   
        k_count_OKit = 0
        step = 1

        # preallocated vectors for beam interpolation
        int_pos = zeros((allbeams.numberInterpolationPoints[1]+1)*length(allbeams),3)
        int_conn = zeros(allbeams.numberInterpolationPoints[1]+1, length(allbeams))
        
        # preallocation of the vectors and matrices used in the computaion
        sol_n, sol_n1, sol_GP, nodes_sol, matrices, energy, fixed_matrices, u_imp = solver_initialisation(conf, allnodes, allbeams, int_pos, int_conn, comp, pn_constrains, thisDirOutputPath, SAVE_INTERPOLATION_VTK, SAVE_GP_VTK, SAVE_NODES_VTK)
        
    end 
    
    # -------------------------------------------------------------------------------------------
    # TIME LOOP 
    # -------------------------------------------------------------------------------------------

    STOP_SIMULATION = false

    @timeit to "Solver time loop" begin
        
        while (t<comp.tend && fact_div < 1E20 && !STOP_SIMULATION)
            
            @timeit to "Dynamic step" begin
                
                t_n = t
                t_n1 = t_n + dt
                tcomp = time() - start
                
                if SHOW_COMP_TIME
                    println("-------------------------------------------------")
                    println("tphys = $t_n1, tcomp = $tcomp, ratio = $(tcomp/t), dt = $dt, step = $step ")
                end 
                
                # solve system @t_n
                flag_conv = solve_step_dynamics!(allnodes, allbeams, pn_constrains, t_n1, dt, sol_n, sol_n1, sol_GP, nodes_sol, matrices, energy, fixed_matrices, u_imp, conf, comp, sdf, to, SHOW_COMP_TIME)
                
                # if not converged, halve the time step and re-solve the system until it converges
                while (flag_conv == 0 && fact_div < 1E20)
                    
                    if scale == 2
                        fact_div = fact_div*2
                        dt = dt/2
                    elseif scale == 10 
                        fact_div = fact_div*10
                        dt = dt/10
                    end 
                    
                    t_n1 = t_n + dt
                    
                    if SHOW_COMP_TIME
                        println("-----TIME STEP DECREASED dt = dt0/$fact_div")
                        println("tphys = $t_n1, tcomp = $tcomp  dt = $dt, ratio = $(tcomp/t)")
                    end
                    
                    sol_n1 = deepcopy(sol_n)
                    update_nodes_not_converged!(allnodes)
                    
                    flag_conv = solve_step_dynamics!(allnodes, allbeams, pn_constrains, t_n1, dt, sol_n, sol_n1, sol_GP, nodes_sol, matrices, energy, fixed_matrices, u_imp, conf, comp, sdf, to, SHOW_COMP_TIME)
                    k_count_OKit = 0
                    
                end
                
                # if the time step has been halved but the simulation has converged the last 8 times, double it
                if fact_div > 1
                    
                    k_count_OKit = k_count_OKit + 1
                
                    if k_count_OKit > 15
                        
                        if SHOW_COMP_TIME
                            println("-----TIME STEP INCREASED dt=dt0/$fact_div")
                        end 
                        
                        if scale == 2
                            fact_div = fact_div/2
                            dt = dt*2
                        elseif scale == 10 
                            fact_div = fact_div/10
                            dt = dt*10
                        end 
                        
                        k_count_OKit = 0
                        
                    end
                    
                end
                
            end
            
            @timeit to "Write results to file" begin
                
                # save VTK with frequency 1/dt_plot: 
                if  abs(t_n1-i*dt_plot)<1e-9 || t_n1>i*dt_plot
                    save_VTK(i, allnodes, allbeams, sol_GP, int_pos, int_conn, thisDirOutputPath, SAVE_INTERPOLATION_VTK, SAVE_GP_VTK, SAVE_NODES_VTK)
                    i = i+1
                end

                # save the energy values at the current step
                push!(plot_Phi_energy, energy.Phi_energy)
                push!(plot_K_energy, energy.K_energy)
                push!(plot_C_energy, energy.C_energy)
                
                if SAVE_ENERGY
                    save_energy(plot_Phi_energy, plot_K_energy, plot_C_energy, thisDirOutputPath)           
                end        
                
            end 
            
            @timeit to "Update variables" begin
                
                # update variables after the step
                sol_n = deepcopy(sol_n1)
                update_nodes_converged!(allnodes)
                t = t_n1
                step = step+1
                
            end 

            if ENERGY_STOP
                if plot_K_energy[end] < 1e-10
                    println("ENERGY THRESHOLD REACHED")
                    STOP_SIMULATION = true
                end 
            end

        end 

    end
    
    # show  sections time
    if SHOW_TIME_SECTIONS
        show(to)
    end 
    
end

#  Solves the current step
function solve_step_dynamics!(allnodes, allbeams, pn_constrains, t_n1, dt, sol_n, sol_n1, sol_GP, nodes_sol, matrices, energy, fixed_matrices, u_imp, conf, comp, sdf, to, SHOW_COMP_TIME) 

    # -------------------------------------------------------------------------------------------
    # INITIALIZATION
    # -------------------------------------------------------------------------------------------
    
    @timeit to "Time step initialization" begin
        
        # maximum number of iterations
        max_it = comp.max_it
        
        # update external force value
        if conf.ext_forces.flag_crimping == false
            update_current_solution_external_force!(sol_n1, t_n1, conf)
        else 
            update_current_solution_external_force_crimping!(sol_n1, t_n1, conf, allnodes)
        end 
        
        # update boundary conditions value
        if conf.bc.flag_disp_vector == false 
            update_current_boundary_conditions!(u_imp, t_n1, conf)
        else
            update_current_boundary_conditions_vector!(u_imp, t_n1, conf)
        end 
        
    end
    
    # -------------------------------------------------------------------------------------------
    # PREDICTOR
    # -------------------------------------------------------------------------------------------
    
    @timeit to "Predictor" begin
        
        # predict the solution @n+1
        predictor!(allnodes, allbeams, pn_constrains, matrices, energy, sol_n1, sol_n, sol_GP, u_imp, dt, conf, comp, sdf, fixed_matrices, nodes_sol, t_n1, to) 
        
    end
    
    # -------------------------------------------------------------------------------------------
    # CORRECTOR
    # -------------------------------------------------------------------------------------------
    
    @timeit to "Corrector" begin
        
        # corrector loop: output = number of iterations
        k = corrector_loop!(allnodes, allbeams, pn_constrains, matrices, energy, sol_n1, sol_n, sol_GP, u_imp, dt, conf, comp, sdf, fixed_matrices, nodes_sol, t_n1, to, SHOW_COMP_TIME)
        
    end
    
    return k < max_it
    
end 

# Predicts the solution at the current step
function predictor!(allnodes, allbeams, pencons, matrices, energy, sol_n1, sol_n, sol_GP, u_imp, dt, conf, comp, sdf, fixed_matrices, nodes_sol, t_n1, to)
    
    # -------------------------------------------------------------------------------------------
    # INITIALISATION
    # -------------------------------------------------------------------------------------------
    
    @timeit to "Initialization" begin
        
        # dofs
        free_dofs = conf.bc.free_dofs
        fixed_dofs = conf.bc.fixed_dofs

        # parameters for the numerical integration 
        beta = comp.beta
        gamma = comp.gamma
        alpha = comp.alpha
        
        # solutions @n
        update_global_predictor!(nodes_sol, allnodes)
        
    end
    
    # -------------------------------------------------------------------------------------------
    # SOLVE
    # -------------------------------------------------------------------------------------------
    
    @timeit to "Compute matrices" begin
        
        # compute the matrices    
        compute_K_T!(allnodes, allbeams, matrices, energy, conf, sdf, fixed_matrices, comp, sol_GP, to)
        
    end
    
    @timeit to "Compute penalty constrains contributions" begin
        
        # impose multi freedom constrains
        compute_multifreedom_constraints!(matrices, allnodes, pencons, t_n1)        
    end 
    
    @timeit to "Compute tangent matrix" begin
        
        # eq142 in [2]: compute tangent matrix
        compute_Ktan_sparse!(nodes_sol, matrices, alpha, beta, gamma, dt)

    end
    
    @timeit to "Compute residual" begin
        
        # eq119 in [3]: compute the residual
        nodes_sol.r .=  (1+alpha) .* (sol_n1.fext .- matrices.Tint .- matrices.Tk .- matrices.Tct) .- alpha .* (sol_n.fext)
        
        nodes_sol.aux1 .= (gamma/beta) .* nodes_sol.Ddt .- (dt/2*(2*beta-gamma)/beta) .* nodes_sol.Ddtdt
        mul!(nodes_sol.aux2, matrices.Ck, nodes_sol.aux1)
        nodes_sol.r .= nodes_sol.r .+  nodes_sol.aux2 
        
        nodes_sol.aux1 .= dt .* nodes_sol.Ddt .+ (dt^2)/2 .* nodes_sol.Ddtdt
        mul!(nodes_sol.aux2, matrices.M, nodes_sol.aux1)
        nodes_sol.aux2 .= 1/(beta*dt^2) .* nodes_sol.aux2
         
        nodes_sol.r .= nodes_sol.r .+ nodes_sol.aux2 

    end
    
    @timeit to "Impose BCs" begin
        
        # impose BCs   
        if conf.bc.flag_cylindrical == 1       
            dirichlet_global_to_local!(nodes_sol, allnodes)     
        end  
        
        # impose single freedom constrain
        impose_BC_displacements!(nodes_sol, u_imp, fixed_dofs)
    end 


    @timeit to "Compute free tangent matrix and residual" begin

        fill_r_free!(nodes_sol, free_dofs)                
        fill_Ktan_free!(nodes_sol)

    end 
    
    @timeit to "Linear solve" begin 
        
        nodes_sol.ΔD_free .=  nodes_sol.Ktan_free\nodes_sol.r_free

    end
    
    @timeit to "Update" begin 

        # fill whole dofs solution vector with free dofs solution
        fill_ΔD_free_dofs!(nodes_sol, free_dofs)
                        
        if conf.bc.flag_cylindrical == 1
            dirichlet_local_to_global!(nodes_sol, allnodes)    
        end  
        
        # eq114-115 in [3]
        update_nodal_solutions_predictor!(nodes_sol, beta, gamma, dt)
        
        # update the local nodes 
        update_local_predictor!(allnodes, nodes_sol)
        
    end
    
end 

# Corrects the solution at the current step
function corrector_loop!(allnodes, allbeams, pncons, matrices, energy, sol_n1, sol_n, sol_GP, u_imp, dt, conf, comp, sdf, fixed_matrices, nodes_sol, t_n1, to, SHOW_COMP_TIME) 
    
    # -------------------------------------------------------------------------------------------
    # INITIALISATION
    # -------------------------------------------------------------------------------------------
    
    # @timeit to "Initialization" begin
        
        # tollerances
        tol_res = comp.tol_res
        tol_ΔD_k = comp.tol_ΔDk
        max_it = comp.max_it
        
        # dofs
        ndofs = conf.ndofs
        free_dofs = conf.bc.free_dofs
        fixed_dofs = conf.bc.fixed_dofs
        disp_dofs = conf.disp_dofs

        # update @n+1   
        update_global_corrector!(nodes_sol, allnodes, disp_dofs)
        
        # constants for the numerical integration
        beta = comp.beta
        gamma = comp.gamma
        alpha = comp.alpha
        
        # current iteration number, initalised to 0
        k = 0
        
        # randomly initialised the variables for the while cycle 
        nodes_sol.ΔD  .= 5 
        aux_tol = 1.0e10
        
    # end
    
    # -------------------------------------------------------------------------------------------
    # CORRECTOR LOOP
    # -------------------------------------------------------------------------------------------
    
    # @timeit to "Newton solver" begin
        
        while ((aux_tol>tol_res) || (((norm(nodes_sol.ΔD[free_dofs])))>tol_ΔD_k)) && (k<max_it)         
            
            k += 1
            
            @timeit to "Compute matrices" begin
                
                # compute the contributions for each beam and assemble into the Matrix structure
                compute_K_T!(allnodes, allbeams, matrices, energy, conf, sdf, fixed_matrices, comp, sol_GP, to)  
                
            end
            
            # @timeit to "Compute multi freedom constrains contributions" begin
                
                # impose multi freedom constrains
                compute_multifreedom_constraints!(matrices, allnodes, pncons, t_n1)             
                
            # end 
            
            @timeit to "Compute tangent matrix and residual" begin
                
                # eq142 in [2]: compute tangent matrix
                compute_Ktan_sparse!(nodes_sol, matrices, alpha, beta, gamma, dt)

                # eq140 in [2]: compute residual 
                compute_res_corrector!(nodes_sol, matrices, sol_n1, sol_n, alpha)

            end
            
            # @timeit to "Update nodal solutions" begin
                
                # update global nodal solution at each iteration
                update_nodal_solution_corrector_loop!(nodes_sol, disp_dofs)
                
            # end 
            
            @timeit to "Impose BCs" begin
                
                
                # if necessary, move to cylindrical coordinates     
                if conf.bc.flag_cylindrical == 1  
                    dirichlet_global_to_local!(nodes_sol, allnodes)          
                end     
                
                # impose single freedom constrains
                impose_BC_displacements!(nodes_sol, u_imp, fixed_dofs)
                
            end 
            
            @timeit to "Compute free tangent matrix and residual" begin

                fill_r_free!(nodes_sol, free_dofs)                
                fill_Ktan_free!(nodes_sol)
        
            end 
            
            @timeit to "Linear solve" begin
                
                nodes_sol.ΔD_free .=  nodes_sol.Ktan_free\nodes_sol.r_free

            end 
            
            @timeit to "Update global and local variables" begin
    
                # fill whole dofs solution vector with free dofs solution
                fill_ΔD_free_dofs!(nodes_sol, free_dofs)
                
                # if necessary, return to cartesian coordinates        
                if conf.bc.flag_cylindrical == 1   
                    dirichlet_local_to_global!(nodes_sol,  allnodes)            
                end     
                
                # update global displacement variables
                update_nodal_solutions_corrector!(nodes_sol, disp_dofs, gamma, beta, dt)
                
                # update the nodes displacement, velocity, acceleration and rotation
                update_local_corrector!(allnodes, nodes_sol.ΔD, dt, nodes_sol, comp)
                
                # update the current solution vectors (used in the next time step)
                update_current_solution_corrector!(sol_n1, ndofs, matrices)
            end 
            
            @timeit to "Compute norms" begin
                
                # update norms (used to check while cycle)
                aux_tol = compute_norms_corrector(k, aux_tol, sol_n1, nodes_sol, matrices, SHOW_COMP_TIME)
                
            end 

        # end
        
        
    end 
    
    # -------------------------------------------------------------------------------------------
    # OUTPUT
    # -------------------------------------------------------------------------------------------
    
    return k 
    
end 