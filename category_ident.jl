# identify categories...


test1 = [ "hello: xHELLO:" ,  "something TWICE: TWICE: ONCE: something BYE:" , " 6 1 3 HIHIHHI :something", "OTHER", "not: YES:", "HAS: TWO:"]


function categories(x::String, D::Dict)
	for el in collect.( eachmatch.( r"[A-Z]+:", x ) )
		if haskey(D, el.match)
			D[el.match] += 1
		else 	
			D[el.match] = 1 
		end 
	end 
end 

testd = Dict{String, Int64}()


for el in test1
	categories(el, testd)
end 