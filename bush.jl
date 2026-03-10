#!/usr/bin/env julia
# tree.jl: decision tree for multi-objective optimization (c) 2026 Tim Menzies, MIT
using Random, Printf
const the = Dict("leaf"=>3,"Budget"=>50,"Show"=>30,"seed"=>1,"p"=>2)

# --- Types ---
abstract type Col end
mutable struct Num<:Col; txt; at; n; has; ok; goal; end
mutable struct Sym<:Col; txt; at; n; has; end
mutable struct Cols    ; names; x; y; all; end
mutable struct Data    ; rows; cols; end
mutable struct Tree    ; sc; col; cut; L; R; mids; y; end

Num(s="", a=0) = Num(s, a, 0, Float64[], 0, endswith(s, "-") ? 0 : 1)
Sym(s="", a=0) = Sym(s, a, 0, Dict{Any,Int}())
Data()         = Data(Vector{Any}[], nothing)
Tree(s)        = Tree(s, 0, 0, 0, 0, Dict(), Num())

function Cols(n)
  x, y, all = Col[], Col[], Col[] # PRO FIX: Typed arrays prevent slow 'Any' boxing
  for (i, s) in enumerate(n)
    col = (isuppercase(s[1]) ? Num : Sym)(s, i)
    push!(all, col)
    endswith(s, "X") || push!(occursin(r"[+\-!]$", s) ? y : x, col) end
  Cols(n, x, y, all) end

# --- Update ---
adds(ls, c=Num()) = (for v in ls add!(c,v) end; c)
add!(x,v)         = (v != "?" && (x.n += 1; add1!(x, v)); v)

add1!(n::Num, v)  = (n.ok=0; push!(n.has, v)) 
add1!(s::Sym, v)  = s.has[v] = 1 + get(s.has,v,0)
add1!(c::Cols,r)  = for col in c.all add!(col,r[col.at]) end
add1!(d::Data,r)  = d.cols===nothing ? d.cols=Cols(r) : push!(d.rows, add!(d.cols,r))

# --- Query ---
ok!(n::Num) = (n.ok==0 && (sort!(n.has); n.ok=1); n)
mid(n::Num) = (h=ok!(n).has; isempty(h) ? 0 : h[length(h)÷2+1])
mid(s::Sym) = isempty(s.has) ? nothing : argmax(s.has)

spread(s::Sym) = -sum(v/s.n*log2(v/s.n) for v in values(s.has) if v>0)
spread(n::Num) = begin
  h=ok!(n).has; m=length(h)
  m<2 ? 0 : (h[Int(0.9m|1)]-h[Int(0.1m|1)])/2.56 end

norm(n::Num, v) =  begin
  v=="?" ? v : (h=ok!(n).has
  length(h)<2 ? 0 : clamp((v-h[1])/(h[end]-h[1]),0,1)) end

disty(d, r) = begin
  # PRO FIX: changed 'the.p' to 'the["p"]' to prevent crashes
  ls=[abs(norm(c,r[c.at])-c.goal)^the["p"] for c in d.cols.y]
  (sum(ls)/length(ls))^(1/the["p"]) end

clone(d, rs=[]) = begin
  d2=Data(); add!(d2,d.cols.names)
  for r in rs add!(d2,r) end; d2 end

# --- Splits ---
leaf(::Num, c, v) = v<=c
leaf(::Sym, c, v) = v==c

cuts(s::Sym, rs) = unique([r[s.at] for r in rs if r[s.at]!="?"])
cuts(n::Num, rs) = begin
  vs=sort([r[n.at] for r in rs if r[n.at]!="?"]) 
  length(vs)>=2 ? [vs[length(vs)÷2]] : [] end

function step(rs, c, cut)
  L = [r for r in rs if r[c.at]!="?" && leaf(c,cut,r[c.at])]
  R = [r for r in rs if r[c.at]!="?" && !leaf(c,cut,r[c.at])]
  length(L)>=the["leaf"] && length(R)>=the["leaf"] ? (L,R) : nothing end

# --- Tree Build ---
function build!(t::Tree, d, rs)
  t.y = adds([t.sc(r) for r in rs])
  t.mids = Dict(c.txt=>mid(c) for c in clone(d,rs).cols.y)
  length(rs) < 2*the["leaf"] && return t
  bestW, best = 1e32, nothing
  for col in d.cols.x, cut in cuts(col,rs)
    if (ss = step(rs,col,cut)) !== nothing
      w = sum(spread(adds([t.sc(r) for r in s]))*length(s) for s in ss)
      w < bestW && (bestW=w; best=(col,cut,ss)) end end
  if best !== nothing
    t.col,t.cut,(L,R) = best
    t.L = build!(Tree(t.sc),d,L)
    t.R = build!(Tree(t.sc),d,R) end
  t end

# --- Display & Helpers ---
rat(x::AbstractFloat) = @sprintf("%.2f",x)
rat(x::Dict)          = "{"*join(sort(["$k=$(rat(v))" for (k,v) in x]),", ")*"}"
rat(x::Vector)        = "{"*join([rat(v) for v in x],", ")*"}"
rat(x)                = string(x)

function nodes(t::Tree, fn, l=0, p="")
  fn(t,l,p); t.L==0 && return
  ops = t.col isa Num ? ("<=",">") : ("==","!=")
  for (k,o) in sort([(t.L,ops[1]),(t.R,ops[2])], by=x->mid(x[1].y))
    nodes(k,fn,l+1, "$(t.col.txt) $o $(rat(t.cut))") end end

thing(s) = (s=strip(s); isnothing(tryparse(Int,s)) ? (isnothing(tryparse(Float64,s)) ? 
  (s=="true"?true:s=="false"?false:s) : parse(Float64,s)) : parse(Int,s))

# --- Examples ---
function eg_data(f)
  d=Data()
  for r in [thing.(split(l,",")) for l in eachline(f)] add!(d,r) end
  d2=clone(d,shuffle(d.rows)[1:min(end,the["Budget"])])
  t=build!(Tree(r->disty(d2,r)),d2,d2.rows)
  nodes(t,(n,l,p)->@printf("%-*s ,%4s ,(%3d), %s\n",the["Show"],
    l>0?"|   "^(l-1)*p:"",rat(mid(n.y)),n.y.n,rat(n.mids))) end

# CLI Map 
const EG = Dict("data" => eg_data)

# --- Main ---
if abspath(PROGRAM_FILE)==@__FILE__
  args=copy(ARGS); Random.seed!(the["seed"])
  while !isempty(args)
    k=replace(popfirst!(args),r"^-+"=>"")
    if haskey(EG, k)
      EG[k](popfirst!(args))
    elseif haskey(the,k) 
      the[k]=thing(popfirst!(args)) end end end
