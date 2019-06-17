# NLP


using Word2Vec

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