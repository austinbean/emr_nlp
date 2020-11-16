# use rnn_diet.jl to define a function to import the data, then put an include statement at the top of this one.

#=
Reminder that this only does formula so far.  
Experiments to do:
- regularization 
- hidden layers.
- node changes: 64 128 256 512 1024 2048 
- switch to relu, it seems.  
=#


module Runner

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
using Functors 
using Embeddings
using Embeddings: EmbeddingTable
using Dates


#include("./punctuation_strip.jl")
#include("./s_split.jl")
#include("./rnn_embeddings.jl")

include("/home/beana1/emr_nlp/punctuation_strip.jl")
include("/home/beana1/emr_nlp/s_split.jl")
include("/home/beana1/emr_nlp/rnn_embeddings.jl")



@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 256            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 1       # throttle timeout
    test_d::Int = 600       # length of the testing set.
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

"""
function LoadData()
		# Load and clean 
	xfile = CSV.read("/home/beana1/emr_nlp/data_labeled.csv", DataFrame);
	#xfile = CSV.read("./data_labeled.csv", DataFrame);

	# TODO - there is nothing called column 1, column 2.  col1 -> diet, col2 -> total_quantity 
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :diet]));
	words = string_cleaner.(words) ;	      # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))
	words = map( x->x*" <EOS>", words) ;   # add <EOS> to the end of every sentence.
	labels = filter( x-> !ismissing(x), xfile[!, :total_quantity]);
		# create an instance of the type
    args = Args()
        #Load the  word embeddings and assign back to args
    eTable = load_embeddings(GloVe)
    args.emb_table = eTable
    

		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
	nwords = size(allwords,1)                                                           # how many unique words are there?
	args.inpt_dim = nwords                                                              # # of unique words is dimension of input to first layer.
    args.vocab = allwords 
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
	# all_data = [(x,y) for (x,y) in zip(interim,labels)] |> shuffle                      # pair data and labels, then randomize order
		# separate test data and train data 
	train_data = interim[1:end-args.test_d]
	test_data = interim[end-args.test_d+1:end]


	train_labels = labels[1:end-args.test_d]
	test_labels = labels[end-args.test_d+1:end]
		# Return args b/c nwords may have been updated.
		# change to train via epochs.
	#Flux.Data.DataLoader(ctrain, ltrain; batchsize=100, shuffle = true), Flux.Data.DataLoader(ctest, ltest), args
		# TODO - there is a deprecation here on the DataLoader type - it doesn't want train_data... anymore.  Rewrite.  
	return Flux.Data.DataLoader(train_data, train_labels; batchsize=100, shuffle = true), Flux.Data.DataLoader((test_data, test_labels)), args
end 



"""
`one_layer(args)`
Takes as an argument the parameters in the "args" type.  
Returns two things: a 'scanner' and an 'encoder'.  
Dimension of the input needs to be # of unique words, 
so Dense(args.inpt_dim) takes an 'args.inpt_dim' type 
argument, where in LoadData() this is updated to the number of words.  
This is passed back after updating w/in the LoadData() function.
"""
function one_layers(args)
	scanner = Chain(Embed(args.vocab, args.embed_len, args.emb_table), LSTM(args.embed_len, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 



"""
`two_layers(args)`
"""
function two_layers(args)
	scanner = Chain(Embed(args.vocab, args.embed_len, args.emb_table), LSTM(args.embed_len, args.N), LSTM(args.N, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 

"""
`three_layers(args)`
"""
function three_layers(args)
	scanner = Chain(Embed(args.vocab, args.embed_len, args.emb_table), LSTM(args.embed_len, args.N), LSTM(args.N, args.N), LSTM(args.N, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 

"""
`four_layers(args)`
"""
function four_layers(args)
	scanner = Chain(Embed(args.vocab, args.embed_len, args.emb_table), LSTM(args.embed_len, args.N), LSTM(args.N, args.N), LSTM(args.N, args.N), LSTM(args.N, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 



"""
`model(x, scanner, encoder)`
Scanner is applied to the data sequentially, then I take the LAST element.
so need to make sure scanner outputs a vector, since that is the input to encoder.
Needs to output args.N x 1 vector if the encoder is to make sense.
NB: must call reset!(scanner) after each call to scanner.  
Otherwise creates a matrix which is not conformable w/ later data elements.
	Question: which matrix?  Why?  
the number of COLUMNS created is: N_words x Dim_hidden state.  So I want the last **column**.  
Flux one-hot matrix has a field called data, which is an array of one-hot vectors. 
so this DOES matter
Accessing via .data seems to change the dims?  Doing scanner.(x.data) returns an array of 
N_elements rows and N_hidden_dim columns.  Then taking scanner.(x.data)[end] returns the LAST 
one of these rows, which is what I want.  
Note then you have to take encoder(state)[1] to access the scalar in the 1x1 record.
Otherwise an error in loss b/c you can't do: [float] - float.
"""
function model(x, scanner, encoder)
	state = scanner.(x.data)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)[1]                 # this returns a vector of a single element...  annoying.  
end 


function RunIt()
	seed!(323) 
	train_data, test_data,  argg = LoadData() # words, labels will be loaded
	epoc = 100
    @info("Constructing Model...")
	scanner, encoder = three_layers(argg)     # NB: scanner and encoder have to be created first. 
	nlayers = length(scanner.layers)-1        # keep this constant 
	ps = params(scanner, encoder)             # collect the parameters to regularize
	sqnorm(x) = sum(abs2, x)
	penalty() = sum(sqnorm, params(scanner)) + sum(sqnorm,params(encoder))
	@info("Test Penalty: ", penalty())
	submod(x) = model(x, scanner, encoder)             # this is a workaround.  This broadcasts 
	loss(x, y)=  Flux.mse(submod.(x),y) + penalty()    # broadcasting the "sub-model" on the input x.
	@info("Initial Loss: ", loss(test_data.data[1], test_data.data[2]) )
	testloss() = loss(test_data.data[1], test_data.data[2])	
	opt = ADAM(argg.lr)
	evalcb = () -> @show testloss()
	loss_v = Array{Float64,1}()
	for i = 1:epoc
		@info("At ", i)
		Flux.train!(loss, ps, train_data, opt, cb = throttle(evalcb, argg.throttle))
		push!(loss_v, testloss())
		@info("Testloss ", testloss())
	end 
	t2 = Dates.format(now(),"yyyy_mm_dd")
	filename = "rnn_emb_"*string(nlayers)*"_l_"*string(argg.N)*"_n_"*string(epoc)*"_e"*t2
	# next step... predict, distribution of predictions, etc.  
	predictions = hcat(["prediction_$nlayers";submod.(test_data.data[1])], ["label_$nlayers"; test_data.data[2]])
	CSV.write("/home/beana1/emr_nlp/results/EM_RO_"*filename*".csv", Tables.table(predictions))
	CSV.write("/home/beana1/emr_nlp/results/EM_RE_"*filename*".csv", Tables.table(hcat( ["training_epoch"; collect(1:length(loss_v))],["loss_value"; loss_v])))
end 

RunIt()

end # of module Runner 


#=

"Postestimation..."

	pred_vals = Array{Float32,1}()
	actual = Array{Float32,1}()
	for i in 1:length(test_data)
		push!(actual, convert(Float32, test_data.data[2][i]))
		push!(pred_vals, model(test_data.data[1][i], scanner, encoder))
	end 
	sv = convert(DataFrame, hcat(pred_vals, actual))	

	Plots.histogram(sv.x2, bins = 10:5:maximum(sv.x2), label  = "Real Values")
	Plots.histogram!(sv.x1, bins = 0:1:(maximum(sv.x1)+1), 
			label = "Model Predictions", 
			xlabel = "Value (Ounces)", 
			ylabel = "Number of Occurences", 
            title = "RNN Model Predictions vs Real Values")
	savefig("./hist1.png")	
	
	df1 = convert(DataFrame, hcat(loss_v, zeros(length(loss_v))))
	plot(df1.x1, [1:size(loss_v,1)], xlabel = "Number of Times Trained", ylabel = "Loss Function",
        title = "Plotting the Loss Function of the RNN Model", legend = false)
    savefig("./lossf.png")

	CSV.write("./t_l_1.csv", convert(DataFrame, hcat(loss_v, zeros(length(loss_v)))))


=#

