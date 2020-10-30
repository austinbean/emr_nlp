# rnn_classification

#=

which patients use formula, breast, both, no information.
Simple task, but good proof of concept, perhaps.

=#


using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Statistics: mean
using Random: shuffle, seed! 
using Parameters: @with_kw
using Plots 
using Tables 

 # /Users/austinbean/Desktop/programs/emr_nlp
include("./punctuation_strip.jl")
include("./s_split.jl")
#include("/home/beana1/emr_nlp/punctuation_strip.jl")
#include("/home/beana1/emr_nlp/s_split.jl")
#include("./rnn_diet.jl")



@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 256            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 1       # throttle timeout
    test_d::Int = 600       # length of the testing set.
    classes::Int = 3        # how many classes are there?
end



"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

"""
function LoadData()
		# Load and clean 
	#xfile = CSV.read("/home/beana1/emr_nlp/data_labeled.csv", DataFrame);
	xfile = CSV.read("./data_labeled.csv", DataFrame);

	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :diet]));
	words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))
	words = map( x->x*" <EOS>", words) ;                                                # add <EOS> to the end of every sentence.
	labels = filter( x-> !ismissing(x), xfile[!, 3]);                                   # 3rd col labels.
		# create an instance of the type
	args = Args()
		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
	nwords = size(allwords,1)                                                           # how many unique words are there?
	args.inpt_dim = nwords                                                              # # of unique words is dimension of input to first layer.
	interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
    #one-hot batch the labels 
    all_labels = [unique(labels); -1]                                                   # how many classes?
    args.classes = size(all_labels,1)     
    interim_labels = map( v-> Flux.onehot(v, all_labels, -1), labels)		

    # separate test data and train data 
	train_data = interim[1:end-args.test_d]
	test_data = interim[end-args.test_d+1:end]

	train_labels = interim_labels[1:end-args.test_d]
	test_labels = interim_labels[end-args.test_d+1:end]
		# Return args b/c nwords may have been updated.
		# change to train via epochs.
	#Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest), args
	return Flux.Data.DataLoader(train_data, train_labels; batchsize=100, shuffle = true), Flux.Data.DataLoader((test_data, test_labels)), args
end 




"""
`two_layers(args)`
"""
function two_layers(args)
    scanner = Chain(Dense(args.inpt_dim, args.N, σ), LSTM(args.N, args.N), LSTM(args.N, args.N))
    encoder = Dense(args.N, args.classes, identity)
	return scanner, encoder 
end 

function model(x, scanner, encoder)
	state = scanner.(x.data)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)                    # this returns a vector of a single element...  annoying.  
end 


function DoIt()
    seed!(323) 
	train_data, test_data,  argg = LoadData() # words, labels will be loaded
    epoc = 5
    scanner, encoder = two_layers(argg)       # NB: scanner and encoder have to be created first. 
	nlayers = length(scanner.layers)-1        # keep this constant 
    ps = params(scanner, encoder)   
    submod(x) = model(x, scanner, encoder)
    loss(x,y) = sum(Flux.logitcrossentropy.(submod.(x), y))
    testloss() = loss(test_data.data[1], test_data.data[2])
    testloss()
    opt = ADAM(argg.lr)
    evalcb = ()-> @show testloss()
    for i = 1:epoc
        @info("At ", i)
        Flux.train!(loss, ps, train_data,opt, cb = throttle(evalcb, argg.throttle))
    end 
end 
DoIt()

