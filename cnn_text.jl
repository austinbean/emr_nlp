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

    # note: removed filepath.  
include("./punctuation_strip.jl")
include("./s_split.jl")
include("./rnn_embeddings.jl")


@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 100            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 5       # throttle timeout
    test_d::Int = 300       # length of the testing set.
    maxw::Int = 30          # maximum number of words in a sentence 
    embeddim::Int = 50      # dimension of embedding 
    tt::Float64 = 0.7       # fraction of data train
    epos::Int64 = 100       # epochs
end



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
    # args instance 
    args = Args()
        # Load and clean 
    # TODO - add a shuffle somewhere early on.  
	xfile = CSV.read("./data_labeled.csv");
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :diet]));
    nobs = size(words,1)
    # NB: longest sentence in training data is 153 words.  
    words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
    maxlen = maximum(length.(split.(words)))                                            # longest sentence (in words)
    args.maxw = maxlen
    words = PadSentence.(words, maxlen)                                                 # now all sentences are padded w/ <EOS> out to maxlen
    labels = filter( x-> !ismissing(x), xfile[!, :total_quantity]);
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
        # send through the embeddings layer to go from one-hot encoded sentences to word embeddings for the sentence
    embtable = load_embeddings(GloVe) # load the embeddings 
    embeddim = args.embeddim                                                                 # dimension of the embedding is constant
    e1 = Embed(allwords, embeddim, embtable)
    sh1 = e1.(interim)
        # At this point data not yet in the right shape
        # Need: 4 dims.  Height, Width, Channels, Sentences
        # Height = 50 == dim(embeddings)
        # Width = 30 == length(words[1]) (after PadSentence) == maxlen 
        # Channels = 1
        # Sentences = length(words) == 1002
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
    tt = Int(floor(args.tt*size(c1,4)))
    ctrain = c1[:,:,:,1:tt];
    ctest = c1[:,:,:,tt+1:end];
    ltrain = convert(Array{Float32,1}, labels[1:tt]);
    ltest = convert(Array{Float32,1}, labels[tt+1:end]);
    # TODO: need to return some size information: longest sentence length will be variable.  
	return Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest), args
end 



        # after the convolutional layer there must be a reshape to reduce dimensions for a dense layer.
        # these dimensions need to be tracked so that after the reshape it's clear what input for Dense should be. 
        # Conv can operate on a height dim after data change. 
function model(args) 
    # TODO - this may change depending on the longest sentence in the set - see Dense layer.  
    return m = Chain(Conv((3,5), 1=>128),                # size here is 28 x 46 x 128 x 701
            MaxPool((2,2)),                     # size here is 14 x 23 x 128 x 701
            Conv((3,3), 128=>8, relu),          # size here is 12 x 21 x 8 x 701,
            MaxPool((4,4)),                     # size here is 3 x 5 x 8 x 701
            x->reshape(x,:, size(x,4)),         # size here is 120 x 701,  = 3 x 5 x 8
            Dense(120,1, identity),             # TODO: this dim will change! size now is 1 x 701 - one prediction per observation.
            x->reshape(x, size(x,2), size(x,1)) # just a transpose 
            ) 
end  
#m(trd[1])


function Run()
    trd, tsd, arr = LoadData()
    m = model(arr)
    loss(x,y) = Flux.mse(m(x), y)
    parms = Flux.params(m)
    testloss() = Flux.mse(m(tsd.data[1]), tsd.data[2]) 
    testloss()
    evalcb = () -> @show testloss()
    opt = ADAM(arr.lr)
    for i = 1:arr.epos
        Flux.train!(loss, parms, trd, opt, cb = throttle(evalcb, 1)) #
    end 
end 

Run()

