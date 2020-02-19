using Distributed
addprocs(2; exeflags="--project")

@info "Creating a MP environment based on 2 procs\n";
@everywhere using Revise;
@info "Load code everywhere\n";
@everywhere includet("tests/TestMP.jl");
@info "MP environment is ready\n";

