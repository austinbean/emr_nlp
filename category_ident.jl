# identify categories...


test1 = [ "hello: xHELLO: ???PUNC: " ,  "something TWICE: TWICE: ONCE: something BYE:" , " 6 1 3 HIHIHHI :something", "OTHER", "not: YES:", "HAS: TWO:"]


function categories(x::Union{String,Missing}, D::Dict)
	if !ismissing(x)
		for el in collect.( eachmatch.( r"[A-Z]+:", x ) )
			if haskey(D, el.match)
				D[el.match] += 1
			else 	
				D[el.match] = 1 
			end 
		end 
	end 
end 

testd = Dict{String, Int64}()


for el in test1
	categories(el, testd)
end 

# Column G.
#=

for el in sh1["G2:G4360"]
    categories(el, testd)
end

out1 = Array{Int64,1}()
labs = Array{String,1}()
for k1 in keys(testd)
	if testd[k1] > 100
		push!(out1, testd[k1])
		push!(labs, titlecase(replace(k1, ":"=>"")))
	end 
end 

Plots.bar( out1, xticks=(1:length(labs), labs), xrotation = 45, xtickfont = font(5, "Courier"), bottom_margin = 20mm, legend=false, fillalpha = 0.4, fillcolor=:navy, title = "Counts of Question Categories")

savefig("/Users/tuk39938/Desktop/programs/emr_nlp/category_frequency.pdf")

=#