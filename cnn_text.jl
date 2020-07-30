# convolutional NN w/ text.

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Embeddings
using Embeddings: EmbeddingTable 
using Functors
using Statistics: mean
using Random: shuffle
using Parameters: @with_kw


include("/Users/austinbean/Desktop/programs/emr_nlp/punctuation_strip.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/s_split.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/rnn_embeddings.jl")



function PadSentence(str, dmax)
    l = length(split(str))
    pad = dmax - l 
    if (pad > 0)
        return str*repeat(" <EOS>", pad)
    else 
        return str 
    end 
end 



function LoadData()
		# Load and clean 
	xfile = CSV.read("/Users/austinbean/Desktop/programs/sumr2020/very_fake_diet_data.csv");
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :Column1]));
	words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
    maxlen = maximum(length.(split.(words)))                                            # longest sentence (in words)
    words = PadSentence.(words, maxlen)                                                 # now all sentences are padded w/ <EOS> out to maxlen
    labels = filter( x-> !ismissing(x), xfile[!, :Column2]);
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
    # data not yet in the right shape
    # easiest to map from here, but to what shape? 
        # 4 dims.  Height, Width, Channels, Sentences
        # Sentences = length(words) == 1002
        # Channels = 50 == dim(embeddings)
        # Height = 1
        # Width = 30 == length(words[1])

        # TODO - first: turn 1002 array sh1 into something like 1002 x 30 x 60. 
        # Then permute dims.  
            # permutedims ->
    e1 = Embed(allwords, 50, embtable)
    sh1 = e1.(interim)
    
    
    
    all_data = [(x,y) for (x,y) in zip(interim,labels)] |> shuffle                      # pair data and labels, then randomize order
    
    
    
    
    # separate test data and train data 
	train_data = all_data[1:end-args.test_d]
    test_data = all_data[end-args.test_d+1:end]
    
    # Embeddings
    embtable = load_embeddings(Word2Vec)



		# Return args b/c nwords may have been updated.
	return train_data, test_data
end 



e1 = Embed(allwords, 50, embtable) # can be evaluated on one-hot vectors, but then needs reshaping.

