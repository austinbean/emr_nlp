# rnn_classification

#=

which patients use formula, breast, both, no information.
Simple task, but good proof of concept, perhaps.


=#

module Run_Class_Embeddings

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
using Embeddings
using Embeddings: EmbeddingTable
using Functors
using Dates 

 # /Users/austinbean/Desktop/programs/emr_nlp
include("./punctuation_strip.jl")
include("./s_split.jl")
include("./rnn_embeddings.jl")
include("./labeler.jl")

#include("/home/beana1/emr_nlp/punctuation_strip.jl")
#include("/home/beana1/emr_nlp/s_split.jl")
#include("/home/beana1/emr_nlp/rnn_embeddings.jl")



@with_kw mutable struct Args
    lr::Float64 = 1e-1      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 1024            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 1       # throttle timeout
    test_d::Int = 600       # length of the testing set.
    classes::Int = 3        # how many classes are there?
    emb_table::Embeddings.EmbeddingTable = EmbeddingTable(zeros(2,2), zeros(3)) # has to be initialized w/ something later
    embed_len::Int = 50    # Length of vector per each word embedding
    test_len::Int = 100    # Number of unique words in test data 
    # TODO - likely deletable.  Is this used anywhere important?  Duplicates inpt_dim 
    word_list_len::Int = 0 # Total number of unique words
    vocab::Array{String, 1} = []  #All the words in the training data
end



"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

# test of filter statement below.  
df = DataFrame(diet_text=["hi", missing, "bye"], total_formula=[missing, 1, 2])
# should be ["bye", 2] and it is.  
"""
function LoadData()
	seed!(0) # for shuffle
		# Load 
	xfile = CSV.read("/Users/austinbean/Desktop/diet_local/formula_subset.csv", DataFrame);	 
	#	xfile = CSV.read("/home/beana1/emr_nlp/class_label.csv", DataFrame);
		# Shuffle DataFrame rows, making a copy  
	xfile = xfile[shuffle(1:size(xfile, 1)),:]
		# this filter must check whether :diet_text is not missing AND whether :total_formula is not missing.  
	xfile = filter(x-> (!ismissing(x[:diet_text])&(!ismissing(x[:total_formula])&(isa(x[:diet_text], String)))), xfile)
		# then subset out words separately.  
	words = convert(Array{String,1}, xfile[!, :diet_text]);
	words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))
	words = map( x->x*" <EOS>", words) ;                                                # add <EOS> to the end of every sentence.
		# create an instance of the type
	args = Args()

    	#Load the  word embeddings and assign back to args
    eTable = load_embeddings(GloVe)
    args.emb_table = eTable
    	# get the labels
	labels = labeler(xfile[!,:total_formula])[:,2] 
   		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
	nwords = size(allwords,1)                                                           # how many unique words are there?
	args.inpt_dim = nwords                                                              # # of unique words is dimension of input to first layer.
    args.vocab = allwords 
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
    	#one-hot batch the labels 
    all_labels = [unique(labels); -1]                                                   # how many classes?
    args.classes = size(all_labels,1)     
    interim_labels = map( v-> Flux.onehot(v, all_labels, -1), labels)		
		# subset test/train	
	test_ix = convert(Int64,floor(0.7*size(xfile,1)))
	train_data = interim[1:test_ix,:]
	train_data = reshape(train_data, 1, size(train_data,1)) # NB: dataloader makes last dimension the observation dim.
	test_data = interim[(test_ix+1):end, :]
	test_data = reshape(test_data, 1, size(test_data,1)) # NB: dataloader makes last dimension the observation dim.
	train_labels = reshape(interim_labels[1:test_ix],1, size(interim_labels[1:test_ix],1))
	test_labels = reshape(interim_labels[(test_ix+1):end],1, size(interim_labels[(test_ix+1):end],1))
	return Flux.DataLoader((data=train_data, label=train_labels), batchsize=100, shuffle=true), Flux.DataLoader((data=test_data,label=test_labels)), args
end 




"""
`two_layers(args)`
"""
function two_layers(args)
    scanner = Chain(Embed(args.vocab, args.embed_len, args.emb_table), LSTM(args.embed_len, args.N), LSTM(args.N, args.N))
    encoder = Dense(args.N, args.classes, identity)
	return scanner, encoder 
end 

function model(x, scanner, encoder)
	# TODO - this can't broadcast in the same way anymore?  
	state = scanner.(x)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)                    # this returns a vector of a single element...  annoying.  
end 


function DoIt()
    seed!(323) 
	train_data, test_data,  argg = LoadData() # words, labels will be loaded
    epoc = 10
	# TODO - rewrite scanner and encoder b/c something has changed.  
    scanner, encoder = two_layers(argg)       # NB: scanner and encoder have to be created first. 
	nlayers = length(scanner.layers)-1        # keep this constant 
    ps = params(scanner, encoder)   
# TODO - this doesn't broadcast to the right dims?  It is for sure a problem w/ the embed layer.  
    # yes, wrong dims on the embed layer. :( 
    submod(x) = model(x, scanner, encoder)
    loss(x,y) = sum(Flux.logitcrossentropy.(submod.(x), y))
    testloss() = loss(test_data.data.data, test_data.data.label)
    testloss()
    opt = ADAM(argg.lr)
	evalcb = ()-> @show testloss()
	loss_v = Array{Float64,1}()

    for i = 1:epoc
        @info("At ", i)
		Flux.train!(loss, ps, train_data,opt, cb = throttle(evalcb, argg.throttle))
		push!(loss_v, testloss())
		@info("Testloss ", testloss())
	end 
	t2 = Dates.format(now(),"yyyy_mm_dd")

	# record the predictions 	
	predictions = map(v -> v[2], findmax.(softmax.(submod.(test_data.data[1]))))
	ix_labels = map( v-> convert(Int64, v.ix), test_data.data[2])
	# save the predictions and the training error:
	filename = "RNEMCL_"*string(nlayers)*"_l_"*string(argg.N)*"_n_"*string(epoc)*"_e"*t2
	CSV.write("/home/beana1/emr_nlp/results/CE_"*filename*".csv", Tables.table(hcat( ["training_epoch"; collect(1:length(loss_v))],["loss_value"; loss_v])))
	CSV.write("/home/beana1/emr_nlp/results/CO_"*filename*".csv", Tables.table(hcat( ["predicted_class"; predictions], ["actual_label"; ix_labels] )) )
end 
DoIt()

end # of module 