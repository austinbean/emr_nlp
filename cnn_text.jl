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
    nobs = size(words,1)
    words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
    maxlen = maximum(length.(split.(words)))                                            # longest sentence (in words)
    words = PadSentence.(words, maxlen)                                                 # now all sentences are padded w/ <EOS> out to maxlen
    labels = filter( x-> !ismissing(x), xfile[!, :Column2]);
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
        # send through the embeddings layer to go from one-hot encoded sentences to word embeddings for the sentence
    embtable = load_embeddings(Word2Vec) # load the embeddings 
    embeddim = 50                                                                 # dimension of the embedding is constant
    e1 = Embed(allwords, embeddim, embtable)
    sh1 = e1.(interim)
        # TODO: rearrange and make Height the Dim for the embedding.  
        # data not yet in the right shape
        # Need: 4 dims.  Height, Width, Channels,  Sentences
        # Sentences = length(words) == 1002
        # Channels = 50 == dim(embeddings)
        # Height = 1
        # Width = 30 == length(words[1]) (after PadSentence) == maxlen 
    a1 = reduce(hcat, sh1) # makes 50 x (1002 x 30)
    b1 = reshape(a1, embeddim, 1, maxlen, nobs);
        # now the shape is right but the axes are wrong.
        # So permute dims: first dim is dimension of embedding (50) ⇒ map to 2nd dim (this is the height) 
        # Second dimension is 1 ⇒ map to 3rd dim (there is only one channel)
        # 3rd dim 30 is max sentence length ⇒ map to 1st dim (this is the width of the data)
        # 1002 is the number of observations in the data. ⇒ map to 4th dim 
    c1 = permutedims(b1, [3,1,2,4]); # This permutation does not look right, but gives the correct size output.  
    # collect as tuples  
    # separate test data and train data - 70/30
    tt = Int(floor(0.7*size(c1,4)))
    ctrain = c1[:,:,:,1:tt];
    ctest = c1[:,:,:,tt+1:end];
    ltrain = convert(Array{Float32,1}, labels[1:tt]);
    ltest = convert(Array{Float32,1}, labels[tt+1:end]);
    # Now do: data_tuple = (c1, labels) for test and train 
    # trd = (ctrain, ltrain)
    # tsd = (ctest, ltest)
    # TODO: need to return some size information: longest sentence length will be variable.  
	return Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest)
end 



        # after the convolutional layer there must be a reshape to reduce dimensions for a dense layer.
        # these dimensions need to be tracked so that after the reshape it's clear what input for Dense should be. 
        # Conv can operate on a height dim after data change. 
function model() 
    return m = Chain(Conv((3,5), 1=>128),                # size here is 28 x 46 x 128 x 701
            MaxPool((2,2)),                     # size here is 14 x 23 x 128 x 701
            Conv((3,3), 128=>8, relu),          # size here is 12 x 21 x 8 x 701,
            MaxPool((4,4)),                     # size here is 3 x 5 x 8 x 701
            x->reshape(x,:, size(x,4)),         # size here is 120 x 701,  = 3 x 5 x 8
            Dense(120,1, identity),             # size now is 1 x 701 - one prediction per observation.
            x->reshape(x, size(x,2), size(x,1)) # just a transpose 
            ) 
end  
#m(trd[1])

# function loss(x,y)
#     (m(x) - y)^2  
# end 


# TODO - something not right here relative to RNN
function Run()
    trd, tsd = LoadData()
    m = model()
    loss(x,y) = Flux.mse(m(x), y)
    parms = Flux.params(m)
    testloss() = Flux.mse(m(tsd.data[1]), tsd.data[2]) 
    testloss()
    evalcb = () -> @show testloss()
    opt = ADAM(1e-2)
    for i = 1:3
        Flux.train!(loss, parms, trd, opt, cb = throttle(evalcb, 1)) #
    end 
end 

Run()

