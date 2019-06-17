# NLP


using Word2Vec, DataFrames, CSVFiles

#=
- Should do more pre-processing: remove "-", "1/2", ".", ";", ")", "("
- Probably want something like "1/2" -> ".5", but the others can be dropped

=#


# produces the file diet_embed
	word2vec("diet_text.txt", "diet_embed", verbose=true)
	# not many words - 395 unique, 55,000 total.


# Load the embeddings
embed_1 = wordvectors("./diet_embed")


# look at some items
	get_vector(embed_1, "NEOSURE")
	get_vector(embed_1, "BREAST")

# cosine similar words

	cosine_similar_words(embed_1, "NEOSURE")
	cosine_similar_words(embed_1, "SIMILAC")
	cosine_similar_words(embed_1, "BREAST")
	# for the most part, those things "look right" - other words are similar

#=
I think what I need to do now is assign these words to the diet variables, then
figure out how to load the representations / outputs into the library.
=#

diet_df = DataFrame(load("data.csv"))

# want... something like a space-separated string of the numbers?

"""
`embedder(x,y)`
y should be a WordVectors{String, Float64, Int64}
x will be an long string
Returns a vector `outp` of floats of the embeddings of words from `x` in the embedding `y`
This should return a vector of floats.  This has variable length, depending on the length of x.
"""
function embedder(x,y)
	outp = Vector{Float64}()         # empty arrray
	for wd in split(x)               # split the string input
		if haskey( y.vocab_hash, wd) # need to catch key errors, I guess?
			push!(outp, y.vectors[y.vocab_hash[wd]])
		end
	end
	return outp
end


outp = Dict(string(i) => )
