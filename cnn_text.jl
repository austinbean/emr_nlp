# convolutional NN w/ text.

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Flux.Data: DataLoader
using Embeddings
using Embeddings: EmbeddingTable 
using Functors
using Statistics: mean
using Random
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
    # TODO - add a shuffle somewhere early on.  
	xfile = CSV.read("/Users/austinbean/Desktop/programs/sumr2020/very_fake_diet_data.csv");
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :Column1]));
    nobs::Int64 = size(words,1)
    words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
    maxlen = maximum(length.(split.(words)))                                            # longest sentence (in words)
    println("max length: ", maxlen)
    words = PadSentence.(words, maxlen)                                                 # now all sentences are padded w/ <EOS> out to maxlen
    labels = filter( x-> !ismissing(x), xfile[!, :Column2]);
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
        # send through the embeddings layer to go from one-hot encoded sentences to word embeddings for the sentence
    embtable = load_embeddings(Word2Vec) # load the embeddings 
    embeddim::Int64 = 50                                                                 # dimension of the embedding is constant
    e1 = Embed(allwords, embeddim, embtable)
    sh1 = e1.(interim)
        # data not yet in the right shape
        # Need: 4 dims.  Height, Width, Channels,  Sentences
        # Sentences = length(words) == 1002
        # Channels = 50 == dim(embeddings)
        # Height = 1
        # Width = 30 == length(words[1]) (after PadSentence) == maxlen 
    a1 = reduce(hcat, sh1) # makes 50 x (1001 x 30)
    b1 = reshape(a1, embeddim, 1, maxlen, nobs);
        # now the shape is right but the axes are wrong.
        # So permute dims: first dim is dimension of embedding ⇒ map to 3rd dim (this is the # of channels) 
        # Second dimension is 1 ⇒ map to 2nd dim (SAME) (there is no height w/ this data - set to 1)
        # 30 is max sentence length ⇒ map to 1st dim (this is the width of the data)
        # 1002 is the number of observations in the data. ⇒ map to 4th dim 
    c1 = permutedims(b1, [3,2,1,4]); # This is the right form, as far as I can tell.  
    # collect as tuples  
    # separate test data and train data - 70/30
    tt = Int(floor(0.7*size(c1,1)))
    ctrain = c1[:,:,:,1:tt];
    ctest = c1[:,:,:,tt+1:end];
    ltrain = labels[1:tt];
    ltest = labels[tt+1:end];
    # Now do: data_tuple = (c1, labels) for test and train 
    trd = (ctrain, ltrain)
    tsd = (ctest, ltest)
	return trd, tsd
end 

trd, tsd = LoadData();

    # this will require a reshape somewhere.
        # after the convolutional layer there must be a reshape.
m = Chain(Conv((3,1), 50=>128), 
          MaxPool((2,1)),
          x->reshape(x,:, size(x,4)), # need to understand the dimensions of this reshape 
          Dense(1792, 1, identity) ) # now this has length 20-something.  

m(trd[1])
