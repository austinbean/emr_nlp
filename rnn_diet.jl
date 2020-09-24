# RNN for Diet Data
# https://fluxml.ai/Flux.jl/stable/models/recurrence/#Sequences-1
# this is the answer:
# https://github.com/FluxML/model-zoo/blob/master/text/lang-detection/model.jl


# load the file punctuation_strip.jl and run that function first to remove punctuation and standardize
    # loads the function string_cleaner
@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 256            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 5       # throttle timeout
	test_d::Int = 600       # length of the testing set.
end




"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

"""
function LoadData()
		# Load and clean 
	xfile = CSV.read("./data_labeled.csv", DataFrame);

	# TODO - there is nothing called column 1, column 2.  col1 -> diet, col2 -> total_quantity 
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :diet]));
	words = string_cleaner.(words) ;	      # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))
	words = map( x->x*" <EOS>", words) ;   # add <EOS> to the end of every sentence.
	labels = filter( x-> !ismissing(x), xfile[!, :total_quantity]);
		# create an instance of the type
	args = Args()
		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
	nwords = size(allwords,1)                                                           # how many unique words are there?
	args.inpt_dim = nwords                                                              # # of unique words is dimension of input to first layer.
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
