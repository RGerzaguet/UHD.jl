push!(LOAD_PATH, "../src/")
using Documenter, DigitalComm

makedocs(sitename="UHD.jl", 
		 format = Documenter.HTML(),
		 pages    = Any[
						"Introduction to UHD"   => "index.md",
						"Function list"          => "base.md",
						"Examples"                => Any[ 
														 "Examples/example_setup.md"
														 ],
						],
		 );

#makedocs(sitename="My Documentation", format = Documenter.HTML(prettyurls = false))

deploydocs(
    repo = "github.com/RGerzaguet/uhd.jl",
)
