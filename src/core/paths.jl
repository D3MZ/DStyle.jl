function defaultsourcepaths()
    sourcedir = joinpath(pwd(), "src")
    if !isdir(sourcedir)
        return String[]
    end

    files = String[]
    foreach(walkdir(sourcedir)) do (root, _, names)
        foreach(names) do name
            if endswith(name, ".jl")
                push!(files, joinpath(root, name))
            end
        end
    end
    return sort!(files)
end

function modulesourcepaths(pkg::Module)
    moduleentry = pathof(pkg)
    if isnothing(moduleentry)
        throw(ArgumentError("Could not resolve source path for module $(nameof(pkg)). Pass paths=[...] explicitly."))
    end

    srcdir = dirname(String(moduleentry))
    if !isdir(srcdir)
        throw(ArgumentError("Resolved src directory does not exist: $srcdir"))
    end

    files = String[]
    foreach(walkdir(srcdir)) do (root, _, names)
        foreach(names) do name
            if endswith(name, ".jl")
                push!(files, joinpath(root, name))
            end
        end
    end
    return sort!(files)
end

function readchompornothing(c::Cmd)
    try
        text = readchomp(c)
        return isempty(strip(text)) ? nothing : text
    catch
        return nothing
    end
end

function repofromremoteurl(url::AbstractString)
    text = strip(String(url))
    result = nothing
    foreach((
        r"^git@github\.com:([^/]+/[^/]+?)(?:\.git)?$",
        r"^https?://github\.com/([^/]+/[^/]+?)(?:\.git)?$",
        r"^ssh://git@github\.com/([^/]+/[^/]+?)(?:\.git)?$",
    )) do pattern
        if isnothing(result)
            matchobj = match(pattern, text)
            if !isnothing(matchobj)
                result = String(matchobj.captures[1])
            end
        end
    end
    return result
end

function infergithubrepo()
    fromenv = get(ENV, "GITHUB_REPOSITORY", "")
    if occursin(r"^[^/]+/[^/]+$", fromenv)
        return fromenv
    end

    fromgit = readchompornothing(`git config --get remote.origin.url`)
    isnothing(fromgit) && return nothing
    return repofromremoteurl(fromgit)
end
