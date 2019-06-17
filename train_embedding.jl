# NLP


using Word2Vec, DataFrames, CSVFiles

#=
- Should do more pre-processing: remove "-", "1/2", ".", ";", ")", "("
- Probably want something like "1/2" -> ".5", but the others can be dropped

=#

"""
`vec_embedder(x,y)`
y should be a WordVectors{String, Float64, Int64}
x will be an long string
Returns a vector `outp` of floats of the embeddings of words from `x` in the embedding `y`
This should return a vector of floats.  This has variable length, depending on the length of x.
"""
function vec_embedder(x,y)
	outp = Vector{Float64}()         # empty arrray
	for wd in split(x)               # split the string input
		if haskey( y.vocab_hash, wd) # need to catch key errors, I guess?
			push!(outp, y.vectors[y.vocab_hash[wd]])
		end
	end
	return outp
end


"""
`embed_set`
will take a dataframe (of strings and quantities) recorded in x
the columns of y are :diet and :total_quantity
will return outp, a vector which is (recorded_consumption, vector_of_word_embeddings)
"""
function embed_set(x,y)
    outp = Vector{Vector{Number}}()
		# TODO - wrong size taken here, probably.
	len, wid = size(x)
	for el in 1:len
		push!(outp, vcat(x[el,:total_quantity] , vec_embedder(x[el,:diet] ,y)) )
	end
	return outp
end


"""
`generate_out(df_1)`
takes the output of embed_set which is a vector of vectors and then
retuns a single array of dimensions (length(df_1)) × (max length(df_1[i]) ∀ i = 1:length(df_1))
Will generate a lot of trailing zeros
"""
function generate_out(df_1)
	int1 = maximum([length(x) for x in df_1])
	output_1 = zeros(length(df_1), int1)
	for i = 1:length(df_1)
		for j = 1:length(df_1[i])
			output_1[i,j] += df_1[i][j]
		end
	end
	return output_1
end


# produces the file diet_embed
	word2vec("diet_text.txt", "diet_embed", verbose=true)
	# not many words - 395 unique, 55,000 total.
# Load the embeddings
	embed_1 = wordvectors("./diet_embed")
# Load the data to write some vectors of embedded words
	diet_df = DataFrame(load("data.csv"))
# map the words to (consumption, embedded_words)
	df_out = embed_set(diet_df, embed_1)
# generate a matrix from the above
	to_save = generate_out(df_out)
# convert the above array to a DataFrame to save the CSV
	to_save = convert(DataFrame, to_save)
# save the CSV
	save("embedded_data.csv", to_save)



#=
# look at some items
	get_vector(embed_1, "NEOSURE")
	get_vector(embed_1, "BREAST")

# cosine similar words

	cosine_similar_words(embed_1, "NEOSURE")
	cosine_similar_words(embed_1, "SIMILAC")
	cosine_similar_words(embed_1, "BREAST")
	# for the most part, those things "look right" - other words are similar
=#
