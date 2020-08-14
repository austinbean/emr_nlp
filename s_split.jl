# s_split - one file for this function. 

"""
`s_split(x)`
This is a dumb function.  Takes a string, applies split (which returns an array of substrings)
then converts that to an array of Strings.
"""
function s_split(x)
	# write to take a delimiter, but return a vector of strings, not substrings
	return convert(Array{String,1}, split(x))
end 