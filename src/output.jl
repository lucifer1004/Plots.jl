
defaultOutputFormat(plt::Plot) = "png"

function png(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "png"), "w") do io
        show(io, MIME("image/png"), plt)
    end
end
png(fn::AbstractString) = png(current(), fn)

function svg(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "svg"), "w") do io
        show(io, MIME("image/svg+xml"), plt)
    end
end
svg(fn::AbstractString) = svg(current(), fn)

function pdf(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "pdf"), "w") do io
        show(io, MIME("application/pdf"), plt)
    end
end
pdf(fn::AbstractString) = pdf(current(), fn)

function ps(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "ps"), "w") do io
        show(io, MIME("application/postscript"), plt)
    end
end
ps(fn::AbstractString) = ps(current(), fn)

function eps(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "eps"), "w") do io
        show(io, MIME("image/eps"), plt)
    end
end
eps(fn::AbstractString) = eps(current(), fn)

function tex(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "tex"), "w") do io
        show(io, MIME("application/x-tex"), plt)
    end
end
tex(fn::AbstractString) = tex(current(), fn)

function json(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "json"), "w") do io
        show(io, MIME("application/vnd.plotly.v1+json"), plt)
    end
end
json(fn::AbstractString) = json(current(), fn)

function html(plt::Plot, fn::AbstractString)
    open(addExtension(fn, "html"), "w") do io
        show(io, MIME("text/html"), plt)
    end
end
html(fn::AbstractString) = html(current(), fn)

function txt(plt::Plot, fn::AbstractString; color::Bool = true)
    open(addExtension(fn, "txt"), "w") do io
        show(IOContext(io, :color => color), MIME("text/plain"), plt)
    end
end
txt(fn::AbstractString) = txt(current(), fn)

# ----------------------------------------------------------------

const _savemap = Dict(
    "png" => png,
    "svg" => svg,
    "pdf" => pdf,
    "ps" => ps,
    "eps" => eps,
    "tex" => tex,
    "json" => json,
    "html" => html,
    "tikz" => tex,
    "txt" => txt,
)

for out in Symbol.(unique(values(_savemap)))
    @eval @doc """
        $($out)([plot,], filename)
    Save plot as $($out)-file.
    """ $out
end

const _extension_map = Dict("tikz" => "tex")

function addExtension(fn::AbstractString, ext::AbstractString)
    oldfn, oldext = splitext(fn)
    oldext = chop(oldext, head = 1, tail = 0)
    if get(_extension_map, oldext, oldext) == ext
        return fn
    else
        return string(fn, ".", ext)
    end
end

"""
    savefig([plot,] filename)

Save a Plot (the current plot if `plot` is not passed) to file. The file
type is inferred from the file extension. All backends support png and pdf
file types, some also support svg, ps, eps, html and tex.
"""
function savefig(plt::Plot, fn::AbstractString)
    fn = abspath(expanduser(fn))

    # get the extension
    _, ext = splitext(fn)
    ext = chop(ext, head = 1, tail = 0)
    if isempty(ext)
        ext = defaultOutputFormat(plt)
    end

    # save it
    if haskey(_savemap, ext)
        func = _savemap[ext]
        return func(plt, fn)
    else
        error("Invalid file extension: ", fn)
    end
end
savefig(fn::AbstractString) = savefig(current(), fn)

# ---------------------------------------------------------

"""
    gui([plot])

Display a plot using the backends' gui window
"""
gui(plt::Plot = current()) = display(PlotsDisplay(), plt)

# IJulia only... inline display
function inline(plt::Plot = current())
    isijulia() || error("inline() is IJulia-only")
    Main.IJulia.clear_output(true)
    display(Main.IJulia.InlineDisplay(), plt)
end

function Base.display(::PlotsDisplay, plt::Plot)
    prepare_output(plt)
    _display(plt)
end

_do_plot_show(plt, showval::Bool) = showval && gui(plt)
function _do_plot_show(plt, showval::Symbol)
    showval == :gui && gui(plt)
    showval in (:inline, :ijulia) && inline(plt)
end

# ---------------------------------------------------------

const _best_html_output_type =
    KW(:pyplot => :png, :unicodeplots => :txt, :plotlyjs => :html, :plotly => :html)

# a backup for html... passes to svg or png depending on the html_output_format arg
function _show(io::IO, ::MIME"text/html", plt::Plot)
    output_type = Symbol(plt.attr[:html_output_format])
    if output_type == :auto
        output_type = get(_best_html_output_type, backend_name(plt.backend), :svg)
    end
    if output_type == :png
        # @info("writing png to html output")
        print(
            io,
            "<img src=\"data:image/png;base64,",
            base64encode(show, MIME("image/png"), plt),
            "\" />",
        )
    elseif output_type == :svg
        # @info("writing svg to html output")
        show(io, MIME("image/svg+xml"), plt)
    elseif output_type == :txt
        show(io, MIME("text/plain"), plt)
    else
        error("only png or svg allowed. got: $(repr(output_type))")
    end
end

# delegate showable to _show instead
function Base.showable(m::M, plt::P) where {M<:MIME,P<:Plot}
    return hasmethod(_show, Tuple{IO,M,P})
end

function _display(plt::Plot)
    @warn("_display is not defined for this backend.")
end

Base.show(io::IO, m::MIME"text/plain", plt::Plot) = show(io, plt)
# for writing to io streams... first prepare, then callback
for mime in (
    "text/html",
    "text/latex",
    "image/png",
    "image/eps",
    "image/svg+xml",
    "application/eps",
    "application/pdf",
    "application/postscript",
    "application/x-tex",
    "application/vnd.plotly.v1+json",
)
    @eval function Base.show(io::IO, m::MIME{Symbol($mime)}, plt::Plot)
        if haskey(io, :juno_plotsize)
            showjuno(io, m, plt)
        else
            prepare_output(plt)
            _show(io, m, plt)
        end
        return nothing
    end
end

Base.showable(::MIME"text/html", plt::Plot{UnicodePlotsBackend}) = false  # Pluto

Base.show(io::IO, m::MIME"application/prs.juno.plotpane+html", plt::Plot) =
    showjuno(io, MIME("text/html"), plt)

"Close all open gui windows of the current backend"
closeall() = closeall(backend())

# function html_output_format(fmt)
#     if fmt == "png"
#         @eval function Base.show(io::IO, ::MIME"text/html", plt::Plot)
#             print(io, "<img src=\"data:image/png;base64,", base64(show, MIME("image/png"), plt), "\" />")
#         end
#     elseif fmt == "svg"
#         @eval function Base.show(io::IO, ::MIME"text/html", plt::Plot)
#             show(io, MIME("image/svg+xml"), plt)
#         end
#     else
#         error("only png or svg allowed. got: $fmt")
#     end
# end
#
# html_output_format("svg")

# ---------------------------------------------------------
# Atom PlotPane
# ---------------------------------------------------------
function showjuno(io::IO, m, plt)
    dpi = plt[:dpi]

    jratio = get(io, :juno_dpi_ratio, 1)

    plt[:dpi] = jratio * Plots.DPI

    prepare_output(plt)
    try
        _showjuno(io, m, plt)
    finally
        plt[:dpi] = dpi
    end
end

function _showjuno(io::IO, m::MIME"image/svg+xml", plt)
    if Symbol(plt.attr[:html_output_format]) ≠ :svg
        throw(MethodError(show, (typeof(m), typeof(plt))))
    else
        _show(io, m, plt)
    end
end

Base.showable(::MIME"application/prs.juno.plotpane+html", plt::Plot) = false

_showjuno(io::IO, m, plt) = _show(io, m, plt)
