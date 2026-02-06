using DStyle
using Documenter

DocMeta.setdocmeta!(DStyle, :DocTestSetup, :(using DStyle); recursive=true)

makedocs(;
    modules=[DStyle],
    authors="Demetrius Michael <arrrwalktheplank@gmail.com>",
    sitename="DStyle.jl",
    format=Documenter.HTML(;
        canonical="https://D3MZ.github.io/DStyle.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/D3MZ/DStyle.jl",
    devbranch="main",
)
