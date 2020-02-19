using Distributed
addprocs(1; exeflags="--project")

@info "Creating a MT environment based on 1 procs\n";
@everywhere using Revise;
@info "Load code everywhere\n";
@everywhere includet("tests/TestMP.jl");
@info "MT environment is ready\n";

